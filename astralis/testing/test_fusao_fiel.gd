extends "res://testing/astralis_test_base.gd"

## test_fusao_fiel — GUT da mão reta + fusão fiel (runtime, sem Fake R2).
## Trava o que o runtime fez (duel_table.gd + fusion_system.gd):
## A) MÃO RETA: sempre retas (sem leque/rotação), centralizadas; levantada (cima)
##    sobe + escala ~1.15 + vizinhas afastam; selo 1,2,3... renumera sozinho.
## B) FUSÃO FIEL (D24 avulsa mantido): 0=avulsa, 1=bloqueia e avisa, 2+=combina
##    no confirmar; voam ao centro EM ORDEM, par a par (receita ordem livre ->
##    regra tipo+atributo fallback D08 -> equip pendente -> falha descarta a
##    ACUMULADA, novata fica e continua); resultado face p/ cima, zona normal,
##    conta como a jogada. Só controle (Input simula botão, método real anda).
## Usa mesa real (duel_table.tscn) + sistemas reais (Duel/Summon/Fusion).
## Seed fixa 42 (duel_setup). Bug aqui vira teste permanente.
## Helpers (_mesa_nova/_indice_monstro_na_mao) vêm de astralis_test_base.gd.

const FusionSystem := preload("res://duel/fusion_system.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")
const CardViewScript := preload("res://ui/card_view.gd")
# TableScript e MesaScene vêm da base (astralis_test_base.gd) - R8: uma cópia só.


func _fusoes_mini() -> Dictionary:
	# Só organiza dado; a regra testada é a do FusionSystem real.
	return {
		"schema_version": 1,
		"recipes": [
			{"id": "r_ab", "input": {"card_a": "card_a", "card_b": "card_b"}, "result": "card_c"},
		],
		"rules": [
			{"id": "regra_fraca", "when": {"type_a": "dragon"}, "result": "card_d", "priority": 5},
			{"id": "regra_forte", "when": {"type_a": "dragon", "attribute_a": "fire"}, "result": "card_e", "priority": 10},
		],
	}


func _carta(id: String, tipo: String = "monster", mt: String = "dragon", attr: String = "fire", atk: int = 1500) -> Dictionary:
	return {"id": id, "name": id, "card_type": tipo, "monster_type": mt, "attribute": attr, "attack": atk, "defense": 1000}


func test_mao_sempre_reta_sem_leque() -> void:
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	# Giro sempre 0 (sem leque), mesmo com várias cartas.
	for n in [1, 2, 5, 7]:
		for i in range(n):
			assert_almost_eq(float(mesa.call("_giro_mao", i, n)), 0.0, 0.001, "Giro reto i=%d n=%d." % [i, n])
	# Posição sem curva: y = y0 da arena (p0 980, p1 20), x simétrico.
	var arena: Dictionary = mesa.get("_arena_data")
	for lado in [0, 1]:
		var h: Dictionary = BoardLayoutScript.get_hand(arena, lado)
		var y0 := float(h.get("y", 980.0 if lado == 0 else 20.0))
		for n in [1, 3, 5]:
			for i in range(n):
				var p: Vector2 = mesa.call("_pos_mao", i, n, lado)
				assert_almost_eq(p.y, y0, 0.05, "Mão reta lado %d i=%d n=%d: y=y0." % [lado, i, n])
	# Desenho real: todas as vistas da mão com rotação 0.
	var camada: Node = mesa.get("_camada_mao")
	assert_true(camada.get_child_count() > 0, "Mão desenha cartas.")
	for v in camada.get_children():
		assert_almost_eq(float((v as Control).rotation), 0.0, 0.001, "Vista da mão reta (rotação 0).")


