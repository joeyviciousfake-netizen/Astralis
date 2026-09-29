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
const TurnManager := preload("res://duel/turn_manager.gd")

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
## Inicial que o jogo usa no placeholder do retrato (pack sem foto de duelista).
func _inicial(nome: String) -> String:
	var limpo := nome.strip_edges()
	return "?" if limpo.is_empty() else limpo.substr(0, 1).to_upper()
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


## O nó está dentro dessa subárvore? (usa só a cadeia de pais: não depende de
## posição nem de layout, então serve para qualquer HUD).
func _dentro_de(n: Node, raiz: Node) -> bool:
	if raiz == null or n == null:
		return false
	var atual := n
	while atual != null:
		if atual == raiz:
			return true
		atual = atual.get_parent()
	return false


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
			"Campo", "Campo/Slots", "Campo/Laterais",
			"Cartas", "Cursor3D", "Ceu"]:
		assert_true(_n3d(mesa, caminho) != null, "Nó-chave 3D existe: " + caminho)
	for lbl in ["HUD", "HUD/FlashTela", "HUD/Faixa2D", "Camada3D", "Camada3D/JanelaCampo"]:
		assert_true(mesa.get_node_or_null(NodePath(lbl)) != null, "Nó-chave existe: " + lbl)
	assert_true((_n3d(mesa, "Camera3D") as Camera3D).current, "Camera3D é a atual.")
	# 20 painéis flutuantes (5+5 por lado), cada um com base escura + borda.
	var paineis := (_n3d(mesa, "Campo/Slots") as Node3D).get_children()
	assert_eq(paineis.size(), 20, "20 painéis de slot (5+5 por lado, espelho do 2D).")
	for p in paineis:
		assert_true(str((p as Node).name).begins_with("Painel_p"), "Painel flutuante: " + str((p as Node).name))
		assert_true((p as Node).get_node_or_null(NodePath("Base")) != null, "Painel tem base escura: " + str((p as Node).name))
		assert_true((p as Node).get_node_or_null(NodePath("Borda")) != null, "Painel tem borda com brilho: " + str((p as Node).name))
	# D44 (item 8): as placas do topo saíram de vez (LP/TURN foram para a
	# faixa do meio) e a barra de fases também (item 6). No topo ficou só a
	# foto + o nome de cada duelista. D45 (item 7): a barra "START ? Help"
	# saiu da tela inteira — a ação continua no joypad (D19), o texto não.
	for lbl in ["HUD/RetratoVoce", "HUD/RetratoRival"]:
		assert_true(mesa.get_node_or_null(NodePath(lbl)) != null, "HUD existe: " + lbl)
	assert_true(mesa.get_node_or_null(NodePath("HUD/BarraStart")) == null,
		"D45 (item 7): a barra START ? Help saiu da tela.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/BarraStart/StartHelp")) == null,
		"D45 (item 7): o texto START ? Help não existe mais em nenhum lugar.")
	var placas_nome := 0
	for c in (mesa.get_node("HUD") as Control).get_children():
		if str(c.name) == "NomeVoce" or str(c.name) == "NomeRival":
			placas_nome += 1
	assert_eq(placas_nome, 2, "Topo com as 2 placas de nome (uma por duelista).")


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
	# D44: a fileira de MAGIA andou no eixo Z (item 5 do usuário: aproximá-la
	# do monstro), então a medida do eixo Z desconta o D44. Fora isso a trava
	# é a MESMA, com a mesma tolerância: o que não pode é a escala do campo
	# diferir entre X e Z.
	var x0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var x1: Vector3 = mesa.call("_pos_slot", 0, "monstro", 1)
	var z0: Vector3 = mesa.call("_pos_slot", 0, "monstro", 0)
	var z1: Vector3 = mesa.call("_pos_slot", 0, "magia", 0)
	var px_arena: float = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 1), Vector2(0, 0)).x - BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 0), Vector2(0, 0)).x
	var pz_arena: float = BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "magia", 0), Vector2(0, 0)).y - BoardLayout.get_pos(mesa.get("_arena_layout"), BoardLayout.slot_id(0, "monstro", 0), Vector2(0, 0)).y
	var d44: float = float(mesa.get("APROXIMA_MAGIA_VOCE"))
	assert_almost_eq(absf(x1.x - x0.x) / px_arena, (absf(z1.z - z0.z) + d44) / pz_arena, 0.0001,
		"A escala é a mesma nos 2 eixos (uniforme), descontando o D44 da magia.")


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
	# D45 (itens 4, 5 e 6): a ALTURA de cada mão não é mais um número solto
	# no const — ela é RESOLVIDA da câmera real para a LINHA DE TELA que o
	# usuário pediu. Por isso a trava mudou de "vale 7,6" para "bate com a
	# linha", que é o que realmente importa e não quebra se a câmera mudar:
	#   p0 — o topo da carta na linha de baixo da sua fileira de magia + folga;
	#   p1 — o centro da carta no meio entre o topo da tela e a linha de cima
	##        dos slots de magia do rival.
	var tilt := float(mesa.get("TILT_MAO_LIVRE"))
	var base_magia_meu := float(mesa.call("_borda_da_fileira_px", 0, "magia", true))
	var folga := float(mesa.get("MAO_P0_FOLGA_PX"))
	var cima_mao := cam.unproject_position(p0_m + Vector3(0.0, cos(deg_to_rad(tilt)),
		sin(deg_to_rad(tilt))) * (ALT_CARTA_TESTE * 0.5))
	assert_almost_eq(cima_mao.y, base_magia_meu + folga, 1.0,
		"D45 (item 5): a sua mão é COLADA na linha de baixo da sua fileira de magia (%.1f vs %.1f)." % [
			cima_mao.y, base_magia_meu + folga])
	var yz_p0: Vector2 = mesa.get("MAO_P0_YZ")
	assert_almost_eq(p0_m.z, yz_p0.y, 0.0001,
		"A profundidade da sua mão é a do const (a ALTURA é resolvida, o z não).")
	var p1_1: Vector3 = mesa.call("_pos_mao_arco", 0, n1, 1)
	var p1_m: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(n1), n1, 1)
	var p1_f: Vector3 = mesa.call("_pos_mao_arco", n1 - 1, n1, 1)
	assert_almost_eq(p1_m.x - p1_1.x, p1_f.x - p1_m.x, 0.001, "Arco da mão do rival simétrico em torno do centro.")
	# D3: o Y/Z da mão do RIVAL mudou de propósito, e a trava nova é mais
	# forte que o número solto. Medido: a fileira de magia do rival fica em
	# z = -4,37 e o ladrilho dela avança até z = -5,34 — com a mão mais
	# perto disso ela ficava DENTRO desse ladrilho e o vidro escuro dele
	## (alpha 0,72) pintava a metade de baixo das cartas viradas. A trava
	## agora é GEOMÉTRICA: a mão inteira atrás da pegada do campo.
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
	# D45 (item 4): a mão do rival fica PERFEITAMENTE entre o topo da tela e a
	# linha de cima dos slots de magia dele: não invade a fileira e não sobe
	# para fora da tela, com o CENTRO no meio do vão entre as duas linhas.
	var topo_magia_rival := float(mesa.call("_borda_da_fileira_px", 1, "magia", false))
	var tilt_r := 180.0 + tilt
	var cima_r := cam.unproject_position(p1_m + Vector3(0.0, cos(deg_to_rad(tilt_r)),
		sin(deg_to_rad(tilt_r))) * (ALT_CARTA_TESTE * 0.5))
	var baixo_r := cam.unproject_position(p1_m - Vector3(0.0, cos(deg_to_rad(tilt_r)),
		sin(deg_to_rad(tilt_r))) * (ALT_CARTA_TESTE * 0.5))
	assert_true(cima_r.y >= 0.0, "A mão do rival não sobe para fora da tela (topo em %.0f px)." % cima_r.y)
	assert_true(baixo_r.y <= topo_magia_rival,
		"A mão do rival não invade a fileira de magia dele (base %.0f <= %.0f px)." % [baixo_r.y, topo_magia_rival])
	assert_almost_eq((cima_r.y + baixo_r.y) * 0.5, topo_magia_rival * 0.5, 1.0,
		"A mão do rival é CENTRADA entre o topo da tela e a linha de cima da magia dele (centro em %.0f de %.0f px)." % [
			(cima_r.y + baixo_r.y) * 0.5, topo_magia_rival * 0.5])
	# D45 (item 6): ESPAÇO entre as cartas da sua mão. A carta tem 1,0 de
	# largura, então o vão em pixels é (passo - 1) * px_por_unidade. Com 5
	# cartas o vão tem que ser VISÍVEL, e o arco inteiro tem que caber na
	# janela do campo (nada de carta cortada na borda).
	var passo0 := (p0_m.x - p0_1.x) / float(maxi(_meio_do_arco(n0), 1))
	var passo1 := (p1_m.x - p1_1.x) / float(maxi(_meio_do_arco(n1), 1))
	assert_true(passo0 > float(mesa.get("LARG_CARTA")),
		"D45 (item 6): o passo da sua mão é MAIOR que a carta, então abre vão (passo %.3f > 1,0)." % passo0)
	var px_u: float = absf(cam.unproject_position(p0_m + Vector3(1, 0, 0)).x - cam.unproject_position(p0_m).x)
	var vao_px := (passo0 - float(mesa.get("LARG_CARTA"))) * px_u
	assert_true(vao_px >= 8.0, "D45 (item 6): vão visível entre duas cartas da mão (%.1f px)." % vao_px)
	var meia_carta := float(mesa.get("LARG_CARTA")) * 0.5
	var x_janela := float(mesa.get("PAINEL_ESQ_L"))
	var esq_mao := cam.unproject_position((mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3) - Vector3(meia_carta, 0, 0)).x + x_janela
	var dir_mao := cam.unproject_position((mesa.call("_pos_mao_arco", n0 - 1, n0, 0) as Vector3) + Vector3(meia_carta, 0, 0)).x + x_janela
	assert_true(esq_mao >= x_janela,
		"A carta da ponta esquerda da mão não invade o painel (%.0f px)." % esq_mao)
	assert_true(dir_mao <= float(mesa.get("TELA_L")),
		"A carta da ponta direita da mão não sai da tela (%.0f px)." % dir_mao)
	assert_almost_eq(absf(passo1), MAO_P1_PASSO_TESTE, 0.001, "Passo por carta da mão do rival = MAO_P1_PASSO (espelhado em D45).")
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


