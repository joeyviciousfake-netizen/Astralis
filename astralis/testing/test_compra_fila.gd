extends GutTest

## test_compra_fila — GUT da compra FM fiel + fila de fusão (runtime, sem Fake R2).
## Trava o que o runtime mudou (sem mudar regra, só prepara dado e observa):
## 1) início 5/5 SEM carta extra (setup não compra; DRAW->MAIN mantém 5);
## 2) refill até 5 todo início de turno, pros 2 lados (TurnManager DRAW);
## 3) deck vazio só dá deckout na hora de COMPLETAR (mão cheia + deck vazio não perde);
## 4) animação em fila da mesa é só visual: cadeia igual + headless ok.
## Sistemas e cena REAIS (Duel/Summon/Fusion/Turn + duel_table.tscn). Seed fixa 42.
## Bug aqui vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const TurnManager := preload("res://duel/turn_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const FusionSystem := preload("res://duel/fusion_system.gd")
const MesaScene := preload("res://ui/duel_table.tscn")


# Monta um duelo novo de verdade: conteúdo FM + duel_setup (seed 42).
func _novo_duelo():
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	return DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))


func _indice_monstro_na_mao(st, player_idx: int) -> int:
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			return i
	return -1


# Só organiza dado; a regra testada continua sendo a do motor real.
func _garantir_monstros_na_mao(st, player_idx: int, quantos: int) -> void:
	var p: Dictionary = st.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var deck: Array = p["deck"]
	var k := 0
	var contados := 0
	for c in mao:
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			contados += 1
	while contados < quantos and k < deck.size():
		var c = deck[k]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			mao.append(c)
			deck.remove_at(k)
			contados += 1
		else:
			k += 1


func _mesa_nova():
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	return mesa


func test_inicio_5_5_sem_extra() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	assert_eq(String(st.phase), "DRAW", "Duelo começa na DRAW.")
	assert_eq(int(st.turn_number), 1, "Duelo começa no turno 1.")
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	assert_eq(((st.players[cur] as Dictionary)["hand"] as Array).size(), 5, "Quem começa tem 5 (sem extra, FM fiel).")
	assert_eq(((st.players[foe] as Dictionary)["hand"] as Array).size(), 5, "Quem espera tem 5.")
	for pi in [0, 1]:
		var p: Dictionary = st.players[pi] as Dictionary
		var total: int = (p["hand"] as Array).size() + (p["deck"] as Array).size()
		assert_eq(total, 40, "Jogador %d conserva as 40 cartas (mão+deck)." % pi)
		assert_eq((p["deck"] as Array).size(), 35, "Jogador %d: deck 35 após as 5 iniciais." % pi)
	var r: Dictionary = duel.advance_phase() # DRAW -> MAIN
	assert_true(bool(r.get("ok", false)), "DRAW -> MAIN avança.")
	assert_eq(String(st.phase), "MAIN", "Fase atual é MAIN.")
	assert_eq(((st.players[cur] as Dictionary)["hand"] as Array).size(), 5, "DRAW -> MAIN não compra extra (segue 5).")
	assert_eq(((st.players[foe] as Dictionary)["hand"] as Array).size(), 5, "Rival segue com 5.")


