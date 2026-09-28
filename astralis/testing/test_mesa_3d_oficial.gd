extends "res://testing/astralis_test_base.gd"

## test_mesa_3d_oficial — GUT da mesa 3D OFICIAL (D23/D40, R8: 1 arquivo).
## Só prepara/observa e chama os sistemas reais (R1/R2): a cena 3D desenha
## o GameState do DuelManager real; nenhuma regra é duplicada aqui.

const Mesa3DScene := preload("res://duel3d/mesa_3d.tscn")
const SummonSys := preload("res://duel/summon_system.gd")
const BoardLayout := preload("res://core/board_layout.gd")


func _mesa3d_nova():
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


func test_cena_3d_carrega_com_duelo_real() -> void:
	var mesa: Node = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Cena mesa_3d.tscn instancia.")
	var st = mesa.get("_st")
	assert_true(st != null, "Mesa 3D tem GameState real (DuelManager).")
	assert_true(mesa.get("_duel") != null, "Mesa 3D tem DuelManager real.")
	# Mesmo duelo do 2D: mão inicial 5/5 sem extra (D26).
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 5, "Mão p0 começa com 5.")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 5, "Mão p1 começa com 5.")
	assert_eq(String(st.phase), "MAIN", "Mesa 3D avança DRAW inicial -> MAIN igual ao 2D.")


func test_nos_chave_3d_existem() -> void:
	var mesa: Node = await _mesa3d_nova()
	for caminho in ["Camera3D", "WorldEnvironment", "SolDirecional", "LuzMesa",
			"Mesa", "Mesa/Slots", "Mesa/Decks", "Cartas", "Cursor3D", "FlashEfeito", "HUD"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Nó-chave existe: " + caminho)
	assert_true((mesa.get_node("Camera3D") as Camera3D).current, "Camera3D é a atual.")
	var n_marcas: int = (mesa.get_node("Mesa/Slots") as Node3D).get_child_count()
	assert_eq(n_marcas, 20, "20 marcas de slot (5+5 por lado, espelho do 2D).")
	for lbl in ["HUD/LpRival", "HUD/MaoRival", "HUD/Fase", "HUD/Log", "HUD/LpVoce", "HUD/Dica"]:
		assert_true(mesa.get_node_or_null(NodePath(lbl)) != null, "HUD existe: " + lbl)
	var hud: Node = mesa.get_node("HUD")
	var n_labels := 0
	for f in hud.get_children():
		if f is Label:
			n_labels += 1
	assert_true(n_labels >= 5, "HUD tem LP rival, mão rival, fase, log, LP você + dica (%d labels)." % n_labels)


func test_estado_real_reflete_na_mesa_3d() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# Leitura: 10 cartas desenhadas (5 abertas p0 + 5 de costas p1), campo vazio.
	var desenhadas: int = (mesa.get_node("Cartas") as Node3D).get_child_count()
	assert_eq(desenhadas, 10, "Mesa 3D desenha as 10 da mão (5 abertas + 5 de costas).")
	# Escrita SÓ pelo sistema real: invoca de verdade e redesenha.
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão p0 tem monstro.")
	var slot: int = SummonSys.free_monster_slot(st, 0)
	assert_true(slot >= 0, "Preparo: há slot livre.")
	var r: Dictionary = SummonSys.normal_summon(st, 0, idx, slot, false, "ATK")
	assert_true(bool(r.get("ok", false)), "Sistema real invocou.")
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var sid := "p0_m%d" % slot
	var achou := false
	var card_id := ""
	for f in (mesa.get_node("Cartas") as Node3D).get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
			achou = true
			card_id = str((f as Node).get_meta("card_id"))
	assert_true(achou, "Carta invocada aparece no slot 3D %s (leitura do estado)." % sid)
	assert_false(card_id.is_empty(), "Carta 3D carrega o card_id do estado real.")


func test_posicao_carta_exatamente_na_marca() -> void:
	# 2D-vs-3D (a): cada carta no XZ EXATO da marca do seu slot, nos 2 lados
	# (rival espelhado via BoardLayout real). Só leitura do estado real.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# p0 invoca no turno dele; p1 só no turno dele (regra real do motor).
	var idx0: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx0 >= 0, "Preparo: mão p0 tem monstro.")
	var slot0: int = SummonSys.free_monster_slot(st, 0)
	var r0: Dictionary = SummonSys.normal_summon(st, 0, idx0, slot0, false, "ATK", "")
	assert_true(bool(r0.get("ok", false)), "Sistema real invocou p0 slot %d." % slot0)
	var guarda := 0
	while (int(st.current_player) != 1 or String(st.phase) != "MAIN") and guarda < 8:
		mesa.get("_duel").advance_phase()
		guarda += 1
	assert_true(int(st.current_player) == 1 and String(st.phase) == "MAIN", "Preparo: vez do rival na MAIN (sistemas reais).")
	var idx1: int = _indice_monstro_na_mao(st, 1)
	assert_true(idx1 >= 0, "Preparo: mão p1 tem monstro.")
	var slot1: int = SummonSys.free_monster_slot(st, 1)
	var r1: Dictionary = SummonSys.normal_summon(st, 1, idx1, slot1, false, "ATK", "")
	assert_true(bool(r1.get("ok", false)), "Sistema real invocou p1 slot %d." % slot1)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var marcas: Node = mesa.get_node("Mesa/Slots")
	for lado in [0, 1]:
		var zona: Array = (st.players[lado] as Dictionary)["monster"]
		for i in range(zona.size()):
			if zona[i] == null:
				continue
			var sid := "p%d_m%d" % [lado, i]
			var marca: Node3D = null
			var carta: Node3D = null
			for f in marcas.get_children():
				if str((f as Node).name) == "Marca_" + sid:
					marca = f as Node3D
			for f in (mesa.get_node("Cartas") as Node3D).get_children():
				if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
					carta = f as Node3D
			assert_true(marca != null, "Marca existe: " + sid)
			assert_true(carta != null, "Carta desenhada no slot: " + sid)
			if marca == null or carta == null:
				continue
			assert_almost_eq(carta.position.x, marca.position.x, 0.001, "Carta XZ na marca %s (x)." % sid)
			assert_almost_eq(carta.position.z, marca.position.z, 0.001, "Carta XZ na marca %s (z)." % sid)
			# Confere contra o BoardLayout real (espelho do rival incluso).
			var p2: Vector2 = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(lado, "monstro", i), BoardLayout.default_pos(BoardLayout.slot_id(lado, "monstro", i)))
			var esp_x := (p2.x - 1158.0) / 150.0
			var esp_z := (p2.y - 540.0) / 150.0
			assert_almost_eq(marca.position.x, esp_x, 0.001, "Marca %s no X do BoardLayout." % sid)
			assert_almost_eq(marca.position.z, esp_z, 0.001, "Marca %s no Z do BoardLayout." % sid)


