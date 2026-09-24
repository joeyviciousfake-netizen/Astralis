extends GutTest

## test_duel_core — GUT sobre o motor real (R2: sem Fake).
## Monta o duelo FM de verdade (fm_duelist_01 vs fm_duelist_03, 8000 LP,
## seed 42) via DuelManager real e afirma as regras fixas do doc 13
## (LOGIC fixa): mão 5/5 sem extra + refill até 5 no DRAW, ordem DRAW→MAIN→BATTLE→END,
## 1 invocação/MAIN, 1 ataque/monstro/BATTLE, dano/cura com teto, LP<=0,
## deck out, fim em até 20 turnos e determinismo por seed.
## Fixtures FM reais (ex.: fm_0001 Blue-eyes 3000/2500 p/ forte).
## Bug aqui vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const TurnManager := preload("res://duel/turn_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const DamageSystem := preload("res://duel/damage_system.gd")


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


func _contar_monstros_na_mao(st, player_idx: int) -> int:
	var n := 0
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for c in mao:
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			n += 1
	return n


# Prepara: garante N monstros na mão puxando do topo do próprio deck.
# Só organiza dado; a regra testada continua sendo a do motor real.
func _garantir_monstros_na_mao(st, player_idx: int, quantos: int) -> void:
	var p: Dictionary = st.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var deck: Array = p["deck"]
	var k := 0
	while _contar_monstros_na_mao(st, player_idx) < quantos and k < deck.size():
		var c = deck[k]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			mao.append(c)
			deck.remove_at(k)
		else:
			k += 1


# Mesma jogada automática do main.gd (só prepara/observa, R2).
func _auto_invocar(st) -> void:
	var cur: int = int(st.current_player)
	if bool(st.normal_summon_used):
		return
	var idx_mao: int = _indice_monstro_na_mao(st, cur)
	if idx_mao < 0:
		return
	var slot: int = SummonSystem.free_monster_slot(st, cur)
	if slot < 0:
		return
	SummonSystem.normal_summon(st, cur, idx_mao, slot)


func _auto_atacar(st) -> void:
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	var zona: Array = (st.players[cur] as Dictionary)["monster"]
	for slot in range(zona.size()):
		if bool(st.over):
			return
		if zona[slot] == null:
			continue
		var m: Dictionary = zona[slot] as Dictionary
		if bool(m.get("has_attacked", false)):
			continue
		var alvo: int = BattleSystem.first_monster_slot(st, foe)
		BattleSystem.attack(st, cur, slot, foe, alvo)


func _rodar_duelo_auto(duel) -> Dictionary:
	var st = duel.get_state()
	var passos := 0
	while not duel.is_over() and int(st.turn_number) <= 20 and passos < 200:
		passos += 1
		match String(st.phase):
			"DRAW":
				duel.advance_phase()
			"MAIN":
				_auto_invocar(st)
				duel.advance_phase()
			"BATTLE":
				_auto_atacar(st)
				duel.advance_phase()
			"END":
				duel.advance_phase()
			_:
				break
	return {
		"acabou": duel.is_over(),
		"vencedor": duel.get_winner(),
		"turnos": int(st.turn_number),
		"lp0": int((st.players[0] as Dictionary)["lp"]),
		"lp1": int((st.players[1] as Dictionary)["lp"]),
	}


func test_mao_inicial_5_sem_extra() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	var mao_cur: int = ((st.players[cur] as Dictionary)["hand"] as Array).size()
	var mao_foe: int = ((st.players[foe] as Dictionary)["hand"] as Array).size()
	# FM fiel (draw up to five): 5 p/ cada lado, SEM carta extra no início.
	assert_eq(mao_foe, 5, "Quem espera começa com 5 cartas na mão.")
	assert_eq(mao_cur, 5, "Quem começa tem 5 (sem extra, FM fiel).")
	# Conservação: cada deck FM tem 40 cartas (mão + deck = 40, campo vazio).
	for pi in [0, 1]:
		var p: Dictionary = st.players[pi] as Dictionary
		var total: int = (p["hand"] as Array).size() + (p["deck"] as Array).size()
		assert_eq(total, 40, "Jogador %d conserva as 40 cartas (mão+deck)." % pi)


