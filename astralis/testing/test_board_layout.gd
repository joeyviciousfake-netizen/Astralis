extends GutTest

## test_board_layout — GUT sobre o desenho real da arena (R2: sem Fake).
## D24: slot tem ID fixo (lado+tipo+índice), XY mora na arena e só move
## o desenho; a lógica continua no índice. Usa BoardLayout + DuelBoard +
## SummonSystem reais. Bug aqui vira teste permanente.

const BoardLayoutScript := preload("res://core/board_layout.gd")
const BoardScript := preload("res://ui/duel_board.gd")
const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const TableScript := preload("res://ui/duel_table.gd")
const CardViewScript := preload("res://ui/card_view.gd")
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


func _contar_monstros_na_mao(st, player_idx: int) -> int:
	var n := 0
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for c in mao:
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			n += 1
	return n


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


func _ids_esperados() -> Array:
	var out: Array = []
	for lado in [0, 1]:
		for i in range(5):
			out.append(BoardLayoutScript.slot_id(lado, "monstro", i))
			out.append(BoardLayoutScript.slot_id(lado, "magia", i))
	return out


func test_arena_starter_tem_20_slots_unicos() -> void:
	var caminho: String = BoardLayoutScript.starter_arena_path()
	assert_true(FileAccess.file_exists(caminho), "arena_starter.json existe: %s" % caminho)
	var layout: Dictionary = BoardLayoutScript.load_arena(caminho)
	assert_eq(layout.size(), 20, "Arena starter tem 20 slots.")
	var vistos := {}
	for sid in layout.keys():
		assert_true(BoardLayoutScript.eh_slot_valido(str(sid)), "Slot '%s' segue o contrato p0/p1+m/s+0-4." % str(sid))
		assert_false(vistos.has(sid), "Slot '%s' não repete (ID único)." % str(sid))
		vistos[sid] = true
	for esperado in _ids_esperados():
		assert_true(layout.has(esperado), "Arena tem o slot '%s'." % esperado)
	for sid in layout.keys():
		var p = layout[sid]
		assert_true(p is Vector2, "Slot '%s' guarda Vector2." % str(sid))
		assert_true((p as Vector2).x >= 0.0 and (p as Vector2).y >= 0.0, "Slot '%s' tem XY válido." % str(sid))


func test_get_pos_com_xy_custom_retorna_custom() -> void:
	var custom := Vector2(11, 22)
	var layout := {"p0_m2": custom}
	var p: Vector2 = BoardLayoutScript.get_pos(layout, "p0_m2")
	assert_eq(p, custom, "get_pos devolve o XY custom da arena.")
	# Formatos aceitos no Dict (Array [x,y] e Dict {x,y}) também valem.
	var via_array: Vector2 = BoardLayoutScript.get_pos({"p0_m2": [30, 40]}, "p0_m2")
	assert_eq(via_array, Vector2(30, 40), "Array [x,y] também vale como XY.")
	var via_dict: Vector2 = BoardLayoutScript.get_pos({"p0_m2": {"x": 50, "y": 60}}, "p0_m2")
	assert_eq(via_dict, Vector2(50, 60), "Dict {x,y} também vale como XY.")
	# O desenho usa o XY custom.
	var r: Rect2 = BoardScript.slot_rect(0, "monstro", 2, layout)
	assert_eq(r.position, custom, "slot_rect usa o XY custom da arena.")
	assert_eq(r.size, Vector2(BoardScript.SLOT, BoardScript.SLOT), "Tamanho do slot continua 165x165.")


func test_sem_layout_retorna_grade_padrao() -> void:
	var padrao: Vector2 = BoardLayoutScript.default_pos("p0_m2")
	assert_true(padrao.x >= 0.0, "Grade padrão tem XY válido p/ p0_m2.")
	var sem_layout: Vector2 = BoardLayoutScript.get_pos({}, "p0_m2")
	assert_eq(sem_layout, padrao, "Sem layout, get_pos volta p/ grade padrão.")
	var r: Rect2 = BoardScript.slot_rect(0, "monstro", 2, {})
	assert_eq(r.position, padrao, "Sem layout, slot_rect volta p/ grade padrão.")
	# Slot inválido não quebra: devolve o fallback.
	var queda := Vector2(-1, -1)
	assert_eq(BoardLayoutScript.get_pos({}, "invalido", queda), queda, "Slot inválido devolve o fallback.")
	assert_eq(BoardLayoutScript.default_pos("xx"), Vector2(-1, -1), "default_pos inválido devolve (-1,-1).")


