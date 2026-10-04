extends "res://testing/astralis_test_base.gd"

## test_board_layout — GUT sobre o desenho real da arena (R2: sem Fake).
## D24: slot tem ID fixo (lado+tipo+índice), XY mora na arena e só move
## o desenho; a lógica continua no índice. Usa BoardLayout + DuelBoard +
## SummonSystem reais. Bug aqui vira teste permanente.
## Helpers (_novo_duelo/_indice_monstro_na_mao/_garantir_monstros_na_mao/
## _contar_monstros_na_mao) vêm de astralis_test_base.gd.

const BoardLayoutScript := preload("res://core/board_layout.gd")
# ProjectLoaderScript/DuelManagerScript/SummonSystem e MesaScene3D vêm da
# base (astralis_test_base.gd) - R8: uma cópia só.


func _ids_esperados() -> Array:
	var out: Array = []
	for lado in [0, 1]:
		for i in range(5):
			out.append(BoardLayoutScript.slot_id(lado, "monstro", i))
			out.append(BoardLayoutScript.slot_id(lado, "magia", i))
		out.append(BoardLayoutScript.slot_id(lado, "deck", 0))
		out.append(BoardLayoutScript.slot_id(lado, "cemiterio", 0))
	return out


## D50: A MESA É O DADO E HÁ SÓ UM. Estas linhas de teste medem o ARQUIVO
## `schemas/examples/arenas/arena_starter.json`, que é a única fonte da mesa.
## Não existe mais nenhuma grade no código: nem `BoardLayout` nem o 2D legado
## (DuelBoard) têm `GRID_X`/`GAP`/`Y_*`, e `get_pos` sem layout devolve NULO
## em vez de inventar uma grade. Prova disso logo abaixo, em
## `test_d50_sem_grade_no_codigo`.


func test_arena_starter_tem_24_slots_unicos() -> void:
	var caminho: String = BoardLayoutScript.arena_oficial_path()
	assert_true(FileAccess.file_exists(caminho), "A arena oficial existe: %s" % caminho)
	var layout: Dictionary = BoardLayoutScript.load_arena(caminho)
	assert_eq(layout.size(), 24, "A arena oficial tem 24 slots (20 + 4 pilhas).")
	var vistos := {}
	for sid in layout.keys():
		assert_true(BoardLayoutScript.eh_slot_valido(str(sid)), "Slot '%s' segue o contrato p0/p1+m/s/d/g." % str(sid))
		assert_false(vistos.has(sid), "Slot '%s' não repete (ID único)." % str(sid))
		vistos[sid] = true
	for esperado in _ids_esperados():
		assert_true(layout.has(esperado), "A arena tem o slot '%s'." % esperado)
	for sid in layout.keys():
		var p = layout[sid]
		assert_true(p is Vector2, "Slot '%s' guarda Vector2." % str(sid))
		assert_true((p as Vector2).x >= 0.0 and (p as Vector2).y >= 0.0, "Slot '%s' tem XY válido." % str(sid))
	assert_true(BoardLayoutScript.valida_arena_oficial(layout).is_empty(), "A arena oficial passa na validação de 24 slots.")


func test_get_pos_com_xy_custom_retorna_custom() -> void:
	var custom := Vector2(11, 22)
	var layout := {"p0_m2": custom}
	var p: Vector2 = BoardLayoutScript.get_pos(layout, "p0_m2")
	assert_eq(p, custom, "get_pos devolve o XY do layout da arena.")
	# Formatos aceitos no Dict (Array [x,y] e Dict {x,y}) também valem.
	var via_array: Vector2 = BoardLayoutScript.get_pos({"p0_m2": [30, 40]}, "p0_m2")
	assert_eq(via_array, Vector2(30, 40), "Array [x,y] também vale como XY.")
	var via_dict: Vector2 = BoardLayoutScript.get_pos({"p0_m2": {"x": 50, "y": 60}}, "p0_m2")
	assert_eq(via_dict, Vector2(50, 60), "Dict {x,y} também vale como XY.")
	# Quem DESPENHA o XY do layout e a mesa 3D (`_pos_slot`): a trava de que o
	# slot sai no XY do dado esta em test_mesa_3d_oficial
	# (test_posicao_carta_exatamente_no_painel).