func test_ordem_fases_draw_main_battle_end() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	assert_eq(String(st.phase), "DRAW", "Duelo começa na fase DRAW.")
	var turno0: int = int(st.turn_number)
	var cur0: int = int(st.current_player)
	var r1: Dictionary = duel.advance_phase()
	assert_true(bool(r1.get("ok", false)), "DRAW -> MAIN avança.")
	assert_eq(String(st.phase), "MAIN", "Fase atual é MAIN.")
	var r2: Dictionary = duel.advance_phase()
	assert_true(bool(r2.get("ok", false)), "MAIN -> BATTLE avança.")
	assert_eq(String(st.phase), "BATTLE", "Fase atual é BATTLE.")
	var r3: Dictionary = duel.advance_phase()
	assert_true(bool(r3.get("ok", false)), "BATTLE -> END avança.")
	assert_eq(String(st.phase), "END", "Fase atual é END.")
	var r4: Dictionary = duel.advance_phase()
	assert_true(bool(r4.get("ok", false)), "END -> DRAW do próximo turno avança.")
	assert_eq(String(st.phase), "DRAW", "Novo turno recomeça na DRAW.")
	assert_eq(int(st.turn_number), turno0 + 1, "Novo turno incrementa o contador.")
	assert_eq(int(st.current_player), 1 - cur0, "Novo turno troca o jogador da vez.")


func test_uma_invocacao_normal_por_main() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	duel.advance_phase() # DRAW -> MAIN
	assert_eq(String(st.phase), "MAIN", "Preparo: estamos na MAIN.")
	var cur: int = int(st.current_player)
	_garantir_monstros_na_mao(st, cur, 2)
	var i1: int = _indice_monstro_na_mao(st, cur)
	assert_true(i1 >= 0, "Preparo: mão tem monstro para invocar.")
	var r1: Dictionary = SummonSystem.normal_summon(st, cur, i1, 0)
	assert_true(bool(r1.get("ok", false)), "1ª invocação na MAIN funciona.")
	var i2: int = _indice_monstro_na_mao(st, cur)
	assert_true(i2 >= 0, "Preparo: ainda há monstro na mão para a 2ª tentativa.")
	var r2: Dictionary = SummonSystem.normal_summon(st, cur, i2, 1)
	assert_false(bool(r2.get("ok", false)), "2ª invocação no mesmo MAIN falha.")
	assert_eq(str(r2.get("erro", "")), "Só 1 invocação normal por turno.", "Erro da 2ª invocação é o esperado.")


func test_um_ataque_por_monstro_por_battle() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	# D17: jogador 0 não ataca no turno 1 -> usa a BATTLE do turno 3 (jogador 0).
	while int(st.turn_number) < 3 or String(st.phase) != "MAIN":
		duel.advance_phase()
	assert_eq(int(st.current_player), 0, "Preparo: turno 3 é do jogador 0.")
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	_garantir_monstros_na_mao(st, cur, 1)
	var i: int = _indice_monstro_na_mao(st, cur)
	var rs: Dictionary = SummonSystem.normal_summon(st, cur, i, 0)
	assert_true(bool(rs.get("ok", false)), "Preparo: invocação na MAIN funciona.")
	duel.advance_phase() # MAIN -> BATTLE
	assert_eq(String(st.phase), "BATTLE", "Preparo: estamos na BATTLE.")
	var lp_antes: int = int((st.players[foe] as Dictionary)["lp"])
	var a1: Dictionary = BattleSystem.attack(st, cur, 0, foe, -1)
	assert_true(bool(a1.get("ok", false)), "1º ataque (direto, rival sem monstros) funciona.")
	assert_true(int(a1.get("dano", 0)) > 0, "Ataque direto causa dano maior que 0.")
	var lp_depois: int = int((st.players[foe] as Dictionary)["lp"])
	assert_true(lp_depois < lp_antes, "Dano reduziu o LP (antes=%d depois=%d)." % [lp_antes, lp_depois])
	var a2: Dictionary = BattleSystem.attack(st, cur, 0, foe, -1)
	assert_false(bool(a2.get("ok", false)), "2º ataque do mesmo monstro falha.")
	assert_eq(str(a2.get("erro", "")), "Este monstro já atacou neste turno.", "Erro do 2º ataque é o esperado.")