func test_refill_apos_jogar_1_carta_volta_a_5_os_2_lados() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	assert_eq(int(st.current_player), 0, "Preparo: jogador 0 começa.")
	duel.advance_phase() # DRAW -> MAIN (P0, mão 5/5 sem extra).
	assert_eq(String(st.phase), "MAIN", "Preparo: MAIN do jogador 0.")
	# P0 joga 1 carta (Summon real): mão 5 -> 4.
	_garantir_monstros_na_mao(st, 0, 1)
	var i0: int = _indice_monstro_na_mao(st, 0)
	assert_true(i0 >= 0, "Preparo: P0 tem monstro na mão.")
	var s0: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(s0 >= 0, "Preparo: P0 tem slot livre.")
	var rs0: Dictionary = SummonSystem.normal_summon(st, 0, i0, s0)
	assert_true(bool(rs0.get("ok", false)), "P0 invoca 1 (jogada do turno).")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 4, "P0 jogou 1: mão 5 -> 4.")
	# Vira o turno: MAIN -> BATTLE -> END -> DRAW (P1). P1 já tem 5, nada a completar.
	duel.advance_phase()
	duel.advance_phase()
	assert_eq(String(st.phase), "END", "Preparo: END do jogador 0.")
	var r_end1: Dictionary = duel.advance_phase() # END -> DRAW (P1).
	assert_true(bool(r_end1.get("ok", false)), "END -> DRAW do turno 2 avança.")
	assert_eq(int(st.current_player), 1, "Turno 2 é do jogador 1.")
	assert_eq(int(r_end1.get("compradas", -1)), 0, "P1 já com 5 não compra nada.")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 5, "P1 segue com 5.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 4, "P0 com 4 espera o próprio DRAW.")
	# P1 joga 1 carta: mão 5 -> 4.
	duel.advance_phase() # DRAW -> MAIN (P1).
	_garantir_monstros_na_mao(st, 1, 1)
	var i1: int = _indice_monstro_na_mao(st, 1)
	assert_true(i1 >= 0, "Preparo: P1 tem monstro na mão.")
	var s1: int = SummonSystem.free_monster_slot(st, 1)
	assert_true(s1 >= 0, "Preparo: P1 tem slot livre.")
	var rs1: Dictionary = SummonSystem.normal_summon(st, 1, i1, s1)
	assert_true(bool(rs1.get("ok", false)), "P1 invoca 1 (jogada do turno).")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 4, "P1 jogou 1: mão 5 -> 4.")
	# Vira o turno: P0 completa 4 -> 5 (lado 0 vale).
	duel.advance_phase()
	duel.advance_phase()
	var r_end2: Dictionary = duel.advance_phase() # END -> DRAW (P0).
	assert_true(bool(r_end2.get("ok", false)), "END -> DRAW do turno 3 avança.")
	assert_eq(int(st.current_player), 0, "Turno 3 é do jogador 0.")
	assert_eq(int(st.turn_number), 3, "Contador no turno 3.")
	assert_eq(int(r_end2.get("compradas", -1)), 1, "P0 completou 4 -> 5 (comprou 1).")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 5, "P0 voltou a 5 após jogar 1 e virar o turno.")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 4, "P1 com 4 espera o próprio DRAW.")
	duel.advance_phase() # DRAW -> MAIN (P0): segue 5, sem extra.
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 5, "P0 na MAIN segue com 5.")
	# Mais um giro: P0 joga 1 e P1 completa 4 -> 5 (lado 1 vale).
	_garantir_monstros_na_mao(st, 0, 1)
	var j0: int = _indice_monstro_na_mao(st, 0)
	var t0: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(j0 >= 0 and t0 >= 0, "Preparo: P0 tem monstro e slot no turno 3.")
	var rs0b: Dictionary = SummonSystem.normal_summon(st, 0, j0, t0)
	assert_true(bool(rs0b.get("ok", false)), "P0 invoca 1 no turno 3.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 4, "P0 jogou 1: mão 5 -> 4.")
	duel.advance_phase()
	duel.advance_phase()
	var r_end3: Dictionary = duel.advance_phase() # END -> DRAW (P1).
	assert_true(bool(r_end3.get("ok", false)), "END -> DRAW do turno 4 avança.")
	assert_eq(int(st.current_player), 1, "Turno 4 é do jogador 1.")
	assert_eq(int(r_end3.get("compradas", -1)), 1, "P1 completou 4 -> 5 (comprou 1).")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 5, "P1 voltou a 5 após jogar 1 e virar o turno.")
	# Conservação total: mão+deck+campo = 40 por lado (nada some nem duplica).
	for pi in [0, 1]:
		var p: Dictionary = st.players[pi] as Dictionary
		var em_campo := 0
		for m in (p["monster"] as Array):
			if m is Dictionary:
				em_campo += 1
		var total: int = (p["hand"] as Array).size() + (p["deck"] as Array).size() + em_campo
		assert_eq(total, 40, "Jogador %d conserva 40 (mão+deck+campo)." % pi)


