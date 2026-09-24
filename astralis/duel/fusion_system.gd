class_name DuelFusionSystem
extends RefCounted

## FusionSystem — fusão fiel FM, sistema REAL (R1/R2, D08).
## - RECEITA EXPLÍCITA primeiro (input card_a+card_b -> result, ordem não importa);
## - REGRA GENÉRICA fallback (when tipo+atributo+min_atk -> result, por priority maior);
## - EQUIPAMENTO sem tabela ainda: qualquer par com equip cai no fracasso
##   e só reporta "equip pendente" (fica pendente, sem fingir).
## - CADEIA par a par EM ORDEM: acumulada + novata; sucesso vira nova acumulada,
##   fracasso descarta a ACUMULADA (a fundida cai p/ o cemitério, a novata fica
##   e continua). Resultado sempre face p/ cima, vai à zona e conta como a
##   jogada do turno (normal_summon_used).
## R3: tudo vem do DADO (fusions.json + cards); a ordem/prioridade é LOGIC fixa.

static func _id_carta(carta: Dictionary) -> String:
	return str(carta.get("id", ""))


static func _tipo(carta: Dictionary) -> String:
	return str(carta.get("card_type", ""))


static func _monster_type(carta: Dictionary) -> String:
	return str(carta.get("monster_type", ""))


static func _attribute(carta: Dictionary) -> String:
	return str(carta.get("attribute", ""))


static func _atk(carta: Dictionary) -> int:
	return int(carta.get("attack", 0))


## Receita exata A+B (ordem não importa). Volta {ok, result, recipe_id}.
static func find_recipe(fusions: Dictionary, id_a: String, id_b: String) -> Dictionary:
	var lista: Array = fusions.get("recipes", []) as Array
	if id_a.strip_edges().is_empty() or id_b.strip_edges().is_empty():
		return {"ok": false}
	for r in lista:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r as Dictionary
		var inp = rd.get("input", {})
		if not (inp is Dictionary):
			continue
		var a := str((inp as Dictionary).get("card_a", ""))
		var b := str((inp as Dictionary).get("card_b", ""))
		if (a == id_a and b == id_b) or (a == id_b and b == id_a):
			return {"ok": true, "result": str(rd.get("result", "")), "recipe_id": str(rd.get("id", ""))}
	return {"ok": false}


## Uma regra "when" casa com 2 cartas (dado puro)? Campos ausentes/vazios = coringa.
## type_a -> monster_type, attribute_a -> attribute, min_atk olha a MAIOR ATK
## das duas (igual ao Studio, documentado na tela).
static func _regra_casa(when: Dictionary, carta_a: Dictionary, carta_b: Dictionary) -> bool:
	var ta := str(when.get("type_a", ""))
	if not ta.strip_edges().is_empty() and _monster_type(carta_a) != ta:
		return false
	var aa := str(when.get("attribute_a", ""))
	if not aa.strip_edges().is_empty() and _attribute(carta_a) != aa:
		return false
	var tb := str(when.get("type_b", ""))
	if not tb.strip_edges().is_empty() and _monster_type(carta_b) != tb:
		return false
	var ab := str(when.get("attribute_b", ""))
	if not ab.strip_edges().is_empty() and _attribute(carta_b) != ab:
		return false
	if when.has("min_atk"):
		var minimo := int(when.get("min_atk", 0))
		var maior := maxi(_atk(carta_a), _atk(carta_b))
		if maior < minimo:
			return false
	return true


## Regra fallback por priority (maior primeiro, desempate por id p/ ser
## determinístico). Tenta as 2 ordens (A,B e B,A). Volta {ok, result, rule_id}.
static func find_rule(fusions: Dictionary, carta_a: Dictionary, carta_b: Dictionary) -> Dictionary:
	var lista: Array = fusions.get("rules", []) as Array
	if lista.is_empty():
		return {"ok": false}
	var ordenadas: Array = lista.duplicate()
	ordenadas.sort_custom(func(x, y):
		var px := int((x as Dictionary).get("priority", 0)) if x is Dictionary else 0
		var py := int((y as Dictionary).get("priority", 0)) if y is Dictionary else 0
		if px == py:
			return str((x as Dictionary).get("id", "")) < str((y as Dictionary).get("id", ""))
		return px > py
	)
	for r in ordenadas:
		if not (r is Dictionary):
			continue
		var rd: Dictionary = r as Dictionary
		var when = rd.get("when", {})
		if not (when is Dictionary):
			continue
		if _regra_casa(when as Dictionary, carta_a, carta_b) or _regra_casa(when as Dictionary, carta_b, carta_a):
			return {"ok": true, "result": str(rd.get("result", "")), "rule_id": str(rd.get("id", ""))}
	return {"ok": false}