func test_arquivo_ruim_retorna_fallback_padrao() -> void:
	var vazio1: Dictionary = BoardLayoutScript.load_arena("")
	assert_true(vazio1.is_empty(), "Caminho vazio carrega vazio (usa grade padrão).")
	var vazio2: Dictionary = BoardLayoutScript.load_arena("Z:/caminho/que/nao/existe/arena.json")
	assert_true(vazio2.is_empty(), "Arquivo que não existe carrega vazio (usa grade padrão).")
	# Arquivo real mas que não é arena (sem lista 'slots'): também não quebra.
	var res_dir: String = ProjectSettings.globalize_path("res://")
	var duel_setup_path: String = res_dir.path_join("../schemas/examples/duel_setup.json").simplify_path()
	var vazio3: Dictionary = BoardLayoutScript.load_arena(duel_setup_path)
	assert_true(vazio3.is_empty(), "JSON que não é arena carrega vazio (usa grade padrão).")
	# E o fallback funciona em todos os casos.
	var padrao: Vector2 = BoardLayoutScript.default_pos("p0_m0")
	for layout_ruim in [vazio1, vazio2, vazio3]:
		var p: Vector2 = BoardLayoutScript.get_pos(layout_ruim, "p0_m0")
		assert_eq(p, padrao, "Com arquivo ruim, get_pos volta p/ grade padrão.")
		var r: Rect2 = BoardScript.slot_rect(0, "monstro", 0, layout_ruim)
		assert_eq(r.position, padrao, "Com arquivo ruim, slot_rect volta p/ grade padrão.")


func test_espelho_p1_x_invertido() -> void:
	# D25 ESPELHO (só desenho): p1 com X invertido, índice 0 à direita.
	var p1_m0: Vector2 = BoardLayoutScript.default_pos("p1_m0")
	var p1_m4: Vector2 = BoardLayoutScript.default_pos("p1_m4")
	var p0_m0: Vector2 = BoardLayoutScript.default_pos("p0_m0")
	var p0_m4: Vector2 = BoardLayoutScript.default_pos("p0_m4")
	assert_true(p1_m0.x > p1_m4.x, "Espelho: p1_m0 à direita de p1_m4 (x maior).")
	assert_eq(p1_m0.x, p0_m4.x, "Espelho horizontal: p1_m0.x == p0_m4.x.")
	assert_eq(p1_m4.x, p0_m0.x, "Espelho horizontal: p1_m4.x == p0_m0.x.")
	var p1_s0: Vector2 = BoardLayoutScript.default_pos("p1_s0")
	var p1_s4: Vector2 = BoardLayoutScript.default_pos("p1_s4")
	assert_true(p1_s0.x > p1_s4.x, "Espelho: p1_s0 à direita de p1_s4 (magia também inverte).")
	assert_eq(p1_s0.x, p1_m0.x, "Mesma coluna: p1_s0.x == p1_m0.x.")
	assert_eq(p1_s4.x, p1_m4.x, "Mesma coluna: p1_s4.x == p1_m4.x.")
	var meio_p1: Vector2 = BoardLayoutScript.default_pos("p1_m2")
	var meio_p0: Vector2 = BoardLayoutScript.default_pos("p0_m2")
	assert_eq(meio_p1.x, meio_p0.x, "Meio espelha no mesmo X: p1_m2.x == p0_m2.x.")
	# O desenho sem layout usa o mesmo espelho.
	var r0: Rect2 = BoardScript.slot_rect(1, "monstro", 0, {})
	assert_eq(r0.position, p1_m0, "slot_rect fallback de p1_m0 usa o espelho.")
	var r4: Rect2 = BoardScript.slot_rect(1, "monstro", 4, {})
	assert_eq(r4.position, p1_m4, "slot_rect fallback de p1_m4 usa o espelho.")