func test_sem_layout_nao_inventa_posicao() -> void:
	# D50: SEM GRADE NO CÓDIGO. Sem layout, `get_pos` devolve NULO - a
	# "segunda arena" que fazia o jogo cair numa tela diferente da oficial
	# NÃO EXISTE MAIS.
	var sem_layout: Vector2 = BoardLayoutScript.get_pos({}, "p0_m2")
	assert_eq(sem_layout, BoardLayoutScript.NULO, "Sem layout, get_pos devolve NULO (não há grade para cair).")
	assert_eq(BoardLayoutScript.default_pos("p0_m2"), BoardLayoutScript.NULO, "default_pos é só o 'não tem posição' (D50).")
	assert_eq(BoardLayoutScript.default_pos("xx"), BoardLayoutScript.NULO, "ID inválido também devolve NULO.")
	# O fallback explícito do chamador ainda funciona (quem sabe o que fazer).
	var queda := Vector2(-1, -1)
	assert_eq(BoardLayoutScript.get_pos({}, "invalido", queda), queda, "Slot fora do layout usa o fallback do chamador.")


func test_arquivo_ruim_nao_inventa_posicao() -> void:
	# D50: arquivo ausente/quebrado é ERRO HONESTO — slots vazios, sem grade
	# para completar, e a mesa avisa em vez de desenhar uma mesa inventada.
	var vazio1: Dictionary = BoardLayoutScript.load_arena("")
	assert_true(vazio1.is_empty(), "Caminho vazio carrega vazio (sem inventar posição).")
	var vazio2: Dictionary = BoardLayoutScript.load_arena("Z:/caminho/que/nao/existe/arena.json")
	assert_true(vazio2.is_empty(), "Arquivo que não existe carrega vazio.")
	var res_dir: String = ProjectSettings.globalize_path("res://")
	var duel_setup_path: String = res_dir.path_join("../schemas/examples/duel_setup.json").simplify_path()
	var vazio3: Dictionary = BoardLayoutScript.load_arena(duel_setup_path)
	assert_true(vazio3.is_empty(), "JSON que não é arena carrega vazio.")
	for layout_ruim in [vazio1, vazio2, vazio3]:
		var p: Vector2 = BoardLayoutScript.get_pos(layout_ruim, "p0_m0")
		assert_eq(p, BoardLayoutScript.NULO, "Com arquivo ruim, get_pos devolve NULO (nada é inventado).")
	# E a validação diz exatamente o que falta, para o log ser útil.
	var faltando: Array = BoardLayoutScript.valida_arena_oficial({})
	assert_eq(faltando.size(), 24, "Layout vazio: a validação aponta os 24 slots que faltam.")


func test_espelho_p1_x_invertido() -> void:
	# D25 ESPELHO (só desenho), medido no ARQUIVO: p1 com X invertido, índice 0
	# à direita, e a mesma distância do espelho dos dois lados.
	var s: Dictionary = BoardLayoutScript.load_arena(BoardLayoutScript.arena_oficial_path())
	var p1_m0: Vector2 = BoardLayoutScript.get_pos(s, "p1_m0")
	var p1_m4: Vector2 = BoardLayoutScript.get_pos(s, "p1_m4")
	var p0_m0: Vector2 = BoardLayoutScript.get_pos(s, "p0_m0")
	var p0_m4: Vector2 = BoardLayoutScript.get_pos(s, "p0_m4")
	assert_true(p1_m0.x > p1_m4.x, "Espelho: p1_m0 à direita de p1_m4 (x maior).")
	assert_eq(p1_m0.x, p0_m4.x, "Espelho horizontal: p1_m0.x == p0_m4.x.")
	assert_eq(p1_m4.x, p0_m0.x, "Espelho horizontal: p1_m4.x == p0_m0.x.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_s0").x, p1_m0.x, "Mesma coluna: p1_s0.x == p1_m0.x.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_s4").x, p1_m4.x, "Mesma coluna: p1_s4.x == p1_m4.x.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_m2").x, BoardLayoutScript.get_pos(s, "p0_m2").x, "Meio espelha no mesmo X.")