func test_menu_estrela_lista_guardians_reais() -> void:
	# 2D-vs-3D (b): menu da estrela existe e lista as 2 guardian stars do DADO.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(mesa.get_node_or_null(NodePath("MenuLayer/MenuEstrela")) != null, "Menu da estrela existe (2D sobre o 3D).")
	assert_true(mesa.get_node_or_null(NodePath("MenuLayer/CentroCarta")) != null, "Carta no centro existe.")
	assert_false((mesa.get_node("MenuLayer/MenuEstrela") as Control).visible, "Menu começa fechado.")
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão p0 tem monstro.")
	mesa.set("_col", idx)
	mesa.set("_fileira", 0)
	mesa.call("_fluxo_escolher_carta")
	await wait_process_frames(2)
	assert_eq(mesa.get("_sub_mao"), 1, "Carta foi ao centro (SUB_FACE).")
	assert_true((mesa.get_node("MenuLayer/CentroCarta") as Control).visible, "Centro mostra a carta.")
	mesa.call("_fluxo_travar_face")
	await wait_process_frames(2)
	assert_eq(mesa.get("_sub_mao"), 2, "Face travada (SUB_SLOT).")
	mesa.call("_fluxo_escolher_slot")
	await wait_process_frames(2)
	assert_eq(mesa.get("_sub_mao"), 3, "Slot escolhido abriu a estrela (SUB_ESTRELA).")
	assert_true((mesa.get_node("MenuLayer/MenuEstrela") as Control).visible, "Menu da estrela abriu.")
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	var ops: Array = mesa.call("_estrelas_da_carta", mao[mesa.get("_mao_idx")] as Dictionary)
	assert_eq(ops.size(), 2, "Menu tem as 2 estrelas do dado.")
	var op0 := str((mesa.get_node("MenuLayer/MenuEstrela/Caixa/Op0") as Label).text)
	var op1 := str((mesa.get_node("MenuLayer/MenuEstrela/Caixa/Op1") as Label).text)
	assert_true(op0.contains(str(ops[0])), "Opção 1 é a guardiã real (%s)." % str(ops[0]))
	assert_true(op1.contains(str(ops[1])), "Opção 2 é a guardiã real (%s)." % str(ops[1]))
	# Resumo dos slots mostra qual tem carta (igual ao 2D).
	var resumo := str(mesa.call("_resumo_slots"))
	assert_true(resumo.contains("vazios"), "Resumo lista os 5 slots: " + resumo)