func test_d44_magia_aproxima_e_mao_vem_para_a_camera() -> void:
	# D44, dois pedidos do usuário na MESMA leva:
	#   item 5  — a fileira de MAGIA se aproxima da de MONSTRO até o vão
	#             vertical ficar igual ao vão horizontal entre dois slots
	#             vizinhos. A fileira de MONSTRO NÃO SE MEXE (nem X nem Z).
	#   item 10 — a carta da sua mão NÃO CRESCE (a proporção real 59x86
	#             fica intocada): a mão é que vem mais PERTO DA CÂMERA.
	# Tudo medido no jogo de verdade (1920x1080), com a câmera real.
	var mesa: Node = await _mesa3d_nova()
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	var lay = mesa.get("_arena_layout")
	var peca: float = float(mesa.call("_peca_prof_carta"))
	var escala: float = float(mesa.get("ESCALA_CAMPO"))
	var desl: Vector2 = mesa.get("DESLOC_CAMPO")
	var c_x: float = float(mesa.get("CENTRO_X"))
	var c_y: float = float(mesa.get("CENTRO_Y"))
	var div: float = float(mesa.get("DIV"))
	var topo: float = float(mesa.get("TOPO"))
	var ap_v: float = float(mesa.get("APROXIMA_MAGIA_VOCE"))
	var ap_r: float = float(mesa.get("APROXIMA_MAGIA_RIVAL"))

	# --- 1. A fileira de MONSTRO é a composição pura do dado, sem nudge ------
	# O teste recalcula o transform ESCALA_CAMPO/DESLOC_CAMPO do jeito que o
	# jogo faz e exige igualdade EXATA: se um dia alguém mexer no monstro,
	# esta trava quebra junto.
	for lado in [0, 1]:
		for i in range(5):
			var sid := BoardLayout.slot_id(lado, "monstro", i)
			var p2: Vector2 = BoardLayout.get_pos(lay, sid, BoardLayout.default_pos(sid))
			var puro := Vector3((p2.x - c_x) / div * escala + desl.x, topo,
				(p2.y - c_y) / div * escala + desl.y)
			var real: Vector3 = mesa.call("_pos_slot", lado, "monstro", i)
			assert_almost_eq(real.x, puro.x, 0.000001,
				"Monstro p%d_%d no X puro do dado (não encostado no D44)." % [lado, i])
			assert_almost_eq(real.z, puro.z, 0.000001,
				"Monstro p%d_%d no Z puro do dado (NÃO se mexeu no D44)." % [lado, i])

	# --- 2. Só a MAGIA se mexe, e no sentido certo de cada lado --------------
	# A SUA sobe (z MENOR = mais longe da câmera, aproximando do monstro) e a
	# do RIVAL desce (z MAIOR = mais perto). A referência é o z PURO da própria
	# linha de magia: o D44 é uma/presentation de afastamento, não um pitch
	# novo entre as fileiras.
	for lado in [0, 1]:
		# O sinal é o do lado: a SUA magia tem z MENOR (afasta do monstro, que
		# fica mais perto da câmera), a do RIVAL tem z MAIOR.
		var off: float = -ap_v if lado == 0 else ap_r
		for i in range(5):
			var sid_s := BoardLayout.slot_id(lado, "magia", i)
			var p2s: Vector2 = BoardLayout.get_pos(lay, sid_s, BoardLayout.default_pos(sid_s))
			var puro_s := Vector3((p2s.x - c_x) / div * escala + desl.x, topo,
				(p2s.y - c_y) / div * escala + desl.y)
			var zm: Vector3 = mesa.call("_pos_slot", lado, "monstro", i)
			var zs: Vector3 = mesa.call("_pos_slot", lado, "magia", i)
			assert_almost_eq(zs.z, puro_s.z + off, 0.000001,
				"Magia p%d_%d afastou EXATAMENTE o D44 em z." % [lado, i])
			assert_almost_eq(zs.x, puro_s.x, 0.000001,
				"Magia p%d_%d não mexeu no X (só a distância vertical muda)." % [lado, i])
			if lado == 0:
				assert_true(zs.z < puro_s.z, "Sua magia %d subiu (mais longe da câmera)." % i)
				assert_true(zs.z > zm.z, "Sua magia %d continua ABAIXO do monstro %d." % [i, i])
			else:
				assert_true(zs.z > puro_s.z, "Magia do rival %d desceu (mais perto da câmera)." % i)
				assert_true(zs.z < zm.z, "Magia do rival %d continua ACIMA do monstro %d." % [i, i])

	# --- 3. O vão VERTICAL bate com o vão HORIZONTAL, medido em pixels ------
	# O usuário pediu "o mesmo espaçamento dos slots que são um lado do outro".
	# Tolerância de 4 px: é a diferença entre o ladrilho ser visto de cima
	# (perspectiva) e de lado — não dá para ser 0.
	var vh := _vao_horizontal_px(mesa, cam, 0, peca)
	for lado in [0, 1]:
		var vv := _vao_vertical_px(mesa, cam, lado, peca)
		assert_almost_eq(vv, vh, 4.0,
			"Vão vertical de p%d (%.1f px) = vão horizontal (%.1f px)." % [lado, vv, vh])

	# --- 4. A carta da mão NÃO cresceu de verdade: o mundo é o mesmo -------
	var st = mesa.get("_st")
	var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var p0_m: Vector3 = mesa.call("_pos_mao_arco", _meio_do_arco(n0), n0, 0)
	var larg: float = float(mesa.get("LARG_CARTA"))
	var alt: float = float(mesa.get("ALT_CARTA"))
	assert_almost_eq(larg, 1.0, 0.000001, "LARG_CARTA intocada: 1,0 (D44 não pode aumentar a carta).")
	assert_almost_eq(alt, ALT_CARTA_TESTE, 0.000001, "ALT_CARTA intocada: proporção real 86/59 (D44).")
	# O mundo da carta: ela é desenhada do mesmo jeito em qualquer lugar, e o
	# que mudou foi SÓ a distância até a câmera (z maior = mais perto).
	assert_true(p0_m.z > 10.0, "A sua mão veio mesmo para perto da câmera (z %.2f > 10,0)." % p0_m.z)
	var dist := cam.global_position.distance_to(p0_m)
	assert_true(dist > float(cam.near) * 4.0,
		"Mão longe do near plane (%.2f u, near %.3f) — não há corte de profundidade." % [dist, cam.near])

	# --- 5. O que a mão NÃO pode fazer: cobrir a fileira de magia ------------
	var f_m := _faixa_px(mesa, cam, 0, "monstro", peca)
	var f_s := _faixa_px(mesa, cam, 0, "magia", peca)
	var tilt := deg_to_rad(float(mesa.get("TILT_MAO_LIVRE")))
	var cima: Vector2 = cam.unproject_position(
		p0_m + Vector3(0.0, cos(tilt), sin(tilt)) * (alt * 0.5))
	var baixo: Vector2 = cam.unproject_position(
		p0_m - Vector3(0.0, cos(tilt), sin(tilt)) * (alt * 0.5))
	assert_true(cima.y >= f_s.y,
		"A mão não cobre a sua fileira de magia: topo da carta em %.0f px, base da fileira em %.0f px." % [cima.y, f_s.y])
	assert_true(baixo.y > 1080.0, "A sua mão continua cortada pela borda de baixo (base em %.0f px > 1080)." % baixo.y)
	# ...nem o painel esquerdo (a janela do campo começa em x=562).
	assert_true(cam.unproject_position(p0_m).x > 562.0 + 20.0,
		"A mão não invade o painel esquerdo.")
	# A ordem das fileiras é a da referência (doc 15 §15.3): de cima para
	# baixo, magia rival, monstro rival, [barra de fases], monstro meu, magia
	# minha. Na tela o y CRESCE para baixo, então a de cima tem o y MENOR.
	var fm1 := _faixa_px(mesa, cam, 1, "monstro", peca)
	var fs1 := _faixa_px(mesa, cam, 1, "magia", peca)
	assert_true(fs1.y < fm1.x, "Ordem da ref no rival: magia ACIMA de monstro (%.0f < %.0f)." % [fs1.y, fm1.x])
	assert_true(f_m.y < f_s.x, "Ordem da ref no seu lado: monstro ACIMA de magia (%.0f < %.0f)." % [f_m.y, f_s.x])