func test_espelho_p1_fileiras_perto_longe() -> void:
	# D25 ESPELHO + D49 (uma distância só), medido no ARQUIVO: monstro perto
	# do centro, magia longe, e o vão monstro->magia é o MESMO dos dois lados e
	# o mesmo do passo horizontal.
	var s: Dictionary = BoardLayoutScript.load_arena(BoardLayoutScript.arena_oficial_path())
	var m: Vector2 = BoardLayoutScript.get_pos(s, "p1_m0")
	var sm: Vector2 = BoardLayoutScript.get_pos(s, "p1_s0")
	assert_eq(m.y, 395.0, "Rival monstro y=395 (perto do centro).")
	assert_eq(sm.y, 158.0, "Rival magia y=158 (longe do centro).")
	assert_true(m.y > sm.y, "Rival: o monstro fica ABAIXO da magia (perto do centro).")
	for i in range(5):
		assert_eq(BoardLayoutScript.get_pos(s, "p1_m%d" % i).y, 395.0, "Rival monstro %d na fileira 395." % i)
		assert_eq(BoardLayoutScript.get_pos(s, "p1_s%d" % i).y, 158.0, "Rival magia %d na fileira 158." % i)
	# Você: monstro 695 perto, magia 932 longe.
	assert_eq(BoardLayoutScript.get_pos(s, "p0_m0").y, 695.0, "Você monstro y=695.")
	assert_eq(BoardLayoutScript.get_pos(s, "p0_s0").y, 932.0, "Você magia y=932.")
	# D49: UM VALOR SÓ no campo.
	var passo: float = BoardLayoutScript.get_pos(s, "p0_m1").x - BoardLayoutScript.get_pos(s, "p0_m0").x
	assert_eq(passo, 237.0, "Passo horizontal dos monstros = 237.")
	assert_eq(BoardLayoutScript.get_pos(s, "p0_s1").x - BoardLayoutScript.get_pos(s, "p0_s0").x, passo, "Passo horizontal das magias = o mesmo.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_m0").x - BoardLayoutScript.get_pos(s, "p1_m1").x, passo, "Passo horizontal dos monstros do rival = o mesmo.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_s0").x - BoardLayoutScript.get_pos(s, "p1_s1").x, passo, "Passo horizontal das magias do rival = o mesmo.")
	assert_eq(absf(BoardLayoutScript.get_pos(s, "p0_s0").y - BoardLayoutScript.get_pos(s, "p0_m0").y), passo, "Vão monstro->magia do jogador = o passo horizontal.")
	assert_eq(absf(BoardLayoutScript.get_pos(s, "p1_m0").y - BoardLayoutScript.get_pos(s, "p1_s0").y), passo, "Vão monstro->magia do rival = o passo horizontal.")
	# E a distância entre as fileiras de monstro dos 2 lados segue CONGELADA.
	assert_eq(BoardLayoutScript.get_pos(s, "p0_m0").y - BoardLayoutScript.get_pos(s, "p1_m0").y, 300.0, "D50/D49: a distância entre as fileiras de monstro é 300.")
	assert_ne(BoardLayoutScript.get_pos(s, "p0_m0").y - BoardLayoutScript.get_pos(s, "p1_m0").y, passo, "A distância dos monstros NÃO virou o valor da grade.")