func test_indicador_atk_def_e_fila() -> void:
	# 2D-vs-3D (b): indicador ATK/DEF por carta + HUD do slot + fila de fusão.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(mesa.get_node_or_null(NodePath("HUD/InfoSlot")) != null, "HUD tem indicador do slot.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/FilaFusao")) != null, "HUD tem fila de fusão.")
	var fus: Dictionary = mesa.get("_fusions_data")
	assert_true(((fus.get("recipes", []) as Array).size() > 0), "Fusões reais carregadas (%d receitas)." % ((fus.get("recipes", []) as Array).size()))
	var idx: int = _indice_monstro_na_mao(st, 0)
	var slot: int = SummonSys.free_monster_slot(st, 0)
	var r: Dictionary = SummonSys.normal_summon(st, 0, idx, slot, false, "ATK", "")
	assert_true(bool(r.get("ok", false)), "Sistema real invocou.")
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var sid := "p0_m%d" % slot
	var carta: Node3D = null
	for f in (mesa.get_node("Cartas") as Node3D).get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
			carta = f as Node3D
	assert_true(carta != null, "Carta no slot " + sid)
	assert_true(carta.get_node_or_null(NodePath("TagPos")) != null, "Carta tem etiqueta ATK/DEF.")
	assert_eq(str((carta.get_node("TagPos") as Label3D).text), "ATK", "Em Ataque mostra ATK.")
	mesa.set("_fase_jogador", 1)
	mesa.set("_fileira", 1)
	mesa.set("_col", slot)
	mesa.call("_atualizar_hud")
	await wait_process_frames(1)
	assert_true(str((mesa.get_node("HUD/InfoSlot") as Label).text).contains(sid), "HUD do slot espelha o foco (%s)." % sid)


func test_mesa_3d_so_joypad_sem_clique() -> void:
	# D19: cena-teste sem Button + nenhum Control clicável.
	var arq := FileAccess.open("res://duel3d/mesa_3d.tscn", FileAccess.READ)
	assert_true(arq != null, "mesa_3d.tscn abre p/ leitura.")
	var texto := arq.get_as_text()
	assert_false(texto.contains("Button"), "Cena 3D sem Button (só joypad).")
	var mesa: Node = await _mesa3d_nova()
	var todos: Array = []
	_coletar(mesa, todos)
	var n_botao := 0
	var n_clicavel := 0
	for n in todos:
		if n is BaseButton:
			n_botao += 1
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			n_clicavel += 1
	assert_eq(n_botao, 0, "Mesa 3D tem zero botão.")
	assert_eq(n_clicavel, 0, "Todo Control da mesa 3D está sem clique.")


func _coletar(n: Node, out: Array) -> void:
	out.append(n)
	for f in n.get_children():
		_coletar(f, out)


func test_camera_fixa_sem_orbita() -> void:
	# Ref Tag Force: câmera FIXA atrás do jogador (sem órbita/balanço).
	var mesa: Node = await _mesa3d_nova()
	var cam := mesa.get_node("Camera3D") as Camera3D
	assert_true(cam != null, "Camera3D existe.")
	assert_eq(cam.position, Vector3(0, 7.4, 9.6), "Câmera fixa atrás do jogador.")
	assert_eq(cam.fov, 50.0, "FOV fixo com profundidade da ref.")
	await wait_process_frames(10)
	assert_eq((mesa.get_node("Camera3D") as Camera3D).position, Vector3(0, 7.4, 9.6), "Câmera não deriva (sem órbita).")