func test_levantar_sobe_escala_afasta_e_selo() -> void:
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	assert_true(n >= 3, "Preparo: mão tem %d cartas p/ afastar." % n)
	var meio := n / 2
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", meio)
	# Cima levanta (só controle: simula o botão, quem anda é a mesa real).
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_true((mesa.get("_levantadas") as Array).has(meio), "Cima levantou a carta do cursor.")
	assert_eq(int(mesa.call("_ordem_levantada", meio)), 1, "Selo 1 na ordem em que levantou.")
	# Visual: levantada sobe + escala ~1.15.
	var base: Vector2 = mesa.call("_pos_mao", meio, n, 0)
	var vis: Vector2 = mesa.call("_pos_mao_visual", meio, n)
	assert_almost_eq(vis.y, base.y - TableScript.LEVANTA_DY, 0.5, "Levantada sobe %d px." % int(TableScript.LEVANTA_DY))
	# Vizinhas se afastam p/ dar espaço.
	var esq: Vector2 = mesa.call("_pos_mao_visual", maxi(meio - 1, 0), n)
	var esq_base: Vector2 = mesa.call("_pos_mao", maxi(meio - 1, 0), n, 0)
	var dir: Vector2 = mesa.call("_pos_mao_visual", mini(meio + 1, n - 1), n)
	var dir_base: Vector2 = mesa.call("_pos_mao", mini(meio + 1, n - 1), n, 0)
	if meio - 1 >= 0:
		assert_true(esq.x < esq_base.x - 1.0, "Vizinha da esquerda afasta (%.0f -> %.0f)." % [esq_base.x, esq.x])
	if meio + 1 < n:
		assert_true(dir.x > dir_base.x + 1.0, "Vizinha da direita afasta (%.0f -> %.0f)." % [dir_base.x, dir.x])
	# Desenho: levantada com escala 1.15 + selo "1" no canto.
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var achou_selo := false
	var achou_escala := false
	for v in (mesa.get("_camada_mao") as Node).get_children():
		var sc: Vector2 = (v as Control).scale
		if sc.is_equal_approx(Vector2(TableScript.LEVANTA_ESCALA, TableScript.LEVANTA_ESCALA)):
			achou_escala = true
			for f in (v as Node).get_children():
				if f is Panel:
					for g in (f as Node).get_children():
						if g is Label and str((g as Label).text) == "1":
							achou_selo = true
	assert_true(achou_escala, "Desenho: levantada aumenta (~1.15).")
	assert_true(achou_selo, "Desenho: selo pequeno numerado '1' no canto.")


func test_abaixar_restaura_e_renumera() -> void:
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	assert_true(n >= 3, "Preparo: mão tem %d cartas." % n)
	# Levanta 2 em ordem (0 depois 1).
	mesa.set("_pad_col", 0)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	mesa.set("_pad_col", 1)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq((mesa.get("_levantadas") as Array), [0, 1], "Ordem em que levantou: [0,1].")
	assert_eq(int(mesa.call("_ordem_levantada", 0)), 1, "Selo 1 na primeira.")
	assert_eq(int(mesa.call("_ordem_levantada", 1)), 2, "Selo 2 na segunda.")
	# Baixo abaixa a primeira e renumera sozinho (segunda vira 1).
	mesa.set("_pad_col", 0)
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq((mesa.get("_levantadas") as Array), [1], "Abaixou a 0, restou [1].")
	assert_eq(int(mesa.call("_ordem_levantada", 1)), 1, "Abaixar renumera: antiga 2 vira 1.")
	# Abaixada volta a descer (y da base); x pode seguir afastado pela outra
	# levantada (vizinhas abrem espaço). Restaura tudo ao abaixar as 2.
	var base0: Vector2 = mesa.call("_pos_mao", 0, n, 0)
	var vis0: Vector2 = mesa.call("_pos_mao_visual", 0, n)
	assert_almost_eq(vis0.y, base0.y, 0.5, "Abaixada volta a descer (y da base).")
	assert_eq(int(mesa.call("_ordem_levantada", 0)), 0, "Abaixada sem selo.")
	mesa.set("_pad_col", 1)
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_true((mesa.get("_levantadas") as Array).is_empty(), "Abaixou tudo, sem levantadas.")
	var vis0b: Vector2 = mesa.call("_pos_mao_visual", 0, n)
	assert_true(vis0b.distance_to(base0) < 0.5, "Abaixar restaura tudo (volta à base).")