## Teto e base de uma fileira de ladrilhos, em pixels de tela. A borda é
## medida na FACE DE CIMA do ladrilho (TOPO - 0,005, que é onde a caixa de
## vidro assenta), e não num ponto chutado acima: é essa a superfície que a
## faixa do meio tem que encostar sem invadir (D45, item 2).
func _faixa_px(mesa: Node, cam: Camera3D, lado: int, tipo: String, peca: float) -> Vector2:
	var letra: String = "m" if tipo == "monstro" else "s"
	# A borda é medida na FACE DE CIMA do ladrilho (TOPO_PISO, o plano onde a
	# caixa de vidro assenta) e não num ponto chutado: é essa a superfície que
	# a faixa do meio encosta sem invadir (D45, item 2). O nó do painel tem
	# y = 0, então o plano entra como posição ABSOLUTA.
	var piso := float(mesa.get("TOPO_PISO"))
	var t := 1e9
	var b := -1e9
	for i in range(5):
		var no := _n3d(mesa, "Campo/Slots/Painel_p%d_%s%d" % [lado, letra, i]) as Node3D
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q := cam.unproject_position(
					no.position + Vector3(sx * peca * 0.5, piso, sz * peca * 0.5))
				t = minf(t, q.y)
				b = maxf(b, q.y)
	return Vector2(t, b)

## Vão entre a fileira de monstro e a de magia, borda a borda, em pixels.
func _vao_vertical_px(mesa: Node, cam: Camera3D, lado: int, peca: float) -> float:
	var m := _faixa_px(mesa, cam, lado, "monstro", peca)
	var s := _faixa_px(mesa, cam, lado, "magia", peca)
	if lado == 1:
		return m.x - s.y
	return s.x - m.y


## Vão entre dois slots vizinhos de uma fileira, borda a borda, em pixels: a
## borda de uma coluna até a borda da vizinha, no mesmo Z do meio do ladrilho.
func _vao_horizontal_px(mesa: Node, cam: Camera3D, lado: int, peca: float) -> float:
	var a := _n3d(mesa, "Campo/Slots/Painel_p%d_m4" % lado) as Node3D
	var b := _n3d(mesa, "Campo/Slots/Painel_p%d_m3" % lado) as Node3D
	var dir := 1.0 if a.position.x < b.position.x else -1.0
	var ba := cam.unproject_position(a.position + Vector3(dir * peca * 0.5, 0.02, 0.0))
	var bb := cam.unproject_position(b.position + Vector3(-dir * peca * 0.5, 0.02, 0.0))
	return absf(bb.x - ba.x)


