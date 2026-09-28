extends "res://testing/astralis_test_base.gd"

## test_regra_turno1 — trava a D43: **no TURNO 1 do duelo ninguém ataca**
## (nem você, nem o rival). A regra é pelo CONTADOR DE TURNO, não pelo lado:
## quem começa a partida está no turno 1 e só pode invocar; assim que passa a
## vez, o outro lado já entra no turno 2 e ataca normal.
##
## O bug do usuário: a trava antiga era `attacker_player == 0 and turn_number
## <= 1`. Com `turn_order = first_p2` o turno 1 é DO RIVAL, então a condição
## do lado 0 não era satisfeita e ele atacava de cara.
##
## O QUE ESTE ARQUIVO TRAVA (motor real, sem dublê, R1/R2):
## (1) first_p1: no turn 1 nem o lado 0 nem o lado 1 ataca.
## (2) first_p2: no turn 1 nem o lado 0 nem o lado 1 ataca (o bug).
## (3) No turn 2+ o ataque VALE para quem está jogando.
## (4) A exceção do Campo de Testes (D34, is_test) continua liberando o
##     ataque no turno 1 — essa trava existe e não pode cair.
## (5) A recusa sai com a frase do dono da regra, em PT-BR.
##
## Quem decide a regra é o MOTOR (`battle_system.can_attack`); aqui só se
## monta DADO (setup com outra ordem de início) e se OBSERVA. Fase, dano,
## deckout, invocação, fusão e IA não são tocados.

const BattleSystem := preload("res://duel/battle_system.gd")


## Duelo REAL do motor com a ordem pedida. `test_state` sai de propósito:
## com ele o motor marca `is_test`, que libera o ataque no turno 1 (D34) e
## portanto não serviria para provar a trava.
func _duelo_comecando_em(primeiro: int) -> Object:
	var data: Dictionary = ProjectLoaderScript.load_initial_state().get("data", {})
	var setup: Dictionary = (data.get("duel_setup", {}) as Dictionary).duplicate(true)
	setup.erase("test_state")
	setup["turn_order"] = "first_p1" if primeiro == 0 else "first_p2"
	return DuelManagerScript.new_duel(setup, data.get("decks", {}), data.get("cards", {}))


## Escreve um atacante de DADO pronto (só dado, é o truque de dado que os
## outros testes do repo usam; a regra continua sendo a do motor).
func _atacante_no_campo(st, lado: int) -> void:
	for i in range(5):
		((st.players[lado] as Dictionary)["monster"] as Array)[i] = _inst(1500, "ATK", false, 1000)


## Tentativa real de ataque direto do lado pedido (campo rival vazio).
func _tenta(st, lado: int) -> Dictionary:
	return BattleSystem.attack(st, lado, 0, 1 - lado, -1)


# ---------- (1) first_p1: no turno 1 NINGUÉM ataca ----------

func test_first_p1_turno1_nem_o_jogador_nem_o_rival_ataca() -> void:
	# (1) Você começa. No turno 1 só o lado 0 joga, e ele é barrado. O lado 1
	# nem está em turno (ele joga no 2), mas a trava é do TURNO, então o teste
	# confirma os dois lados recusados no próprio turno em que cada um joga.
	var duel = _duelo_comecando_em(0)
	var st = duel.get_state()
	assert_false(bool(st.get("is_test")), "Preparo: duelo normal (sem Campo de Testes).")
	assert_eq(int(st.current_player), 0, "Preparo: o motor deu o primeiro turno ao lado 0.")
	assert_eq(int(st.turn_number), 1, "Preparo: estamos no turno 1.")
	while not bool(st.over) and not (int(st.current_player) == 0 and String(st.phase) == "BATTLE"):
		duel.advance_phase()
	assert_eq(int(st.turn_number), 1, "Preparo: a BATTLE ainda é do TURNO 1.")
	_atacante_no_campo(st, 0)
	var r0: Dictionary = _tenta(st, 0)
	assert_false(bool(r0.get("ok", false)), "Turno 1: o lado 0 (quem começou) NÃO ataca.")
	# O lado 1 no turno 1 do duelo: força o estado do motor para conferir que a
	# trava é do TURNO e não do lado (é exatamente o bug do usuário).
	st.set("current_player", 1)
	_atacante_no_campo(st, 1)
	var r1: Dictionary = _tenta(st, 1)
	assert_false(bool(r1.get("ok", false)), "Turno 1: o lado 1 TAMBÉM não ataca (a trava é do turno, não do lado).")
	assert_eq(str(r1.get("erro", "")), BattleSystem.ERRO_TURNO_1, "A recusa do rival tem a MESMA frase do jogador.")