func test_dano_reduz_lp_e_cura_respeita_teto() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var inicial: int = int(st.starting_lp)
	assert_eq(inicial, 8000, "Duelo FM usa LP inicial 8000.")
	var foe: int = 1 - int(st.current_player)
	var rd: Dictionary = DamageSystem.apply_damage(st, foe, 1000)
	assert_true(bool(rd.get("ok", false)), "Dano de 1000 aplica.")
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 7000, "1000 de dano: 8000 -> 7000.")
	var rc: Dictionary = DamageSystem.apply_heal(st, foe, 5000)
	assert_true(bool(rc.get("ok", false)), "Cura de 5000 aplica.")
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 8000, "Cura nunca passa do inicial (teto 8000).")
	assert_true(int((st.players[foe] as Dictionary)["lp"]) <= inicial, "LP nunca passa do inicial.")


func test_lp_zero_declara_vencedor() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var rd: Dictionary = DamageSystem.apply_damage(st, 1, 8000)
	assert_true(bool(rd.get("ok", false)), "Dano letal aplica.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), 0, "LP do jogador 1 chegou a 0.")
	assert_true(duel.is_over(), "Duelo acabou com LP<=0.")
	assert_eq(duel.get_winner(), 0, "Quem zerou o LP do rival venceu (jogador 0).")


func test_deck_vazio_na_compra_e_derrota() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var cur: int = int(st.current_player)
	# FM fiel: deckout só na hora de COMPLETAR até 5. Mão cheia (5) com
	# deck vazio não perde; mão curta (4) com deck vazio perde.
	var r_cheia: Dictionary = TurnManager.draw_for_current(st)
	assert_true(bool(r_cheia.get("ok", false)), "Mão cheia (5) não precisa completar.")
	((st.players[cur] as Dictionary)["deck"] as Array).clear()
	var r_cheia_vazia: Dictionary = TurnManager.draw_for_current(st)
	assert_true(bool(r_cheia_vazia.get("ok", false)), "Mão cheia com deck vazio não perde (nada a completar).")
	((st.players[cur] as Dictionary)["hand"] as Array).pop_back()
	assert_eq(((st.players[cur] as Dictionary)["hand"] as Array).size(), 4, "Preparo: mão com 4 precisa completar.")
	var r: Dictionary = TurnManager.draw_for_current(st)
	assert_false(bool(r.get("ok", false)), "Completar com deck vazio falha.")
	assert_true(bool(r.get("deckout", false)), "Flag deckout marcada.")
	assert_true(duel.is_over(), "Duelo acabou por deck out.")
	assert_eq(duel.get_winner(), 1 - cur, "Quem não tem carta perde; vence o outro jogador.")


func test_duelo_automatico_termina_com_vencedor_em_ate_20_turnos() -> void:
	var duel = _novo_duelo()
	var fim: Dictionary = _rodar_duelo_auto(duel)
	assert_true(bool(fim.get("acabou", false)), "Duelo automático termina.")
	assert_true(int(fim.get("vencedor", -1)) != -1, "Há vencedor (ou empate) ao fim, não -1.")
	assert_true(int(fim.get("turnos", 99)) <= 20, "Termina em até 20 turnos (foi %d)." % int(fim.get("turnos", 99)))


func test_mesma_seed_mesmo_vencedor() -> void:
	var duel_a = _novo_duelo()
	var fim_a: Dictionary = _rodar_duelo_auto(duel_a)
	var duel_b = _novo_duelo()
	var fim_b: Dictionary = _rodar_duelo_auto(duel_b)
	assert_eq(int(fim_a.get("vencedor", -99)), int(fim_b.get("vencedor", -99)), "Mesma seed (42) = mesmo vencedor.")
	assert_eq(int(fim_a.get("turnos", -1)), int(fim_b.get("turnos", -1)), "Mesma seed = mesma duração em turnos.")
	assert_eq(int(fim_a.get("lp0", -1)), int(fim_b.get("lp0", -1)), "Mesma seed = mesmo LP final do jogador 0.")
	assert_eq(int(fim_a.get("lp1", -1)), int(fim_b.get("lp1", -1)), "Mesma seed = mesmo LP final do jogador 1.")


func test_sem_ataque_do_jogador_no_turno_1() -> void:
	# D17/D22: jogador (lado 0) não ataca no 1º turno; inimigo pode no dele.
	var duel = _novo_duelo()
	var st = duel.get_state()
	assert_eq(int(st.turn_number), 1, "Preparo: turno 1.")
	duel.advance_phase() # DRAW -> MAIN
	var cur: int = int(st.current_player)
	assert_eq(cur, 0, "Preparo: jogador 0 começa.")
	_garantir_monstros_na_mao(st, cur, 1)
	var i: int = _indice_monstro_na_mao(st, cur)
	var rs: Dictionary = SummonSystem.normal_summon(st, cur, i, 0)
	assert_true(bool(rs.get("ok", false)), "Preparo: invocação na MAIN funciona.")
	duel.advance_phase() # MAIN -> BATTLE
	assert_eq(String(st.phase), "BATTLE", "Preparo: estamos na BATTLE.")
	var foe: int = 1 - cur
	var a: Dictionary = BattleSystem.attack(st, cur, 0, foe, -1)
	assert_false(bool(a.get("ok", false)), "Jogador 0 não ataca no turno 1.")
	assert_eq(str(a.get("erro", "")), "Sem ataque no 1º turno.", "Erro do turno 1 é o esperado.")


func test_so_ataca_virado_para_cima_em_atk() -> void:
	# D17: carta virada p/ baixo (ou em DEF) não pode atacar.
	var duel = _novo_duelo()
	var st = duel.get_state()
	while int(st.turn_number) < 2 or String(st.phase) != "MAIN":
		duel.advance_phase()
	assert_eq(int(st.current_player), 1, "Preparo: turno 2 é do rival.")
	_garantir_monstros_na_mao(st, 1, 1)
	var i: int = _indice_monstro_na_mao(st, 1)
	var rs: Dictionary = SummonSystem.normal_summon(st, 1, i, 0, true, "DEF")
	assert_true(bool(rs.get("ok", false)), "Preparo: rival invoca virado p/ baixo.")
	duel.advance_phase() # MAIN -> BATTLE
	var a: Dictionary = BattleSystem.attack(st, 1, 0, 0, -1)
	assert_false(bool(a.get("ok", false)), "Virada p/ baixo não ataca.")
	assert_eq(str(a.get("erro", "")), "Só monstro virado em Ataque pode atacar.", "Erro da virada é o esperado.")
	(st.players[1] as Dictionary)["monster"][0] = null
	_garantir_monstros_na_mao(st, 1, 1)
	# Truque de teste: 2ª invocação no mesmo turno é proibida, então monta
	# o defensor em DEF direto na zona (só organiza dado, sem regra nova).
	var zona: Array = (st.players[1] as Dictionary)["monster"]
	var mao: Array = (st.players[1] as Dictionary)["hand"]
	var j: int = _indice_monstro_na_mao(st, 1)
	var base: Dictionary = mao[j] as Dictionary
	mao.remove_at(j)
	zona[0] = {"card_id": str(base.get("id", "")), "nome": str(base.get("name", "")), "atk": int(base.get("attack", 0)), "def": int(base.get("defense", 0)), "position": "DEF", "battle_position": "DEF", "face_down": false, "has_attacked": false}
	st.normal_summon_used = true
	var b: Dictionary = BattleSystem.attack(st, 1, 0, 0, -1)
	assert_false(bool(b.get("ok", false)), "Monstro em Defesa não ataca.")


func test_virada_desvira_ao_ser_atacada() -> void:
	# D17/D22: ao ser atacada, a virada vira p/ cima ANTES do cálculo;
	# 1500 vs DEF 2000: atacante é DESTRUÍDO e toma 500 no próprio LP.
	var duel = _novo_duelo()
	var st = duel.get_state()
	(st.players[0] as Dictionary)["monster"][0] = {"card_id": "alvo", "nome": "Alvo", "atk": 100, "def": 2000, "position": "DEF", "battle_position": "DEF", "face_down": true, "has_attacked": false}
	(st.players[1] as Dictionary)["monster"][0] = {"card_id": "atacante", "nome": "Atacante", "atk": 1500, "def": 1000, "position": "ATK", "battle_position": "ATK", "face_down": false, "has_attacked": false}
	while int(st.turn_number) < 2 or String(st.phase) != "BATTLE":
		duel.advance_phase()
	assert_eq(int(st.current_player), 1, "Preparo: turno 2 é do rival.")
	var lp1_antes: int = int((st.players[1] as Dictionary)["lp"])
	var a: Dictionary = BattleSystem.attack(st, 1, 0, 0, 0)
	assert_true(bool(a.get("ok", false)), "Ataque contra a virada funciona.")
	assert_true(bool(a.get("destruiu_atacante", false)), "1500 < 2000, atacante foi destruído.")
	assert_false(bool(a.get("destruiu_alvo", true)), "Alvo em DEF forte sobrevive.")
	assert_eq(int(a.get("dano", -1)), 500, "Dano é a diferença 2000-1500=500.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), lp1_antes - 500, "Atacante toma 500 no próprio LP.")
	var alvo: Dictionary = (st.players[0] as Dictionary)["monster"][0] as Dictionary
	assert_false(bool(alvo.get("face_down", true)), "A virada desvira ao ser atacada.")
	assert_true((st.players[1] as Dictionary)["monster"][0] == null, "Atacante saiu do campo.")


func test_empate_atk_vs_def_nada_acontece() -> void:
	# F1: empate ATK x vs DEF x = nada acontece (sem dano, sem destruição).
	var duel = _novo_duelo()
	var st = duel.get_state()
	(st.players[0] as Dictionary)["monster"][0] = {"card_id": "alvo", "nome": "Alvo", "atk": 500, "def": 1500, "position": "DEF", "battle_position": "DEF", "face_down": false, "has_attacked": false}
	(st.players[1] as Dictionary)["monster"][0] = {"card_id": "atacante", "nome": "Atacante", "atk": 1500, "def": 1000, "position": "ATK", "battle_position": "ATK", "face_down": false, "has_attacked": false}
	while int(st.turn_number) < 2 or String(st.phase) != "BATTLE":
		duel.advance_phase()
	assert_eq(int(st.current_player), 1, "Preparo: turno 2 é do rival.")
	var lp0_antes: int = int((st.players[0] as Dictionary)["lp"])
	var lp1_antes: int = int((st.players[1] as Dictionary)["lp"])
	var a: Dictionary = BattleSystem.attack(st, 1, 0, 0, 0)
	assert_true(bool(a.get("ok", false)), "Ataque com empate ATK vs DEF resolve.")
	assert_false(bool(a.get("destruiu_atacante", false)), "Empate contra Defesa: atacante sobrevive.")
	assert_false(bool(a.get("destruiu_alvo", false)), "Empate contra Defesa: alvo sobrevive.")
	assert_eq(int(a.get("dano", -1)), 0, "Empate contra Defesa: dano é 0.")
	assert_true((st.players[1] as Dictionary)["monster"][0] != null, "Atacante segue no campo.")
	assert_true((st.players[0] as Dictionary)["monster"][0] != null, "Alvo segue no campo.")
	assert_eq(int((st.players[0] as Dictionary)["lp"]), lp0_antes, "LP do dono do alvo não muda.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), lp1_antes, "LP do dono do atacante não muda.")


func test_empate_atk_vs_atk_os_dois_caem_sem_dano() -> void:
	# Empate ATK x vs ATK x = os dois vão ao cemitério, sem dano a ninguém.
	var duel = _novo_duelo()
	var st = duel.get_state()
	(st.players[0] as Dictionary)["monster"][0] = {"card_id": "alvo", "nome": "Alvo", "atk": 1500, "def": 1000, "position": "ATK", "battle_position": "ATK", "face_down": false, "has_attacked": false}
	(st.players[1] as Dictionary)["monster"][0] = {"card_id": "atacante", "nome": "Atacante", "atk": 1500, "def": 1000, "position": "ATK", "battle_position": "ATK", "face_down": false, "has_attacked": false}
	while int(st.turn_number) < 2 or String(st.phase) != "BATTLE":
		duel.advance_phase()
	assert_eq(int(st.current_player), 1, "Preparo: turno 2 é do rival.")
	var lp0_antes: int = int((st.players[0] as Dictionary)["lp"])
	var lp1_antes: int = int((st.players[1] as Dictionary)["lp"])
	var a: Dictionary = BattleSystem.attack(st, 1, 0, 0, 0)
	assert_true(bool(a.get("ok", false)), "Ataque com empate ATK vs ATK resolve.")
	assert_true(bool(a.get("destruiu_atacante", false)), "Empate ATK vs ATK: atacante foi destruído.")
	assert_true(bool(a.get("destruiu_alvo", false)), "Empate ATK vs ATK: alvo foi destruído.")
	assert_eq(int(a.get("dano", -1)), 0, "Empate ATK vs ATK: dano é 0.")
	assert_true((st.players[1] as Dictionary)["monster"][0] == null, "Atacante saiu do campo.")
	assert_true((st.players[0] as Dictionary)["monster"][0] == null, "Alvo saiu do campo.")
	assert_eq(int((st.players[0] as Dictionary)["lp"]), lp0_antes, "LP do dono do alvo não muda.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), lp1_antes, "LP do dono do atacante não muda.")


func test_invocacao_limita_atk_em_9999() -> void:
	# F2: ATK/DEF acima de 9999 entram no campo limitados a 9999.
	var duel = _novo_duelo()
	var st = duel.get_state()
	duel.advance_phase() # DRAW -> MAIN
	assert_eq(String(st.phase), "MAIN", "Preparo: estamos na MAIN.")
	var cur: int = int(st.current_player)
	_garantir_monstros_na_mao(st, cur, 1)
	var i: int = _indice_monstro_na_mao(st, cur)
	assert_true(i >= 0, "Preparo: mão tem monstro para invocar.")
	# Só organiza dado: carta com ataque absurdo; a regra testada é o clamp real.
	((st.players[cur] as Dictionary)["hand"][i] as Dictionary)["attack"] = 25000
	((st.players[cur] as Dictionary)["hand"][i] as Dictionary)["defense"] = 30000
	var r: Dictionary = SummonSystem.normal_summon(st, cur, i, 0)
	assert_true(bool(r.get("ok", false)), "Invocação da carta com ataque alto funciona.")
	var inst: Dictionary = (st.players[cur] as Dictionary)["monster"][0] as Dictionary
	assert_true(int(inst.get("atk", 99999)) <= 9999, "ATK em campo nunca passa de 9999.")
	assert_eq(int(inst.get("atk", -1)), 9999, "ATK 25000 entra limitado a 9999.")
	assert_true(int(inst.get("def", 99999)) <= 9999, "DEF em campo nunca passa de 9999.")


func test_blue_eyes_fm_0001_ataque_direto_3000() -> void:
	# Fixture FM real: fm_0001 (Blue-eyes 3000/2500) via Summon + Battle reais.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var cards: Dictionary = (state.get("data", {}) as Dictionary).get("cards", {})
	assert_true(cards.has("fm_0001"), "Preparo: fm_0001 existe no conteúdo FM.")
	var be: Dictionary = cards["fm_0001"] as Dictionary
	assert_eq(int(be.get("attack", -1)), 3000, "Preparo: Blue-eyes ATK 3000 no dado.")
	var duel = _novo_duelo()
	var st = duel.get_state()
	# D17: jogador 0 não ataca no turno 1 -> usa a MAIN do turno 3 (jogador 0).
	while int(st.turn_number) < 3 or String(st.phase) != "MAIN":
		duel.advance_phase()
	var cur: int = int(st.current_player)
	assert_eq(cur, 0, "Preparo: turno 3 é do jogador 0.")
	((st.players[cur] as Dictionary)["hand"] as Array).append((be as Dictionary).duplicate(true))
	var i: int = ((st.players[cur] as Dictionary)["hand"] as Array).size() - 1
	var rs: Dictionary = SummonSystem.normal_summon(st, cur, i, 0)
	assert_true(bool(rs.get("ok", false)), "Preparo: Blue-eyes invocado na MAIN.")
	duel.advance_phase() # MAIN -> BATTLE
	assert_eq(String(st.phase), "BATTLE", "Preparo: estamos na BATTLE.")
	var foe: int = 1 - cur
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 8000, "Preparo: rival começa com 8000 LP.")
	var a: Dictionary = BattleSystem.attack(st, cur, 0, foe, -1)
	assert_true(bool(a.get("ok", false)), "Blue-eyes ataca direto (rival sem monstros).")
	assert_eq(int(a.get("dano", -1)), 3000, "Blue-eyes causa 3000 de dano direto.")
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 5000, "Dano FM: 8000 - 3000 = 5000.")
