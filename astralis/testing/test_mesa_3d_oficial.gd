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
## Consts do desenho 3D que o GUT espelha (D3 mudou a mão do rival para
## trás do campo). A trava é o valor da const do runtime: se alguém mexer
## na const sem atualizar o desenho, o teste acusa.
const ALT_CARTA_TESTE := 86.0 / 59.0
const MAO_P1_YZ_TESTE := Vector2(-0.35, -6.45)
const MAO_P1_PASSO_TESTE := 0.86


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
	# FASE 3: LP e nome ganharam rótulos separados dentro da placa (o valor
	# em amarelo, como na ref), e a aba inventada "Single" saiu de vez.
	for lbl in ["HUD/PlacaVoce/Linha/LpVoce", "HUD/PlacaVoce/Linha/NomeVoce",
			"HUD/PlacaTurno/CaixaTurno/Turno", "HUD/PlacaRival/Linha/LpRival",
			"HUD/PlacaRival/Linha/NomeRival", "HUD/BarraTopo", "HUD/BarraFases",
			"HUD/BarraStart/StartHelp"]:
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
			# O 3D tem de ser a ARENA (dado) transformada por ESCALA uniforme +
			# DESLOC (doc 15 §15.5) — o assert prova o TRANSFORM, não a
			# identidade: a composição e o espelho do rival (D17/D18) vêm do
			# dado, e escala/deslocamento são apresentação.
			var p2: Vector2 = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(lado, "monstro", i), BoardLayout.default_pos(BoardLayout.slot_id(lado, "monstro", i)))
			var esc: float = mesa.get("ESCALA_CAMPO")
			var desl: Vector2 = mesa.get("DESLOC_CAMPO")
			assert_true(esc > 0.0, "Escala de apresentação positiva.")
			var esp_x := (p2.x - 1158.0) / 150.0 * esc + desl.x
			var esp_z := (p2.y - 540.0) / 150.0 * esc + desl.y
			assert_almost_eq(painel.position.x, esp_x, 0.001, "Painel %s no X do BoardLayout transformado." % sid)
			assert_almost_eq(painel.position.z, esp_z, 0.001, "Painel %s no Z do BoardLayout transformado." % sid)
	# O transform é o MESMO nos 2 lados (escala uniforme = o espelho do rival
	# continua valendo) e é o mesmo em X e Y da arena.
	var mundo0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var mundo1: Vector3 = mesa.call("_pos_slot", 1, "monstro", 0)
	var a0: Vector2 = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 0), Vector2(632, 695))
	var a1: Vector2 = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(1, "monstro", 0), Vector2(632, 305))
	var esc: float = mesa.get("ESCALA_CAMPO")
	var desl: Vector2 = mesa.get("DESLOC_CAMPO")
	assert_almost_eq(mundo0.x, (a0.x - 1158.0) / 150.0 * esc + desl.x, 0.001, "p0 segue a arena transformada (x).")
	assert_almost_eq(mundo0.z, (a0.y - 540.0) / 150.0 * esc + desl.y, 0.001, "p0 segue a arena transformada (z).")
	assert_almost_eq(mundo1.x, (a1.x - 1158.0) / 150.0 * esc + desl.x, 0.001, "p1 segue a arena transformada (x).")
	assert_almost_eq(mundo1.z, (a1.y - 540.0) / 150.0 * esc + desl.y, 0.001, "p1 segue a arena transformada (z).")
	# Espelho do rival: p1_m0 fica no X OPOSTO do p0_m0 (D18) e a distância
	# entre os dois é a MESMA que entre os extremos do próprio lado.
	var p0_0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var p0_4: Vector3 = mesa.call("_pos_slot", 0, "monstro", 4)
	var p1_0: Vector3 = mesa.call("_pos_slot", 1, "monstro", 0)
	var p1_4: Vector3 = mesa.call("_pos_slot", 1, "monstro", 4)
	assert_almost_eq(p0_0.x, -p1_0.x, 0.001, "Espelho do rival: p1_m0 é o oposto de p0_m0 (x).")
	assert_almost_eq(absf(p0_4.x - p0_0.x), absf(p1_0.x - p1_4.x), 0.001, "Distância do espelho é a mesma dos 2 lados.")
	# A ESCALA é uniforme: a mesma escala vale no eixo X e no Z do dado.
	var x0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var x1: Vector3 = mesa.call("_pos_slot", 0, "monstro", 1)
	var z0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var z1: Vector3 = mesa.call("_pos_slot", 0, "magia", 0)
	var px_arena: float = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 1), Vector2(0, 0)).x - BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 0), Vector2(0, 0)).x
	var pz_arena: float = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "magia", 0), Vector2(0, 0)).y - BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 0), Vector2(0, 0)).y
	assert_almost_eq(absf(x1.x - x0.x) / px_arena, absf(z1.z - z0.z) / pz_arena, 0.0001,
		"A escala é a mesma nos 2 eixos (uniforme).")


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
	assert_true(str((mesa.get_node("HUD/PainelCarta/FocoNome") as Label).text) != "—", "Painel espelha o foco (%s)." % sid)


