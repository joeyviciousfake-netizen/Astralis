extends GutTest

## test_fluxo_fiel — GUT do fluxo fiel FM da mesa (R2: sem Fake).
## Trava o que o runtime fez em 2026-09-24 (duel_table.gd + position_system.gd):
## (1) fase da mão não sai da mão (cursor recusado fora),
## (2) carta desce sempre em Ataque com face + estrela escolhidas,
## (3) RB/LB bloqueado pós-ataque,
## (4) START na fase da mão não passa e na de campo passa.
## Usa a mesa real (duel_table.tscn) + sistemas reais (Duel/Summon/Battle/
## Position). Sem gamepad físico: Input.action_press só simula o botão;
## o passo é sempre o método real da mesa. Seed fixa 42 (duel_setup).
## Bug aqui vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const TableScript := preload("res://ui/duel_table.gd")
const MesaScene := preload("res://ui/duel_table.tscn")


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
	while _contar_monstros(st, player_idx) < quantos and k < deck.size():
		var c = deck[k]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			mao.append(c)
			deck.remove_at(k)
		else:
			k += 1


func _contar_monstros(st, player_idx: int) -> int:
	var n := 0
	for c in ((st.players[player_idx] as Dictionary)["hand"] as Array):
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			n += 1
	return n


func _mesa_nova():
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	return mesa


# Roda o fluxo fiel completo na mesa real via confirmar de verdade:
# carta -> centro (face) -> slot -> estrela -> campo. Devolve o slot usado
# e a estrela esperada. O botão é só simulado (Input.action_press);
# quem anda é o método real da mesa.
func _fluxo_completo_ate_campo(mesa: Node, face_baixo: bool, estrela_idx: int) -> Dictionary:
	var st = mesa.get("_st")
	var mao_antes: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão tem monstro p/ o fluxo fiel.")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", idx)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Carta foi ao centro (trava a face).")
	if face_baixo:
		Input.action_press("mover_dir")
		mesa.call("_pad_mover", 1, 0)
		Input.action_release("mover_dir")
	assert_eq(bool(mesa.get("_face_baixo")), face_baixo, "Face escolhida: p/ baixo = %s." % str(face_baixo))
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Face travada, escolhe 1 dos 5 slots.")
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(slot >= 0, "Preparo: há slot livre no próprio campo.")
	mesa.set("_pad_col", slot)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Slot escolhido, abre o menu da estrela.")
	assert_true((mesa.get("_popup") as Control).visible, "Menu da estrela abriu no centro.")
	var ops: Array = mesa.get("_estrela_ops")
	assert_eq(ops.size(), 2, "Menu traz as 2 guardian stars do dado.")
	if estrela_idx == 1:
		Input.action_press("mover_baixo")
		mesa.call("_pad_mover", 0, 1)
		Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_pad_popup_idx")), estrela_idx, "Cursor do menu na estrela %d." % (estrela_idx + 1))
	var esperada := str(ops[estrela_idx])
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	return {"slot": slot, "estrela": esperada, "mao_antes": mao_antes}


func test_fase_da_mao_cursor_nunca_sai_da_mao() -> void:
	# (1) Na fase da mão o cursor é recusado fora: cima/baixo não trocam
	# de fileira em nenhum passo (mão -> centro/face -> 5 slots).
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_MAO, "Começa na fase da mão.")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_MAO_ESCOLHA, "Passo inicial: escolher o monstro.")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Cursor começa na fileira da mão.")
	# Passo 1 (escolha): cima/baixo recusados, esq/dir anda só na mão.
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Escolha: cima/baixo não saem da mão.")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_MAO_ESCOLHA, "Escolha: passo não mudou.")
	var col_ini: int = int(mesa.get("_pad_col"))
	Input.action_press("mover_dir")
	mesa.call("_pad_mover", 1, 0)
	Input.action_release("mover_dir")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Escolha: esq/dir fica na mão.")
	mesa.set("_pad_col", col_ini)
	# Passo 2 (face, carta no centro): cima/baixo recusados, esq/dir só alterna a face.
	var st = mesa.get("_st")
	mesa.set("_pad_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Carta foi ao centro (passo da face).")
	var face_ini: bool = bool(mesa.get("_face_baixo"))
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Face: cima/baixo não saem do centro.")
	assert_eq(bool(mesa.get("_face_baixo")), face_ini, "Face: cima/baixo não alternam a face.")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Face: fileira não sai da mão.")
	# Passo 3 (slot): cima/baixo recusados, esq/dir anda só nos 5 slots próprios.
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Face travada (passo do slot).")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MEU_CAMPO, "Slot: cursor nos 5 do próprio campo.")
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Slot: cima/baixo não saem dos 5 slots.")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MEU_CAMPO, "Slot: fileira fica no próprio campo.")
	var col_slot: int = int(mesa.get("_pad_col"))
	Input.action_press("mover_dir")
	mesa.call("_pad_mover", 1, 0)
	Input.action_release("mover_dir")
	assert_eq(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MEU_CAMPO, "Slot: esq/dir fica no próprio campo.")
	assert_eq(int(mesa.get("_pad_col")), posmod(col_slot + 1, 5), "Slot: esq/dir anda 1 casa nos 5 slots.")


