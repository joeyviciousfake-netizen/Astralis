extends "res://testing/astralis_test_base.gd"

## test_mesa_3d_oficial — GUT do CAMPO 3D OFICIAL (D23/D40, R8: 1 arquivo).
## Só prepara/observa e chama os sistemas reais (R1/R2): a cena 3D desenha
## o GameState do DuelManager real; nenhuma regra é duplicada aqui.
## Ref GX (céu azul, sem mesa): trava que nenhum nó de mesa existe, que só
## existe texto da ref (placas, painel carta, fases, contadores, menus
## funcionais) e que painéis/HUD/fases trazem o dado real.

const Mesa3DScene := preload("res://duel3d/mesa_3d.tscn")
const SummonSys := preload("res://duel/summon_system.gd")
const BoardLayout := preload("res://core/board_layout.gd")

## Nomes proibidos na cena 3D (demolição da mesa, ref sem tampo/moldura).
const NOS_PROIBIDOS := ["Mesa", "Tampo", "MolduraN", "MolduraS", "MolduraL",
	"MolduraO", "Emblema", "TopoFundo", "Cruz"]
## Doc 15 §15.4: o campo foi para a DIREITA da tela sem entortar a
## perspectiva — o mundo 3D inteiro (céu, campo, cartas, mão, cursor) mora
## dentro de um SubViewport com a região do campo, mostrado por baixo do HUD
## 2D. Os nós 3D mantiveram os MESMOS nomes; só ganharam o prefixo da janela.
const JANELA := "Camada3D/JanelaCampo/Viewport3D"


## Procura um nó do MUNDO 3D (dentro da janela do campo).
func _n3d(mesa: Node, caminho: String) -> Node:
	return mesa.get_node_or_null(NodePath(JANELA + "/" + caminho))


func _mesa3d_nova():
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


func _coletar(n: Node, out: Array) -> void:
	out.append(n)
	for f in n.get_children():
		_coletar(f, out)


## Índice do MEIO do arco de uma mão de n cartas (com n par o meio do arco
## cai entre 2 cartas — é o que a mesa usa na calibração).
func _meio_do_arco(n: int) -> int:
	return int(ceil(float(maxi(n - 1, 0)) / 2.0))


func test_cena_3d_carrega_com_duelo_real() -> void:
	var mesa: Node = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Cena mesa_3d.tscn instancia.")
	var st = mesa.get("_st")
	assert_true(st != null, "Campo 3D tem GameState real (DuelManager).")
	assert_true(mesa.get("_duel") != null, "Campo 3D tem DuelManager real.")
	# Mesmo duelo do 2D: mão inicial 5/5 sem extra (D26).
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), 5, "Mão p0 começa com 5.")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array).size(), 5, "Mão p1 começa com 5.")
	assert_eq(String(st.phase), "MAIN", "Campo 3D avança DRAW inicial -> MAIN igual ao 2D.")


func test_sem_mesa_nenhum_no_de_mesa() -> void:
	# Ref SEM MESA: tampo, molduras douradas, emblema e marcas sumiram.
	var mesa: Node = await _mesa3d_nova()
	assert_true(_n3d(mesa, "Mesa") == null, "Sem nó Mesa.")
	assert_true(_n3d(mesa, "Campo") != null, "Campo flutuante existe no lugar.")
	var todos: Array = []
	_coletar(mesa, todos)
	for n in todos:
		var nome := str((n as Node).name)
		assert_false(nome in NOS_PROIBIDOS, "Nó de mesa proibido ausente: " + nome)
		assert_false(nome.begins_with("Marca_"), "Sem Marca_ de slot: " + nome)
	# Fundo = céu azul GX sem neblina (neblina lavava a cena): só Sky.
	var we := _n3d(mesa, "WorldEnvironment") as WorldEnvironment
	assert_true(we != null, "WorldEnvironment existe.")
	assert_eq(we.environment.background_mode, Environment.BG_SKY, "Fundo é céu (Sky).")
	assert_false(we.environment.fog_enabled, "Sem neblina (lava os painéis).")