func test_verso_marrom_com_espiral() -> void:
	# Ref: carta virada = verso marrom com espiral (sem cruz azul). Com o
	# asset EMBUTIDO (doc 15 §15.2, fase 2) o verso é a arte real; SEM ele,
	# cai no marrom com espiral. Os dois caminhos são o comportamento certo:
	# o que NUNCA pode é a cruz azul.
	var mesa: Node = await _mesa3d_nova()
	var carta := mesa.call("_fazer_carta", {}, true, 1, false) as Node3D
	assert_true(carta != null, "Carta virada construída.")
	assert_true(carta.get_node_or_null(NodePath("Cruz")) == null, "Sem cruz no verso.")
	var verso := carta.get_node_or_null(NodePath("Verso")) as MeshInstance3D
	assert_true(verso != null, "Verso existe.")
	var mat := verso.material_override as StandardMaterial3D
	if mat.albedo_texture != null:
		assert_eq(mat.albedo_texture.get_size(), Vector2(813, 1185), "Verso usa a arte real embutida.")
		assert_eq((carta.get_node("Espiral") as Node3D).visible, false, "Com arte real, a espiral de fallback some.")
	else:
		assert_eq(mat.albedo_color, Color(0.45, 0.28, 0.13), "Sem arte, verso marrom da ref.")
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
	# Ref GX: câmera FIXA (posição/FOV medidos contra a referência, doc 15
	# §15.5), sem órbita e sem deslocamento em X.
	var mesa: Node = await _mesa3d_nova()
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	assert_true(cam != null, "Camera3D existe.")
	assert_eq(cam.position, Vector3(0, 16.8, 20.9), "Câmera fixa (posição medida).")
	assert_eq(cam.fov, 20.0, "FOV fixo medido contra a referência.")
	await wait_process_frames(10)
	assert_eq((_n3d(mesa, "Camera3D") as Camera3D).position, Vector3(0, 16.8, 20.9), "Câmera não deriva (sem órbita).")


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
	# A LENTE: no EIXO (X = 0, sem frustum_offset) e apontada para o centro.
	# A altura/Z/FOV podem mudar (doc 15 §15.5, alavanca de desenho), mas a
	# tríade que garante a perspectiva simétrica é intocável.
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	assert_eq(cam.frustum_offset, Vector2.ZERO, "Lente no eixo: frustum_offset = 0 (nada de torto).")
	assert_eq(cam.position.x, 0.0, "Câmera sem deslocamento em X (a lente fica no eixo).")
	assert_eq(cam.position, Vector3(0, 16.8, 20.9), "Câmera na altura/Z medidos contra a referência.")
	assert_eq(cam.fov, 20.0, "FOV medido contra a referência.")
	assert_eq(cam.global_position, Vector3(0, 16.8, 20.9), "Câmera dentro da janela 3D (transform da janela não move a lente).")
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
	# Y/Z da SUA mão: mudaram na FASE 2 (doc 15 §15.3) porque a mão tinha
	# 45% da tela e ficava colada no START. Agora ela é pequena e vive no
	# rodapé, cortada embaixo — os valores são as consts MAO_P0_YZ, e a
	# trava continua sendo a MESMA coisa: o que importa (centralização no X
	# do campo, simetria do arco, carta desenhada no ponto e cursor) segue
	# travado abaixo com a mesma tolerância. O Y/Z mudou de novo porque a
	# CÂMERA mudou (doc 15 §15.5): a mão é medida contra a referência
	# (cartas de ~190 px no rodapé, cortadas embaixo) com a câmera nova.
	assert_almost_eq(p0_m.y, 4.63, 0.0001, "Altura da sua mão = MAO_P0_YZ medida na referência.")
	assert_almost_eq(p0_m.z, 10.0, 0.0001, "Profundidade da sua mão = MAO_P0_YZ medida na referência.")
	var p1_1: Vector3 = mesa.call("_pos_mao_arco", 0, n1, 1)
	var p1_m: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(n1), n1, 1)
	var p1_f: Vector3 = mesa.call("_pos_mao_arco", n1 - 1, n1, 1)
	assert_almost_eq(p1_m.x - p1_1.x, p1_f.x - p1_m.x, 0.001, "Arco da mão do rival simétrico em torno do centro.")
	# D3: o Y/Z da mão do RIVAL mudou de propósito, e a trava nova é mais
	# forte que o número solto. Medido: a fileira de magia do rival fica em
	# z = -4,42 e o ladrilho dela avança até z = -5,36 — com a mão em
	# z = -5,18 ela ficava DENTRO desse ladrilho e o vidro escuro dele
	# (alpha 0,72) pintava a metade de baixo das cartas viradas, que na ref
	# não existe. A trava agora é GEOMÉTRICA: a mão inteira atrás da
	# pegada do campo, e continua em cima na tela (11%..26% da altura).
	var peca: float = float(mesa.call("_peca_prof_carta"))
	var z_dos_slots := 0
	for zona_nome in ["monster", "spell"]:
		for i in range(5):
			var ps: Vector3 = mesa.call("_pos_slot", 1, ("monstro" if zona_nome == "monster" else "magia"), i)
			z_dos_slots += 1
			# Cada ladrilho do rival, com a METADE que avança para a câmera:
			# nenhum deles pode ficar na frente da carta da mão.
			assert_true(p1_m.z < ps.z - peca * 0.5,
				"Mão do rival atrás do ladrilho %s%d (mao %.2f < vidro %.2f) — nada de vidro na frente." % [
					("p1_m" if zona_nome == "monster" else "p1_s"), i, p1_m.z, ps.z - peca * 0.5])
	assert_eq(z_dos_slots, 10, "Os 10 ladrilhos do rival conferidos contra a mão.")
	assert_almost_eq(p1_m.y, MAO_P1_YZ_TESTE.x, 0.0001, "Altura da mão do rival = MAO_P1_YZ medido na referência.")
	# Espalhamento preservado: passo por carta.
	var passo0 := (p0_m.x - p0_1.x) / float(maxi(_meio_do_arco(n0), 1))
	var passo1 := (p1_m.x - p1_1.x) / float(maxi(_meio_do_arco(n1), 1))
	assert_almost_eq(passo0, 1.06, 0.001, "Passo por carta da sua mão = MAO_P0_PASSO da fase 2 (1.06).")
	assert_almost_eq(passo1, MAO_P1_PASSO_TESTE, 0.001, "Passo por carta da mão do rival = MAO_P1_PASSO (acompanhado a nova profundidade).")
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
	# FASE 3 (doc 15 §15.3): a barra metálica azul ocupa SÓ a faixa do campo
	# (x 562..1920) e as 3 placas ficam nas faixas medidas da ref
	# (você 576..960 / TURN 1190..1460 / rival 1458..1920). Os valores de LP
	# e turno saem SEMPRE do estado real; a aba "Single" foi removida porque
	# era texto inventado (nosso contrato não tem modo de duelo).
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	for caminho in ["HUD/BarraTopo", "HUD/PlacaVoce", "HUD/PlacaTurno", "HUD/PlacaRival"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Peça do topo existe: " + caminho)
	var barra := mesa.get_node("HUD/BarraTopo") as Control
	assert_eq(barra.position, Vector2(562, 0), "Barra metálica começa na borda do painel esquerdo (x 562).")
	assert_true(barra.size.x >= 1358.0 and barra.size.y <= 93.0, "Barra metálica vai até a direita com altura ~8,5%%: %s" % str(barra.size))
	var voce := (mesa.get_node("HUD/PlacaVoce") as Control).position
	var turno := (mesa.get_node("HUD/PlacaTurno") as Control).position
	var rival := (mesa.get_node("HUD/PlacaRival") as Control).position
	assert_true(voce.x < turno.x, "Sua placa à esquerda do TURN.")
	assert_true(turno.x < rival.x, "TURN ao centro, rival à direita.")
	assert_true(voce.x >= 562.0 and voce.x + 384.0 <= 960.0, "Sua placa na faixa 576..960 da ref: %d." % int(voce.x))
	assert_true(turno.x >= 1190.0 and turno.x + 270.0 <= 1460.0, "Caixa TURN na faixa 1190..1460 da ref: %d." % int(turno.x))
	assert_true(rival.x >= 1458.0 and rival.x + 462.0 <= 1920.0, "Placa rival na faixa 1458..1920 da ref: %d." % int(rival.x))
	assert_true(str((mesa.get_node("HUD/PlacaTurno/CaixaTurno/TurnoTitulo") as Label).text).contains("TURN"), "Turno mostra TURN.")
	assert_eq(str((mesa.get_node("HUD/PlacaTurno/CaixaTurno/Turno") as Label).text), str(int(st.turn_number)), "TURN com o turno real.")
	# O VALOR de LP fica sozinho no rótulo (amarelo) e o NOME em outro rótulo
	# — os dois com o dado real, como na ref.
	var lp0: int = int((st.players[0] as Dictionary)["lp"])
	var lp1: int = int((st.players[1] as Dictionary)["lp"])
	assert_eq(str((mesa.get_node("HUD/PlacaVoce/Linha/LpVoce") as Label).text), str(lp0), "Sua placa com o LP real.")
	assert_eq(str((mesa.get_node("HUD/PlacaRival/Linha/LpRival") as Label).text), str(lp1), "Placa rival com o LP real.")
	assert_eq(str((mesa.get_node("HUD/PlacaVoce/Linha/NomeVoce") as Label).text), str(mesa.get("_nome_voce")).to_upper(), "Sua placa com o nome real.")
	assert_eq(str((mesa.get_node("HUD/PlacaRival/Linha/NomeRival") as Label).text), str(mesa.get("_nome_rival")).to_upper(), "Placa rival com o nome real.")
	# Aba "Single" removida: nosso duelo não tem modo declarado.
	assert_true(mesa.get_node_or_null(NodePath("HUD/TagVoce")) == null, "Sem aba inventada TagVoce.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/TagRival")) == null, "Sem aba inventada TagRival.")
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
	# FASE 3: moldura clara com FUNDO EM GRADIENTE + inicial (placeholder
	# elegante). O pack do FM NÃO traz retrato de duelista (os 39 duelistas
	# vêm com `portrait` vazio), então a foto real nunca aparece — se um dia
	# vier, a foto substitui o placeholder. Rival no topo à direita, você à
	# esquerda do campo.
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
		var fundo := mesa.get_node("HUD/Retrato%s/Fundo" % quem) as TextureRect
		var silhueta := mesa.get_node("HUD/Retrato%s/Silhueta" % quem) as Label
		assert_true(foto != null and silhueta != null, "Retrato %s tem foto + silhueta." % quem)
		# O placeholder não é mais um quadrado chapado: tem gradiente real.
		assert_true(fundo != null and fundo.texture != null, "Retrato %s tem fundo em gradiente." % quem)
		assert_false(foto.visible and silhueta.visible, "Retrato %s: foto OU placeholder, nunca os dois." % quem)
		if silhueta.visible:
			var nome: String = str(mesa.get("_nome_rival" if quem == "Rival" else "_nome_voce"))
			assert_eq(silhueta.text, nome.strip_edges().substr(0, 1).to_upper(), "Placeholder com a inicial do nome (%s)." % quem)
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoRivalNome")) == null, "Sem nome sob retrato (nome vive na placa).")
	assert_true(mesa.get_node_or_null(NodePath("HUD/RetratoVoceNome")) == null, "Sem nome sob retrato (nome vive na placa).")