func test_pilhas_ao_lado_no_meio_das_fileiras() -> void:
	# As 4 pilhas: baralho a direita (d), cemiterio a esquerda (g), no MEIO
	# entre as fileiras de cada lado e ENCOSTADAS nas colunas das pontas (sem
	# vao de vidro): centro a 215.5 (metade do vidro do slot + metade do vidro
	# da pilha).
	var s: Dictionary = BoardLayoutScript.load_arena(BoardLayoutScript.arena_oficial_path())
	for lado in [0, 1]:
		var d: Vector2 = BoardLayoutScript.get_pos(s, BoardLayoutScript.slot_id(lado, "deck", 0))
		var g: Vector2 = BoardLayoutScript.get_pos(s, BoardLayoutScript.slot_id(lado, "cemiterio", 0))
		assert_eq(d.x, 1834.5, "Pilha do baralho p%d a direita do campo." % lado)
		assert_eq(g.x, 481.5, "Pilha do cemitério p%d a esquerda do campo." % lado)
		assert_eq(d.x - 1632.0, 202.5, "Baralho p%d encostado na última coluna." % lado)
		assert_eq(684.0 - g.x, 202.5, "Cemitério p%d encostado na primeira coluna." % lado)
	var ym0: float = BoardLayoutScript.get_pos(s, "p0_m0").y
	var ys0: float = BoardLayoutScript.get_pos(s, "p0_s0").y
	assert_eq(BoardLayoutScript.get_pos(s, "p0_d0").y, (ym0 + ys0) * 0.5, "Baralho p0 no meio das fileiras.")
	assert_eq(BoardLayoutScript.get_pos(s, "p0_g0").y, (ym0 + ys0) * 0.5, "Cemitério p0 no meio das fileiras.")
	var ym1: float = BoardLayoutScript.get_pos(s, "p1_m0").y
	var ys1: float = BoardLayoutScript.get_pos(s, "p1_s0").y
	assert_eq(BoardLayoutScript.get_pos(s, "p1_d0").y, (ym1 + ys1) * 0.5, "Baralho p1 no meio das fileiras.")
	assert_eq(BoardLayoutScript.get_pos(s, "p1_g0").y, (ym1 + ys1) * 0.5, "Cemitério p1 no meio das fileiras.")


func test_d50_sem_grade_no_codigo() -> void:
	# D50: o que o usuário mandou — UMA arena. A prova de que não existe uma
	# segunda: (1) o código não tem mais as constantes da grade, (2) sem layout
	# não sai posição nenhuma, (3) a pasta arenas/ do projeto é ignorada, e
	# (4) o único arquivo de arena do repo é a arena oficial.
	assert_eq(BoardLayoutScript.default_pos("p0_m0"), BoardLayoutScript.NULO, "BoardLayout não tem grade: default_pos é NULO.")
	assert_eq(BoardLayoutScript.default_pos("p1_s4"), BoardLayoutScript.NULO, "BoardLayout não tem grade: nenhum slot tem posição embutida.")
	var vazio: Dictionary = BoardLayoutScript.default_layout()
	for sid in vazio.keys():
		assert_eq(vazio[sid] as Vector2, BoardLayoutScript.NULO, "default_layout sem layout é tudo NULO: '%s'." % str(sid))
	# O caminho da arena é SEMPRE o oficial, e o id do setup é ignorado.
	assert_eq(BoardLayoutScript.project_arena_path("arena_starter"), BoardLayoutScript.arena_oficial_path(), "arena_id da oficial = arena oficial.")
	assert_eq(BoardLayoutScript.project_arena_path("arena_qualquer_outra"), BoardLayoutScript.arena_oficial_path(), "D50: qualquer outra arena cai na oficial (o jogo tem uma só).")
	assert_true(FileAccess.file_exists(BoardLayoutScript.arena_oficial_path()), "A arena oficial existe no disco.")
	# E o projeto do Studio não tem mais pasta arenas/ (uma mesa só).
	var proj: String = "res://../astralis-studio/projects/default/arenas"
	assert_false(DirAccess.dir_exists_absolute(proj), "O projeto do Studio não tem mais pasta arenas/ (D50).")

