extends "res://testing/astralis_test_base.gd"

## test_mesa_3bugs — GUT permanente dos 3 bugs da mesa (runtime c47d4c6).
## Trava sem mudar regra, com mesa/carta REAIS (duel_table.tscn + CardView
## real + Duel/Summon/Battle reais). Sem Fake (R2). Seed fixa 42 (duel_setup).
## (1) menu sem Atacar inválido: turno 1 confirmar na própria carta NÃO marca
##     o atacante e avisa o motivo; turno 3 marca (can_attack real, D17);
## (2) carta centrada: centro do desenho (position+pivô) = centro do slot
##     nos 2 lados (posição nova do runtime, pivô TAM/2);
## (3) rival rotacionado: lado 1 gira 180° (PI) na frente E no verso,
##     lado 0 fica 0°; DEF soma 90° (deitada) em cima da base.
## Bug aqui vira teste permanente.
## Helpers (_mesa_nova/_fluxo_completo_ate_campo/_limpar_campo/_inst_campo/
## _indice_monstro_na_mao) vêm de astralis_test_base.gd.

const BattleSystem := preload("res://duel/battle_system.gd")
const BoardScript := preload("res://ui/duel_board.gd")
const CardViewScript := preload("res://ui/card_view.gd")


# Só organiza dado; a regra testada é sempre a do motor real.
func _centro_slot(mesa: Node, lado: int, slot: int) -> Vector2:
	var layout: Dictionary = mesa.get("_arena_layout")
	return (BoardScript.slot_rect(lado, "monstro", slot, layout) as Rect2).get_center()


func _vista_no_centro(mesa: Node, esperado: Vector2):
	var camada: Node = mesa.get("_camada_campo")
	for v in camada.get_children():
		var c: Vector2 = (v as Control).position + (v as Control).pivot_offset
		if c.distance_to(esperado) < 1.5:
			return v
	return null


func test_menu_turno1_nao_marca_e_avisa_turno3_marca() -> void:
	# (1) Menu sem Atacar inválido: a mesa consulta o can_attack real.
	# Turno 1 (D17 bloqueia p0): confirmar na própria carta NÃO marca e avisa.
	# Turno 3: a mesma confirmação marca o atacante. Sem mudar regra.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var fim: Dictionary = _fluxo_completo_ate_campo(mesa, false, 0)
	var st = mesa.get("_st")
	var slot_atk: int = int(fim["slot"])
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Preparo: fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Preparo: BATTLE da mesa.")
	assert_eq(int(st.turn_number), 1, "Preparo: turno 1 (D17 bloqueia o lado 0).")
	var pode1: Dictionary = BattleSystem.can_attack(st, 0, slot_atk)
	assert_false(bool(pode1.get("ok", false)), "Motor real: turno 1 não deixa p0 atacar.")
	assert_true(str(pode1.get("erro", "")).contains("1º turno"), "Motor diz o motivo (1º turno, erro '%s')." % str(pode1.get("erro", "")))
	# Turno 1: confirmar na própria carta (cursor real no próprio campo).
	mesa.set("_pad_fileira", TableScript.FILEIRA_MEU_CAMPO)
	mesa.set("_pad_col", slot_atk)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sel_atk")), -1, "Turno 1: NÃO marca o atacante (menu sem Atacar inválido).")
	assert_false((mesa.get("_popup") as Control).visible, "Turno 1: nenhum menu abre p/ ataque inválido.")
	var fala1 := str((mesa.get("_log") as Array).back())
	assert_true(fala1.contains("Não pode atacar"), "Turno 1: avisa que não pode (fala '%s')." % fala1)
	assert_true(fala1.contains("1º turno"), "Turno 1: avisa o motivo (1º turno, fala '%s')." % fala1)
	# Turno 3: a mesma confirmação marca (só organiza dado, regra intacta).
	st.set("turn_number", 3)
	assert_true(bool(BattleSystem.can_attack(st, 0, slot_atk).get("ok", false)), "Motor real: turno 3 libera o ataque.")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MEU_CAMPO)
	mesa.set("_pad_col", slot_atk)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sel_atk")), slot_atk, "Turno 3: marca o atacante.")
	assert_true(str((mesa.get("_log") as Array).back()).contains("Atacante escolhido"), "Turno 3: confirma que escolheu.")