## Tenta 1 par: receita -> equip pendente -> regra -> falha.
## (Equip antes da regra: sem tabela ainda, qualquer par com equip cai no
## fracasso e só reporta, nunca usa regra genérica.)
## Sempre volta {ok, tipo, result_id, result_card, mensagem}.
## tipo: "receita" | "regra" | "equip_pendente" | "falha".
static func try_fuse_pair(carta_a: Dictionary, carta_b: Dictionary, fusions: Dictionary, cards_db: Dictionary) -> Dictionary:
	var id_a := _id_carta(carta_a)
	var id_b := _id_carta(carta_b)
	if id_a.is_empty() or id_b.is_empty():
		return {"ok": false, "tipo": "falha", "result_id": "", "mensagem": "Par sem ID não funde."}
	var rec: Dictionary = find_recipe(fusions, id_a, id_b)
	if bool(rec.get("ok", false)):
		var rid := str(rec.get("result", ""))
		var dado: Dictionary = (cards_db.get(rid, {}) as Dictionary).duplicate(true) if cards_db.has(rid) else {}
		if dado.is_empty():
			dado = {"id": rid, "name": rid, "card_type": "monster", "monster_type": "beast", "attribute": "earth", "attack": 0, "defense": 0}
		return {"ok": true, "tipo": "receita", "result_id": rid, "result_card": dado, "recipe_id": str(rec.get("recipe_id", "")), "mensagem": "Receita: %s + %s = %s." % [id_a, id_b, rid]}
	# Equip sem tabela ainda: qualquer lado com equip cai no fracasso e só reporta.
	var ta := _tipo(carta_a)
	var tb := _tipo(carta_b)
	if ta == "equip" or tb == "equip":
		return {"ok": false, "tipo": "equip_pendente", "result_id": "", "mensagem": "Equip ainda sem tabela: %s + %s não funde (pendente)." % [id_a, id_b]}
	var reg: Dictionary = find_rule(fusions, carta_a, carta_b)
	if bool(reg.get("ok", false)):
		var rid2 := str(reg.get("result", ""))
		var dado2: Dictionary = (cards_db.get(rid2, {}) as Dictionary).duplicate(true) if cards_db.has(rid2) else {}
		if dado2.is_empty():
			dado2 = {"id": rid2, "name": rid2, "card_type": "monster", "monster_type": "beast", "attribute": "earth", "attack": 0, "defense": 0}
		return {"ok": true, "tipo": "regra", "result_id": rid2, "result_card": dado2, "rule_id": str(reg.get("rule_id", "")), "mensagem": "Regra %s: %s + %s = %s." % [str(reg.get("rule_id", "")), id_a, id_b, rid2]}
	return {"ok": false, "tipo": "falha", "result_id": "", "mensagem": "%s + %s não fundem." % [id_a, id_b]}


## Resolve a cadeia EM ORDEM (levantadas): acumulada + novata, par a par.
## Sucesso: acumulada vira o resultado e continua.
## Fracasso (inclui equip_pendente): descarta a ACUMULADA (vai p/ descartes),
## a novata fica como nova acumulada e continua.
## Volta {ok, final_id, final_card, passos, descartes, mensagem}.
static func resolve_chain(cartas: Array, fusions: Dictionary, cards_db: Dictionary) -> Dictionary:
	if cartas.size() < 2:
		return {"ok": false, "erro": "Precisa de ao menos 2 cartas p/ fundir."}
	var acumulada: Dictionary = (cartas[0] as Dictionary).duplicate(true)
	var aid := _id_carta(acumulada)
	if aid.is_empty():
		return {"ok": false, "erro": "Primeira carta sem ID."}
	var passos: Array = []
	var descartes: Array = []
	for i in range(1, cartas.size()):
		var novata = cartas[i]
		if not (novata is Dictionary):
			passos.append({"a": aid, "b": "", "tipo": "falha", "mensagem": "Carta %d inválida, ignorada." % i})
			continue
		var nd: Dictionary = novata as Dictionary
		var nid := _id_carta(nd)
		var tent: Dictionary = try_fuse_pair(acumulada, nd, fusions, cards_db)
		if bool(tent.get("ok", false)):
			var rid := str(tent.get("result_id", ""))
			passos.append({"a": aid, "b": nid, "tipo": str(tent.get("tipo", "")), "result_id": rid, "mensagem": str(tent.get("mensagem", ""))})
			var prox: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
			if prox.is_empty():
				prox = {"id": rid, "name": rid, "card_type": "monster", "monster_type": "beast", "attribute": "earth", "attack": 0, "defense": 0}
			acumulada = prox
			aid = rid
		else:
			var tipo_f := str(tent.get("tipo", "falha"))
			passos.append({"a": aid, "b": nid, "tipo": tipo_f, "result_id": "", "mensagem": str(tent.get("mensagem", ""))})
			descartes.append(aid)
			acumulada = nd.duplicate(true)
			aid = nid
	return {"ok": true, "erro": "", "final_id": aid, "final_card": acumulada, "passos": passos, "descartes": descartes, "mensagem": "Cadeia com %d passos, %d descartes." % [passos.size(), descartes.size()]}