func test_logica_por_indice_intacta_xy_nao_muda_slot() -> void:
	# D24: mover o XY no JSON só move o desenho; a carta vai p/ o ÍNDICE.
	var duel = _novo_duelo()
	var st = duel.get_state()
	duel.advance_phase() # DRAW -> MAIN
	assert_eq(String(st.phase), "MAIN", "Preparo: estamos na MAIN.")
	var cur: int = int(st.current_player)
	_garantir_monstros_na_mao(st, cur, 1)
	var mao_idx: int = _indice_monstro_na_mao(st, cur)
	assert_true(mao_idx >= 0, "Preparo: mão tem monstro.")
	# Arena custom com p0_m2 longe do padrão (desenho movido).
	var movido := Vector2(11, 22)
	var layout := {"p0_m2": movido}
	assert_eq(BoardLayoutScript.get_pos(layout, "p0_m2"), movido, "Preparo: desenho de p0_m2 foi movido.")
	assert_ne(BoardLayoutScript.get_pos(layout, "p0_m2"), BoardLayoutScript.default_pos("p0_m2"), "Preparo: XY custom difere da grade padrão.")
	var r: Dictionary = SummonSystem.normal_summon(st, cur, mao_idx, 2)
	assert_true(bool(r.get("ok", false)), "Summon no slot 2 funciona mesmo com XY movido.")
	assert_eq(int(r.get("slot", -1)), 2, "Retorno confirma índice 2.")
	var zona: Array = (st.players[cur] as Dictionary)["monster"]
	assert_true(zona[2] != null, "Carta foi p/ o ÍNDICE 2 (lógica intacta).")
	for i in [0, 1, 3, 4]:
		assert_true(zona[i] == null, "Slot %d continua vazio." % i)


func test_escolha_livre_slot_0_e_4_aceitam_summon() -> void:
	# D24: jogador escolhe qualquer slot livre (0 e 4 valem).
	# 1 summon por MAIN: usa 2 duelos reais (seed 42, determinístico).
	var duel_a = _novo_duelo()
	var st_a = duel_a.get_state()
	duel_a.advance_phase()
	var cur_a: int = int(st_a.current_player)
	_garantir_monstros_na_mao(st_a, cur_a, 1)
	var pode_0: Dictionary = SummonSystem.can_normal_summon(st_a, cur_a, _indice_monstro_na_mao(st_a, cur_a), 0)
	assert_true(bool(pode_0.get("ok", false)), "Slot 0 livre aceita summon.")
	var pode_4: Dictionary = SummonSystem.can_normal_summon(st_a, cur_a, _indice_monstro_na_mao(st_a, cur_a), 4)
	assert_true(bool(pode_4.get("ok", false)), "Slot 4 livre aceita summon.")
	var r0: Dictionary = SummonSystem.normal_summon(st_a, cur_a, _indice_monstro_na_mao(st_a, cur_a), 0)
	assert_true(bool(r0.get("ok", false)), "Summon no slot 0 funciona.")
	assert_true((st_a.players[cur_a] as Dictionary)["monster"][0] != null, "Carta foi p/ o índice 0.")
	var duel_b = _novo_duelo()
	var st_b = duel_b.get_state()
	duel_b.advance_phase()
	var cur_b: int = int(st_b.current_player)
	_garantir_monstros_na_mao(st_b, cur_b, 1)
	var r4: Dictionary = SummonSystem.normal_summon(st_b, cur_b, _indice_monstro_na_mao(st_b, cur_b), 4)
	assert_true(bool(r4.get("ok", false)), "Summon no slot 4 funciona (outro duelo, mesma seed).")
	assert_true((st_b.players[cur_b] as Dictionary)["monster"][4] != null, "Carta foi p/ o índice 4.")


# ---- Mão arrumada (runtime real, sem Fake) ----

func test_hand_starter_p0_p1_valores() -> void:
	# Arena starter traz a mão: p0 aberta embaixo + p1 de costas no topo.
	var caminho: String = BoardLayoutScript.starter_arena_path()
	var arena: Dictionary = BoardLayoutScript.load_arena_data(caminho)
	assert_true(arena.has("hand"), "Arena completa traz 'hand'.")
	var hand: Dictionary = arena.get("hand", {})
	var p0: Dictionary = hand.get("p0", {})
	var p1: Dictionary = hand.get("p1", {})
	assert_eq(float(p0.get("x", -1.0)), 1240.0, "Starter p0.x=1240 (centro sob o campo).")
	assert_eq(float(p0.get("y", -1.0)), 980.0, "Starter p0.y=980 (embaixo).")
	assert_eq(float(p0.get("step", -1.0)), 95.0, "Starter p0.step=95.")
	assert_eq(float(p1.get("x", -1.0)), 1240.0, "Starter p1.x=1240 (centro no topo).")
	assert_eq(float(p1.get("y", -1.0)), 20.0, "Starter p1.y=20 (topo).")
	assert_eq(float(p1.get("step", -1.0)), 60.0, "Starter p1.step=60 (mini junta).")
	var h0: Dictionary = BoardLayoutScript.get_hand(arena, 0)
	assert_eq(float(h0.get("x", 0.0)), 1240.0, "get_hand arena p0.x=1240.")
	assert_eq(float(h0.get("y", 0.0)), 980.0, "get_hand arena p0.y=980.")
	assert_eq(float(h0.get("step", 0.0)), 95.0, "get_hand arena p0.step=95.")
	var h1: Dictionary = BoardLayoutScript.get_hand(arena, 1)
	assert_eq(float(h1.get("x", 0.0)), 1240.0, "get_hand arena p1.x=1240.")
	assert_eq(float(h1.get("y", 0.0)), 20.0, "get_hand arena p1.y=20.")
	assert_eq(float(h1.get("step", 0.0)), 60.0, "get_hand arena p1.step=60.")