func test_nos_chave_3d_existem() -> void:
	var mesa: Node = await _mesa3d_nova()
	for caminho in ["Camera3D", "WorldEnvironment",
			"Campo", "Campo/Slots", "Campo/Laterais", "Campo/Tokens",
			"Cartas", "Cursor3D", "Ceu"]:
		assert_true(_n3d(mesa, caminho) != null, "Nó-chave 3D existe: " + caminho)
	for lbl in ["HUD", "HUD/FlashTela", "Camada3D", "Camada3D/JanelaCampo"]:
		assert_true(mesa.get_node_or_null(NodePath(lbl)) != null, "Nó-chave existe: " + lbl)
	assert_true((_n3d(mesa, "Camera3D") as Camera3D).current, "Camera3D é a atual.")
	# 20 painéis flutuantes (5+5 por lado), cada um com base escura + borda.
	var paineis := (_n3d(mesa, "Campo/Slots") as Node3D).get_children()
	assert_eq(paineis.size(), 20, "20 painéis de slot (5+5 por lado, espelho do 2D).")
	for p in paineis:
		assert_true(str((p as Node).name).begins_with("Painel_p"), "Painel flutuante: " + str((p as Node).name))
		assert_true((p as Node).get_node_or_null(NodePath("Base")) != null, "Painel tem base escura: " + str((p as Node).name))
		assert_true((p as Node).get_node_or_null(NodePath("Borda")) != null, "Painel tem borda com brilho: " + str((p as Node).name))
	for lbl in ["HUD/PlacaVoce/LpVoce", "HUD/PlacaTurno/CaixaTurno/Turno", "HUD/PlacaRival/LpRival",
			"HUD/TagVoce", "HUD/TagRival", "HUD/BarraStart/StartHelp"]:
		assert_true(mesa.get_node_or_null(NodePath(lbl)) != null, "HUD existe: " + lbl)


func test_estado_real_reflete_no_campo_3d() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# Leitura: 10 cartas desenhadas (5 abertas p0 + 5 de costas p1), campo vazio.
	var desenhadas: int = (_n3d(mesa, "Cartas") as Node3D).get_child_count()
	assert_eq(desenhadas, 10, "Campo 3D desenha as 10 da mão (5 abertas + 5 de costas).")
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
	for f in (_n3d(mesa, "Cartas") as Node3D).get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
			achou = true
			card_id = str((f as Node).get_meta("card_id"))
	assert_true(achou, "Carta invocada aparece no painel 3D %s (leitura do estado)." % sid)
	assert_false(card_id.is_empty(), "Carta 3D carrega o card_id do estado real.")


