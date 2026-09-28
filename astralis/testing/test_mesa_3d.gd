extends "res://testing/astralis_test_base.gd"

## test_mesa_3d — GUT da mesa 3D EXPERIMENTAL (D23, teste, R8: 1 arquivo).
## Só prepara/observa e chama os sistemas reais (R1/R2): a cena 3D desenha
## o GameState do DuelManager real; nenhuma regra é duplicada aqui.

const Mesa3DScene := preload("res://duel3d_test/mesa_3d_test.tscn")
const SummonSys := preload("res://duel/summon_system.gd")


func _mesa3d_nova():
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


func test_cena_3d_carrega_com_duelo_real() -> void:
	var mesa: Node = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Cena mesa_3d_test.tscn instancia.")
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


func test_mesa_3d_so_joypad_sem_clique() -> void:
	# D19: cena-teste sem Button + nenhum Control clicável.
	var arq := FileAccess.open("res://duel3d_test/mesa_3d_test.tscn", FileAccess.READ)
	assert_true(arq != null, "mesa_3d_test.tscn abre p/ leitura.")
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