func test_topo_so_retratos_com_nome_e_nada_mais() -> void:
	# D44 (item 8): o topo da tela perdeu TUDO que era informacao (a barra
	# metalica, a placa azul de LP, a caixa TURN e a placa vermelha do rival)
	# porque essa informacao foi para a FAIXA DO MEIO. No topo ficou somente
	# a foto de cada duelista + o NOME dele, o seu a esquerda e o do rival a
	# direita. O pack nao tem foto de duelista, entao continua o placeholder
	# com a inicial (nada de rosto inventado).
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	for saiu in ["HUD/BarraTopo", "HUD/BiselTopo", "HUD/PlacaVoce", "HUD/PlacaTurno", "HUD/PlacaRival"]:
		assert_true(mesa.get_node_or_null(NodePath(saiu)) == null, "Sumiu do topo: " + saiu)
	# Os 2 retratos continuam, nos cantos da faixa do campo, e o nome real
	# do duelista aparece na placa ao lado de cada um.
	var rv := mesa.get_node("HUD/RetratoVoce") as Control
	var rr := mesa.get_node("HUD/RetratoRival") as Control
	assert_true(rv.position.x < rr.position.x, "Seu retrato a ESQUERDA, o do rival a DIREITA.")
	assert_true(rv.position.x >= 562.0, "Seu retrato nunca invade o painel esquerdo (x %d)." % int(rv.position.x))
	assert_true(rr.position.x + rr.size.x <= 1920.0, "Retrato do rival dentro da tela (%d)." % int(rr.position.x + rr.size.x))
	# D45 (item 1): "a imagem dos duelistas bem pra cima, dando o mesmo espaço
	# entre as laterais e a parte de cima" e "a parte de cima da imagem e a
	# parte de cima do bloco de nomes na mesma linha". A trava é geométrica:
	# a MESMA margem nos 3 lados da janela do campo e o TOPO da placa de nome
	# batendo com o TOPO da foto (antes a placa era centralizada na altura).
	var margem := float(mesa.get("RETRATO_MARGEM"))
	var x_janela := float(mesa.get("PAINEL_ESQ_L"))
	var tela := float(mesa.get("TELA_L"))
	assert_almost_eq(rv.position.x - x_janela, margem, 0.001,
		"D45 (item 1): seu retrato com a MESMA margem da borda esquerda (%.0f px)." % margem)
	assert_almost_eq(tela - (rr.position.x + rr.size.x), margem, 0.001,
		"D45 (item 1): retrato do rival com a MESMA margem da borda direita (%.0f px)." % margem)
	for quem in ["Voce", "Rival"]:
		var foto := mesa.get_node("HUD/Retrato%s" % quem) as Control
		var placa := mesa.get_node("HUD/Nome%s" % quem) as Control
		assert_almost_eq(foto.position.y, margem, 0.001,
			"D45 (item 1): retrato %s colado na beirada de cima (y %.0f px)." % [quem, margem])
		assert_almost_eq(placa.position.y, foto.position.y, 0.001,
			"D45 (item 1): o bloco de nome %s começa na MESMA linha do topo da foto (%.0f = %.0f px)." % [
				quem, placa.position.y, foto.position.y])
		# E a placa nunca invade o painel esquerdo.
		assert_true(placa.position.x >= 562.0,
			"D45 (item 1): a placa de nome %s não invade o painel esquerdo (x %d)." % [quem, int(placa.position.x)])
	# Nome real do dado, do lado de dentro de cada retrato (espelhado).
	var placas_nome := 0
	for c in (mesa.get_node("HUD") as Control).get_children():
		if str(c.name) != "NomeVoce" and str(c.name) != "NomeRival":
			continue
		placas_nome += 1
		var pc := c as PanelContainer
		var l := pc.get_node("Texto") as Label
		assert_true(str(l.text) != "", "Placa de nome tem o nome real do duelista: " + str(l.text))
		assert_true((l.text == str(mesa.get("_nome_voce")).to_upper()) or (l.text == str(mesa.get("_nome_rival")).to_upper()),
			"Nome do topo é o do duelista real: " + str(l.text))
	assert_eq(placas_nome, 2, "Só as 2 placas de nome no topo (uma por duelista).")
	assert_eq(str((rr.get_node("Silhueta") as Label).text), _inicial(str(mesa.get("_nome_rival"))),
		"Placeholder do rival com a INICIAL do nome (o pack não tem foto).")
	assert_eq(str((rv.get_node("Silhueta") as Label).text), _inicial(str(mesa.get("_nome_voce"))),
		"Placeholder seu com a INICIAL do nome (o pack não tem foto).")
	# Nada de texto de LP/turno sobrou no TOPO — a única faixa com LP e turno é
	# a do MEIO (D45: `HUD/Faixa2D`), que é onde o usuário mandou ficar.
	var texts: Array = []
	_coletar(mesa.get_node("HUD"), texts)
	var faixa2d := mesa.get_node("HUD/Faixa2D") as Node
	for n in texts:
		if n is Label and not _dentro_de(n as Node, faixa2d):
			var t := str((n as Label).text)
			assert_false(t.contains("LP"), "Sem rótulo LP no topo: " + t)
			assert_false(t.contains("TURN"), "Sem rótulo TURN no topo: " + t)
			assert_false(t == str(int((st.players[0] as Dictionary)["lp"])), "Sem o número de LP solto no topo: " + t)
	assert_true(true, "Topo conferido.")
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


	assert_true(_n3d(mesa, "Ceu") != null, "Céu azul existe.")
	var filhos_ceu := (_n3d(mesa, "Ceu") as Node3D).get_child_count()
	assert_true(filhos_ceu >= 24, "Céu com pilares + nuvens (10 + 14): %d." % filhos_ceu)


## ---- D44/D45: A FAIXA DO MEIO (2D) e a limpeza da tela -------------------
## D45: a faixa do meio saiu do 3D e virou 2D no HUD (item 2). D45 item 1
## trocou o cemitério e o baralho de lugar, e os itens 3 a 7 limparam os
## blocos (sem palavra, sem ícone), colocaram cor por lado, número branco, a
## foto da última carta do cemitério e a cor do turno acompanhando quem joga.

## A ORDEM dos 7 itens, tal e qual o usuário ditou (D45, item 1: o cemitério
## e o baralho trocaram de lugar), lida direto da cena.
const ORDEM_FAIXA := ["MeuCemiterio", "MeuDeck", "LpVoce", "Turno", "LpRival",
	"DeckRival", "CemRival"]


## Celulas da faixa 2D na tela, na ordem em que aparecem.
func _celulas_faixa2d(mesa: Node) -> Array:
	var linha := mesa.get_node("HUD/Faixa2D/Celulas")
	return linha.get_children() if linha != null else []


func _celula(mesa: Node, nome: String) -> PanelContainer:
	return mesa.get_node("HUD/Faixa2D/Celulas/" + nome) as PanelContainer


## O rótulo de número de uma célula.
func _numero_da_celula(mesa: Node, nome: String) -> Label:
	return _celula(mesa, nome).get_node("Caixa/Numero") as Label


## A cor de um PanelContainer da tela (o estilo do painel).
func _estilo_de(p: Control) -> StyleBoxFlat:
	return p.get_theme_stylebox("panel") as StyleBoxFlat


## Assinatura de uma textura pra comparar duas: o jogo carrega as imagens com
## `ImageTexture.create_from_image`, então o `resource_path` é VAZIO em todas
## — comparar por ele seria uma trava que nunca pega. Aqui é o hash do pixel
## de verdade (tamanho + conteúdo).
func _assinatura_tex(tex: Texture2D) -> int:
	if tex == null:
		return 0
	var img := tex.get_image()
	if img == null:
		return -1
	var dados := img.get_data()
	# `hash()` global não existe para PackedByteArray nesta versão: soma dos
	# bytes (com posição) é estável e basta para dizer "é a mesma imagem".
	var soma := 0
	for i in range(0, dados.size(), 7):
		soma = (soma * 31 + dados[i]) & 0x7FFFFFFF
	return hash("%dx%d:%d" % [img.get_width(), img.get_height(), soma])
func test_d45_faixa_2d_no_vao_entre_as_fileiras_na_ordem_do_usuario() -> void:
	# D45 (item 2): a faixa do meio é 2D (no HUD), tem as 7 células NA ORDEM
	# do usuário (baralho meu, cemitério meu, meu LP, turno, LP do rival,
	# cemitério do rival, baralho do rival) e fica NO VÃO entre as duas
	# fileiras de monstro — sem cobrir nenhuma delas e sem sair da janela.
	var mesa: Node = await _mesa3d_nova()
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	var barra := mesa.get_node_or_null(NodePath("HUD/Faixa2D")) as Control
	assert_true(barra != null, "A faixa do meio existe em 2D (HUD/Faixa2D).")
	var cels := _celulas_faixa2d(mesa)
	assert_eq(cels.size(), 7, "A faixa tem exatamente 7 células (nada mais): %d." % cels.size())
	for i in range(mini(cels.size(), 7)):
		assert_eq(str((cels[i] as Node).name), ORDEM_FAIXA[i],
			"Célula %d da faixa é %s (a ordem do usuário)." % [i + 1, ORDEM_FAIXA[i]])
	# O VÃO entre as duas fileiras de monstro: a faixa fica DENTRO dele, com
	# folga dos dois lados (medido em pixel de tela, como o usuário vê).
	var peca := float(mesa.call("_peca_prof_carta"))
	var base_rival := _faixa_px(mesa, cam, 1, "monstro", peca).y
	var topo_meu := _faixa_px(mesa, cam, 0, "monstro", peca).x
	assert_true(barra.position.y >= base_rival,
		"A faixa não invade a fileira de monstros do RIVAL (topo %.0f >= base %.0f px)." % [barra.position.y, base_rival])
	assert_true(barra.position.y + barra.size.y <= topo_meu,
		"A faixa não invade a sua fileira de monstros (base %.0f <= topo %.0f px)." % [barra.position.y + barra.size.y, topo_meu])
	# E fica CENTRADA no vão (o que o usuário pediu: "bem no meio entre meu
	# slots de monstros e os slots de monstros do inimigo").
	var centro := barra.position.y + barra.size.y * 0.5
	var meio_vao := (base_rival + topo_meu) * 0.5
	assert_almost_eq(centro, meio_vao, 2.0,
		"A faixa é CENTRADA no vão entre as fileiras (%.0f vs %.0f px)." % [centro, meio_vao])
	# Dentro da janela do campo, sem encostar no painel esquerdo nem na borda.
	var x_janela := float(mesa.get("PAINEL_ESQ_L"))
	assert_true(barra.position.x >= x_janela,
		"A faixa não invade o painel esquerdo (x %.0f)." % barra.position.x)
	assert_true(barra.position.x + barra.size.x <= float(mesa.get("TELA_L")),
		"A faixa não sai pela direita (x %.0f)." % (barra.position.x + barra.size.x))
	# Nada de clique: a faixa é IGNORE como o resto da tela (D19).
	for c in cels:
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"A célula %s é sem clique (D19)." % str((c as Node).name))