func test_deck_vazio_ao_completar_deckout() -> void:
	# a) Mão cheia (5) + deck vazio: nada a completar, sem deckout.
	var d1 = _novo_duelo()
	var s1 = d1.get_state()
	var c1: int = int(s1.current_player)
	((s1.players[c1] as Dictionary)["deck"] as Array).clear()
	assert_eq(((s1.players[c1] as Dictionary)["hand"] as Array).size(), 5, "Preparo (a): mão cheia com 5.")
	var ra: Dictionary = TurnManager.draw_for_current(s1)
	assert_true(bool(ra.get("ok", false)), "Mão cheia com deck vazio não perde (nada a completar).")
	assert_false(bool(ra.get("deckout", false)), "Sem flag deckout na mão cheia.")
	assert_false(d1.is_over(), "Duelo segue com mão cheia e deck vazio.")
	# b) Mão 4 + 1 no deck: completa 4 -> 5, sem deckout.
	var d2 = _novo_duelo()
	var s2 = d2.get_state()
	var c2: int = int(s2.current_player)
	var deck2: Array = (s2.players[c2] as Dictionary)["deck"]
	var uma = deck2.pop_front()
	deck2.clear()
	deck2.append(uma)
	((s2.players[c2] as Dictionary)["hand"] as Array).pop_back()
	assert_eq(((s2.players[c2] as Dictionary)["hand"] as Array).size(), 4, "Preparo (b): mão com 4.")
	var rb: Dictionary = TurnManager.draw_for_current(s2)
	assert_true(bool(rb.get("ok", false)), "Com 1 no deck, completar funciona.")
	assert_eq(int(rb.get("compradas", -1)), 1, "Completou 4 -> 5 (comprou 1).")
	assert_eq(((s2.players[c2] as Dictionary)["hand"] as Array).size(), 5, "Mão 4 -> 5 com a última do deck.")
	assert_false(d2.is_over(), "Duelo segue após completar com a última carta.")
	# c) Mão 4 + deck vazio: deckout na hora de completar.
	var d3 = _novo_duelo()
	var s3 = d3.get_state()
	var c3: int = int(s3.current_player)
	((s3.players[c3] as Dictionary)["deck"] as Array).clear()
	((s3.players[c3] as Dictionary)["hand"] as Array).pop_back()
	assert_eq(((s3.players[c3] as Dictionary)["hand"] as Array).size(), 4, "Preparo (c): mão com 4 e deck vazio.")
	var rc: Dictionary = TurnManager.draw_for_current(s3)
	assert_false(bool(rc.get("ok", false)), "Completar com deck vazio falha.")
	assert_true(bool(rc.get("deckout", false)), "Flag deckout marcada ao completar sem deck.")
	assert_true(d3.is_over(), "Duelo acabou por deck out.")
	assert_eq(d3.get_winner(), 1 - c3, "Quem não tem carta perde; vence o outro jogador.")
	# d) Parcial: mão 3 + 1 no deck compra 1 (mão 4) e dá deckout no resto.
	var d4 = _novo_duelo()
	var s4 = d4.get_state()
	var c4: int = int(s4.current_player)
	var deck4: Array = (s4.players[c4] as Dictionary)["deck"]
	var sobra = deck4.pop_front()
	deck4.clear()
	deck4.append(sobra)
	((s4.players[c4] as Dictionary)["hand"] as Array).pop_back()
	((s4.players[c4] as Dictionary)["hand"] as Array).pop_back()
	assert_eq(((s4.players[c4] as Dictionary)["hand"] as Array).size(), 3, "Preparo (d): mão com 3 e 1 no deck.")
	var rd: Dictionary = TurnManager.draw_for_current(s4)
	assert_false(bool(rd.get("ok", false)), "Faltando carta p/ completar até 5, falha.")
	assert_true(bool(rd.get("deckout", false)), "Flag deckout na falta parcial.")
	assert_eq(int(rd.get("compradas", -1)), 1, "Comprou 1 antes de esvaziar (mão 3 -> 4).")
	assert_eq(((s4.players[c4] as Dictionary)["hand"] as Array).size(), 4, "Mão parcial 4 após 1 compra + deckout.")
	assert_true(d4.is_over(), "Duelo acabou por deck out parcial.")
	# e) Via virada de turno (END -> DRAW): o próximo sem carta p/ completar perde.
	var d5 = _novo_duelo()
	var s5 = d5.get_state()
	assert_eq(int(s5.current_player), 0, "Preparo (e): turno 1 do jogador 0.")
	((s5.players[1] as Dictionary)["deck"] as Array).clear()
	((s5.players[1] as Dictionary)["hand"] as Array).pop_back()
	assert_eq(((s5.players[1] as Dictionary)["hand"] as Array).size(), 4, "Preparo (e): P1 com 4 e deck vazio.")
	d5.advance_phase() # DRAW -> MAIN
	d5.advance_phase() # MAIN -> BATTLE
	d5.advance_phase() # BATTLE -> END
	var re: Dictionary = d5.advance_phase() # END -> DRAW (P1 tenta completar).
	assert_false(bool(re.get("ok", false)), "Virada sem carta p/ completar falha.")
	assert_true(bool(re.get("deckout", false)), "Flag deckout na virada de turno.")
	assert_true(d5.is_over(), "Duelo acabou na virada por deck out.")
	assert_eq(d5.get_winner(), 0, "Vence quem tinha carta (jogador 0).")