# ---------- (2) first_p2: o bug do usuário ----------

func test_first_p2_turno1_nem_o_rival_nem_o_jogador_ataca() -> void:
	# (2) O BUG REPORTADO. Com o RIVAL começando, o turno 1 é DELE — e a
	# trava antiga (lado 0) não olhava, então ele atacava de cara. Aqui os DOIS
	# lados são barrados no turno 1.
	var duel = _duelo_comecando_em(1)
	var st = duel.get_state()
	assert_false(bool(st.get("is_test")), "Preparo: duelo normal.")
	assert_eq(int(st.current_player), 1, "Preparo: o motor deu o primeiro turno ao RIVAL.")
	assert_eq(int(st.turn_number), 1, "Preparo: o turno 1 é o DO RIVAL (este é o caso do bug).")
	while not bool(st.over) and not (int(st.current_player) == 1 and String(st.phase) == "BATTLE"):
		duel.advance_phase()
	assert_eq(int(st.turn_number), 1, "Preparo: a BATTLE é do turno 1.")
	_atacante_no_campo(st, 1)
	var r1: Dictionary = _tenta(st, 1)
	assert_false(bool(r1.get("ok", false)), "Turno 1: o RIVAL que começou NÃO ataca (o bug do usuário).")
	# E o lado 0 no mesmo turno 1 também não.
	st.set("current_player", 0)
	_atacante_no_campo(st, 0)
	var r0: Dictionary = _tenta(st, 0)
	assert_false(bool(r0.get("ok", false)), "Turno 1: o lado 0 também não ataca.")


# ---------- (3) NO TURNO 2 O ATAQUE VALE ----------

func test_no_turno2_o_ataque_vale_para_quem_esta_jogando() -> void:
	# (3) A regra é do turno: no 2 (e em diante) quem está jogando ataca.
	for primeiro in [0, 1]:
		var duel = _duelo_comecando_em(primeiro)
		var st = duel.get_state()
		# Anda com o motor até o turno 2 do lado que começou entrar na BATTLE.
		var guard := 0
		while not bool(st.over) and guard < 20:
			if int(st.turn_number) >= 2 and String(st.phase) == "BATTLE":
				break
			duel.advance_phase()
			guard += 1
		var lado := int(st.current_player)
		assert_eq(int(st.turn_number), 2, "Preparo (começou por %d): estamos no turno 2, jogando o lado %d." % [primeiro, lado])
		_atacante_no_campo(st, lado)
		var r: Dictionary = _tenta(st, lado)
		assert_true(bool(r.get("ok", false)),
			"Começando pelo lado %d: no turno 2 o lado %d (na vez) ataca normalmente." % [primeiro, lado])


func test_turno3_e_em_diante_seguem_liberados() -> void:
	# (3b) Depois do turno 2 nada volta a travar: o bloqueio é só do turno 1.
	# A cada BATTLE o campo é limpo e o atacante recolocado (dado), senão o
	# monstro do turno anterior fica na frente e o ataque direto é recusado
	# por outro motivo.
	var duel = _duelo_comecando_em(0)
	var st = duel.get_state()
	var turnos_liberados := 0
	var guard := 0
	while not bool(st.over) and guard < 60:
		var lado := int(st.current_player)
		if String(st.phase) == "BATTLE" and int(st.turn_number) >= 2:
			_limpar_campo(st)
			_atacante_no_campo(st, lado)
			if bool(_tenta(st, lado).get("ok", false)):
				turnos_liberados += 1
		duel.advance_phase()
		guard += 1
	assert_true(turnos_liberados >= 2,
		"Vários turnos depois do 1 o ataque segue liberado (%d BATTLEs atacadas)." % turnos_liberados)


