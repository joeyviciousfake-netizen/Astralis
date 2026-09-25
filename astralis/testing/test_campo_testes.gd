extends "res://testing/astralis_test_base.gd"

## test_campo_testes — GUT do Campo de Testes, a tab Testes do Studio (R2: sem Fake).
## Trava o contrato systems `duel_setup.test_state` V1 (schemas/duel_setup.schema.json)
## + a leitura real no DuelManager (astralis/duel/duel_manager.gd):
## (1) com test_state, o duelo começa em p0 na fase DRAW (fase da mão, D24);
## (2) my_hand (2 FM reais) vira a mão de p0 NA ORDEM + refill real até 5;
## (3) p0/p1_monster viram instâncias REAIS (SummonSystem.construir_instancia,
##     o construtor único R1: ATK/DEF da base, face_down = !face_up,
##     position ATK/DEF, estrela = guardian_star_1 do dado);
## (4) null = vazio (as magias dos 2 lados ficam vazias);
## (5) seed fixa = mesmo campo + mesma mão em 2 montagens;
## (6) sem test_state, tudo igual a antes (5/5, campo vazio, ordem do setup);
## (7) com test_state, turno 1 BATTLE: ataque de p0 funciona e mata/dá dano
##     como o motor manda (fm_0001 3000 vs fm_0004 1200 = 1800 de dano);
## (8) sem test_state, turno 1 BATTLE: ataque de p0 continua bloqueado com
##     "Sem ataque no 1º turno." (D15/D17 vale no duelo normal).
## Fixtures FM reais: fm_0001 Blue-eyes 3000/2500 sol, fm_0002 Mystical Elf
## 800/2000, fm_0003 Hitotsu-me 1200/1000 lua, fm_0004 Baby Dragon 1200/700.
## Seed fixa 42 (a do duel_setup FM). Bug aqui vira teste permanente.
## Helpers (ProjectLoaderScript/DuelManagerScript/SummonSystem/
## _indice_monstro_na_mao) vêm de astralis_test_base.gd.

const BattleSystem := preload("res://duel/battle_system.gd")


# Monta o setup FM de verdade + test_state do contrato (só dado, R3).
func _setup_com_teste() -> Dictionary:
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	var setup: Dictionary = ((data as Dictionary).get("duel_setup", {}) as Dictionary).duplicate(true)
	setup["turn_order"] = "first_p1"
	setup["seed"] = 42
	setup["test_state"] = {
		"my_hand": ["fm_0001", "fm_0002"],
		"p0_monster": [
			{"card_id": "fm_0001"},
			{"card_id": "fm_0003", "face_up": false, "attack_position": false},
			null, null, null,
		],
		"p0_spell": [null, null, null, null, null],
		"p1_monster": [
			{"card_id": "fm_0004"},
			null, null, null, null,
		],
		"p1_spell": [null, null, null, null, null],
	}
	return setup


# Duelo de teste montado pelo DuelManager REAL (quem lê o test_state).
func _duelo_com_teste():
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	return DuelManagerScript.new_duel(_setup_com_teste(), data.get("decks", {}), data.get("cards", {}))


# Ids ("id" do dado) das cartas na mão de um lado, na ordem.
func _ids_da_mao(st, pi: int) -> Array:
	var out: Array = []
	for c in ((st.players[pi] as Dictionary)["hand"] as Array):
		out.append(str((c as Dictionary).get("id", "")))
	return out


func test_comeca_em_p0_na_fase_da_mao() -> void:
	# (1) Com test_state, o duelo começa em p0 na fase DRAW (fase da mão, D24):
	# a mesa real sempre abre em FASE_MAO e o motor força current_player 0.
	var duel = _duelo_com_teste()
	var st = duel.get_state()
	assert_eq(int(st.current_player), 0, "Campo de Testes começa em p0 (sua vez).")
	assert_eq(String(st.phase), "DRAW", "Começa na fase DRAW (fase da mão, D24).")
	assert_eq(int(st.turn_number), 1, "Começa no turno 1.")
	assert_eq(int((st.players[0] as Dictionary)["lp"]), 8000, "Seu LP é o do setup (8000).")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), 8000, "LP do rival é o do setup (8000).")
	assert_false(duel.is_over(), "Duelo recém-montado não acabou.")
	assert_eq(duel.get_winner(), -1, "Sem vencedor no início.")