func test_confirmar_0_avulsa_1_bloqueia() -> void:
	# 0 levantadas = avulsa (fluxo D24 vai ao centro); 1 = bloqueia e avisa.
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	assert_true((mesa.get("_levantadas") as Array).is_empty(), "Preparo: 0 levantadas.")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "0 levantadas: avulsa vai ao centro (D24 mantido).")
	# Volta e levanta 1: confirmar bloqueia e avisa, sem sair da mão.
	mesa.call("_pad_cancelar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_MAO_ESCOLHA, "Preparo: voltou à escolha.")
	mesa.set("_pad_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq((mesa.get("_levantadas") as Array).size(), 1, "Preparo: 1 levantada.")
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_MAO_ESCOLHA, "1 levantada: bloqueia, não sai da mão.")
	assert_true(str((mesa.get("_log") as Array).back()).contains("Só 1"), "1 levantada: avisa (fala '%s')." % str((mesa.get("_log") as Array).back()))


func test_fusion_receita_ordem_nao_importa() -> void:
	var fus: Dictionary = _fusoes_mini()
	var a := _carta("card_a")
	var b := _carta("card_b")
	var r1: Dictionary = FusionSystem.try_fuse_pair(a, b, fus, {})
	assert_true(bool(r1.get("ok", false)), "Receita A+B funde.")
	assert_eq(str(r1.get("tipo", "")), "receita", "Tipo receita.")
	assert_eq(str(r1.get("result_id", "")), "card_c", "Resultado card_c.")
	var r2: Dictionary = FusionSystem.try_fuse_pair(b, a, fus, {})
	assert_true(bool(r2.get("ok", false)), "Receita B+A funde (ordem não importa).")
	assert_eq(str(r2.get("result_id", "")), "card_c", "Ordem inversa dá o mesmo resultado.")


func test_fusion_regra_fallback_prioridade() -> void:
	# Sem receita: regra tipo+atributo por priority (maior vence, D08).
	var fus: Dictionary = _fusoes_mini()
	var drag_fire := _carta("x1", "monster", "dragon", "fire", 1500)
	var planta := _carta("x2", "monster", "plant", "earth", 800)
	var r: Dictionary = FusionSystem.try_fuse_pair(drag_fire, planta, fus, {})
	assert_true(bool(r.get("ok", false)), "Regra casa (dragon+fire).")
	assert_eq(str(r.get("tipo", "")), "regra", "Tipo regra (fallback).")
	assert_eq(str(r.get("result_id", "")), "card_e", "Priority 10 vence (regra forte).")
	# min_atk olha a maior ATK (igual ao Studio).
	var fus2 := {"schema_version": 1, "recipes": [], "rules": [{"id": "r_atk", "when": {"min_atk": 2000}, "result": "card_forte", "priority": 1}]}
	var fraco1 := _carta("f1", "monster", "beast", "earth", 800)
	var fraco2 := _carta("f2", "monster", "beast", "earth", 900)
	var rf: Dictionary = FusionSystem.try_fuse_pair(fraco1, fraco2, fus2, {})
	assert_false(bool(rf.get("ok", false)), "min_atk 2000: 800/900 não casa.")
	var forte := _carta("f3", "monster", "beast", "earth", 2500)
	var rok: Dictionary = FusionSystem.try_fuse_pair(fraco1, forte, fus2, {})
	assert_true(bool(rok.get("ok", false)), "min_atk 2000: maior 2500 casa.")


func test_fusion_equip_pendente_sem_tabela() -> void:
	# Equip (qualquer direção) sem tabela cai no fracasso e só reporta.
	var fus: Dictionary = _fusoes_mini()
	var mon := _carta("m1")
	var eq := _carta("e1", "equip", "", "", 0)
	var r1: Dictionary = FusionSystem.try_fuse_pair(mon, eq, fus, {})
	assert_false(bool(r1.get("ok", false)), "Monstro+equip não funde (sem tabela).")
	assert_eq(str(r1.get("tipo", "")), "equip_pendente", "Tipo equip_pendente.")
	assert_true(str(r1.get("mensagem", "")).contains("Equip"), "Reporta equip (msg '%s')." % str(r1.get("mensagem", "")))
	var r2: Dictionary = FusionSystem.try_fuse_pair(eq, mon, fus, {})
	assert_eq(str(r2.get("tipo", "")), "equip_pendente", "Qualquer direção é equip.")


func test_fusion_cadeia_descarta_acumulada() -> void:
	# Cadeia EM ORDEM: A+B=C (sucesso), C+D falha -> descarta C, D fica e continua.
	var fus: Dictionary = _fusoes_mini()
	var cards := {"card_c": _carta("card_c", "monster", "plant", "earth", 1800)}
	var a := _carta("card_a")
	var b := _carta("card_b")
	var d := _carta("card_z", "monster", "zombie", "dark", 500)
	var cadeia: Dictionary = FusionSystem.resolve_chain([a, b, d], fus, cards)
	assert_true(bool(cadeia.get("ok", false)), "Cadeia resolve.")
	var passos: Array = cadeia.get("passos", []) as Array
	assert_eq(passos.size(), 2, "2 passos par a par.")
	assert_eq(str((passos[0] as Dictionary).get("tipo", "")), "receita", "1º passo: receita A+B=C.")
	assert_eq(str((passos[0] as Dictionary).get("result_id", "")), "card_c", "1º resultado C.")
	assert_false(str((passos[1] as Dictionary).get("tipo", "")) == "receita", "2º passo: C+D falha.")
	assert_eq((cadeia.get("descartes", []) as Array), ["card_c"], "Fracasso descarta a ACUMULADA (C cai).")
	assert_eq(str(cadeia.get("final_id", "")), "card_z", "Novata D fica e é o final.")


func test_mesa_fusao_desce_face_cima_conta_jogada() -> void:
	# Mesa real com receita FM de verdade: fm_0002+fm_0008=fm_0638.
	# Fluxo novo: 2+ levantadas no confirmar -> ESCOLHE O SLOT PRIMEIRO
	# (vazio ou ocupado) -> fila ao centro EM ORDEM -> FINAL + menu da estrela
	# -> desce face p/ cima em Ataque.
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	assert_true(cartas.has("fm_0002") and cartas.has("fm_0008"), "Preparo: FM tem fm_0002/fm_0008.")
	assert_true(cartas.has("fm_0638"), "Preparo: FM tem resultado fm_0638.")
	# Só organiza dado: garante o par exato no fim da mão (ordem de levantar).
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0002"] as Dictionary).duplicate(true))
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0008"] as Dictionary).duplicate(true))
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var i_a := n - 2
	var i_b := n - 1
	var mao_antes := n
	mesa.call("_atualizar")
	# Levanta EM ORDEM (A depois B) só no controle.
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", i_a)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	mesa.set("_pad_col", i_b)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq((mesa.get("_levantadas") as Array), [i_a, i_b], "Preparo: 2 levantadas EM ORDEM.")
	# Confirmar: escolhe o SLOT primeiro (não desce direto).
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Fusão: confirmar pede o slot primeiro.")
	assert_true(bool(mesa.get("_combinando")), "Fusão: marca combinando no slot.")
	assert_true(str((mesa.get("_log") as Array).back()).contains("slots") or str((mesa.get("_log") as Array).back()).contains("Slot"), "Fusão: mostra slots (fala '%s')." % str((mesa.get("_log") as Array).back()))
	# Escolhe o slot 0 vazio -> fila + FINAL + menu da estrela.
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(6)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Fusão: fila pronta, abre o menu da estrela (igual ao da avulsa).")
	assert_false((mesa.get("_fusao_final") as Dictionary).is_empty(), "Fusão: FINAL calculado antes da estrela.")
	# Estrela no fim da combinação (menu igual ao da avulsa).
	mesa.set("_pad_popup_idx", 0)
	var estrela_fusao: String = str((mesa.get("_estrela_ops") as Array)[0])
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(4)
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Fusão: entra na fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Fusão: MAIN -> BATTLE (conta como a jogada).")
	assert_true(bool(st.normal_summon_used), "Fusão conta como a jogada do turno.")
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	var achou := false
	for m in zona:
		if m is Dictionary and str((m as Dictionary).get("card_id", "")) == "fm_0638":
			achou = true
			assert_false(bool((m as Dictionary).get("face_down", true)), "Resultado sempre face p/ cima.")
			assert_eq(str((m as Dictionary).get("position", "")), "ATK", "Resultado em Ataque.")
			assert_eq(str((m as Dictionary).get("guardian_star", "")), estrela_fusao, "Estrela do menu gravada no resultado.")
	assert_true(achou, "Resultado fm_0638 desceu à zona (fluxo normal).")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes - 2, "2 levantadas saíram da mão.")
	assert_true((mesa.get("_levantadas") as Array).is_empty(), "Levantadas limpam após fundir.")


