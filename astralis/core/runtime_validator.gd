class_name RuntimeValidator
extends RefCounted

## RuntimeValidator — checa o Starter Kit carregado (só leitura, R5).
## Checa: schema_version==1, refs (deck->cartas, duel_setup->duelistas/decks,
## fusão->cartas) e starting_lp>0. Retorna lista de erros em PT-BR simples.
## Lista vazia = tudo certo.

static func validate(data: Dictionary) -> Array:
	var erros: Array = []
	var cards: Dictionary = data.get("cards", {})
	var duelists: Dictionary = data.get("duelists", {})
	var decks: Dictionary = data.get("decks", {})
	var fusions: Dictionary = data.get("fusions", {})
	var effects: Dictionary = data.get("effects", {})
	var duel_setup: Dictionary = data.get("duel_setup", {})

	# 1. schema_version == 1 em tudo.
	for cid in cards:
		var c: Variant = cards[cid]
		if not (c is Dictionary) or int((c as Dictionary).get("schema_version", -1)) != 1:
			erros.append("Carta '" + str(cid) + "' com versão errada (esperava schema_version 1).")
	for did in duelists:
		var d: Variant = duelists[did]
		if not (d is Dictionary) or int((d as Dictionary).get("schema_version", -1)) != 1:
			erros.append("Duelista '" + str(did) + "' com versão errada (esperava schema_version 1).")
	for kid in decks:
		var k: Variant = decks[kid]
		if not (k is Dictionary) or int((k as Dictionary).get("schema_version", -1)) != 1:
			erros.append("Deck '" + str(kid) + "' com versão errada (esperava schema_version 1).")
	if not fusions.is_empty() and int(fusions.get("schema_version", -1)) != 1:
		erros.append("Fusões com versão errada (esperava schema_version 1).")
	if not effects.is_empty() and int(effects.get("schema_version", -1)) != 1:
		erros.append("Efeitos com versão errada (esperava schema_version 1).")
	if not duel_setup.is_empty() and int(duel_setup.get("schema_version", -1)) != 1:
		erros.append("Duelo inicial com versão errada (esperava schema_version 1).")

	# 2. Toda carta citada no deck precisa existir.
	for deck_id in decks:
		var deck: Variant = decks[deck_id]
		if not (deck is Dictionary):
			continue
		var lista: Array = (deck as Dictionary).get("cards", [])
		for ref in lista:
			var ref_id: String = str(ref)
			if not cards.has(ref_id):
				erros.append("Deck '" + str(deck_id) + "' usa carta que não existe: '" + ref_id + "'.")

	# 3. duel_setup precisa apontar para duelista/deck que existem + LP > 0.
	if not duel_setup.is_empty():
		for lado in ["duelist1", "duelist2"]:
			if duel_setup.has(lado):
				var slot: Variant = duel_setup[lado]
				if slot is Dictionary:
					var did2: String = str((slot as Dictionary).get("duelist_id", ""))
					var kid2: String = str((slot as Dictionary).get("deck_id", ""))
					if did2 != "" and not duelists.has(did2):
						erros.append("Duelo usa duelista que não existe: '" + did2 + "'.")
					if kid2 != "" and not decks.has(kid2):
						erros.append("Duelo usa deck que não existe: '" + kid2 + "'.")
		var lp: int = int(duel_setup.get("starting_lp", 0))
		if lp <= 0:
			erros.append("Vida inicial (LP) precisa ser maior que 0.")

	# 4. Fusão: entrada e resultado precisam ser cartas que existem.
	var recipes: Array = fusions.get("recipes", [])
	for r in recipes:
		if r is Dictionary:
			var rd: Dictionary = r
			var rid: String = str(rd.get("id", "fusão sem nome"))
			var inp: Variant = rd.get("input", {})
			if inp is Dictionary:
				for campo in ["card_a", "card_b"]:
					var need: String = str((inp as Dictionary).get(campo, ""))
					if need != "" and not cards.has(need):
						erros.append("Fusão '" + rid + "' usa carta que não existe: '" + need + "'.")
			var res_id: String = str(rd.get("result", ""))
			if res_id != "" and not cards.has(res_id):
				erros.append("Fusão '" + rid + "' cria carta que não existe: '" + res_id + "'.")
	var rules: Array = fusions.get("rules", [])
	for rl in rules:
		if rl is Dictionary:
			var rld: Dictionary = rl
			var res2: String = str(rld.get("result", ""))
			if res2 != "" and not cards.has(res2):
				erros.append("Regra de fusão '" + str(rld.get("id", "regra sem nome")) + "' cria carta que não existe: '" + res2 + "'.")

	return erros