func test_espelho_p1_fileiras_perto_longe() -> void:
	# D25 ESPELHO (só desenho): monstro perto do centro, magia longe.
	var m: Vector2 = BoardLayoutScript.default_pos("p1_m0")
	var s: Vector2 = BoardLayoutScript.default_pos("p1_s0")
	assert_eq(m.y, BoardLayoutScript.Y_RIVAL_MONSTRO, "Fileira rival monstro = Y_RIVAL_MONSTRO.")
	assert_eq(s.y, BoardLayoutScript.Y_RIVAL_MAGIA, "Fileira rival magia = Y_RIVAL_MAGIA.")
	assert_eq(m.y, 317.0, "Rival monstro y=317 (embaixo/perto do centro).")
	assert_eq(s.y, 128.0, "Rival magia y=128 (cima/longe do centro).")
	assert_true(m.y > s.y, "Rival monstro fica abaixo da magia (perto do centro).")
	for i in range(5):
		assert_eq(BoardLayoutScript.default_pos("p1_m%d" % i).y, 317.0, "Rival monstro %d na fileira 317." % i)
		assert_eq(BoardLayoutScript.default_pos("p1_s%d" % i).y, 128.0, "Rival magia %d na fileira 128." % i)
	# Você continua intacto (monstro 600 perto, magia 789 longe).
	assert_eq(BoardLayoutScript.default_pos("p0_m0").y, 600.0, "Você monstro y=600 (cima/perto).")
	assert_eq(BoardLayoutScript.default_pos("p0_s0").y, 789.0, "Você magia y=789 (baixo/longe).")


func test_espelho_arena_starter_igual_fallback() -> void:
	# Arena starter carrega espelhada igual ao fallback (D25).
	var arena: Dictionary = BoardLayoutScript.load_arena_data(BoardLayoutScript.starter_arena_path())
	assert_true(arena.has("slots"), "Arena completa traz 'slots'.")
	var slots: Dictionary = arena.get("slots", {})
	for sid in ["p1_m0", "p1_m4", "p1_s0", "p1_s4", "p0_m0", "p0_m4", "p0_s0"]:
		assert_eq(slots[sid], BoardLayoutScript.default_pos(sid), "Starter '%s' espelhado igual ao fallback." % sid)
	var p1_m0: Vector2 = BoardLayoutScript.get_pos(slots, "p1_m0")
	var p1_m4: Vector2 = BoardLayoutScript.get_pos(slots, "p1_m4")
	var p0_m4: Vector2 = BoardLayoutScript.get_pos(slots, "p0_m4")
	assert_true(p1_m0.x > p1_m4.x, "Starter: p1_m0 à direita de p1_m4.")
	assert_eq(p1_m0.x, p0_m4.x, "Starter: p1_m0.x == p0_m4.x (espelho).")
	assert_eq(p1_m0.y, 317.0, "Starter: p1_m0.y=317 (perto do centro).")
	assert_eq(BoardLayoutScript.get_pos(slots, "p1_s0").y, 128.0, "Starter: p1_s0.y=128 (longe).")
	var r: Rect2 = BoardScript.slot_rect(1, "monstro", 0, slots)
	assert_eq(r.position, BoardLayoutScript.default_pos("p1_m0"), "slot_rect com starter = fallback espelhado.")


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
	var so_slots := {"p0_m0": Vector2(780, 600)}
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