func test_mao_p0_na_ordem_com_refill_ate_5() -> void:
	# (2) my_hand vira a mão de p0 NA ORDEM; o resto completa até 5 pela
	# regra real (TurnManager DRAW refill, o mesmo motor do turno).
	var duel = _duelo_com_teste()
	var st = duel.get_state()
	var ids: Array = _ids_da_mao(st, 0)
	assert_eq(ids.size(), 5, "Sua mão tem 5 cartas (2 pedidas + refill até 5).")
	assert_eq(str(ids[0]), "fm_0001", "1ª carta é a 1ª pedida (fm_0001 Blue-eyes).")
	assert_eq(str(ids[1]), "fm_0002", "2ª carta é a 2ª pedida (fm_0002 Mystical Elf).")
	for k in [2, 3, 4]:
		assert_true(str(ids[k]) != "", "Carta %d do refill é carta de verdade (id não vazio)." % k)
	assert_eq(((st.players[0] as Dictionary)["deck"] as Array).size(), 37, "Refill tirou 3 do topo do seu deck (40-3).")
	assert_eq(_ids_da_mao(st, 1).size(), 5, "Mão do rival é normal (5 do deck).")
	assert_eq(((st.players[1] as Dictionary)["deck"] as Array).size(), 35, "Rival comprou 5 do deck (40-5).")


func test_campo_com_instancias_reais() -> void:
	# (3) O campo vem do construtor ÚNICO real (R1): ATK/DEF da base,
	# face/posição do dado, estrela = guardian_star_1. (4) null = vazio.
	var duel = _duelo_com_teste()
	var st = duel.get_state()
	var m0: Array = (st.players[0] as Dictionary)["monster"]
	var m1: Array = (st.players[1] as Dictionary)["monster"]
	var aberta: Dictionary = m0[0] as Dictionary
	assert_eq(str(aberta.get("card_id", "")), "fm_0001", "Seu slot 0 tem a fm_0001.")
	assert_eq(str(aberta.get("nome", "")), "Blue-eyes White Dragon", "Nome vem do dado FM.")
	assert_eq(int(aberta.get("atk", -1)), 3000, "ATK da base (3000).")
	assert_eq(int(aberta.get("def", -1)), 2500, "DEF da base (2500).")
	assert_false(bool(aberta.get("face_down", true)), "Aberta: face p/ cima (padrão face_up).")
	assert_eq(str(aberta.get("position", "")), "ATK", "Posição Ataque (padrão attack_position).")
	assert_eq(str(aberta.get("battle_position", "")), "ATK", "Posição de batalha Ataque.")
	assert_eq(str(aberta.get("guardian_star", "")), "sun", "Estrela = guardiã 1 do dado (sun).")
	assert_false(bool(aberta.get("has_attacked", true)), "Recém-chegada ainda não atacou.")
	var virada: Dictionary = m0[1] as Dictionary
	assert_eq(str(virada.get("card_id", "")), "fm_0003", "Seu slot 1 tem a fm_0003.")
	assert_eq(str(virada.get("nome", "")), "Hitotsu-me Giant", "Nome vem do dado FM.")
	assert_eq(int(virada.get("atk", -1)), 1200, "ATK da base (1200).")
	assert_eq(int(virada.get("def", -1)), 1000, "DEF da base (1000).")
	assert_true(bool(virada.get("face_down", false)), "Virada: face p/ baixo.")
	assert_eq(str(virada.get("position", "")), "DEF", "Virada entra em Defesa.")
	assert_eq(str(virada.get("battle_position", "")), "DEF", "Posição de batalha Defesa.")
	assert_eq(str(virada.get("guardian_star", "")), "moon", "Estrela = guardiã 1 do dado (moon).")
	for i in [2, 3, 4]:
		assert_true(m0[i] == null, "Seu slot %d vazio (null)." % i)
	var rival: Dictionary = m1[0] as Dictionary
	assert_eq(str(rival.get("card_id", "")), "fm_0004", "Slot 0 do rival tem a fm_0004.")
	assert_eq(str(rival.get("nome", "")), "Baby Dragon", "Nome vem do dado FM.")
	assert_eq(int(rival.get("atk", -1)), 1200, "ATK da base (1200).")
	assert_eq(int(rival.get("def", -1)), 700, "DEF da base (700).")
	assert_false(bool(rival.get("face_down", true)), "Rival: face p/ cima.")
	assert_eq(str(rival.get("position", "")), "ATK", "Rival em Ataque.")
	assert_eq(str(rival.get("guardian_star", "")), "uranus", "Estrela = guardiã 1 do dado (uranus).")
	for i in [1, 2, 3, 4]:
		assert_true(m1[i] == null, "Slot %d do rival vazio (null)." % i)
	for pi in [0, 1]:
		var zona: Array = (st.players[pi] as Dictionary)["spell"]
		for i in range(5):
			assert_true(zona[i] == null, "Magia p%d slot %d vazia (null)." % [pi, i])


