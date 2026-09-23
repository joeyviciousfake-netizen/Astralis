extends GutTest

## test_duel_core — GUT sobre o motor real (R2: sem Fake).
## Monta o duelo de verdade a partir do duel_setup do Starter Kit (seed 42)
## via DuelManager real e afirma as regras fixas do doc 13 (LOGIC fixa):
## mão 5 + compra turno 1, ordem DRAW→MAIN→BATTLE→END, 1 invocação/MAIN,
## 1 ataque/monstro/BATTLE, dano/cura com teto, LP<=0, deck out, fim em
## até 20 turnos e determinismo por seed. Bug aqui vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const TurnManager := preload("res://duel/turn_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const DamageSystem := preload("res://duel/damage_system.gd")


# Monta um duelo novo de verdade: Starter Kit + duel_setup (seed 42).
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


func test_mao_inicial_5_mais_compra_turno1() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	var mao_cur: int = ((st.players[cur] as Dictionary)["hand"] as Array).size()
	var mao_foe: int = ((st.players[foe] as Dictionary)["hand"] as Array).size()
	# Doc 13.3: 5 iniciais + 1 compra do turno 1 (sem passe na V1).
	assert_eq(mao_foe, 5, "Quem espera começa com 5 cartas na mão.")
	assert_eq(mao_cur, 6, "Quem começa tem 5 + 1 compra do turno 1 = 6.")
	# Conservação: cada deck do Starter tem 20 cartas (mão + deck = 20, campo vazio).
	for pi in [0, 1]:
		var p: Dictionary = st.players[pi] as Dictionary
		var total: int = (p["hand"] as Array).size() + (p["deck"] as Array).size()
		assert_eq(total, 20, "Jogador %d conserva as 20 cartas (mão+deck)." % pi)


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
	duel.advance_phase() # DRAW -> MAIN
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
	assert_eq(inicial, 4000, "Starter usa LP inicial 4000.")
	var foe: int = 1 - int(st.current_player)
	var rd: Dictionary = DamageSystem.apply_damage(st, foe, 1000)
	assert_true(bool(rd.get("ok", false)), "Dano de 1000 aplica.")
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 3000, "1000 de dano: 4000 -> 3000.")
	var rc: Dictionary = DamageSystem.apply_heal(st, foe, 5000)
	assert_true(bool(rc.get("ok", false)), "Cura de 5000 aplica.")
	assert_eq(int((st.players[foe] as Dictionary)["lp"]), 4000, "Cura nunca passa do inicial (teto 4000).")
	assert_true(int((st.players[foe] as Dictionary)["lp"]) <= inicial, "LP nunca passa do inicial.")


func test_lp_zero_declara_vencedor() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var rd: Dictionary = DamageSystem.apply_damage(st, 1, 4000)
	assert_true(bool(rd.get("ok", false)), "Dano letal aplica.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), 0, "LP do jogador 1 chegou a 0.")
	assert_true(duel.is_over(), "Duelo acabou com LP<=0.")
	assert_eq(duel.get_winner(), 0, "Quem zerou o LP do rival venceu (jogador 0).")


func test_deck_vazio_na_compra_e_derrota() -> void:
	var duel = _novo_duelo()
	var st = duel.get_state()
	var cur: int = int(st.current_player)
	((st.players[cur] as Dictionary)["deck"] as Array).clear()
	var r: Dictionary = TurnManager.draw_for_current(st)
	assert_false(bool(r.get("ok", false)), "Compra com deck vazio falha.")
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