func test_topo_hud_turno_no_centro() -> void:
	# Ref: seu LP à esquerda, TURN ao centro, rival + LP à direita.
	var mesa: Node = await _mesa3d_nova()
	for caminho in ["HUD/TopoFundo", "HUD/LpVoce", "HUD/Turno", "HUD/LpRival"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Topo existe: " + caminho)
	var voce := (mesa.get_node("HUD/LpVoce") as Label).position
	var turno := (mesa.get_node("HUD/Turno") as Label).position
	var rival := (mesa.get_node("HUD/LpRival") as Label).position
	assert_true(voce.x < turno.x, "Seu LP à esquerda do TURN.")
	assert_true(turno.x < rival.x, "TURN ao centro, rival à direita.")
	assert_true(str((mesa.get_node("HUD/Turno") as Label).text).contains("TURN"), "Turno mostra TURN.")
	assert_true(str((mesa.get_node("HUD/LpVoce") as Label).text).contains("LP"), "Seu LP no topo.")
	assert_true(str((mesa.get_node("HUD/LpRival") as Label).text).contains("LP"), "LP do rival no topo.")


func test_painel_esquerdo_carta_focada() -> void:
	# Ref: painel 2D fixo à esquerda com a carta focada GRANDE + dados reais.
	var mesa: Node = await _mesa3d_nova()
	assert_true(mesa.get_node_or_null(NodePath("HUD/PainelCarta")) != null, "Painel esquerdo existe.")
	for caminho in ["HUD/PainelCarta/Caixa/FocoNome", "HUD/PainelCarta/Caixa/FocoEstrelas",
			"HUD/PainelCarta/Caixa/FocoArte", "HUD/PainelCarta/Caixa/FocoStats",
			"HUD/PainelCarta/Caixa/FocoTipo", "HUD/PainelCarta/Caixa/FocoDesc"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Painel tem: " + caminho)
	var st = mesa.get("_st")
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	assert_true(mao.size() > 0, "Preparo: mão p0 tem carta.")
	mesa.set("_fileira", 0)
	mesa.set("_col", 0)
	mesa.call("_atualizar_hud")
	await wait_process_frames(1)
	var nome := str((mesa.get_node("HUD/PainelCarta/Caixa/FocoNome") as Label).text)
	assert_false(nome.is_empty() or nome == "—", "Painel mostra o nome real da carta focada: " + nome)
	var stats := str((mesa.get_node("HUD/PainelCarta/Caixa/FocoStats") as Label).text)
	assert_true(stats.contains("ATK/") and stats.contains("DEF/"), "Faixa ATK/DEF do dado real: " + stats)


func test_fases_no_meio_e_laterais() -> void:
	# Ref: fases DP/SP/MP1/BP/MP2/EP no meio; decks/cemitérios laterais + contadores.
	var mesa: Node = await _mesa3d_nova()
	assert_true(mesa.get_node_or_null(NodePath("Mesa/Fases")) != null, "Fileira de fases existe no meio.")
	assert_eq((mesa.get_node("Mesa/Fases") as Node3D).get_child_count(), 12, "6 fases x (base + rótulo).")
	for tag in ["DP", "SP", "MP1", "BP", "MP2", "EP"]:
		assert_true(mesa.get_node_or_null(NodePath("Mesa/Fases/Fase_" + tag)) != null, "Fase existe: " + tag)
	for caminho in ["Mesa/Decks/DeckRival", "Mesa/Decks/DeckVoce", "Mesa/Decks/CemRival", "Mesa/Decks/CemVoce"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Lateral existe: " + caminho)
	for caminho in ["Mesa/Decks/ContaDeckVoce", "Mesa/Decks/ContaCemVoce",
			"Mesa/Decks/ContaDeckRival", "Mesa/Decks/ContaCemRival"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Contador existe: " + caminho)
	assert_true(mesa.get_node_or_null(NodePath("Estrelas")) != null, "Fundo estrelado existe.")
	assert_true((mesa.get_node("Estrelas") as Node3D).get_child_count() >= 100, "Céu com 100+ estrelas.")