func test_seed_fixa_mesmo_campo_e_mao() -> void:
	# (5) Seed fixa = determinismo: 2 montagens dão a mesma mão, o mesmo
	# campo e a mesma ordem de deck (embaralhar com seed 42).
	var sa = _duelo_com_teste().get_state()
	var sb = _duelo_com_teste().get_state()
	assert_eq(_ids_da_mao(sa, 0), _ids_da_mao(sb, 0), "Mesma seed: sua mão igual nas 2 montagens.")
	assert_eq(_ids_da_mao(sa, 1), _ids_da_mao(sb, 1), "Mesma seed: mão do rival igual.")
	for pi in [0, 1]:
		for i in range(5):
			var xa = (sa.players[pi] as Dictionary)["monster"][i]
			var xb = (sb.players[pi] as Dictionary)["monster"][i]
			if xa == null or xb == null:
				assert_eq(xa == null, xb == null, "Mesma seed: slot p%d m%d vazio nos 2." % [pi, i])
			else:
				assert_eq(str((xa as Dictionary).get("card_id", "")), str((xb as Dictionary).get("card_id", "")), "Mesma seed: mesma carta no slot p%d m%d." % [pi, i])
				assert_eq(str((xa as Dictionary).get("position", "")), str((xb as Dictionary).get("position", "")), "Mesma seed: mesma posição no slot p%d m%d." % [pi, i])
	var da: Array = []
	for c in ((sa.players[0] as Dictionary)["deck"] as Array):
		da.append(str((c as Dictionary).get("id", "")))
	var db: Array = []
	for c in ((sb.players[0] as Dictionary)["deck"] as Array):
		db.append(str((c as Dictionary).get("id", "")))
	assert_eq(da, db, "Mesma seed: ordem do deck restante igual.")


func test_sem_test_state_igual_a_antes() -> void:
	# (6) Sem test_state, o caminho novo nunca roda: mão 5/5, campo vazio,
	# deck 35/35 e a ordem do setup valendo (comportamento 100% igual).
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	var setup: Dictionary = ((data as Dictionary).get("duel_setup", {}) as Dictionary).duplicate(true)
	assert_false(setup.has("test_state"), "Preparo: o setup FM não tem test_state.")
	var duel = DuelManagerScript.new_duel(setup, data.get("decks", {}), data.get("cards", {}))
	var st = duel.get_state()
	assert_eq(_ids_da_mao(st, 0).size(), 5, "Sem teste: sua mão tem 5.")
	assert_eq(_ids_da_mao(st, 1).size(), 5, "Sem teste: mão do rival tem 5.")
	for pi in [0, 1]:
		for zona_nome in ["monster", "spell"]:
			var zona: Array = (st.players[pi] as Dictionary)[zona_nome]
			for i in range(5):
				assert_true(zona[i] == null, "Sem teste: campo vazio (p%d %s %d)." % [pi, zona_nome, i])
		assert_eq(((st.players[pi] as Dictionary)["deck"] as Array).size(), 35, "Sem teste: deck p%d com 35 (40-5)." % pi)
	assert_eq(int(st.current_player), 0, "Sem teste: first_p1 começa em p0 (ordem do setup vale).")
	assert_eq(String(st.phase), "DRAW", "Sem teste: começa na DRAW.")


func test_duelo_de_teste_e_jogavel() -> void:
	# O duelo montado pelo Campo de Testes aceita o fluxo real: DRAW->MAIN
	# avança e 1 invocação normal da mão de teste funciona (regra real).
	var duel = _duelo_com_teste()
	var st = duel.get_state()
	var r: Dictionary = duel.advance_phase()
	assert_true(bool(r.get("ok", false)), "DRAW -> MAIN avança no duelo de teste.")
	assert_eq(String(st.phase), "MAIN", "Fase MAIN no duelo de teste.")
	var cur: int = int(st.current_player)
	assert_eq(cur, 0, "Ainda é a vez de p0.")
	var idx: int = _indice_monstro_na_mao(st, cur)
	assert_true(idx >= 0, "Preparo: mão de teste tem monstro.")
	var slot: int = SummonSystem.free_monster_slot(st, cur)
	assert_eq(slot, 2, "Slots 0-1 ocupados pelo teste: 1º livre é o 2.")
	var rs: Dictionary = SummonSystem.normal_summon(st, cur, idx, slot)
	assert_true(bool(rs.get("ok", false)), "Invocação normal funciona no duelo de teste.")
	assert_true((st.players[cur] as Dictionary)["monster"][slot] != null, "Carta desceu no slot 2.")