func test_hand_fallback_sem_hand() -> void:
	# Arena antiga sem "hand" continua válida: usa o fallback.
	var f0: Dictionary = BoardLayoutScript.default_hand(0)
	var f1: Dictionary = BoardLayoutScript.default_hand(1)
	assert_eq(float(f0.get("x", 0.0)), 1240.0, "Fallback p0.x=1240.")
	assert_eq(float(f0.get("y", 0.0)), 980.0, "Fallback p0.y=980.")
	assert_eq(float(f0.get("step", 0.0)), 95.0, "Fallback p0.step=95.")
	assert_eq(float(f1.get("x", 0.0)), 1240.0, "Fallback p1.x=1240.")
	assert_eq(float(f1.get("y", 0.0)), 20.0, "Fallback p1.y=20.")
	assert_eq(float(f1.get("step", 0.0)), 60.0, "Fallback p1.step=60.")
	assert_eq(BoardLayoutScript.get_hand({}, 0), f0, "Dict vazio volta fallback p0.")
	assert_eq(BoardLayoutScript.get_hand({}, 1), f1, "Dict vazio volta fallback p1.")
	var so_slots := {"p0_m0": Vector2(632, 695)}
	assert_eq(BoardLayoutScript.get_hand(so_slots, 0), f0, "Slots-only legado volta fallback p0.")
	assert_eq(BoardLayoutScript.get_hand(so_slots, 1), f1, "Slots-only legado volta fallback p1.")
	var sem_hand: Dictionary = BoardLayoutScript.parse_hand({})
	assert_eq(sem_hand.get("p0", {}), f0, "parse_hand sem hand volta fallback p0.")
	assert_eq(sem_hand.get("p1", {}), f1, "parse_hand sem hand volta fallback p1.")
	var parcial: Dictionary = BoardLayoutScript.get_hand({"p0": {"x": 500}}, 0)
	assert_eq(float(parcial.get("x", 0.0)), 500.0, "Hand parcial troca só o x.")
	assert_eq(float(parcial.get("y", 0.0)), 980.0, "Hand parcial mantém y do fallback.")
	assert_eq(float(parcial.get("step", 0.0)), 95.0, "Hand parcial mantém step do fallback.")
	var ruim: Dictionary = BoardLayoutScript.get_hand({"p0": {"x": -10, "y": 9999, "step": 999}}, 0)
	assert_eq(ruim, f0, "Valor fora do contrato volta fallback inteiro.")
	var via_arena: Dictionary = BoardLayoutScript.get_hand({"hand": {"p0": {"x": 1000, "y": 900, "step": 100}}}, 0)
	assert_eq(float(via_arena.get("x", 0.0)), 1000.0, "Formato arena {hand} vale p/ p0.")
	assert_eq(BoardLayoutScript.get_hand({"hand": {"p0": {"x": 1000, "y": 900, "step": 100}}}, 1), f1, "Sem p1 no {hand}, volta fallback p1.")