func test_painel_esquerdo_carta_focada() -> void:
	# FASE 3 (doc 15 §15.3): painel esquerdo AZUL-MARINHO com as faixas medidas
	# na ref — carta y 16..562, ATK/DEF + orbes + contador y 562..648, NOME
	# amarelo y 670..756, TIPO verde y 756..799, DESCRIÇÃO branca com barra
	# laranja y 810..1080. Tudo com o DADO REAL da carta focada.
	var mesa: Node = await _mesa3d_nova()
	assert_true(mesa.get_node_or_null(NodePath("HUD/PainelCarta")) != null, "Painel esquerdo existe.")
	# Fundo azul-marinho (#1b2340) ocupando a faixa x 0..562, altura toda.
	var fundo := mesa.get_node("HUD/FundoPainelEsq") as ColorRect
	assert_eq(fundo.color, Color(0.106, 0.137, 0.251, 1.0), "Fundo do painel no azul-marinho da ref (#1b2340).")
	assert_eq(fundo.size.x, 562, "Fundo do painel na faixa x 0..562 da ref.")
	assert_eq(fundo.size.y, 1080, "Fundo do painel com altura toda.")
	# D5: a linha de atributo em texto ("LUZ") foi REMOVIDA — na ref, depois
	# do [TIPO] vem direto a descrição. O atributo continua visível como
	# ORBE (asset real) na faixa de ATK/DEF e no canto da carta; o que
	# muda aqui é só o texto que não pode mais existir.
	for caminho in ["HUD/PainelCarta/CartaMolde", "HUD/PainelCarta/CartaMolde/Moldura",
			"HUD/PainelCarta/CartaMolde/FocoArte", "HUD/PainelCarta/CartaMolde/FocoCor",
			"HUD/PainelCarta/CartaMolde/FocoNomeMolde", "HUD/PainelCarta/CartaMolde/FocoOrbe",
			"HUD/PainelCarta/CartaMolde/FocoEstrelasBox", "HUD/PainelCarta/FocoFaixa",
			"HUD/PainelCarta/FocoFaixa/FocoAttrIcon", "HUD/PainelCarta/FocoFaixa/FocoStats",
			"HUD/PainelCarta/FocoFaixa/FocoOrbeFaixa", "HUD/PainelCarta/FocoFaixa/FocoOrbeTipo",
			"HUD/PainelCarta/FocoFaixa/FocoCopias", "HUD/PainelCarta/FocoNome",
			"HUD/PainelCarta/FocoTipo", "HUD/PainelCarta/BlocoDesc",
			"HUD/PainelCarta/BlocoDesc/FocoDesc",
			"HUD/PainelCarta/BlocoDesc/BarraVermelha"]:
		assert_true(mesa.get_node_or_null(NodePath(caminho)) != null, "Painel tem: " + caminho)
	assert_true(mesa.get_node_or_null(NodePath("HUD/PainelCarta/BlocoDesc/FocoAttr")) == null,
		"D5: sem linha de atributo em texto (só o orbe real).")
	# As faixas da ref: a carta preserva a proporção da moldura real
	# (832x1248 = 0,667) e fica entre y 16 e 562.
	var molde := mesa.get_node("HUD/PainelCarta/CartaMolde") as Control
	assert_eq(molde.position.y, 16, "Carta começa em y 16 como na ref.")
	assert_true(molde.size.y <= 546, "Carta cabe na faixa y 16..562 da ref: %d." % int(molde.size.y))
	assert_true(molde.size.x < 502.0, "Carta com a proporção da moldura (não esticada na faixa): %d." % int(molde.size.x))
	assert_true(molde.position.x + molde.size.x <= 562, "Carta dentro da faixa do painel, sem vazar.")
	# Faixa ATK/DEF fica logo abaixo da carta, como na ref.
	var faixa := mesa.get_node("HUD/PainelCarta/FocoFaixa") as Control
	assert_true(faixa.position.y >= 562 and faixa.position.y + faixa.size.y <= 648, "Faixa ATK/DEF na faixa y 562..648: %d." % int(faixa.position.y))
	# NOME amarelo, TIPO verde e DESCRIÇÃO branca, nas faixas da ref.
	var l_nome := mesa.get_node("HUD/PainelCarta/FocoNome") as Label
	var l_tipo := mesa.get_node("HUD/PainelCarta/FocoTipo") as Label
	assert_eq(l_nome.get_theme_color("font_color"), Color(1.0, 0.85, 0.15, 1.0), "NOME em amarelo como na ref.")
	assert_eq(l_tipo.get_theme_color("font_color"), Color(0.30, 0.95, 0.45, 1.0), "TIPO em verde como na ref.")
	assert_true(l_nome.position.y >= 670 and l_nome.position.y + l_nome.size.y <= 756, "NOME na faixa y 670..756: %d." % int(l_nome.position.y))
	assert_true(l_tipo.position.y >= 756 and l_tipo.position.y + l_tipo.size.y <= 799, "TIPO na faixa y 756..799: %d." % int(l_tipo.position.y))
	var bloco := mesa.get_node("HUD/PainelCarta/BlocoDesc") as Control
	assert_true(bloco.position.y >= 810, "DESCRIÇÃO começa em y 810 como na ref: %d." % int(bloco.position.y))
	assert_eq((mesa.get_node("HUD/PainelCarta/BlocoDesc/BarraVermelha") as ColorRect).color, Color(1.0, 0.55, 0.0, 1.0), "Barra de rolagem laranja da ref.")
	# Agora o CONTEÚDO: nome, ATK/DEF, atributo e descrição do DADO REAL.
	var st = mesa.get("_st")
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	assert_true(mao.size() > 0, "Preparo: mão p0 tem carta.")
	mesa.set("_fileira", 0)
	mesa.set("_col", 0)
	mesa.call("_atualizar_hud")
	await wait_process_frames(1)
	var nome := str(l_nome.text)
	assert_false(nome.is_empty() or nome == "—", "Painel mostra o nome real da carta focada: " + nome)
	var stats := str((mesa.get_node("HUD/PainelCarta/FocoFaixa/FocoStats") as Label).text)
	assert_true(stats.contains("ATK/") and stats.contains("DEF/"), "Faixa ATK/DEF do dado real: " + stats)
	var tipo := str(l_tipo.text)
	assert_true(tipo.begins_with("["), "TIPO entre colchetes como na ref: " + tipo)
	var desc := str((mesa.get_node("HUD/PainelCarta/BlocoDesc/FocoDesc") as Label).text)
	assert_false(desc.is_empty(), "Painel mostra a descrição (ou guardiãs + atributo).")
	# Orbes: o 1º é o ATRIBUTO (vem do asset real). O 2º (tipo) só aparece
	# se o dado for magia/armadilha — carta sem esse atributo não ganha
	# orbe inventado.
	# D5: o atributo continua aparecendo — como ORBE do asset real (o
	# quadradinho colorido da faixa é a cor do atributo do dado).
	var orbe_attr := mesa.get_node("HUD/PainelCarta/FocoFaixa/FocoOrbeFaixa") as TextureRect
	assert_true(orbe_attr.visible and orbe_attr.texture != null, "Orbe do atributo visível com o asset real.")
	var cor_attr: Color = (mesa.get_node("HUD/PainelCarta/FocoFaixa/FocoAttrIcon") as ColorRect).color
	assert_true(cor_attr.r + cor_attr.g + cor_attr.b > 0.05, "Quadradinho da faixa com a cor real do atributo.")
	var foco: Dictionary = mesa.call("_carta_focada") as Dictionary
	var dado_foco: Dictionary = foco.get("dado", {}) as Dictionary
	var ctipo := str(dado_foco.get("card_type", "monster"))
	if ctipo == "spell" or ctipo == "trap":
		assert_true((mesa.get_node("HUD/PainelCarta/FocoFaixa/FocoOrbeTipo") as TextureRect).visible, "Orbe de tipo visível em " + ctipo + ".")
	# Contador de cópias: só aparece se o baralho do jogador TEM a carta.
	var copias := str((mesa.get_node("HUD/PainelCarta/FocoFaixa/FocoCopias") as Label).text)
	var cid := str(dado_foco.get("card_id", dado_foco.get("id", "")))
	var esperado_copia: int = int(mesa.call("_contar_copia_carta", cid))
	assert_eq(copias, ("x%d" % esperado_copia) if esperado_copia > 0 else "", "Contador de cópias bate com o baralho real (%d)." % esperado_copia)
	# Bloco com tamanho FIXO (ref): descrição longa nunca muda o tamanho.
	assert_true(bloco.custom_minimum_size.y > 0 and bloco.size.y > 0, "Bloco de descrição tem tamanho fixo.")
	assert_true((mesa.get_node("HUD/PainelCarta/BlocoDesc/FocoDesc") as Label).clip_text, "Descrição corta com clip (não estoura o bloco).")
	assert_true(bloco.position.y + bloco.size.y <= 1080.0, "Bloco de descrição não estoura a tela.")