func test_carta_desce_em_ataque_com_face_cima_e_estrela() -> void:
	# (2a) Fluxo fiel p/ cima: desce SEMPRE em Ataque (vertical) com a face
	# escolhida e a guardian star do menu gravada na instância.
	var mesa = await _mesa_nova()
	var fim: Dictionary = _fluxo_completo_ate_campo(mesa, false, 0)
	var st = mesa.get("_st")
	var slot: int = int(fim["slot"])
	var inst: Dictionary = (st.players[0] as Dictionary)["monster"][slot] as Dictionary
	assert_true(inst != null and not (inst as Dictionary).is_empty(), "Carta desceu ao slot %d." % slot)
	assert_eq(str(inst.get("position", "")), "ATK", "Desce sempre em Ataque (vertical).")
	assert_false(bool(inst.get("face_down", true)), "Face escolhida: p/ cima.")
	assert_eq(str(inst.get("guardian_star", "")), str(fim["estrela"]), "Estrela do menu gravada na instância.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), int(fim["mao_antes"]) - 1, "Carta saiu da mão.")
	assert_eq(String(st.phase), "BATTLE", "Fim da fase da mão: MAIN -> BATTLE automático.")
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Entrou na fase de campo.")


func test_carta_desce_em_ataque_com_face_baixo_e_estrela() -> void:
	# (2b) Fluxo fiel p/ baixo + 2ª estrela: também desce em Ataque, virada.
	var mesa = await _mesa_nova()
	var fim: Dictionary = _fluxo_completo_ate_campo(mesa, true, 1)
	var st = mesa.get("_st")
	var slot: int = int(fim["slot"])
	var inst: Dictionary = (st.players[0] as Dictionary)["monster"][slot] as Dictionary
	assert_true(inst != null and not (inst as Dictionary).is_empty(), "Carta desceu ao slot %d." % slot)
	assert_eq(str(inst.get("position", "")), "ATK", "Virada também desce em Ataque (vertical).")
	assert_true(bool(inst.get("face_down", false)), "Face escolhida: p/ baixo (virada).")
	assert_eq(str(inst.get("guardian_star", "")), str(fim["estrela"]), "2ª estrela do menu gravada na instância.")
	assert_eq(String(st.phase), "BATTLE", "Fim da fase da mão: MAIN -> BATTLE automático.")
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Entrou na fase de campo.")


func test_rb_lb_bloqueado_pos_ataque() -> void:
	# (3) RB/LB (posicao_l1/r1) trava pós-ataque: o sistema real recusa com
	# "Já atacou" e a mesa mantém a posição. Ataque de verdade primeiro.
	var duel = _novo_duelo()
	var st = duel.get_state()
	while int(st.turn_number) < 3 or String(st.phase) != "MAIN":
		duel.advance_phase()
	assert_eq(int(st.current_player), 0, "Preparo: turno 3 é do jogador 0 (já pode atacar).")
	_garantir_monstros_na_mao(st, 0, 1)
	var rs: Dictionary = SummonSystem.normal_summon(st, 0, _indice_monstro_na_mao(st, 0), 0)
	assert_true(bool(rs.get("ok", false)), "Preparo: invocação na MAIN funciona.")
	duel.advance_phase() # MAIN -> BATTLE
	# Só organiza dado: garante o direto (rival sem monstros) p/ o ataque real.
	for i in range(5):
		(st.players[1] as Dictionary)["monster"][i] = null
	var a: Dictionary = BattleSystem.attack(st, 0, 0, 1, -1)
	assert_true(bool(a.get("ok", false)), "Preparo: ataque direto de verdade funciona.")
	assert_true((st.players[0] as Dictionary)["monster"][0] != null, "Ataque direto: atacante segue no campo.")
	var pos_antes := str(((st.players[0] as Dictionary)["monster"][0] as Dictionary).get("position", "ATK"))
	var travou: Dictionary = PositionSystem.toggle_position(st, 0, 0)
	assert_false(bool(travou.get("ok", false)), "RB/LB pós-ataque: sistema real bloqueia.")
	assert_eq(str(travou.get("erro", "")), "Já atacou: posição travada neste turno.", "Erro pós-ataque é o esperado.")
	assert_eq(str(((st.players[0] as Dictionary)["monster"][0] as Dictionary).get("position", "")), pos_antes, "Posição não mudou no sistema.")
	# Mesa real com a mesma trava: cursor na própria carta, RB não deita/levanta.
	var mesa = await _mesa_nova()
	var stm = mesa.get("_st")
	_garantir_monstros_na_mao(stm, 0, 1)
	var rm: Dictionary = SummonSystem.normal_summon(stm, 0, _indice_monstro_na_mao(stm, 0), 0)
	assert_true(bool(rm.get("ok", false)), "Preparo: mesa invoca via Summon real.")
	mesa.call("_atualizar")
	(mesa.get("_duel") as RefCounted).advance_phase() # MAIN -> BATTLE da mesa
	# Só organiza dado: simula o pós-ataque (turno 1 não ataca, D17).
	((stm.players[0] as Dictionary)["monster"][0] as Dictionary)["has_attacked"] = true
	mesa.set("_fase_jogador", TableScript.FASE_CAMPO)
	mesa.set("_pad_fileira", TableScript.FILEIRA_MEU_CAMPO)
	mesa.set("_pad_col", 0)
	var mesa_antes := str(((stm.players[0] as Dictionary)["monster"][0] as Dictionary).get("position", "ATK"))
	Input.action_press("posicao_r1")
	assert_true(Input.is_action_pressed("posicao_r1"), "Botão RB simulado fica pressionado.")
	mesa.call("_alternar_posicao")
	Input.action_release("posicao_r1")
	assert_eq(str(((stm.players[0] as Dictionary)["monster"][0] as Dictionary).get("position", "")), mesa_antes, "RB pós-ataque: mesa mantém a posição.")
	Input.action_press("posicao_l1")
	mesa.call("_alternar_posicao")
	Input.action_release("posicao_l1")
	assert_eq(str(((stm.players[0] as Dictionary)["monster"][0] as Dictionary).get("position", "")), mesa_antes, "LB pós-ataque: mesa mantém a posição.")


func test_start_na_mao_nao_passa_e_no_campo_passa() -> void:
	# (4) START (pausar, botão 6): na fase da mão não faz nada (tem que
	# descer 1 carta); na fase de campo passa o turno ao rival.
	var mesa_mao = await _mesa_nova()
	var stm = mesa_mao.get("_st")
	assert_eq(int(mesa_mao.get("_fase_jogador")), TableScript.FASE_MAO, "Preparo: mesa está na fase da mão.")
	var turno_ini: int = int(stm.turn_number)
	var fase_ini := String(stm.phase)
	Input.action_press("pausar")
	assert_true(Input.is_action_pressed("pausar"), "START simulado fica pressionado.")
	mesa_mao.call("_no_start_passar_turno")
	Input.action_release("pausar")
	assert_eq(int(stm.current_player), 0, "START na fase da mão: continua sua vez.")
	assert_eq(String(stm.phase), fase_ini, "START na fase da mão: fase não muda (%s)." % fase_ini)
	assert_eq(int(stm.turn_number), turno_ini, "START na fase da mão: turno não muda.")
	assert_eq(int(mesa_mao.get("_fase_jogador")), TableScript.FASE_MAO, "START na fase da mão: segue na fase da mão.")
	var mesa_campo = await _mesa_nova()
	_fluxo_completo_ate_campo(mesa_campo, false, 0)
	var stc = mesa_campo.get("_st")
	assert_eq(int(mesa_campo.get("_fase_jogador")), TableScript.FASE_CAMPO, "Preparo: mesa está na fase de campo.")
	assert_eq(int(stc.current_player), 0, "Preparo: ainda é sua vez antes do START.")
	Input.action_press("pausar")
	mesa_campo.call("_no_start_passar_turno")
	Input.action_release("pausar")
	assert_eq(int(stc.current_player), 1, "START na fase de campo: passa o turno ao rival.")
	# Deixa a IA do rival terminar o turno dela (mesa real, ~3s) e libera limpo (R8).
	await wait_seconds(5.0)
	assert_true(is_instance_valid(mesa_campo), "Mesa segue válida após o turno do rival.")
	assert_eq(int(stc.current_player), 0, "Rival jogou e devolveu sua vez.")
	assert_eq(int(mesa_campo.get("_fase_jogador")), TableScript.FASE_MAO, "De volta à sua fase da mão.")