func test_cancelar_abaixa_ultima_e_renumera() -> void:
	# Cancelar abaixa a ÚLTIMA levantada e renumera sozinho (mesa real, só controle).
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	assert_true(n >= 3, "Preparo: mão tem %d cartas." % n)
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	for col in [0, 1, 2]:
		mesa.set("_pad_col", col)
		Input.action_press("mover_cima")
		mesa.call("_pad_mover", 0, -1)
		Input.action_release("mover_cima")
	assert_eq((mesa.get("_levantadas") as Array), [0, 1, 2], "Preparo: 3 levantadas em ordem.")
	assert_eq(int(mesa.call("_ordem_levantada", 2)), 3, "Selo 3 na última.")
	# Cancelar abaixa a última (2) e renumera o resto.
	mesa.call("_pad_cancelar")
	assert_eq((mesa.get("_levantadas") as Array), [0, 1], "Cancelar abaixou a última, restou [0,1].")
	assert_eq(int(mesa.call("_ordem_levantada", 0)), 1, "Renumera: 0 vira selo 1.")
	assert_eq(int(mesa.call("_ordem_levantada", 1)), 2, "Renumera: 1 vira selo 2.")
	assert_eq(int(mesa.call("_ordem_levantada", 2)), 0, "Abaixada sem selo.")
	mesa.call("_pad_cancelar")
	assert_eq((mesa.get("_levantadas") as Array), [0], "Cancelar de novo abaixa a última, restou [0].")
	assert_eq(int(mesa.call("_ordem_levantada", 0)), 1, "Última restante vira selo 1.")