func test_posicao_carta_exatamente_no_painel() -> void:
	# 2D-vs-3D (a): cada carta no XZ EXATO do painel do seu slot, nos 2 lados
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
	var slots: Node = _n3d(mesa, "Campo/Slots")
	for lado in [0, 1]:
		var zona: Array = (st.players[lado] as Dictionary)["monster"]
		for i in range(zona.size()):
			if zona[i] == null:
				continue
			var sid := "p%d_m%d" % [lado, i]
			var painel := slots.get_node_or_null(NodePath("Painel_" + sid)) as Node3D
			var carta: Node3D = null
			for f in (_n3d(mesa, "Cartas") as Node3D).get_children():
				if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
					carta = f as Node3D
			assert_true(painel != null, "Painel existe: " + sid)
			assert_true(carta != null, "Carta desenhada no slot: " + sid)
			if painel == null or carta == null:
				continue
			assert_almost_eq(carta.position.x, painel.position.x, 0.001, "Carta XZ no painel %s (x)." % sid)
			assert_almost_eq(carta.position.z, painel.position.z, 0.001, "Carta XZ no painel %s (z)." % sid)
			# Confere contra o BoardLayout real (espelho do rival incluso).
			var p2: Vector2 = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(lado, "monstro", i), BoardLayout.default_pos(BoardLayout.slot_id(lado, "monstro", i)))
			var esp_x := (p2.x - 1158.0) / 150.0
			var esp_z := (p2.y - 540.0) / 150.0
			assert_almost_eq(painel.position.x, esp_x, 0.001, "Painel %s no X do BoardLayout." % sid)
			assert_almost_eq(painel.position.z, esp_z, 0.001, "Painel %s no Z do BoardLayout." % sid)


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
	# Indicador ATK/DEF por carta + foco espelhado no painel (sem textos
	# inventados: InfoSlot/FilaFusao/Dica/Log removidos da tela).
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(mesa.get_node_or_null(NodePath("HUD/InfoSlot")) == null, "Sem InfoSlot inventado.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/FilaFusao")) == null, "Sem FilaFusao inventada.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/Dica")) == null, "Sem Dica inventada.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/Log")) == null, "Sem Log inventado.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/MaoRival")) == null, "Sem MaoRival inventado.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoRivalNome")) == null, "Sem nome sob retrato.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoVoceNome")) == null, "Sem nome sob retrato.")
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
	for f in (_n3d(mesa, "Cartas") as Node3D).get_children():
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
	var foco: Dictionary = mesa.call("_carta_focada")
	assert_false((foco.get("dado", {}) as Dictionary).is_empty(), "Foco encontra a carta do slot.")
	assert_true(str((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoNome") as Label).text) != "—", "Painel espelha o foco (%s)." % sid)


func test_verso_marrom_com_espiral() -> void:
	# Ref: carta virada = marrom com verso espiral (sem cruz azul).
	var mesa: Node = await _mesa3d_nova()
	var carta := mesa.call("_fazer_carta", {}, true, 1, false) as Node3D
	assert_true(carta != null, "Carta virada construída.")
	assert_true(carta.get_node_or_null(NodePath("Cruz")) == null, "Sem cruz no verso.")
	var verso := carta.get_node_or_null(NodePath("Verso")) as MeshInstance3D
	assert_true(verso != null, "Verso existe.")
	assert_eq((verso.material_override as StandardMaterial3D).albedo_color, Color(0.45, 0.28, 0.13), "Verso marrom da ref.")
	var espiral := carta.get_node_or_null(NodePath("Espiral")) as Node3D
	assert_true(espiral != null, "Espiral do verso existe.")
	assert_eq(espiral.get_child_count(), 3, "Espiral com 3 anéis.")
	carta.free()


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
	assert_eq(n_botao, 0, "Campo 3D tem zero botão.")
	assert_eq(n_clicavel, 0, "Todo Control do campo 3D está sem clique.")


func test_camera_fixa_sem_orbita() -> void:
	# Ref GX: câmera FIXA deslocada (campo colado à direita), sem órbita.
	var mesa: Node = await _mesa3d_nova()
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	assert_true(cam != null, "Camera3D existe.")
	assert_eq(cam.position, Vector3(0, 9, 8), "Câmera fixa (posição do usuário).")
	assert_eq(cam.fov, 50.0, "FOV fixo com profundidade da ref.")
	await wait_process_frames(10)
	assert_eq((_n3d(mesa, "Camera3D") as Camera3D).position, Vector3(0, 9, 8), "Câmera não deriva (sem órbita).")


func test_campo_a_direita_sem_perspectiva_torta() -> void:
	# Doc 15 §15.4 (pedido do usuário: "a mesma perspectiva de quando fica no
	# meio"): o campo foi para a DIREITA empurrando a JANELA (SubViewport),
	# nunca a LENTE. Aqui travamos as 3 coisas que fazem isso:
	#  1) a janela ocupa x 562..1920 (29,3%..100% medidos na referência);
	#  2) a lente fica NO EIXO (frustum_offset = 0) = projeção simétrica;
	#  3) o centro do campo cai no meio DA JANELA = 64,6% da tela.
	var mesa: Node = await _mesa3d_nova()
	var vp := mesa.get_node_or_null(NodePath(JANELA)) as SubViewport
	assert_true(vp != null, "Mundo 3D dentro de um SubViewport (janela do campo).")
	assert_eq(vp.size, Vector2i(1358, 1080), "Janela com a região do campo (1358x1080).")
	assert_true(vp.own_world_3d, "Janela com mundo 3D próprio (o céu não invade o HUD).")
	var camada := mesa.get_node_or_null(NodePath("Camada3D")) as CanvasLayer
	assert_true(camada != null, "Camada da janela 3D existe.")
	assert_eq(camada.layer, -1, "Janela 3D ATRÁS do HUD 2D (camada 0).")
	var janela := mesa.get_node_or_null(NodePath("Camada3D/JanelaCampo")) as SubViewportContainer
	assert_true(janela != null, "Janela do campo exibida na tela.")
	assert_eq(janela.position, Vector2(562, 0), "Janela começa em 29,3% da largura (562 px).")
	assert_eq(janela.size, Vector2(1358, 1080), "Janela ocupa até a borda direita, altura toda.")
	assert_eq(janela.stretch_shrink, 1, "Textura 1:1 (sem escala/rotação na imagem do campo).")
	# O HUD 2D continua em tela cheia, filho da cena (nada dele entrou no 3D).
	assert_true(mesa.get_node_or_null(NodePath("HUD")) != null, "HUD 2D segue filho da cena.")
	assert_true(mesa.get_node_or_null(NodePath(JANELA + "/HUD")) == null, "Nenhum HUD dentro da janela 3D.")
	# A LENTE: mesma posição/alvo/FOV de sempre e SEM deslocamento.
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	assert_eq(cam.frustum_offset, Vector2.ZERO, "Lente no eixo: frustum_offset = 0 (nada de torto).")
	assert_eq(cam.position, Vector3(0, 9, 8), "Câmera exatamente onde estava antes da janela.")
	# O CENTRO DO CAMPO no meio da janela = 562 + 1358/2 = 1241 px = 64,6%.
	var centro_campo: float = cam.unproject_position(Vector3(0.0, 0.35, 0.0)).x + 562.0
	assert_almost_eq(centro_campo, 1241.0, 1.0, "Centro do campo em 1241 px (64,6%% da tela): %.1f." % centro_campo)
	assert_almost_eq(centro_campo / 1920.0 * 100.0, 64.6, 0.1, "Centro do campo em 64,6% da tela (ref: ~63,5%).")
	# SIMETRIA: as pontas das fileiras equidistantes do centro (a projeção é
	# simétrica porque a lente está no eixo). Se um lado esticar e o outro
	# comprimir, a diferença aqui estoura e o teste pega.
	var meio := 679.0
	for lado in [0, 1]:
		var esq: float = cam.unproject_position(mesa.call("_pos_slot", lado, "monstro", 0) as Vector3).x
		var dir: float = cam.unproject_position(mesa.call("_pos_slot", lado, "monstro", 4) as Vector3).x
		var a := minf(esq, dir)
		var b := maxf(esq, dir)
		assert_true(a < meio and b > meio, "Fileira p%d tem slots dos 2 lados do centro." % int(lado))
		assert_almost_eq(meio - a, b - meio, 0.5,
			"Fileira p%d simétrica: %.2f px à esquerda e %.2f px à direita do centro." % [int(lado), meio - a, b - meio])


func test_maos_centralizadas_no_x_do_campo() -> void:
	# Bug do usuário (2026-09-28): as duas mãos saíam tortas na tela porque o
	# X do centro do arco era chutado "no olho" (0.3 e -2.8). Agora é
	# CALCULADO da câmera real: o centro do arco de p0 E de p1 tem que cair no
	# mesmo X de tela do centro do campo. Medido em PIXELS, como o usuário vê.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var n1: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
	var alvo: float = cam.unproject_position(Vector3(0.0, 0.35, 0.0)).x
	var x_p0 := 0.0
	var x_p1 := 0.0
	for lado in [0, 1]:
		var q: int = n0 if lado == 0 else n1
		var centro: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(q), q, lado)
		var sx: float = cam.unproject_position(centro).x
		assert_almost_eq(sx, alvo, 0.5, "Centro do arco de p%d no X de tela do centro do campo (%.2f vs %.2f)." % [lado, sx, alvo])
		if lado == 0:
			x_p0 = sx
		else:
			x_p1 = sx
	assert_almost_eq(x_p0, x_p1, 0.5, "As DUAS mãos centralizadas no mesmo X de tela.")
	# Arco SIMÉTRICO (1ª e última equidistantes do centro) e Y/Z preservados.
	var p0_1: Vector3 = mesa.call("_pos_mao_arco", 0, n0, 0)
	var p0_m: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(n0), n0, 0)
	var p0_f: Vector3 = mesa.call("_pos_mao_arco", n0 - 1, n0, 0)
	assert_almost_eq(p0_m.x - p0_1.x, p0_f.x - p0_m.x, 0.001, "Arco da sua mão simétrico em torno do centro.")
	assert_almost_eq(p0_m.y, 4.35, 0.0001, "Altura da sua mão preservada (ordem do usuário).")
	assert_almost_eq(p0_m.z, 6.1, 0.0001, "Profundidade da sua mão preservada (ordem do usuário).")
	var p1_1: Vector3 = mesa.call("_pos_mao_arco", 0, n1, 1)
	var p1_m: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(n1), n1, 1)
	var p1_f: Vector3 = mesa.call("_pos_mao_arco", n1 - 1, n1, 1)
	assert_almost_eq(p1_m.x - p1_1.x, p1_f.x - p1_m.x, 0.001, "Arco da mão do rival simétrico em torno do centro.")
	assert_almost_eq(p1_m.y, 1.4, 0.0001, "Altura da mão do rival preservada.")
	assert_almost_eq(p1_m.z, -4.75, 0.0001, "Profundidade da mão do rival preservada.")
	# Espalhamento preservado: passo por carta (o usuário não pediu mudar).
	var passo0 := (p0_m.x - p0_1.x) / float(maxi(_meio_do_arco(n0), 1))
	var passo1 := (p1_m.x - p1_1.x) / float(maxi(_meio_do_arco(n1), 1))
	assert_almost_eq(passo0, 1.12, 0.001, "Passo por carta da sua mão preservado (1.12).")
	assert_almost_eq(passo1, 0.7, 0.001, "Passo por carta da mão do rival preservado (0.7).")
	# A carta DESENHADA tem que estar no ponto que a função devolveu.
	var vistas := 0
	for f in (_n3d(mesa, "Cartas") as Node3D).get_children():
		if not (f as Node).has_meta("mao_idx"):
			continue
		vistas += 1
		var i: int = int((f as Node).get_meta("mao_idx"))
		var esperado: Vector3 = mesa.call("_pos_mao_arco", i, n0, 0)
		assert_almost_eq((f as Node3D).position.x, esperado.x, 0.0001, "Carta desenhada %d no X do arco." % i)
	assert_eq(vistas, n0, "As %d cartas da sua mão desenhadas seguem o arco centralizado." % n0)
	# O cursor da fileira da mão usa a MESMA função: centraliza junto.
	mesa.set("_fileira", 0)
	mesa.set("_col", _meio_do_arco(n0))
	mesa.call("_posicionar_cursor")
	var cur: Vector3 = (_n3d(mesa, "Cursor3D") as Node3D).position
	assert_almost_eq(cur.x, p0_m.x, 0.001, "Cursor da mão bate com a carta centralizada.")