func test_animacao_nao_muda_resultado_cadeia_igual() -> void:
	# Mesa real (headless): a fila anima e a regra resolve igual, com ou sem animação.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	var fusions: Dictionary = mesa.get("_fusions_data")
	assert_true(cartas.has("fm_0002") and cartas.has("fm_0008"), "Preparo: FM tem fm_0002/fm_0008.")
	assert_true(cartas.has("fm_0638"), "Preparo: FM tem resultado fm_0638.")
	assert_false(bool(mesa.get("_fusao_animando")), "Preparo: trava da animação solta.")
	# Só organiza dado: par exato no fim da mão (ordem de levantar).
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0002"] as Dictionary).duplicate(true))
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0008"] as Dictionary).duplicate(true))
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var ordem := [n - 2, n - 1]
	var em_ordem: Array = [
		(((st.players[0] as Dictionary)["hand"] as Array)[n - 2] as Dictionary).duplicate(true),
		(((st.players[0] as Dictionary)["hand"] as Array)[n - 1] as Dictionary).duplicate(true),
	]
	# Cadeia esperada via sistema real (sem animação).
	var previa: Dictionary = FusionSystem.resolve_chain(em_ordem, fusions, cartas)
	assert_true(bool(previa.get("ok", false)), "Preparo: cadeia resolve no sistema real.")
	assert_eq(str(previa.get("final_id", "")), "fm_0638", "Preparo: fm_0002+fm_0008=fm_0638.")
	var passos_prev: Array = previa.get("passos", []) as Array
	# Foto do estado antes da animação.
	var mao_antes: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var deck_antes: int = ((st.players[0] as Dictionary)["deck"] as Array).size()
	var cem_antes: int = ((st.players[0] as Dictionary)["graveyard"] as Array).size()
	var campo_antes := 0
	for m in ((st.players[0] as Dictionary)["monster"] as Array):
		if m is Dictionary:
			campo_antes += 1
	# A fila (só visual): não pode mexer no estado nem travar.
	mesa.call("_animar_fila_fusao", em_ordem, passos_prev, ordem)
	await wait_process_frames(3)
	assert_false(bool(mesa.get("_fusao_animando")), "Fila direta não prende a trava (só _iniciar prende).")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes, "Animação não tira carta da mão.")
	assert_eq(((st.players[0] as Dictionary)["deck"] as Array).size(), deck_antes, "Animação não mexe no deck.")
	assert_eq(((st.players[0] as Dictionary)["graveyard"] as Array).size(), cem_antes, "Animação não descarta nada.")
	var campo_depois := 0
	for m in ((st.players[0] as Dictionary)["monster"] as Array):
		if m is Dictionary:
			campo_depois += 1
	assert_eq(campo_depois, campo_antes, "Animação não desce nada ao campo.")
	# A regra resolve igual após a animação (mesmo final, mesmos passos).
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(slot >= 0, "Preparo: slot livre p/ a fusão real.")
	var r: Dictionary = FusionSystem.perform_fusion_summon(st, 0, ordem, slot, fusions, cartas)
	assert_true(bool(r.get("ok", false)), "Fusão real funciona após a animação.")
	assert_eq(str(r.get("carta", "")), str(previa.get("final_id", "")), "Animação não muda o resultado (cadeia igual).")
	var passos_r: Array = r.get("passos", []) as Array
	assert_eq(passos_r.size(), passos_prev.size(), "Mesmo nº de passos com e sem animação.")
	for k in range(passos_r.size()):
		assert_eq(str((passos_r[k] as Dictionary).get("tipo", "")), str((passos_prev[k] as Dictionary).get("tipo", "")), "Passo %d do mesmo tipo." % k)
		assert_eq(str((passos_r[k] as Dictionary).get("result_id", "")), str((passos_prev[k] as Dictionary).get("result_id", "")), "Passo %d com o mesmo resultado." % k)


func test_animacao_headless_ok_sem_render() -> void:
	# Headless (comando oficial): animação vira só som/print, sem tween nem erro.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	assert_true(bool(mesa.call("_sem_render")), "Headless: sem render (DisplayServer headless).")
	assert_false(bool(mesa.get("_fusao_animando")), "Preparo: trava solta.")
	var st = mesa.get("_st")
	var mao_antes: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	# Flash + chacoalhada toleram sem render (só som, sem quebrar).
	mesa.call("_flash_fusao")
	mesa.call("_sacudir_fusao", null)
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes, "Flash/chacoalhada não mexem na mão.")
	# Fila vazia/curta sai na hora (precisa de ao menos 2).
	mesa.call("_animar_fila_fusao", [], [], [])
	mesa.call("_animar_fila_fusao", [{"id": "x"}], [], [0])
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes, "Fila vazia/curta não mexe em nada.")
	# Voo compatível (agora usa a fila) tolera headless sem erro.
	mesa.call("_animar_voo_centro", [0, 1])
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes, "Voo headless não mexe na mão.")
	assert_false(bool(mesa.get("_fusao_animando")), "Trava segue solta após animações headless.")