func test_mao_centrada_no_cx_sem_rotacao() -> void:
	# Mão centrada: média dos centros = cx da arena, nos 2 lados, sem rotação.
	var mesa = await _mesa_nova()
	var arena: Dictionary = mesa.get("_arena_data")
	for lado in [0, 1]:
		var h: Dictionary = BoardLayoutScript.get_hand(arena, lado)
		var cx := float(h.get("x", 1240.0))
		var larg := CardViewScript.TAM.x
		if lado == 1:
			larg *= TableScript.ESCALA_MAO_P1
		for n in [1, 3, 5, 7]:
			var soma := 0.0
			for i in range(n):
				var p: Vector2 = mesa.call("_pos_mao", i, n, lado)
				assert_almost_eq(float(mesa.call("_giro_mao", i, n)), 0.0, 0.001, "Giro 0 lado %d n=%d." % [lado, n])
				soma += p.x + larg / 2.0
			var centro := soma / float(n)
			assert_almost_eq(centro, cx, 0.5, "Mão centrada lado %d n=%d (centro %.0f = cx %.0f)." % [lado, n, centro, cx])
	# Desenho real: mão dos 2 lados (p0 aberta + p1 costas) toda com rotação 0.
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var camada: Node = mesa.get("_camada_mao")
	assert_true(camada.get_child_count() > 0, "Mão desenha cartas dos 2 lados.")
	for v in camada.get_children():
		assert_almost_eq(float((v as Control).rotation), 0.0, 0.001, "Vista reta dos 2 lados (rotação 0).")


func test_1_levantada_bloqueia_e_preserva() -> void:
	# 1 levantada bloqueia no confirmar, avisa e PRESERVA a levantada (mesa real).
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	var alvo: int = _indice_monstro_na_mao(st, 0)
	assert_eq((mesa.get("_levantadas") as Array), [alvo], "Preparo: 1 levantada.")
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_MAO_ESCOLHA, "1 levantada: bloqueia, não sai da mão.")
	assert_eq((mesa.get("_levantadas") as Array), [alvo], "1 levantada: preserva p/ levantar +1 ou abaixar.")
	assert_eq(int(mesa.call("_ordem_levantada", alvo)), 1, "1 levantada: selo 1 mantido.")
	assert_eq(String(st.phase), "MAIN", "1 levantada: não conta como jogada (segue na MAIN).")
	assert_false(bool(st.normal_summon_used), "1 levantada: não gasta a jogada.")


func test_cadeia_falha_cemiterio_novata_desce() -> void:
	# Cadeia com FALHA via sistema real: fundida cai ao cemitério, novata desce
	# face p/ cima em ATK e conta como jogada. Equip no meio também descarta.
	var fus_vazia := {"schema_version": 1, "recipes": [], "rules": []}
	var a := _carta("id_a", "monster", "dragon", "fire", 1500)
	var b := _carta("id_b", "monster", "zombie", "dark", 500)
	var cadeia: Dictionary = FusionSystem.resolve_chain([a, b], fus_vazia, {})
	assert_true(bool(cadeia.get("ok", false)), "Cadeia com falha resolve.")
	assert_eq((cadeia.get("descartes", []) as Array), ["id_a"], "Fundida A cai (descartes).")
	assert_eq(str(cadeia.get("final_id", "")), "id_b", "Novata B fica e é o final.")
	# Equip no meio: cada falha descarta a acumulada, novata sempre continua.
	var mon := _carta("m1")
	var eq := _carta("e1", "equip", "", "", 0)
	var mon2 := _carta("m2", "monster", "beast", "earth", 800)
	var cadeia_eq: Dictionary = FusionSystem.resolve_chain([mon, eq, mon2], _fusoes_mini(), {})
	var passos_eq: Array = cadeia_eq.get("passos", []) as Array
	assert_eq(passos_eq.size(), 2, "2 passos com equip no meio.")
	assert_eq(str((passos_eq[0] as Dictionary).get("tipo", "")), "equip_pendente", "1º passo: equip pendente.")
	assert_eq((cadeia_eq.get("descartes", []) as Array), ["m1", "e1"], "Falhas descartam acumulada em ordem.")
	assert_eq(str(cadeia_eq.get("final_id", "")), "m2", "Última novata fica e é o final.")
	# Mesa real: falha desce a novata face p/ cima em ATK, descarte ao cemitério.
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	mao.append(a.duplicate(true))
	mao.append(b.duplicate(true))
	var n: int = mao.size()
	var ordem := [n - 2, n - 1]
	var cem_antes: int = ((st.players[0] as Dictionary)["graveyard"] as Array).size()
	var r: Dictionary = FusionSystem.perform_fusion_summon(st, 0, ordem, 0, fus_vazia, {})
	assert_true(bool(r.get("ok", false)), "Mesa: falha ainda desce a novata.")
	assert_eq((r.get("descartes", []) as Array), ["id_a"], "Mesa: fundida ao cemitério.")
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	assert_true(zona[0] is Dictionary, "Mesa: novata desceu ao slot 0.")
	assert_eq(str((zona[0] as Dictionary).get("card_id", "")), "id_b", "Mesa: novata B no slot.")
	assert_false(bool((zona[0] as Dictionary).get("face_down", true)), "Mesa: falha desce face p/ cima.")
	assert_eq(str((zona[0] as Dictionary).get("position", "")), "ATK", "Mesa: falha desce em Ataque.")
	assert_eq(str((zona[0] as Dictionary).get("battle_position", "")), "ATK", "Mesa: battle_position ATK.")
	assert_true(bool(st.normal_summon_used), "Mesa: falha conta como a jogada.")
	assert_eq(((st.players[0] as Dictionary)["graveyard"] as Array).size(), cem_antes + 1, "Mesa: 1 descarte ao cemitério.")
	assert_true(((st.players[0] as Dictionary)["graveyard"] as Array).has("id_a"), "Mesa: fundida id_a no cemitério.")