func test_p1_nunca_expoe_id_ou_nome() -> void:
	# R1: a mao do RIVAL e de costas - a tela mostra a CONTAGEM (as cartas dele
	# desenhadas) e nunca o id, o nome ou o ATK delas. No 2D legado isso era
	# `set_facedown` + escala 0,55; na mesa 3D (a oficial) a mao do rival nasce
	# de VERSO e o lugar de cima e tapado inteiro (D52).
	var duel = _novo_duelo()
	var st = duel.get_state()
	var mao_rival: Array = (st.players[1] as Dictionary)["hand"]
	assert_true(mao_rival.size() > 0, "Preparo: rival tem cartas na mao.")
	var segredos := {}
	for c in mao_rival:
		if c is Dictionary:
			segredos[str((c as Dictionary).get("id", ""))] = true
			segredos[str((c as Dictionary).get("name", ""))] = true
	# Os dois baralhos saem do MESMO pool de cartas (FM), entao um nome que
	# tambem esta na SUA mao pode (e deve) aparecer na tela. O que nao pode
	# aparecer e o que SO o rival tem - por isso os nomes da sua mao saem da
	# lista de segredos.
	var mao_meu: Array = (st.players[0] as Dictionary)["hand"]
	for c in mao_meu:
		if c is Dictionary:
			segredos.erase(str((c as Dictionary).get("id", "")))
			segredos.erase(str((c as Dictionary).get("name", "")))
	# 1) Nenhum texto da cena inteira (Label 2D e Label3D) vaza id/nome dele.
	var mesa = await _mesa3d_nova()
	var textos: Array = []
	_textos_visiveis(mesa, textos)
	var vazou: Array = []
	for t in textos:
		for s2 in segredos:
			if str(s2) != "" and str(t).contains(str(s2)):
				vazou.append("%s (em '%s')" % [s2, t])
	assert_true(vazou.is_empty(), "A tela nao vaza id/nome de carta do rival: %s" % str(vazou))
	# 2) A mao do rival ESTA desenhada: e a contagem que aparece, nao o nome.
	var n_rival := 0
	for i in range(mao_rival.size()):
		if _carta_da_mao(mesa, i, 1) != null:
			n_rival += 1
	assert_eq(n_rival, mao_rival.size(), "As %d cartas do rival estao desenhadas (so contagem)." % mao_rival.size())
	# 3) E a sua mao NAO esta de costas (o contrario seria esconder a sua).
	var n_meu := 0
	for i in range(mao_meu.size()):
		if _carta_da_mao(mesa, i, 0) != null:
			n_meu += 1
	assert_eq(n_meu, mao_meu.size(), "A sua mao de %d cartas tambem esta desenhada." % mao_meu.size())


## O arco da mao em 2D (_pos_mao, centro = cx da arena) foi junto com a mesa
## legada. No 3D o X do arco de cada LUGAR de mao e resolvido da camera real
## (`_x_centro_da_mao`) e a trava dessa invariante esta no arquivo 3D:
## test_mesa_3d_oficial/test_maos_centralizadas_no_x_do_campo (erro 0,00 px
## nos dois lugares) e test_volta_mesa/test_as_duas_maos_trocam_de_lugar_e_as_duas_aparecem.


func test_animacao_recriar_mesa_2x_sem_erro() -> void:
	# Guarda de CRASH da cena real: tween preso a carta que morre no free,
	# recriar a mesa nao quebra. Roda na mesa 3D (a oficial desde o D40).
	for k in [1, 2]:
		var mesa: Node = await _mesa3d_nova()
		assert_true(is_instance_valid(mesa), "Mesa %d valida apos instanciar." % k)
		var st: Variant = mesa.get("_st")
		assert_true(st != null, "Mesa %d tem estado real (duelo montado)." % k)
		var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
		var n1: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
		var n_cartas: int = _cartas3d(mesa).size()
		assert_eq(n_cartas, n0 + n1 + 2, "Mesa %d desenha as DUAS maos + os 2 dorsos de baralho (efeito ligado)." % k)
		mesa.call("_redesenhar", true, 0)
		await wait_process_frames(6)
		assert_eq(_cartas3d(mesa).size(), n0 + n1 + 2, "Mesa %d recriada com efeito mantem a contagem." % k)
		mesa.queue_free()
		await wait_process_frames(2)
	assert_true(true, "2 mesas criadas/liberadas sem erro (tween preso a carta).")
