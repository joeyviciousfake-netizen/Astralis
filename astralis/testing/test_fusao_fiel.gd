extends GutTest

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

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const FusionSystem := preload("res://duel/fusion_system.gd")
const TableScript := preload("res://ui/duel_table.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")
const CardViewScript := preload("res://ui/card_view.gd")
const MesaScene := preload("res://ui/duel_table.tscn")


func _mesa_nova():
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	return mesa


func _indice_monstro_na_mao(st, player_idx: int) -> int:
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			return i
	return -1


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
	# 2+ levantadas no confirmar voam ao centro EM ORDEM e descem face p/ cima.
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
	# Confirmar combina (sem SCRIPT ERROR headless).
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	await wait_process_frames(6)
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
	assert_true(achou, "Resultado fm_0638 desceu à zona (fluxo normal).")
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), mao_antes - 2, "2 levantadas saíram da mão.")
	assert_true((mesa.get("_levantadas") as Array).is_empty(), "Levantadas limpam após fundir.")