func test_placas_topo_com_dado_real_sem_marca() -> void:
	# Ref: placa do seu LP esq / TURN centro / rival+LP dir. Sem KONAMI.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	for caminho in ["HUD/PlacaVoce", "HUD/PlacaTurno", "HUD/PlacaRival"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Placa existe: " + caminho)
	var voce := (mesa.get_node("HUD/PlacaVoce") as Control).position
	var turno := (mesa.get_node("HUD/PlacaTurno") as Control).position
	var rival := (mesa.get_node("HUD/PlacaRival") as Control).position
	assert_true(voce.x < turno.x, "Sua placa à esquerda do TURN.")
	assert_true(turno.x < rival.x, "TURN ao centro, rival à direita.")
	assert_true(str((mesa.get_node("HUD/PlacaTurno/CaixaTurno/TurnoTitulo") as Label).text).contains("TURN"), "Turno mostra TURN.")
	assert_eq(str((mesa.get_node("HUD/PlacaTurno/CaixaTurno/Turno") as Label).text), str(int(st.turn_number)), "TURN com o turno real.")
	var lp0: int = int((st.players[0] as Dictionary)["lp"])
	assert_eq(str((mesa.get_node("HUD/PlacaVoce/LpVoce") as Label).text), "LP %d %s" % [lp0, str(mesa.get("_nome_voce")).to_upper()], "Sua placa com LP + nome reais.")
	var nome_rival: String = str(mesa.get("_nome_rival")).to_upper()
	var lp1: int = int((st.players[1] as Dictionary)["lp"])
	assert_eq(str((mesa.get_node("HUD/PlacaRival/LpRival") as Label).text), "%s LP %d" % [nome_rival, lp1], "Placa rival com nome + LP reais.")
	# Sem marca da ref nem marca d'água do print em nenhum texto da cena.
	var todos: Array = []
	_coletar(mesa, todos)
	for n in todos:
		if n is Label:
			var t := str((n as Label).text)
			assert_false(t.contains("KONAMI"), "Sem KONAMI no HUD: " + str((n as Node).name))
			assert_false(t.contains("START.COM"), "Sem marca d'água no HUD: " + str((n as Node).name))
		if n is Label3D:
			var t3 := str((n as Label3D).text)
			assert_false(t3.contains("KONAMI"), "Sem KONAMI no 3D: " + str((n as Node).name))
			assert_false(t3.contains("START.COM"), "Sem marca d'água no 3D: " + str((n as Node).name))