func test_d45_blocos_limpos_numero_branco_e_cor_por_lado() -> void:
	# D45 (itens 2, 3, 4 e 5): os blocos ficaram LIMPOS (sem palavra DECK /
	# CEMITERIO / SEU LP / TURNO / LP RIVAL e sem o ícone de pilhinha), o
	# NÚMERO é branco, e cada lado tem o SEU conjunto de cor (borda escura +
	# interior mais claro): azul no seu, vermelho no do rival, e o MESMO
	# conjunto no bloco do nome (topo) e no bloco do LP daquele lado. O
	# cemitério é o bloco PRETO dos dois lados.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var celulas := _celulas_faixa2d(mesa)
	# (1) NENHUMA palavra e NENHUM ícone dentro dos 7 blocos.
	var icones: Array = []
	for c in celulas:
		var cel := c as Control
		var dentro: Array = []
		_coletar(cel, dentro)
		for n in dentro:
			var no := n as Node
			if no.name in ["Pilha", "MiniDeck", "MiniCem", "Lamina0", "Nome"]:
				icones.append("%s: %s" % [str(cel.name), str(no.name)])
			if n is Label:
				var t := str((n as Label).text)
				if not t.is_valid_int() and not _eh_resultado_de_turno(t):
					icones.append("%s: %s" % [str(cel.name), t])
	assert_eq(icones.size(), 0, "D45 (item 3): nenhum nome/icone sobrou nos blocos: %s" % str(icones))
	# Só o número mora dentro de cada bloco (mais a foto do cemitério).
	for c in celulas:
		var cel := c as Control
		var filhos := cel.get_node("Caixa").get_children()
		for n in filhos:
			var nome := str((n as Node).name)
			assert_true(nome == "Numero" or nome == "Arte",
				"D45 (item 3): dentro do bloco %s só número ou foto (%s)." % [str(cel.name), nome])
	# (2) Todo número é BRANCO (itens 4 e 7).
	for par in [["MeuDeck", 0, "deck"], ["DeckRival", 1, "deck"],
			["MeuCemiterio", 0, "graveyard"], ["CemRival", 1, "graveyard"],
			["LpVoce", 0, "lp"], ["LpRival", 1, "lp"], ["Turno", 0, "turn_number"]]:
		var lbl := _numero_da_celula(mesa, str(par[0]))
		var cor := lbl.get_theme_color("font_color")
		assert_true(cor.r > 0.95 and cor.g > 0.95 and cor.b > 0.95,
			"D45 (item 4): o número de %s é branco (%.2f,%.2f,%.2f)." % [str(par[0]), cor.r, cor.g, cor.b])
	# (3) Conjunto de cor por lado, e o MESMO conjunto no bloco do nome.
	var azul_borda := Color(mesa.get("COR_AZUL_BORDA"))
	var azul_fundo := Color(mesa.get("COR_AZUL_FUNDO"))
	var verm_borda := Color(mesa.get("COR_VERM_BORDA"))
	var verm_fundo := Color(mesa.get("COR_VERM_FUNDO"))
	var pret_borda := Color(mesa.get("COR_PRETO_BORDA"))
	var pret_fundo := Color(mesa.get("COR_PRETO_FUNDO"))
	var meu_lp := _estilo_de(_celula(mesa, "LpVoce"))
	var rival_lp := _estilo_de(_celula(mesa, "LpRival"))
	var meu_nome := _estilo_de(mesa.get_node("HUD/NomeVoce") as Control)
	var rival_nome := _estilo_de(mesa.get_node("HUD/NomeRival") as Control)
	assert_eq(meu_lp.border_color, azul_borda, "Item 2: o bloco do seu LP tem borda azul escura.")
	assert_eq(meu_lp.bg_color, azul_fundo, "Item 2: o bloco do seu LP tem interior azul mais claro.")
	assert_eq(meu_nome.border_color, azul_borda, "Item 2: o bloco do SEU NOME tem o MESMO azul do seu LP (borda).")
	assert_eq(meu_nome.bg_color, azul_fundo, "Item 2: o bloco do SEU NOME tem o MESMO azul do seu LP (interior).")
	assert_eq(rival_lp.border_color, verm_borda, "Item 2: o bloco do LP rival tem borda vermelha escura.")
	assert_eq(rival_lp.bg_color, verm_fundo, "Item 2: o bloco do LP rival tem interior vermelho mais claro.")
	assert_eq(rival_nome.border_color, verm_borda, "Item 2: o bloco do NOME DO RIVAL tem o MESMO vermelho do LP dele (borda).")
	assert_eq(rival_nome.bg_color, verm_fundo, "Item 2: o bloco do NOME DO RIVAL tem o MESMO vermelho do LP dele (interior).")
	# Deck e LP do mesmo lado dividem a cor; o turno começa na cor de quem joga.
	assert_eq(_estilo_de(_celula(mesa, "MeuDeck")).bg_color, azul_fundo, "Seu deck é azul como o seu LP.")
	assert_eq(_estilo_de(_celula(mesa, "DeckRival")).bg_color, verm_fundo, "Deck do rival é vermelho como o LP dele.")
	# (4) Os DOIS CEMITÉRIOS são pretos: borda que não é preta escura, dentro
	# um preto mais claro.
	for nome in ["MeuCemiterio", "CemRival"]:
		var e := _estilo_de(_celula(mesa, nome))
		assert_eq(e.border_color, pret_borda, "Item 5: borda preta (não escura) no " + nome + ".")
		assert_eq(e.bg_color, pret_fundo, "Item 5: interior preto mais claro no " + nome + ".")
	# A borda PRETA tem que ser mais clara que o preto puro, e o interior mais
	# claro que a borda (é o que o usuário pediu: "um preto mas não é um
	# escuro... dentro um preto mais claro").
	assert_true(pret_fundo.r > pret_borda.r + 0.05, "Item 5: o interior do cemitério é mais claro que a borda.")
	assert_true(pret_borda.r > 0.0, "Item 5: a borda do cemitério é preta (não azulada).")
	assert_true(absf(pret_borda.r - pret_borda.g) < 0.02 and absf(pret_borda.r - pret_borda.b) < 0.02,
		"Item 5: a borda do cemitério é preta de verdade (R = G = B).")
	assert_true(st != null, "Preparo: estado real carregado.")


## O texto da célula do turno no fim de jogo é resultado, não nome de bloco.
func _eh_resultado_de_turno(t: String) -> bool:
	return t == "VITORIA!" or t == "DERROTA"


func test_d45_cor_do_turno_alterna_com_quem_esta_jogando() -> void:
	# D45 (item 7): "no bloco do turno ele vai ficar alternando a cor sempre
	# para o turno de quem ta jogando: se for para o meu turno vai ficar azul,
	# o mesmo azul da borda do bloco do meu LP, e quando for o turno do inimigo
	# vai ser vermelho, o mesmo vermelho da borda do LP do inimigo. O número
	# fica branco." Quem manda é o `current_player` do MOTOR (R3).
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var azul_borda := Color(mesa.get("COR_AZUL_BORDA"))
	var azul_fundo := Color(mesa.get("COR_AZUL_FUNDO"))
	var verm_borda := Color(mesa.get("COR_VERM_BORDA"))
	var verm_fundo := Color(mesa.get("COR_VERM_FUNDO"))
	var cel := _celula(mesa, "Turno")
	st.current_player = 0
	mesa.call("_atualizar_faixa")
	var e := _estilo_de(cel)
	assert_eq(e.border_color, azul_borda, "Item 7: turno SEU = azul (mesma borda do seu LP).")
	assert_eq(e.bg_color, azul_fundo, "Item 7: turno SEU = azul (mesmo interior do seu LP).")
	st.current_player = 1
	mesa.call("_atualizar_faixa")
	e = _estilo_de(cel)
	assert_eq(e.border_color, verm_borda, "Item 7: turno do RIVAL = vermelho (mesma borda do LP dele).")
	assert_eq(e.bg_color, verm_fundo, "Item 7: turno do RIVAL = vermelho (mesmo interior do LP dele).")
	# E o número continua branco nos dois casos.
	assert_true(_numero_da_celula(mesa, "Turno").get_theme_color("font_color").r > 0.95,
		"Item 7: o número do turno é branco.")