func test_com_teste_turno1_p0_ataca_e_mata_como_o_motor_manda() -> void:
	# (7) Com test_state (is_test=true), o turno 1 libera o ataque de p0:
	# fm_0001 (3000 ATK aberta) vs fm_0004 (1200 ATK aberta) = destrói o alvo
	# + 1800 de dano no LP do rival, pela regra real do BattleSystem.
	var duel = _duelo_com_teste()
	var st = duel.get_state()
	assert_true(bool(st.get("is_test")), "Duelo de teste marca is_test.")
	assert_eq(int(st.turn_number), 1, "Preparo: turno 1.")
	assert_eq(int(st.current_player), 0, "Preparo: vez de p0.")
	var r1: Dictionary = duel.advance_phase() # DRAW -> MAIN
	assert_true(bool(r1.get("ok", false)), "DRAW -> MAIN avança no turno 1 de teste.")
	assert_eq(String(st.phase), "MAIN", "Preparo: estamos na MAIN.")
	var r2: Dictionary = duel.advance_phase() # MAIN -> BATTLE
	assert_true(bool(r2.get("ok", false)), "MAIN -> BATTLE avança no turno 1 de teste.")
	assert_eq(String(st.phase), "BATTLE", "Preparo: estamos na BATTLE do turno 1.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), 8000, "Preparo: rival começa com 8000 LP.")
	var a: Dictionary = BattleSystem.attack(st, 0, 0, 1, 0)
	assert_true(bool(a.get("ok", false)), "Com test_state, p0 ataca no turno 1.")
	assert_true(bool(a.get("destruiu_alvo", false)), "3000 > 1200: Baby Dragon foi destruída.")
	assert_false(bool(a.get("destruiu_atacante", true)), "Blue-eyes sobrevive.")
	assert_eq(int(a.get("dano", -1)), 1800, "Dano é a diferença 3000-1200=1800.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), 6200, "LP do rival: 8000-1800=6200.")
	assert_true((st.players[1] as Dictionary)["monster"][0] == null, "Slot 0 do rival ficou vazio.")
	assert_true((st.players[0] as Dictionary)["monster"][0] != null, "Blue-eyes segue no campo.")


func test_sem_teste_turno1_p0_continua_bloqueado() -> void:
	# (8) Sem test_state (is_test=false), D15/D17 vale: p0 invoca na MAIN do
	# turno 1 mas o ataque na BATTLE continua bloqueado com a mensagem de sempre.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	var setup: Dictionary = ((data as Dictionary).get("duel_setup", {}) as Dictionary).duplicate(true)
	assert_false(setup.has("test_state"), "Preparo: o setup FM não tem test_state.")
	var duel = DuelManagerScript.new_duel(setup, data.get("decks", {}), data.get("cards", {}))
	var st = duel.get_state()
	assert_false(bool(st.get("is_test")), "Duelo normal não marca is_test.")
	assert_eq(int(st.turn_number), 1, "Preparo: turno 1.")
	assert_eq(int(st.current_player), 0, "Preparo: vez de p0.")
	duel.advance_phase() # DRAW -> MAIN
	var cur: int = int(st.current_player)
	_garantir_monstros_na_mao(st, cur, 1)
	var i: int = _indice_monstro_na_mao(st, cur)
	assert_true(i >= 0, "Preparo: mão tem monstro (carta FM de verdade).")
	var rs: Dictionary = SummonSystem.normal_summon(st, cur, i, 0)
	assert_true(bool(rs.get("ok", false)), "Preparo: invocação na MAIN funciona.")
	var rb: Dictionary = duel.advance_phase() # MAIN -> BATTLE
	assert_true(bool(rb.get("ok", false)), "MAIN -> BATTLE avança.")
	assert_eq(String(st.phase), "BATTLE", "Preparo: estamos na BATTLE do turno 1.")
	var a: Dictionary = BattleSystem.attack(st, cur, 0, 1 - cur, -1)
	assert_false(bool(a.get("ok", false)), "Sem test_state, p0 não ataca no turno 1.")
	assert_eq(str(a.get("erro", "")), "Sem ataque no 1º turno.", "Erro do turno 1 é o de sempre.")