func test_retratos_rival_e_voce() -> void:
	# Ref: retrato do rival no canto superior direito (moldura laranja) +
	# retrato seu à esquerda do campo. Sem foto = silhueta com a inicial.
	var mesa: Node = await _mesa3d_nova()
	for caminho in ["HUD/RetratoRival", "HUD/RetratoVoce"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Retrato existe: " + caminho)
	var rr := (mesa.get_node("HUD/RetratoRival") as Control).position
	var rv := (mesa.get_node("HUD/RetratoVoce") as Control).position
	assert_true(rr.x > 1500.0, "Retrato do rival no canto superior direito.")
	assert_true(rr.y < 200.0, "Retrato do rival no topo.")
	assert_true(rv.x < 900.0, "Seu retrato à esquerda do campo.")
	for quem in ["Rival", "Voce"]:
		var foto := mesa.get_node("HUD/Retrato%s/Foto" % quem) as TextureRect
		var silhueta := mesa.get_node("HUD/Retrato%s/Silhueta" % quem) as Label
		assert_true(foto != null and silhueta != null, "Retrato %s tem foto + silhueta." % quem)
		assert_true(foto.visible != silhueta.visible, "Retrato %s: foto OU silhueta." % quem)
		if silhueta.visible:
			var nome: String = str(mesa.get("_nome_rival" if quem == "Rival" else "_nome_voce"))
			assert_eq(silhueta.text, nome.strip_edges().substr(0, 1).to_upper(), "Silhueta com a inicial do nome (%s)." % quem)
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoRivalNome")) == null, "Sem nome sob retrato (nome vive na placa).")
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoVoceNome")) == null, "Sem nome sob retrato (nome vive na placa).")


func test_painel_esquerdo_carta_focada() -> void:
	# Ref nova: painel 2D fixo à esquerda estilo CARTA (fundo bege, nome e
	# tipo verdes, barra vermelha), carta GRANDE + faixa ATK/DEF + NOME +
	# [TIPO] + DESCRIÇÃO do dado real.
	var mesa: Node = await _mesa3d_nova()
	assert_true(mesa.get_node_or_null(NodePath("HUD/PainelCarta")) != null, "Painel esquerdo existe.")
	var est := (mesa.get_node("HUD/PainelCarta") as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(est.border_color, Color(0.45, 0.28, 0.12), "Painel com moldura marrom estilo carta.")
	for caminho in ["HUD/PainelCarta/Linha/Caixa/BlocoDesc", "HUD/PainelCarta/Linha/Caixa/CartaMolde",
			"HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoNome", "HUD/PainelCarta/Linha/Caixa/CartaMolde/Moldura",
			"HUD/PainelCarta/Linha/Caixa/CartaMolde/FocoArte", "HUD/PainelCarta/Linha/Caixa/CartaMolde/FocoCor",
			"HUD/PainelCarta/Linha/Caixa/CartaMolde/FocoNomeMolde", "HUD/PainelCarta/Linha/Caixa/CartaMolde/FocoOrbe",
			"HUD/PainelCarta/Linha/Caixa/CartaMolde/FocoEstrelasBox",
			"HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoFaixa/FocoAttrIcon", "HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoFaixa/FocoAttr",
			"HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoFaixa/FocoStats",
			"HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoTipo", "HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoDesc",
			"HUD/PainelCarta/Linha/BarraVermelha"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Painel tem: " + caminho)
	var st = mesa.get("_st")
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	assert_true(mao.size() > 0, "Preparo: mão p0 tem carta.")
	mesa.set("_fileira", 0)
	mesa.set("_col", 0)
	mesa.call("_atualizar_hud")
	await wait_process_frames(1)
	var nome := str((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoNome") as Label).text)
	assert_false(nome.is_empty() or nome == "—", "Painel mostra o nome real da carta focada: " + nome)
	var stats := str((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoFaixa/FocoStats") as Label).text)
	assert_true(stats.contains("ATK/") and stats.contains("DEF/"), "Faixa ATK/DEF do dado real: " + stats)
	var attr := str((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoFaixa/FocoAttr") as Label).text)
	assert_false(attr.is_empty(), "Faixa mostra o atributo: " + attr)
	var desc := str((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoDesc") as Label).text)
	assert_false(desc.is_empty(), "Painel mostra a descrição (ou guardiãs + atributo).")
	# Bloco com tamanho FIXO (ref): descrição longa nunca muda o tamanho.
	var bloco := mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc") as Control
	assert_eq(bloco.custom_minimum_size, Vector2(300, 330), "Bloco de descrição tem tamanho fixo.")
	assert_true((mesa.get_node("HUD/PainelCarta/Linha/Caixa/BlocoDesc/Bloco/FocoDesc") as Label).clip_text, "Descrição corta com clip (não estoura o bloco).")


func test_fases_no_meio_laterais_e_tokens() -> void:
	# SEM fases Tag Force (ordem do usuário, duelo segue o FM):
	# nenhum nó de fase existe; laterais + tokens continuam.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_n3d(mesa, "Campo/Fases") == null, "Sem fileira de fases.")
	for tag in ["DP", "SP", "MP1", "BP", "MP2", "EP"]:
		assert_true(_n3d(mesa, "Campo/Fases/Fase_" + tag) == null, "Sem fase: " + tag)
	for caminho in ["Campo/Laterais/DeckRival", "Campo/Laterais/DeckVoce", "Campo/Laterais/CemRival", "Campo/Laterais/CemVoce"]:
		assert_true(_n3d(mesa, caminho) != null, "Lateral existe: " + caminho)
	# Contadores = números puros do estado real (ref: 33/32/6).
	var esperados := {
		"Campo/Laterais/ContaDeckVoce": ((st.players[0] as Dictionary)["deck"] as Array).size(),
		"Campo/Laterais/ContaCemVoce": ((st.players[0] as Dictionary)["graveyard"] as Array).size(),
		"Campo/Laterais/ContaDeckRival": ((st.players[1] as Dictionary)["deck"] as Array).size(),
		"Campo/Laterais/ContaCemRival": ((st.players[1] as Dictionary)["graveyard"] as Array).size(),
		"Campo/ContaMaoRival": ((st.players[1] as Dictionary)["hand"] as Array).size(),
	}
	for caminho in esperados.keys():
		assert_true(_n3d(mesa, caminho) != null, "Contador existe: " + caminho)
		assert_eq(str((_n3d(mesa, caminho) as Label3D).text), str(int(esperados[caminho])), "Contador com o número real: " + caminho)
	assert_true(mesa.get_node_or_null(NodePath("HUD/MaoRival")) == null, "Sem MaoRival em texto (número vive no 3D).")
	for caminho in ["Campo/Tokens/TokenX", "Campo/Tokens/TokenBussola"]:
		assert_true(_n3d(mesa, caminho) != null, "Token decorativo existe: " + caminho)
	assert_true(_n3d(mesa, "Ceu") != null, "Céu azul existe.")
	var filhos_ceu := (_n3d(mesa, "Ceu") as Node3D).get_child_count()
	assert_true(filhos_ceu >= 24, "Céu com pilares + nuvens (10 + 14): %d." % filhos_ceu)