func test_fases_no_meio_laterais_e_tokens() -> void:
	# FASE 3 (doc 15 §15.3): as fases passaram a ser uma barra 2D no MEIO do
	# campo, no meio da altura, com as 4 fases REAIS do motor
	# (DRAW/MAIN/BATTLE/END). Nosso duelo é Forbidden Memories e NÃO tem
	# DP/SP/MP1/BP/MP2/EP (§15.1) — mostrar essas seria inventar mecânica.
	# Laterais, contadores e tokens continuam.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_n3d(mesa, "Campo/Fases") == null, "Sem fileira de fases no 3D (agora é barra 2D).")
	for tag in ["DP", "SP", "MP1", "BP", "MP2", "EP"]:
		assert_true(_n3d(mesa, "Campo/Fases/Fase_" + tag) == null, "Sem fase: " + tag)
		var caixa_falsa := mesa.get_node_or_null(NodePath("HUD/BarraFases/Fase_" + tag))
		assert_true(caixa_falsa == null, "Barra de fases não inventa a fase: " + tag)
	var barra := mesa.get_node("HUD/BarraFases") as Control
	# y 497..551 = 46%..51% da altura na ref, no meio do campo.
	assert_true(barra.position.y >= 497 and barra.position.y + barra.size.y <= 551, "Barra de fases na faixa y 497..551 da ref: %d." % int(barra.position.y))
	var caixa_turno := mesa.get_node("HUD/BarraFases") as Control
	assert_true(caixa_turno.position.x >= 562.0, "Barra de fases começa depois do painel esquerdo.")
	# As 4 fases REAIS existem, e só a fase real do estado acende.
	for fase in ["DRAW", "MAIN", "BATTLE", "END"]:
		var p := mesa.get_node_or_null(NodePath("HUD/BarraFases/Fase_" + fase)) as PanelContainer
		assert_true(p != null, "Caixinha da fase real existe: " + fase)
		assert_eq(str((p.get_node("Txt") as Label).text), fase, "Caixinha mostra o rótulo da fase real: " + fase)
	var real := String(st.phase).to_upper()
	var acesas := 0
	for fase in ["DRAW", "MAIN", "BATTLE", "END"]:
		var p2 := mesa.get_node("HUD/BarraFases/Fase_" + fase) as PanelContainer
		var est2 := p2.get_theme_stylebox("panel") as StyleBoxFlat
		if est2.bg_color == Color(1.0, 0.83, 0.0, 1.0):
			acesas += 1
			assert_eq(fase, real, "Só a fase REAL do estado acende (%s)." % real)
	assert_eq(acesas, 1, "Exatamente uma fase acesa (a do estado: %s)." % real)
	for caminho in ["Campo/Laterais/DeckRival", "Campo/Laterais/DeckVoce", "Campo/Laterais/CemRival", "Campo/Laterais/CemVoce"]:
		assert_true(_n3d(mesa, caminho) != null, "Lateral existe: " + caminho)
	# Contadores = números puros do estado real (ref: 33/32/6), agora em
	# placa escura DENTRO do campo.
	var esperados := {
		"Campo/Laterais/ContaDeckVoce": ((st.players[0] as Dictionary)["deck"] as Array).size(),
		"Campo/Laterais/ContaCemVoce": ((st.players[0] as Dictionary)["graveyard"] as Array).size(),
		"Campo/Laterais/ContaDeckRival": ((st.players[1] as Dictionary)["deck"] as Array).size(),
		"Campo/Laterais/ContaCemRival": ((st.players[1] as Dictionary)["graveyard"] as Array).size(),
		"Campo/ContaMaoRival": ((st.players[1] as Dictionary)["hand"] as Array).size(),
	}
	for caminho in esperados.keys():
		var placa := _n3d(mesa, caminho)
		assert_true(placa != null, "Contador existe: " + caminho)
		# FASE 3: o número é o rótulo DENTRO de uma placa escura deitada no
		# campo (não mais um número solto no canto da tela).
		assert_true(_n3d(mesa, caminho + "/Vidro") != null, "Contador sobre placa de vidro: " + caminho)
		assert_true(_n3d(mesa, caminho + "/Aro") != null, "Contador com aro: " + caminho)
		assert_eq((placa as Node3D).rotation_degrees, Vector3.ZERO, "Placa do contador deitada no campo: " + caminho)
		var num := _n3d(mesa, caminho + "/Numero") as Label3D
		assert_true(num != null, "Contador tem o número dentro da placa: " + caminho)
		assert_eq(str(num.text), str(int(esperados[caminho])), "Contador com o número real: " + caminho)
		assert_eq((num as Label3D).modulate, Color(1, 1, 1), "Número do contador em branco: " + caminho)
	# O cemitério no turno 1 é 0 REAL (nada foi descartado ainda) — o número
	# não pode ser "corrigido" para algo inventado.
	assert_true(mesa.get("_lbl_conta_cem_voce") != null, "Contador de cemitério do jogador existe.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/MaoRival")) == null, "Sem MaoRival em texto (número vive no 3D).")
	for caminho in ["Campo/Tokens/TokenX", "Campo/Tokens/TokenBussola"]:
		assert_true(_n3d(mesa, caminho) != null, "Token decorativo existe: " + caminho)
	assert_true(_n3d(mesa, "Ceu") != null, "Céu azul existe.")
	var filhos_ceu := (_n3d(mesa, "Ceu") as Node3D).get_child_count()
	assert_true(filhos_ceu >= 24, "Céu com pilares + nuvens (10 + 14): %d." % filhos_ceu)