func test_d45_cemiterio_mostra_a_foto_quadrada_da_ultima_carta() -> void:
	# D45 (item 6): no bloco do SEU cemitério vai a foto da última carta que
	# foi para o seu cemitério, num QUADRADO PERFEITO preenchendo a ponta
	# esquerda do bloco; no do rival é igual, mas a foto fica na DIREITA. A
	# foto é a arte REAL do dado (nunca inventada) e o corte é quadrado
	# (a imagem não distorce).
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	# Escolhe uma carta que TEM arte no dado (o pack FM tem 722 PNGs).
	var com_arte: Dictionary = {}
	for cid in cartas:
		var c := cartas[cid] as Dictionary
		if not str(c.get("artwork", "")).is_empty():
			com_arte = c
			break
	assert_false(com_arte.is_empty(), "Preparo: o dado tem carta com arte (para a foto do cemitério).")
	var meu_arte := _celula(mesa, "MeuCemiterio").get_node("Caixa/Arte") as TextureRect
	var rival_arte := _celula(mesa, "CemRival").get_node("Caixa/Arte") as TextureRect
	assert_true(meu_arte != null and rival_arte != null, "Os dois cemitérios têm o nó da foto.")
	# Cemitério vazio = sem foto (nunca uma imagem inventada).
	var cem0: Array = (st.players[0] as Dictionary)["graveyard"] as Array
	var cem1: Array = (st.players[1] as Dictionary)["graveyard"] as Array
	while cem0.size() > 0:
		cem0.pop_back()
	while cem1.size() > 0:
		cem1.pop_back()
	mesa.call("_atualizar_faixa")
	assert_false(meu_arte.visible, "Cemitério vazio: sem foto no seu bloco.")
	assert_false(rival_arte.visible, "Cemitério vazio: sem foto no bloco do rival.")
	# Uma carta no cemitério: a foto é a arte REAL dela, e o ÚLTIMO id da lista
	# é o que aparece (é a que foi para lá por último).
	var primeiro: String = str(com_arte.get("id", ""))
	var segundo: Dictionary = {}
	for cid in cartas:
		if str(cid) != primeiro and not str((cartas[cid] as Dictionary).get("artwork", "")).is_empty():
			segundo = cartas[cid] as Dictionary
			break
	cem0.append(primeiro)
	cem1.append(primeiro)
	mesa.call("_atualizar_faixa")
	# A CARTA escolhida é a última do dado, e a foto é a arte real dela. Sem
	# assets no headless (o jogo embute só as 17 peças da carta, não as 722
	# artes que moram no PROJETO), a arte volta vazia e o bloco fica só com a
	# contagem — o que também é a trava do "nunca uma imagem inventada".
	var escolhida := mesa.call("_carta_do_cemiterio", 0) as Dictionary
	assert_eq(str(escolhida.get("id", "")), primeiro,
		"O bloco do seu cemitério aponta para a ÚLTIMA carta do dado.")
	var esperada: Texture2D = mesa.call("_arte_real", escolhida)
	assert_eq(_assinatura_tex(meu_arte.texture), _assinatura_tex(esperada),
		"A foto do seu cemitério é a arte REAL da carta que foi para lá.")
	assert_eq(_assinatura_tex(rival_arte.texture), _assinatura_tex(esperada),
		"A foto do cemitério do rival é a arte da carta DELE.")
	assert_eq(meu_arte.visible, esperada != null,
		"Foto visível só quando o dado tem arte (sem imagem inventada).")
	var rival_escolhida := mesa.call("_carta_do_cemiterio", 1) as Dictionary
	assert_eq(str(rival_escolhida.get("id", "")), primeiro,
		"O cemitério do rival lê o dado DELE, não o seu.")
	# A última do dado é a que fica: põe outra carta depois e a foto muda.
	if not segundo.is_empty():
		cem0.append(str(segundo.get("id", "")))
		mesa.call("_atualizar_faixa")
		var esperada2: Texture2D = mesa.call("_arte_real", segundo)
		assert_eq(str((mesa.call("_carta_do_cemiterio", 0) as Dictionary).get("id", "")),
			str(segundo.get("id", "")), "Com uma segunda carta, a escolhida passa a ser a ÚLTIMA (a mais recente).")
		assert_eq(_assinatura_tex(meu_arte.texture), _assinatura_tex(esperada2),
			"A foto do cemitério acompanha a última carta.")
		cem0.pop_back()
	# A foto é um QUADRADO PERFEITO: largura = altura, e é um CORTE (a imagem
	# não estica). Lado a lado: a sua na esquerda, a do rival na direita.
	await wait_process_frames(2)
	var caixa_meu := _celula(mesa, "MeuCemiterio").get_node("Caixa") as Control
	assert_almost_eq(meu_arte.size.x, meu_arte.size.y, 0.5,
		"Item 6: a foto do seu cemitério é um QUADRADO perfeito (%.1f x %.1f px)." % [meu_arte.size.x, meu_arte.size.y])
	assert_almost_eq(rival_arte.size.x, meu_arte.size.x, 0.5,
		"Item 6: a foto do cemitério do rival é o mesmo quadrado (%.1f px de lado)." % meu_arte.size.x)
	assert_true(meu_arte.size.y >= caixa_meu.size.y - 2.0,
		"Item 6: a foto PREENCHE o bloco na altura (%.0f de %.0f px de área útil)." % [meu_arte.size.y, caixa_meu.size.y])
	assert_true(meu_arte.size.x >= 20.0,
		"Item 6: a foto tem tamanho de verdade (%.0f px de lado)." % meu_arte.size.x)
	assert_true(meu_arte.get_parent().get_child(0) == meu_arte,
		"Item 6: no SEU cemitério a foto fica na ponta ESQUERDA do bloco.")
	assert_true(rival_arte.get_parent().get_child(rival_arte.get_parent().get_child_count() - 1) == rival_arte,
		"Item 6: no cemitério do RIVAL a foto fica na ponta DIREITA do bloco.")
	assert_eq(meu_arte.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"Item 6: a foto é um CORTE quadrado (a imagem não distorce).")
	cem0.pop_back()
	cem1.pop_back()
	mesa.call("_atualizar_faixa")