func test_centro_desenho_igual_centro_slot_2_lados() -> void:
	# (2) Carta centrada no slot nos 2 lados: position+pivô = centro do slot.
	# Pivô é o centro (TAM/2); escala 0.85 não entra na conta do centro.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[0] as Dictionary)["monster"][1] = _inst_campo("ATK", false)
	(st.players[1] as Dictionary)["monster"][3] = _inst_campo("ATK", false)
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var camada: Node = mesa.get("_camada_campo")
	assert_eq(camada.get_child_count(), 2, "Campo desenha as 2 cartas (1 por lado).")
	for par in [[0, 1], [1, 3]]:
		var lado: int = int(par[0])
		var slot: int = int(par[1])
		var esperado: Vector2 = _centro_slot(mesa, lado, slot)
		var vista = _vista_no_centro(mesa, esperado)
		assert_true(vista != null, "Lado %d slot %d: desenho existe no centro do slot (%.0f, %.0f)." % [lado, slot, esperado.x, esperado.y])
		assert_eq((vista as Control).pivot_offset, CardViewScript.TAM / 2.0, "Lado %d: pivô é o centro (TAM/2)." % lado)
		var centro: Vector2 = (vista as Control).position + (vista as Control).pivot_offset
		assert_true(centro.distance_to(esperado) < 1.5, "Lado %d slot %d: centro do desenho = centro do slot (%.1f px)." % [lado, slot, centro.distance_to(esperado)])
		assert_eq((vista as Control).scale, Vector2(0.85, 0.85), "Lado %d: escala de campo 0.85." % lado)


func test_rotacao_lado1_180_frente_e_verso_lado0_0() -> void:
	# (3) Lado 1 de cabeça p/ cima p/ o rival: base 180° (PI) na frente E no
	# verso; lado 0 fica 0°. DEF soma 90° (deitada) em cima da base.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[0] as Dictionary)["monster"][0] = _inst_campo("ATK", false)
	(st.players[1] as Dictionary)["monster"][0] = _inst_campo("ATK", false)
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var c0: Vector2 = _centro_slot(mesa, 0, 0)
	var c1: Vector2 = _centro_slot(mesa, 1, 0)
	var v0 = _vista_no_centro(mesa, c0)
	var v1 = _vista_no_centro(mesa, c1)
	assert_true(v0 != null and v1 != null, "As 2 cartas ATK de frente existem.")
	assert_true(absf(float(v0.get("rotation")) - 0.0) < 0.001, "Lado 0 ATK frente: rotação 0° (%.3f)." % float(v0.get("rotation")))
	assert_true(absf(float(v1.get("rotation")) - PI) < 0.001, "Lado 1 ATK frente: rotação 180° (%.3f)." % float(v1.get("rotation")))
	# Verso mantém a mesma base (frente e verso virados p/ o dono).
	(st.players[0] as Dictionary)["monster"][0]["face_down"] = true
	(st.players[1] as Dictionary)["monster"][0]["face_down"] = true
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var w0 = _vista_no_centro(mesa, c0)
	var w1 = _vista_no_centro(mesa, c1)
	assert_true(w0 != null and w1 != null, "As 2 cartas ATK de verso existem.")
	assert_true(bool(w0.get("_face_down")), "Lado 0 está de costas (verso).")
	assert_true(bool(w1.get("_face_down")), "Lado 1 está de costas (verso).")
	assert_true(absf(float(w0.get("rotation")) - 0.0) < 0.001, "Lado 0 ATK verso: rotação 0° (%.3f)." % float(w0.get("rotation")))
	assert_true(absf(float(w1.get("rotation")) - PI) < 0.001, "Lado 1 ATK verso: rotação 180° (%.3f)." % float(w1.get("rotation")))
	# DEF soma 90° (deitada, mas virada p/ o dono): 90° e 270°.
	(st.players[0] as Dictionary)["monster"][0]["face_down"] = false
	(st.players[1] as Dictionary)["monster"][0]["face_down"] = false
	(st.players[0] as Dictionary)["monster"][0]["position"] = "DEF"
	(st.players[1] as Dictionary)["monster"][0]["position"] = "DEF"
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var d0 = _vista_no_centro(mesa, c0)
	var d1 = _vista_no_centro(mesa, c1)
	assert_true(d0 != null and d1 != null, "As 2 cartas DEF existem.")
	assert_true(absf(float(d0.get("rotation")) - PI / 2.0) < 0.001, "Lado 0 DEF: 0° + 90° (%.3f)." % float(d0.get("rotation")))
	assert_true(absf(float(d1.get("rotation")) - (PI + PI / 2.0)) < 0.001, "Lado 1 DEF: 180° + 90° (%.3f)." % float(d1.get("rotation")))