func test_p1_nunca_expoe_id_so_contagem() -> void:
	# Rival desenha de costas: só a QUANTIDADE, nunca id/nome (R1).
	var arena: Dictionary = BoardLayoutScript.load_arena_data(BoardLayoutScript.starter_arena_path())
	var duel = _novo_duelo()
	var st = duel.get_state()
	var mao_rival: Array = (st.players[1] as Dictionary)["hand"]
	assert_true(mao_rival.size() > 0, "Preparo: rival tem cartas na mão.")
	var segredos := {}
	for c in mao_rival:
		if c is Dictionary:
			segredos[str((c as Dictionary).get("id", ""))] = true
			segredos[str((c as Dictionary).get("name", ""))] = true
	var mesa = TableScript.new()
	mesa._arena_data = arena
	mesa._st = st
	mesa._sel_mao = -1
	var camada := Control.new()
	mesa._camada_mao = camada
	mesa._desenhar_mao(false)
	var filhos: Array = camada.get_children()
	var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var n1: int = mao_rival.size()
	assert_eq(filhos.size(), n0 + n1, "Mesa desenha p0 abertas + p1 de costas (contagem).")
	var minis := 0
	for vista in filhos:
		if not (vista is Control) or not vista.has_method("set_facedown"):
			continue
		var escala: Vector2 = (vista as Control).scale
		if escala.is_equal_approx(Vector2(0.55, 0.55)):
			minis += 1
			var carta: Dictionary = vista.get("_carta")
			assert_true(carta.is_empty(), "Mini p1 nasce vazia (setup({})), sem id.")
			assert_true(bool(vista.get("_face_down")), "Mini p1 é de costas.")
			assert_eq((vista as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Mini p1 não é clicável.")
			assert_false((vista as Node).has_signal("clicada"), "Sinal clicada removido (D26 parcial, 100% controle).")
			for f in (vista as Node).get_children():
				if f is Label:
					assert_false(segredos.has((f as Label).text), "Texto não vaza id/nome do rival.")
	assert_eq(minis, n1, "Qtd de minis = cartas do rival (só contagem).")
	camada.free()
	mesa.free()


func test_pos_mao_centraliza_soma_simetrica() -> void:
	# _pos_mao real: centro médio = cx da arena, pares somam 2*cx.
	var arena: Dictionary = BoardLayoutScript.load_arena_data(BoardLayoutScript.starter_arena_path())
	var mesa = TableScript.new()
	mesa._arena_data = arena
	for lado in [0, 1]:
		var h: Dictionary = BoardLayoutScript.get_hand(arena, lado)
		var cx := float(h.get("x", 1240.0))
		var larg := CardViewScript.TAM.x
		if lado == 1:
			larg *= 0.55
		for n in [1, 2, 3, 5, 7]:
			var centros: Array = []
			for i in range(n):
				var p: Vector2 = mesa._pos_mao(i, n, lado)
				centros.append(p.x + larg / 2.0)
			var media := 0.0
			for c in centros:
				media += float(c)
			media /= float(n)
			assert_almost_eq(media, cx, 0.05, "lado %d n=%d: centro médio = cx." % [lado, n])
			for i in range(n):
				var soma: float = float(centros[i]) + float(centros[n - 1 - i])
				assert_almost_eq(soma, 2.0 * cx, 0.05, "lado %d n=%d i=%d: soma simétrica = 2*cx." % [lado, n, i])
			if n == 1:
				assert_almost_eq(float(centros[0]), cx, 0.05, "lado %d: carta única centraliza no cx." % lado)
			# Fileira não cobre os slots: p0 embaixo (y>=900), p1 no topo (y<=120).
			for i in range(n):
				var py: float = (mesa._pos_mao(i, n, lado) as Vector2).y
				if lado == 0:
					assert_true(py >= 900.0, "p0 carta %d/%d fica embaixo (y=%.0f)." % [i, n, py])
				else:
					assert_true(py <= 120.0, "p1 carta %d/%d fica no topo (y=%.0f)." % [i, n, py])
	mesa.free()


func test_animacao_recriar_mesa_2x_sem_erro() -> void:
	# Cena real 2x: tween preso à carta morre no free, recriar não quebra.
	for k in [1, 2]:
		var mesa: Node = MesaScene.instantiate()
		add_child_autofree(mesa)
		await wait_process_frames(4)
		assert_true(is_instance_valid(mesa), "Mesa %d válida após instanciar." % k)
		var st: Variant = mesa.get("_st")
		assert_true(st != null, "Mesa %d tem estado real (duelo montado)." % k)
		var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
		var n1: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
		var camada: Node = mesa.get("_camada_mao")
		assert_eq(camada.get_child_count(), n0 + n1, "Mesa %d desenha p0+p1 com animação." % k)
		mesa.call("_atualizar", true)
		await wait_process_frames(6)
		assert_eq((mesa.get("_camada_mao") as Node).get_child_count(), n0 + n1, "Mesa %d recriada com efeito mantém contagem." % k)
		mesa.queue_free()
		await wait_process_frames(2)
	assert_true(true, "2 mesas criadas/liberadas sem erro (tween preso à carta).")