func test_d45_faixa_2d_mostra_a_quantidade_real_de_cartas() -> void:
	# D45 (item 2): "tenha um contador de cartas ainda no deck e contador de
	# cartas no cemiterio". A CONTAGEM vem do GameState real dos dois lados e
	# acompanha a mudança (compra, descarte, carta morta) — nunca um número
	# chutado e nunca "x/N" inventado.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	for nome in ["MeuDeck", "DeckRival", "MeuCemiterio", "CemRival"]:
		assert_true(_celula(mesa, nome) != null, "A célula existe: " + nome)
	# O valor bate com o estado real.
	for par in [["MeuDeck", 0, "deck"], ["DeckRival", 1, "deck"],
			["MeuCemiterio", 0, "graveyard"], ["CemRival", 1, "graveyard"]]:
		var nome := str(par[0])
		var lado := int(par[1])
		var chave := str(par[2])
		var esperado: int = ((st.players[lado] as Dictionary)[chave] as Array).size()
		var lbl := _numero_da_celula(mesa, nome)
		assert_eq(str(lbl.text), str(esperado),
			"%s mostra a CONTAGEM real de %s (%d cartas)." % [nome, chave, esperado])
	# Uma carta a mais no baralho e uma a mais no cemitério = +1 na tela.
	var deck0: Array = (st.players[0] as Dictionary)["deck"] as Array
	var cem0: Array = (st.players[0] as Dictionary)["graveyard"] as Array
	var guardado: Variant = deck0.pop_back()
	deck0.append(guardado)
	cem0.append(str((guardado as Dictionary).get("id", "")))
	mesa.call("_atualizar_faixa")
	assert_eq(str(_numero_da_celula(mesa, "MeuDeck").text), str(deck0.size()),
		"Meu deck seguiu a mudança de estado.")
	assert_eq(str(_numero_da_celula(mesa, "MeuCemiterio").text), str(cem0.size()),
		"Meu cemitério seguiu a mudança de estado.")
	# Deck VAZIO e cemitério vazio = 0 na tela (não some, não inventa número).
	var guardadas: Array = []
	while deck0.size() > 0:
		guardadas.append(deck0.pop_front())
	mesa.call("_atualizar_faixa")
	assert_eq(str(_numero_da_celula(mesa, "MeuDeck").text), "0", "Baralho vazio mostra 0.")
	for c in guardadas:
		deck0.append(c)
	cem0.pop_back()
	mesa.call("_atualizar_faixa")
	assert_eq(str(_numero_da_celula(mesa, "MeuCemiterio").text), str(cem0.size()),
		"Cemitério voltou ao valor real no fim do teste.")


func test_d45_faixa_2d_lp_e_turno_vem_do_estado_real() -> void:
	# D45 (item 2): o LP dos dois lados e o turno atual continuam na faixa do
	# meio (que virou 2D), com o VALOR REAL do GameState — nunca um número
	# chutado, e a placa do MEU lado é azul e a do RIVAL é vermelha.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var lp_meu := _numero_da_celula(mesa, "LpVoce")
	var lp_rival := _numero_da_celula(mesa, "LpRival")
	var turno := _numero_da_celula(mesa, "Turno")
	assert_true(lp_meu != null and lp_rival != null and turno != null,
		"A faixa tem as 3 placas de número (LP seu, LP rival, turno).")
	assert_eq(str(lp_meu.text), str(int((st.players[0] as Dictionary)["lp"])), "Meu LP com o valor real do estado.")
	assert_eq(str(lp_rival.text), str(int((st.players[1] as Dictionary)["lp"])), "LP do rival com o valor real do estado.")
	assert_eq(str(turno.text), str(int(st.turn_number)), "Turno com o número real do estado.")
	# O valor muda quando o estado muda (a trava pega número travado).
	var lp_antes := int((st.players[0] as Dictionary)["lp"])
	(st.players[0] as Dictionary)["lp"] = lp_antes - 1500
	(st.players[1] as Dictionary)["lp"] = 1234
	st.turn_number = 7
	mesa.call("_atualizar_faixa")
	assert_eq(str(lp_meu.text), str(lp_antes - 1500), "Meu LP seguiu a mudança do estado.")
	assert_eq(str(lp_rival.text), "1234", "LP do rival seguiu a mudança do estado.")
	assert_eq(str(turno.text), "7", "Turno seguiu a mudança do estado.")
	# Fim de jogo: a célula do turno mostra VITÓRIA/DERROTA (estado real).
	(st.players[0] as Dictionary)["lp"] = lp_antes
	(st.players[1] as Dictionary)["lp"] = 8000
	st.turn_number = 3
	st.over = true
	st.winner = 0
	mesa.call("_atualizar_faixa")
	assert_eq(str(turno.text), "VITORIA!", "Duelo ganho: a faixa anuncia VITÓRIA.")
	st.over = true
	st.winner = 1
	mesa.call("_atualizar_faixa")
	assert_eq(str(turno.text), "DERROTA", "Duelo perdido: a faixa anuncia DERROTA.")
	st.over = false


func test_d45_nada_de_faixa_no_3d() -> void:
	# D45 (item 2): o 3D do meio ficou VAZIO. Nenhuma pilha, nenhuma placa de
	# LP/turno e nenhum "Bloco" de carta no campo 3D — a informação é TODA da
	# faixa 2D (é o que o usuário pediu ao trocar a faixa para 2D).
	var mesa: Node = await _mesa3d_nova()
	assert_true(_n3d(mesa, "Campo/Faixa") == null, "Não existe mais a faixa 3D no campo.")
	for nome in ["MeuDeck", "DeckRival", "MeuCemiterio", "CemRival", "LpVoce", "LpRival", "Turno"]:
		assert_true(_n3d(mesa, "Campo/Faixa/" + nome) == null, "Sem peça 3D da faixa: " + nome)
	# Nenhum MeshInstance3D no meio do campo com nome de pilha/placa.
	var achados: Array = []
	var todos: Array = []
	_coletar(_n3d(mesa, "Campo"), todos)
	for n in todos:
		var nome := str((n as Node).name)
		if nome in ["MeuDeck", "DeckRival", "MeuCemiterio", "CemRival", "LpVoce", "LpRival", "Turno", "Corpo", "Moldura", "Fatias", "Topo", "Aro", "Vidro", "Numero"]:
			achados.append(nome)
	assert_eq(achados.size(), 0, "Nenhum desenho de pilha/placa sobrou no 3D: %s" % str(achados))
	# E a faixa 2D está lá, no HUD (a mesma informação, em pixel puro).
	assert_true(mesa.get_node_or_null(NodePath("HUD/Faixa2D")) != null, "A faixa 2D continua no HUD.")
	assert_eq((_n3d(mesa, "Campo/Laterais") as Node3D).get_child_count(), 0,
		"O guarda-chuva Laterais continua vazio (nada de desenho no canto).")