## ---- SLOT OCUPADO (runtime liberou avulsa + combinação) ----
## Regra travada (só controle na mesa, par-a-par no FusionSystem real):
## avulsa em ocupado tenta fusão campo+mão (funde = resultado no slot,
## falha = campo descartado e a da mão desce COM a face); combinação em
## ocupado: a FINAL tenta fusão com o campo (funde ou desce), sempre
## face-up em ATK com a estrela do menu gravada.

func _indice_id_na_mao(st, card_id: String) -> int:
	var mao: Array = (st.players[0] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("id", "")) == card_id:
			return i
	return -1


func _ocupar_slot_com(st, mesa, slot: int, card_id: String) -> void:
	# GIVEN de teste (doc 10): prepara estado, quem resolve é o sistema real.
	var cartas: Dictionary = mesa.get("_cartas")
	assert_true(cartas.has(card_id), "Preparo: dado tem %s." % card_id)
	var base := (cartas[card_id] as Dictionary).duplicate(true)
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	zona[slot] = {"card_id": card_id, "nome": str(base.get("name", card_id)), "atk": clampi(int(base.get("attack", 0)), 0, 9999), "def": clampi(int(base.get("defense", 0)), 0, 9999), "position": "ATK", "battle_position": "ATK", "face_down": false, "guardian_star": str(base.get("guardian_star_1", "")), "has_attacked": false}
	mesa.call("_atualizar")


func _achar_par_que_falha(cartas: Dictionary, fusions: Dictionary, id_campo: String, candidatos: Array) -> String:
	# Procura ordem fixa (determinístico): 1º par sem receita no sistema real.
	var base_campo := (cartas[id_campo] as Dictionary).duplicate(true)
	for cid in candidatos:
		var c := str(cid)
		if not cartas.has(c):
			continue
		var t: Dictionary = FusionSystem.try_fuse_pair(base_campo, (cartas[c] as Dictionary).duplicate(true), fusions, cartas)
		if not bool(t.get("ok", false)):
			return c
	return ""