# ---------- (4) A EXCEÇÃO DO CAMPO DE TESTES CONTINUA (D34) ----------

func test_campo_de_testes_ainda_libera_ataque_no_turno_1() -> void:
	# (4) D34: o Campo de Testes (duel com test_state, dado do Studio) libera
	# o ataque no turno 1 para testar carta atacando de cara. Essa trava NÃO
	# pode cair por causa da D43.
	var data: Dictionary = ProjectLoaderScript.load_initial_state().get("data", {})
	var setup: Dictionary = (data.get("duel_setup", {}) as Dictionary).duplicate(true)
	var carta := _primeira_carta_monstro(data.get("cards", {}))
	assert_false(carta.is_empty(), "Preparo: o catálogo tem monstro de verdade.")
	setup["test_state"] = {
		"my_hand": [carta], "p0_monster": [{"card_id": carta, "face_up": true, "attack_position": true}],
		"p1_monster": [], "p1_spell": [],
	}
	var duel = DuelManagerScript.new_duel(setup, data.get("decks", {}), data.get("cards", {}))
	var st = duel.get_state()
	assert_true(bool(st.get("is_test")), "Preparo: é um duelo do Campo de Testes (is_test).")
	assert_eq(int(st.turn_number), 1, "Preparo: turno 1.")
	assert_eq(int(st.current_player), 0, "Preparo: o Campo de Testes sempre começa no lado 0.")
	while not bool(st.over) and String(st.phase) != "BATTLE":
		duel.advance_phase()
	assert_eq(int(st.turn_number), 1, "Preparo: a BATTLE é a do turno 1.")
	_atacante_no_campo(st, 0)
	var r: Dictionary = _tenta(st, 0)
	assert_true(bool(r.get("ok", false)), "D34: no Campo de Testes o ataque no TURNO 1 continua LIBERADO.")


## Primeiro id de carta MONSTRO do catálogo real (só para montar o test_state).
func _primeira_carta_monstro(cards: Dictionary) -> String:
	for cid in cards:
		if str((cards[cid] as Dictionary).get("card_type", "")) == "monster":
			return str(cid)
	return ""


# ---------- (5) A RECUSA É A FRASE DO DONO DA REGRA, EM PT-BR ----------

func test_recusa_sai_com_a_frase_do_motor_em_portugues() -> void:
	# (5) A frase mora no dono da regra (BattleSystem.ERRO_TURNO_1) e é a
	# mesma para os dois lados — não diz "seu primeiro turno", que não faria
	# sentido para quem nem começou. A tela só mostra essa frase.
	var duel = _duelo_comecando_em(1)
	var st = duel.get_state()
	while not bool(st.over) and String(st.phase) != "BATTLE":
		duel.advance_phase()
	_atacante_no_campo(st, int(st.current_player))
	var r: Dictionary = _tenta(st, int(st.current_player))
	assert_eq(str(r.get("erro", "")), BattleSystem.ERRO_TURNO_1, "A recusa é a frase do motor, sem string duplicada.")
	var frase := str(BattleSystem.ERRO_TURNO_1)
	assert_true(frase.contains("Turno 1"), "A frase diz que é o TURNO 1 (não 'seu turno').")
	assert_true(frase.contains("turno 2"), "A frase diz quando o ataque abre.")
	assert_false(frase.contains("seu "), "A frase não diz 'seu' (para o rival também fazer sentido).")
	assert_false(r.has("dano"), "A recusa não devolve dano (o turno 1 não mexe em nada).")