static func can_fusion_summon(state, player_idx: int, hand_indices: Array, slot_idx: int) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou."}
	if String(state.phase) != "MAIN":
		return {"ok": false, "erro": "Fusão só na sua MAIN."}
	if int(state.current_player) != player_idx:
		return {"ok": false, "erro": "Só o jogador da vez pode fundir."}
	if bool(state.normal_summon_used):
		return {"ok": false, "erro": "Só 1 jogada por turno (fusão conta como a jogada)."}
	if hand_indices.size() < 2:
		return {"ok": false, "erro": "Levante ao menos 2 cartas p/ fundir."}
	var vistos := {}
	var mao: Array = (state.players[player_idx] as Dictionary)["hand"]
	for h in hand_indices:
		if not (h is int):
			return {"ok": false, "erro": "Carta inválida na mão."}
		var hi: int = h
		if hi < 0 or hi >= mao.size():
			return {"ok": false, "erro": "Carta inválida na mão."}
		if vistos.has(hi):
			return {"ok": false, "erro": "Carta repetida na fusão."}
		vistos[hi] = true
		var c = mao[hi]
		if not (c is Dictionary):
			return {"ok": false, "erro": "Carta inválida na mão."}
		var t := str((c as Dictionary).get("card_type", ""))
		if t != "monster" and t != "equip":
			return {"ok": false, "erro": "Só monstro e equip participam da fusão."}
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	if slot_idx < 0 or slot_idx >= zona.size():
		return {"ok": false, "erro": "Slot de monstro inválido (0 a %d)." % (zona.size() - 1)}
	if zona[slot_idx] != null:
		return {"ok": false, "erro": "Slot de monstro ocupado."}
	return {"ok": true, "erro": ""}


## Executa a fusão e desce o resultado na zona (fluxo normal).
## - tira as levantadas da mão EM ORDEM, resolve a cadeia, desce o final
##   em ATK virado p/ cima (face_down=false) no slot, conta como a jogada;
## - descartes (acumuladas que falharam) vão ao cemitério;
## - final precisa ser monstro (equip puro ainda sem tabela não desce).
static func perform_fusion_summon(state, player_idx: int, hand_indices_ordered: Array, slot_idx: int, fusions: Dictionary, cards_db: Dictionary) -> Dictionary:
	var pode: Dictionary = can_fusion_summon(state, player_idx, hand_indices_ordered, slot_idx)
	if not bool(pode.get("ok", false)):
		return pode
	var p: Dictionary = state.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	# Guarda as cartas EM ORDEM de levantamento antes de tirar da mão.
	var em_ordem: Array = []
	for h in hand_indices_ordered:
		em_ordem.append((mao[int(h)] as Dictionary).duplicate(true))
	# Tira da mão do maior índice p/ o menor (sem embaralhar o resto).
	var para_tirar: Array = hand_indices_ordered.duplicate()
	para_tirar.sort()
	para_tirar.reverse()
	for h in para_tirar:
		mao.remove_at(int(h))
	var cadeia: Dictionary = resolve_chain(em_ordem, fusions, cards_db)
	if not bool(cadeia.get("ok", false)):
		# Devolve as cartas p/ a mão (nada foi ao campo).
		for c in em_ordem:
			mao.append(c)
		return {"ok": false, "erro": str(cadeia.get("erro", "Fusão falhou."))}
	var final_card: Dictionary = cadeia.get("final_card", {}) as Dictionary
	var final_id := str(cadeia.get("final_id", ""))
	# Final precisa ser monstro p/ descer na zona de monstro.
	var real: Dictionary = (cards_db.get(final_id, {}) as Dictionary) if cards_db.has(final_id) else final_card
	var tipo_final := str(real.get("card_type", final_card.get("card_type", "monster")))
	if tipo_final != "monster":
		for c in em_ordem:
			mao.append(c)
		return {"ok": false, "erro": "Equip ainda sem tabela: resultado %s não desce (pendente)." % final_id, "tipo": "equip_pendente", "passos": cadeia.get("passos", []), "descartes": cadeia.get("descartes", [])}
	var atk_f := clampi(int(real.get("attack", final_card.get("attack", 0))), 0, 9999)
	var def_f := clampi(int(real.get("defense", final_card.get("defense", 0))), 0, 9999)
	var estrela := str(real.get("guardian_star_1", final_card.get("guardian_star_1", "")))
	var inst := {
		"card_id": final_id,
		"nome": str(real.get("name", final_card.get("name", "?"))),
		"atk": atk_f,
		"def": def_f,
		"position": "ATK",
		"battle_position": "ATK",
		"face_down": false,
		"guardian_star": estrela,
		"has_attacked": false,
	}
	zona[slot_idx] = inst
	state.normal_summon_used = true
	var cem: Array = p["graveyard"]
	for d in (cadeia.get("descartes", []) as Array):
		cem.append(str(d))
	return {"ok": true, "erro": "", "carta": final_id, "slot": slot_idx, "face_down": false, "position": "ATK", "guardian_star": estrela, "passos": cadeia.get("passos", []), "descartes": cadeia.get("descartes", []), "mensagem": "Fusão: %s no slot %d." % [final_id, slot_idx]}