func test_avulsa_ocupado_que_funde_resultado_no_slot() -> void:
	# (1) Avulsa em ocupado que FUNDE: encontro campo+mão via FusionSystem
	# real, resultado fm_0638 desce ao slot (mesa real, sem Fake).
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	var fusions: Dictionary = mesa.get("_fusions_data")
	var t: Dictionary = FusionSystem.try_fuse_pair((cartas["fm_0002"] as Dictionary).duplicate(true), (cartas["fm_0008"] as Dictionary).duplicate(true), fusions, cartas)
	assert_true(bool(t.get("ok", false)), "Preparo: fm_0002+fm_0008 funde no sistema real.")
	assert_eq(str(t.get("result_id", "")), "fm_0638", "Preparo: resultado fm_0638.")
	_ocupar_slot_com(st, mesa, 0, "fm_0002")
	var cem_antes: int = ((st.players[0] as Dictionary)["graveyard"] as Array).size()
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0008"] as Dictionary).duplicate(true))
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var idx := _indice_id_na_mao(st, "fm_0008")
	assert_true(idx >= 0, "Preparo: fm_0008 na mão.")
	mesa.call("_atualizar")
	# Fluxo avulsa só no controle: carta -> centro -> face -> slot -> estrela.
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", idx)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Avulsa: carta foi ao centro.")
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Avulsa: face travada, pede o slot.")
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Avulsa em ocupado: abre o menu da estrela.")
	assert_false(bool(mesa.get("_combinando")), "Avulsa: não marca combinando.")
	assert_true(str((mesa.get("_log") as Array).back()).contains("fus"), "Avulsa em ocupado: avisa o encontro (fala '%s')." % str((mesa.get("_log") as Array).back()))
	var estrela: String = str((mesa.get("_estrela_ops") as Array)[0])
	mesa.set("_pad_popup_idx", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(4)
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Avulsa: entra na fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Avulsa: MAIN -> BATTLE (conta como a jogada).")
	assert_true(bool(st.normal_summon_used), "Avulsa em ocupado conta como a jogada.")
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	assert_true(zona[0] is Dictionary, "Slot 0 tem carta.")
	assert_eq(str((zona[0] as Dictionary).get("card_id", "")), "fm_0638", "Encontro fundiu: resultado fm_0638 no slot.")
	assert_eq(str((zona[0] as Dictionary).get("position", "")), "ATK", "Resultado em Ataque.")
	assert_false(bool((zona[0] as Dictionary).get("face_down", true)), "Resultado desce com a face escolhida (p/ cima).")
	assert_eq(str((zona[0] as Dictionary).get("guardian_star", "")), estrela, "Estrela do menu gravada na instância.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), n - 1, "1 carta saiu da mão.")
	assert_eq(((st.players[0] as Dictionary)["graveyard"] as Array).size(), cem_antes, "Fundiu: nada ao cemitério.")
	assert_false(((st.players[0] as Dictionary)["graveyard"] as Array).has("fm_0002"), "Campo fundido não é descartado.")


func test_avulsa_ocupado_que_falha_descarta_campo_e_desce_com_face() -> void:
	# (2) Avulsa em ocupado que FALHA: campo descartado ao cemitério e a da
	# mão desce ao slot COM a face escolhida (mesa real, sem Fake).
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	var fusions: Dictionary = mesa.get("_fusions_data")
	_ocupar_slot_com(st, mesa, 0, "fm_0002")
	var mao_id := _achar_par_que_falha(cartas, fusions, "fm_0002", ["fm_0001", "fm_0003", "fm_0004", "fm_0005", "fm_0006", "fm_0007", "fm_0009", "fm_0010"])
	assert_false(mao_id.is_empty(), "Preparo: par que falha com fm_0002 no sistema real.")
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas[mao_id] as Dictionary).duplicate(true))
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var idx := _indice_id_na_mao(st, mao_id)
	assert_true(idx >= 0, "Preparo: %s na mão." % mao_id)
	var cem_antes: int = ((st.players[0] as Dictionary)["graveyard"] as Array).size()
	mesa.call("_atualizar")
	# Fluxo avulsa com face P/ BAIXO (esq/dir no centro alterna, só controle).
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", idx)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Avulsa: carta foi ao centro.")
	Input.action_press("mover_esq")
	mesa.call("_pad_mover", -1, 0)
	Input.action_release("mover_esq")
	assert_true(bool(mesa.get("_face_baixo")), "Face p/ baixo escolhida no centro.")
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Avulsa: face travada, pede o slot.")
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Avulsa em ocupado: abre o menu da estrela.")
	var estrela: String = str((mesa.get("_estrela_ops") as Array)[0])
	mesa.set("_pad_popup_idx", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(4)
	assert_eq(String(st.phase), "BATTLE", "Avulsa: MAIN -> BATTLE (conta como a jogada).")
	assert_true(bool(st.normal_summon_used), "Avulsa em ocupado conta como a jogada.")
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	assert_true(zona[0] is Dictionary, "Slot 0 tem carta.")
	assert_eq(str((zona[0] as Dictionary).get("card_id", "")), mao_id, "Falhou: a da mão desce ao slot.")
	assert_true(bool((zona[0] as Dictionary).get("face_down", false)), "Falhou: desce COM a face escolhida (p/ baixo).")
	assert_eq(str((zona[0] as Dictionary).get("position", "")), "ATK", "Falhou: desce em Ataque.")
	assert_eq(str((zona[0] as Dictionary).get("guardian_star", "")), estrela, "Estrela do menu gravada na instância.")
	assert_true(((st.players[0] as Dictionary)["graveyard"] as Array).has("fm_0002"), "Falhou: campo fm_0002 descartado ao cemitério.")
	assert_eq(((st.players[0] as Dictionary)["graveyard"] as Array).size(), cem_antes + 1, "Falhou: 1 descarte ao cemitério.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), n - 1, "1 carta saiu da mão.")
	assert_true(str((mesa.get("_log") as Array).back()).contains("Ataque"), "Avulsa: confirma a descida (fala '%s')." % str((mesa.get("_log") as Array).back()))


func test_combinacao_ocupado_final_funde_ou_desce_com_estrela() -> void:
	# (3) Combinação em ocupado: a FINAL encontra o campo via FusionSystem
	# real (funde = resultado no slot; falha = campo descartado e FINAL
	# desce), sempre face-up em ATK com a estrela do menu gravada.
	var mesa = await _mesa_nova()
	var st = mesa.get("_st")
	var cartas: Dictionary = mesa.get("_cartas")
	var fusions: Dictionary = mesa.get("_fusions_data")
	# Precondição no sistema real: fm_0002+fm_0008 -> FINAL fm_0638.
	var cadeia: Dictionary = FusionSystem.resolve_chain([(cartas["fm_0002"] as Dictionary).duplicate(true), (cartas["fm_0008"] as Dictionary).duplicate(true)], fusions, cartas)
	assert_true(bool(cadeia.get("ok", false)), "Preparo: cadeia resolve no sistema real.")
	assert_eq(str(cadeia.get("final_id", "")), "fm_0638", "Preparo: FINAL fm_0638.")
	# Ocupa o slot 0; o esperado (funde ou desce) vem do sistema real,
	# igual ao encontro que a mesa vai tentar.
	assert_true(cartas.has("fm_0001"), "Preparo: dado tem fm_0001.")
	_ocupar_slot_com(st, mesa, 0, "fm_0001")
	var cem_antes: int = ((st.players[0] as Dictionary)["graveyard"] as Array).size()
	var campo_full: Dictionary = mesa.call("_carta_completa_do_campo", (st.players[0] as Dictionary)["monster"][0])
	var final_prev: Dictionary = (cadeia.get("final_card", {}) as Dictionary).duplicate(true)
	final_prev["id"] = str(cadeia.get("final_id", ""))
	var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, final_prev, fusions, cartas)
	var esperado := "fm_0638"
	var funde := false
	if bool(tent.get("ok", false)):
		var rid := str(tent.get("result_id", ""))
		var real: Dictionary = (cartas.get(rid, {}) as Dictionary) if cartas.has(rid) else {}
		if str(real.get("card_type", "monster")) == "monster":
			esperado = rid
			funde = true
	# Levanta o par EM ORDEM só no controle.
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0002"] as Dictionary).duplicate(true))
	((st.players[0] as Dictionary)["hand"] as Array).append((cartas["fm_0008"] as Dictionary).duplicate(true))
	var n: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var i_a := n - 2
	var i_b := n - 1
	mesa.call("_atualizar")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", i_a)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	mesa.set("_pad_col", i_b)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq((mesa.get("_levantadas") as Array), [i_a, i_b], "Preparo: 2 levantadas EM ORDEM.")
	# Confirmar pede o SLOT primeiro (vazio ou ocupado).
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Fusão: confirmar pede o slot primeiro.")
	assert_true(bool(mesa.get("_combinando")), "Fusão: marca combinando no slot.")
	# Escolhe o slot 0 OCUPADO -> fila + FINAL + menu da estrela.
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(6)
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Fusão em ocupado: abre o menu da estrela.")
	assert_eq(str((mesa.get("_fusao_final") as Dictionary).get("id", "")), "fm_0638", "Fusão: FINAL fm_0638 antes da estrela.")
	var estrela: String = str((mesa.get("_estrela_ops") as Array)[0])
	mesa.set("_pad_popup_idx", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(4)
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Fusão: entra na fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Fusão: MAIN -> BATTLE (conta como a jogada).")
	assert_true(bool(st.normal_summon_used), "Fusão em ocupado conta como a jogada.")
	var zona: Array = (st.players[0] as Dictionary)["monster"]
	assert_true(zona[0] is Dictionary, "Slot 0 tem carta.")
	assert_eq(str((zona[0] as Dictionary).get("card_id", "")), esperado, "Encontro em ocupado: sistema real diz '%s' (funde=%s)." % [esperado, str(funde)])
	assert_false(bool((zona[0] as Dictionary).get("face_down", true)), "FINAL sempre face p/ cima.")
	assert_eq(str((zona[0] as Dictionary).get("position", "")), "ATK", "FINAL em Ataque.")
	assert_eq(str((zona[0] as Dictionary).get("guardian_star", "")), estrela, "Estrela do menu gravada na instância.")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), n - 2, "2 levantadas saíram da mão.")
	if funde:
		assert_false(((st.players[0] as Dictionary)["graveyard"] as Array).has("fm_0001"), "Fundiu com campo: nada descartado.")
	else:
		assert_true(((st.players[0] as Dictionary)["graveyard"] as Array).has("fm_0001"), "Não fundiu: campo fm_0001 descartado ao cemitério.")
	assert_eq(((st.players[0] as Dictionary)["graveyard"] as Array).size(), cem_antes + (0 if funde else 1), "Cemitério bate com o encontro real.")