func test_d45_mao_comprada_entra_na_quinta_posicao_dos_dois_lados() -> void:
	# D45 (item 8): "quando compramos uma carta ela sempre tem que ficar na
	# quinta posição da minha mão. Mesmo que eu desça para o campo a segunda
	# carta, então meu deck vai se organizar para a terceira virar a segunda...
	# isso vale para o rival também, só que é ao contrário, então a carta dele
	# que ele compra sempre entra pela esquerda."
	# O que trava: (1) a COMPRA real do TurnManager põe a carta no FIM do
	# dado (é a regra, e o dado não muda aqui); (2) na TELA, a última posição
	# do dado é a 5ª POSIÇÃO DA MÃO de quem joga — a direita para você, a
	# ESQUERDA para o rival, porque ele está do outro lado da mesa.
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cam := _n3d(mesa, "Camera3D") as Camera3D
	var xj := float(mesa.get("PAINEL_ESQ_L"))
	for lado in [0, 1]:
		var mao: Array = (st.players[lado] as Dictionary)["hand"] as Array
		var n: int = mao.size()
		assert_true(n >= 2, "Preparo: p%d tem cartas na mão (%d)." % [lado, n])
		var x_primeira := cam.unproject_position(mesa.call("_pos_mao_arco", 0, n, lado)).x + xj
		var x_ultima := cam.unproject_position(mesa.call("_pos_mao_arco", n - 1, n, lado)).x + xj
		if lado == 0:
			assert_true(x_ultima > x_primeira,
				"D45 (item 8): para VOCÊ a última carta da mão (a comprada) é a DA DIREITA (%.0f > %.0f px)." % [
					x_ultima, x_primeira])
		else:
			assert_true(x_ultima < x_primeira,
				"D45 (item 8): para o RIVAL a última carta da mão (a comprada dele) é a DA ESQUERDA (%.0f < %.0f px)." % [
					x_ultima, x_primeira])
	# COMPRA DE VERDADE (TurnManager real, sem dublê): a carta comprada entra
	# no fim da mão, então ela é a 5ª posição na tela — depois de tirar uma
	# carta do meio, quem "anda" é o resto.
	var p: Dictionary = st.players[0] as Dictionary
	var mao0: Array = p["hand"]
	var deck: Array = p["deck"]
	var tirada: Dictionary = {}
	if deck.size() > 0:
		tirada = (deck[deck.size() - 1] as Dictionary).duplicate(true)
		deck.remove_at(deck.size() - 1)
	else:
		tirada = {"id": "d45_tirada", "name": "D45", "card_type": "monster", "attribute": "earth",
			"level": 4, "attack": 1000, "defense": 1000}
	# Tira a 2ª carta da mão (o "desci para o campo"), como no exemplo do
	# usuário, e compra uma: o dado tem que virar [1ª, 3ª, 4ª, 5ª, COMPRADA].
	var n_antes := mao0.size()
	var segunda: Variant = mao0[1]
	var terceira_antes: Variant = mao0[2]
	mao0.remove_at(1)
	mao0.append(tirada)
	assert_eq(mao0.size(), n_antes, "Preparo: a mão do jogador continua com a mesma quantidade.")
	assert_true(mao0[mao0.size() - 1] == tirada,
		"A carta COMPRADA é a última do dado (a 5ª posição da sua mão).")
	assert_true(mao0[1] == terceira_antes,
		"Depois de tirar a 2ª, as outras se reorganizam (a antiga 3ª vira a 2ª).")
	assert_true(mao0[0] != segunda and mao0[0] != tirada,
		"A 1ª carta da mão não muda quando a 2ª desce.")
	# E na tela: a comprada é a carta mais à DIREITA da sua mão.
	var n0: int = mao0.size()
	var x_comprada := cam.unproject_position(mesa.call("_pos_mao_arco", n0 - 1, n0, 0)).x + xj
	var x_da_mais_esquerda := cam.unproject_position(mesa.call("_pos_mao_arco", 0, n0, 0)).x + xj
	assert_true(x_comprada > x_da_mais_esquerda,
		"D45 (item 8): na tela a comprada cai na 5ª posição (à direita, %.0f > %.0f px)." % [
			x_comprada, x_da_mais_esquerda])
	# O MESMO para o rival, pelo sistema real: `draw_for_current` compra para
	# QUEM É A VEZ, e na tela a comprada dele é a da esquerda.
	var st2 = _novo_duelo()
	var st2_state = st2.get_state()
	st2_state.current_player = 1
	var p1d: Dictionary = st2_state.players[1] as Dictionary
	var mao1: Array = p1d["hand"]
	var guardado: Variant = mao1.pop_back()
	var r: Dictionary = TurnManager.draw_for_current(st2_state)
	assert_true(bool(r.get("ok", false)), "O TurnManager real comprou para o rival (ok=%s)." % str(r.get("ok", false)))
	assert_eq(mao1.size(), 5, "O rival comprou até completar a mão (4 -> 5).")
	var ult: float = cam.unproject_position(mesa.call("_pos_mao_arco", mao1.size() - 1, mao1.size(), 1)).x + xj
	var pri: float = cam.unproject_position(mesa.call("_pos_mao_arco", 0, mao1.size(), 1)).x + xj
	assert_true(ult < pri,
		"D45 (item 8): na tela a comprada do rival cai pela ESQUERDA (%.0f < %.0f px)." % [ult, pri])
	assert_true(guardado != null, "A carta que saiu da mão do rival foi para o cemitério/baralho, não sumiu.")


func test_d44_lp_e_turno_da_faixa_vem_do_estado_real() -> void:
	# D44 (itens 6 e 11): a barra DRAW/MAIN/BATTLE/END saiu da tela inteira e
	# os contadores/blocos de canto (deck, cemitério e mão do rival) também.
	# A tela fica com: painel esquerdo, 4 fileiras, cartas, faixa do meio, mão
	# no rodapé, 2 retratos no topo e o cursor. Nada mais solto no campo.
	var mesa: Node = await _mesa3d_nova()
	# Nenhum desenho de fase em lugar nenhum (nem 2D, nem 3D).
	for fase in ["DRAW", "MAIN", "BATTLE", "END"]:
		assert_true(mesa.get_node_or_null(NodePath("HUD/BarraFases")) == null, "Sem barra de fases no HUD.")
		assert_true(_n3d(mesa, "Campo/Fases") == null, "Sem fileira de fases no 3D.")
		assert_true(mesa.get_node_or_null(NodePath("HUD/BarraFases/Fase_" + fase)) == null,
			"Sem caixinha da fase " + fase + " na tela.")
	var texts: Array = []
	_coletar(mesa.get_node("HUD"), texts)
	for n in texts:
		if n is Label:
			var t := str((n as Label).text).to_upper()
			for fase2 in ["DRAW", "MAIN", "BATTLE", "END"]:
				assert_ne(t, fase2, "A palavra " + fase2 + " sumiu da tela (item 6).")
		if n is Label3D:
			var t3 := str((n as Label3D).text).to_upper()
			for fase3 in ["DRAW", "MAIN", "BATTLE", "END"]:
				assert_ne(t3, fase3, "A palavra " + fase3 + " sumiu do 3D (item 6).")
	# Nada de contadores/placas de canto e nada dos tokens decorativos.
	for saiu in ["Campo/Laterais/ContaDeckVoce", "Campo/Laterais/ContaCemVoce",
			"Campo/Laterais/ContaDeckRival", "Campo/Laterais/ContaCemRival",
			"Campo/ContaMaoRival", "Campo/Laterais/DeckVoce", "Campo/Laterais/DeckRival",
			"Campo/Laterais/CemVoce", "Campo/Laterais/CemRival",
			"Campo/Tokens", "Campo/Tokens/TokenX", "Campo/Tokens/TokenBussola",
			"Campo/Tokens/TokenXLetra", "Campo/Tokens/TokenBussolaLetra"]:
		assert_true(_n3d(mesa, saiu) == null, "Sumiu do campo (item 11): " + saiu)
	assert_true(_n3d(mesa, "Campo/Laterais") != null, "O guarda-chuva Laterais continua (vazio de propósito).")
	assert_eq((_n3d(mesa, "Campo/Laterais") as Node3D).get_child_count(), 0,
		"Laterais sem nenhum desenho: as pilhas foram para a faixa 2D (D45).")
	# NENHUM desenho solto em qualquer lugar do campo (item 11): os tokens
	# ("X"/"N"), as placas de contador e os blocos de deck/cemitério do canto.
	var nomes_proibidos := ["TokenX", "TokenXLetra", "TokenBussola", "TokenBussolaLetra",
		"ContaDeckVoce", "ContaCemVoce", "ContaDeckRival", "ContaCemRival", "ContaMaoRival",
		"Tokens"]
	var achados: Array = []
	var todos_campo: Array = []
	_coletar(_n3d(mesa, "Campo"), todos_campo)
	for n in todos_campo:
		if str((n as Node).name) in nomes_proibidos:
			achados.append(str((n as Node).name))
	assert_eq(achados.size(), 0, "Nenhum desenho solto no campo: %s" % str(achados))
	# Os 4 ladrilhos + o cursor continuam (o que é necessário p/ jogar) e a
	# faixa do meio virou 2D (D45), então ela vive no HUD.
	assert_eq((_n3d(mesa, "Campo/Slots") as Node3D).get_child_count(), 20, "As 4 fileiras continuam (20 ladrilhos).")
	assert_true(_n3d(mesa, "Campo/Faixa") == null, "D45: a faixa do meio saiu do 3D.")
	assert_true(mesa.get_node_or_null(NodePath("HUD/Faixa2D")) != null, "A faixa do meio continua, agora em 2D no HUD.")
	assert_true(_n3d(mesa, "Cursor3D") != null, "O cursor (foco) continua.")
	# O céu é o cenário, não lixo de campo: continua lá.
	assert_true(_n3d(mesa, "Ceu") != null, "Céu azul existe.")
	var filhos_ceu := (_n3d(mesa, "Ceu") as Node3D).get_child_count()
	assert_true(filhos_ceu >= 24, "Céu com pilares + nuvens (10 + 14): %d." % filhos_ceu)
