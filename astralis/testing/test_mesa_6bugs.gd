extends GutTest

## test_mesa_6bugs — GUT permanente dos 6 bugs da mesa (runtime, só duel_table.gd).
## Trava o que o runtime corrigiu em 2026-09-24 (só controle/desenho, sem regra nova):
## (1) face_down=true desce escondida nos 2 lados;
## (2) popup da estrela acima da carta central (menu POR CIMA, cursor no topo);
## (3) navegação alcança as 4 fileiras (20 slots, magia inclusa);
## (4) lado rival: passo p/ direita aumenta o X de tela (por posição, sem espelhar);
## (5) cima no topo e baixo na base não saem dos slots (nunca no LP);
## (6) rival vazio -> menu oferece LP (dano ATK cheio via Battle real) + IA direta.
## Usa a mesa real (duel_table.tscn) + sistemas reais (Duel/Summon/Battle).
## Sem Fake (R2). Sem gamepad físico: Input.action_press só simula o botão;
## quem anda é o método real da mesa. Seed fixa 42 (duel_setup).
## Bug aqui vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
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


func _contar_monstros_na_mao(st, player_idx: int) -> int:
	var n := 0
	for c in ((st.players[player_idx] as Dictionary)["hand"] as Array):
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


func _mesa_nova():
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	return mesa


# Roda o fluxo fiel completo na mesa real via confirmar de verdade:
# carta -> centro (face) -> slot -> estrela -> campo. O botão é só simulado
# (Input.action_press); quem anda é o método real da mesa.
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


func test_bug1_face_baixo_desce_escondida_nos_2_lados() -> void:
	# (1) Invocação com face_down=true desce escondida (de costas) nos 2 lados.
	# Sistema real (Summon) + desenho real (_desenhar_campo via _atualizar).
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	var duel = mesa.get("_duel")
	_garantir_monstros_na_mao(st, 0, 1)
	var idx0: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx0 >= 0, "Preparo: mão p0 tem monstro.")
	var r0: Dictionary = SummonSystem.normal_summon(st, 0, idx0, 1, true, "ATK", "Sol")
	assert_true(bool(r0.get("ok", false)), "Preparo: p0 invoca virado p/ baixo via Summon real.")
	var inst0: Dictionary = (st.players[0] as Dictionary)["monster"][1] as Dictionary
	assert_true(bool(inst0.get("face_down", false)), "Instância p0 guarda face_down=true.")
	assert_eq(str(inst0.get("position", "")), "ATK", "Virada desce em Ataque (vertical, sem regra nova).")
	mesa.call("_atualizar")
	await wait_process_frames(2)
	var camada: Node = mesa.get("_camada_campo")
	assert_eq(camada.get_child_count(), 1, "Campo desenha 1 carta (p0).")
	var v0: Node = camada.get_child(0)
	assert_true(bool(v0.get("_face_down")), "p0 face_down desce escondida (de costas).")
	for f in v0.get_children():
		if f is Control:
			assert_false((f as Control).visible, "p0 virada: dado escondido (filhos invisíveis).")
	# Avança ao MAIN do rival (MAIN->BATTLE->END->DRAW->MAIN, reseta 1 summon).
	var guard := 0
	while (int(st.current_player) != 1 or String(st.phase) != "MAIN") and guard < 10:
		duel.advance_phase()
		guard += 1
	assert_eq(int(st.current_player), 1, "Preparo: vez do rival.")
	assert_eq(String(st.phase), "MAIN", "Preparo: rival está na MAIN.")
	_garantir_monstros_na_mao(st, 1, 1)
	var idx1: int = _indice_monstro_na_mao(st, 1)
	assert_true(idx1 >= 0, "Preparo: mão p1 tem monstro.")
	var r1: Dictionary = SummonSystem.normal_summon(st, 1, idx1, 2, true, "ATK", "Lua")
	assert_true(bool(r1.get("ok", false)), "Preparo: p1 invoca virado p/ baixo via Summon real.")
	var inst1: Dictionary = (st.players[1] as Dictionary)["monster"][2] as Dictionary
	assert_true(bool(inst1.get("face_down", false)), "Instância p1 guarda face_down=true.")
	mesa.call("_atualizar")
	await wait_process_frames(2)
	assert_eq(camada.get_child_count(), 2, "Campo desenha as 2 cartas (p0+p1).")
	for v in camada.get_children():
		assert_true(bool(v.get("_face_down")), "Os 2 lados descem escondidos (bug 1 travado).")


func test_bug2_popup_estrela_acima_da_carta_central() -> void:
	# (2) Menu da estrela sempre POR CIMA da carta central; cursor no topo.
	# Ordem real de desenho: centro embaixo, popup acima, cursor no topo.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Preparo: carta no centro.")
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Preparo: escolhe o slot.")
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	mesa.set("_pad_col", slot)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Preparo: menu da estrela aberto.")
	var popup: Control = mesa.get("_popup")
	var centro: Node = mesa.get("_vista_centro")
	var cursor: Control = mesa.get("_cursor")
	assert_true(popup.visible, "Menu da estrela visível.")
	assert_true(centro != null and is_instance_valid(centro), "Carta central existe atrás do menu.")
	assert_true(popup.get_index() > (centro as Node).get_index(), "Popup acima da carta central (z/camada).")
	assert_true(cursor.get_index() > popup.get_index(), "Cursor no topo, acima do popup.")
	# O cursor redesenha e mantém a ordem (centro < popup < cursor).
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	mesa.call("_atualizar_cursor")
	assert_true(popup.visible, "Menu segue visível após navegar.")
	assert_true(popup.get_index() > (centro as Node).get_index(), "Ordem mantida: popup acima do centro.")
	assert_true(cursor.get_index() > popup.get_index(), "Ordem mantida: cursor no topo.")


func test_bug3_navegacao_alcanca_4_fileiras_20_slots() -> void:
	# (3) Fase de campo anda SÓ nos 20 slots: 2 monstro + 2 magia (próprias + rival).
	var mesa = await _mesa_nova()
	var fim: Dictionary = _fluxo_completo_ate_campo(mesa, false, 0)
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Preparo: fase de campo.")
	var ordem: Array = TableScript.ORDEM_CAMPO
	assert_eq(ordem.size(), 4, "Campo tem 4 fileiras.")
	assert_eq(ordem, [4, 1, 2, 5], "Ordem visual: magia rival -> monstro rival -> meu monstro -> minha magia.")
	var total := 0
	for f in ordem:
		assert_true(bool(mesa.call("_eh_fileira_campo", int(f))), "Fileira %d é de campo." % int(f))
		var larg: int = int(mesa.call("_pad_largura_fileira", int(f)))
		assert_eq(larg, 5, "Fileira %d tem 5 slots." % int(f))
		total += larg
		var lt: Array = mesa.call("_lado_tipo_de_fileira", int(f))
		assert_eq(lt.size(), 2, "Fileira %d tem lado+tipo." % int(f))
	assert_eq(total, 20, "4 fileiras x 5 = 20 slots (magia inclusa).")
	assert_false(bool(mesa.call("_eh_fileira_campo", TableScript.FILEIRA_RIVAL_LP)), "LP rival não é fileira de campo.")
	assert_false(bool(mesa.call("_eh_fileira_campo", TableScript.FILEIRA_MAO)), "Mão não é fileira de campo.")
	assert_eq((mesa.call("_lado_tipo_de_fileira", 4) as Array), [1, "magia"], "Fileira 4: magia rival.")
	assert_eq((mesa.call("_lado_tipo_de_fileira", 1) as Array), [1, "monstro"], "Fileira 1: monstro rival.")
	assert_eq((mesa.call("_lado_tipo_de_fileira", 2) as Array), [0, "monstro"], "Fileira 2: meu monstro.")
	assert_eq((mesa.call("_lado_tipo_de_fileira", 5) as Array), [0, "magia"], "Fileira 5: minha magia.")
	# Anda de cima a baixo e visita as 4 (botão só simulado, passo real).
	mesa.set("_pad_fileira", int(ordem[0]))
	mesa.set("_pad_col", 2)
	var visitadas: Array = [int(mesa.get("_pad_fileira"))]
	for k in range(3):
		Input.action_press("mover_baixo")
		mesa.call("_pad_mover", 0, 1)
		Input.action_release("mover_baixo")
		visitadas.append(int(mesa.get("_pad_fileira")))
	assert_eq(visitadas, [4, 1, 2, 5], "Baixo visita as 4 fileiras em ordem.")
	for k in range(3):
		Input.action_press("mover_cima")
		mesa.call("_pad_mover", 0, -1)
		Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_pad_fileira")), 4, "Cima 3x volta ao topo (magia rival).")


func test_bug4_rival_direita_aumenta_x_de_tela() -> void:
	# (4) No lado rival (espelho), direita anda p/ direita VISÍVEL (por X de tela).
	# Por índice espelhava: este teste quebra se voltar a andar por índice.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	for f in [TableScript.FILEIRA_RIVAL_CAMPO, TableScript.FILEIRA_RIVAL_MAGIA]:
		var xs := {}
		for i in range(5):
			xs[i] = float((mesa.call("_centro_campo", int(f), i) as Vector2).x)
		var idx_min := 0
		var idx_max := 0
		for i in range(5):
			if float(xs[i]) < float(xs[idx_min]):
				idx_min = i
			if float(xs[i]) > float(xs[idx_max]):
				idx_max = i
		assert_ne(idx_min, idx_max, "Fileira rival %d tem X distintos (espelho).")
		# Passo p/ direita fora da borda: X sempre aumenta.
		for i in range(5):
			if i == idx_max:
				continue
			var viz: int = int(mesa.call("_vizinho_horizontal_por_posicao", int(f), i, 1))
			var x_antes := float(xs[i])
			var x_depois := float((mesa.call("_centro_campo", int(f), viz) as Vector2).x)
			assert_true(x_depois > x_antes, "Rival f=%d col %d: direita aumenta X (%.0f -> %.0f, viz %d)." % [int(f), i, x_antes, x_depois, viz])
		# Na borda direita, direita dá a volta p/ a borda esquerda (único caso que diminui).
		var volta: int = int(mesa.call("_vizinho_horizontal_por_posicao", int(f), idx_max, 1))
		assert_eq(volta, idx_min, "Rival f=%d: na borda direita, direita dá a volta p/ esquerda." % int(f))
		# Passo p/ esquerda fora da borda: X sempre diminui.
		for i in range(5):
			if i == idx_min:
				continue
			var viz2: int = int(mesa.call("_vizinho_horizontal_por_posicao", int(f), i, -1))
			assert_true(float((mesa.call("_centro_campo", int(f), viz2) as Vector2).x) < float(xs[i]), "Rival f=%d col %d: esquerda diminui X." % [int(f), i])
		# Via cursor real (botão simulado): da esquerda visível, 1 direita aumenta X.
		mesa.set("_fase_jogador", TableScript.FASE_CAMPO)
		(mesa.get("_st") as Object).set("current_player", 0)
		mesa.set("_pad_fileira", int(f))
		mesa.set("_pad_col", idx_min)
		var x0 := float((mesa.call("_centro_campo", int(f), idx_min) as Vector2).x)
		Input.action_press("mover_dir")
		mesa.call("_pad_mover", 1, 0)
		Input.action_release("mover_dir")
		var col1: int = int(mesa.get("_pad_col"))
		var x1 := float((mesa.call("_centro_campo", int(f), col1) as Vector2).x)
		assert_true(x1 > x0, "Cursor rival f=%d: 1 direita aumenta X visível (%.0f -> %.0f)." % [int(f), x0, x1])
	# Trocar de campo preserva a COLUNA VISÍVEL (X), não o índice (espelho).
	mesa.set("_pad_fileira", TableScript.FILEIRA_MEU_CAMPO)
	mesa.set("_pad_col", 0)
	var x_meu := float((mesa.call("_centro_campo", TableScript.FILEIRA_MEU_CAMPO, 0) as Vector2).x)
	mesa.call("_pad_ao_trocar", TableScript.FILEIRA_RIVAL_CAMPO)
	var col_rival: int = int(mesa.get("_pad_col"))
	var x_rival := float((mesa.call("_centro_campo", TableScript.FILEIRA_RIVAL_CAMPO, col_rival) as Vector2).x)
	assert_true(absf(x_rival - x_meu) < 200.0, "Troca meu->rival preserva X visível (%.0f -> %.0f, col %d)." % [x_meu, x_rival, col_rival])


func test_bug5_cima_no_topo_e_baixo_na_base_nao_saem_dos_slots() -> void:
	# (5) Na fase de campo, cima no topo e baixo na base não saem dos slots.
	# Nunca fogem p/ o LP (0) nem p/ a mão (3): ficam no campo.
	var mesa = await _mesa_nova()
	_fluxo_completo_ate_campo(mesa, false, 0)
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Preparo: fase de campo.")
	var ordem: Array = TableScript.ORDEM_CAMPO
	var topo: int = int(ordem[0])
	var base: int = int(ordem[ordem.size() - 1])
	# Cima no topo: não sai do lugar.
	mesa.set("_pad_fileira", topo)
	mesa.set("_pad_col", 2)
	Input.action_press("mover_cima")
	mesa.call("_pad_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_pad_fileira")), topo, "Cima no topo não sai do lugar.")
	assert_eq(int(mesa.get("_pad_col")), 2, "Cima no topo não muda a coluna.")
	for k in range(5):
		Input.action_press("mover_cima")
		mesa.call("_pad_mover", 0, -1)
		Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_pad_fileira")), topo, "5x cima no topo: segue no topo.")
	# Baixo na base: não sai do lugar.
	mesa.set("_pad_fileira", base)
	mesa.set("_pad_col", 2)
	Input.action_press("mover_baixo")
	mesa.call("_pad_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_pad_fileira")), base, "Baixo na base não sai do lugar.")
	assert_eq(int(mesa.get("_pad_col")), 2, "Baixo na base não muda a coluna.")
	for k in range(5):
		Input.action_press("mover_baixo")
		mesa.call("_pad_mover", 0, 1)
		Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_pad_fileira")), base, "5x baixo na base: segue na base.")
	# Passeio completo nunca encosta no LP (0) nem na mão (3).
	mesa.set("_pad_fileira", int(ordem[1]))
	mesa.set("_pad_col", 2)
	for k in range(6):
		Input.action_press("mover_cima")
		mesa.call("_pad_mover", 0, -1)
		Input.action_release("mover_cima")
		assert_true((ordem as Array).has(int(mesa.get("_pad_fileira"))), "Cima %d: segue num slot do campo." % k)
		assert_ne(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_RIVAL_LP, "Cima %d: nunca vai ao LP." % k)
		assert_ne(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Cima %d: nunca vai à mão." % k)
	for k in range(6):
		Input.action_press("mover_baixo")
		mesa.call("_pad_mover", 0, 1)
		Input.action_release("mover_baixo")
		assert_true((ordem as Array).has(int(mesa.get("_pad_fileira"))), "Baixo %d: segue num slot do campo." % k)
		assert_ne(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_RIVAL_LP, "Baixo %d: nunca vai ao LP." % k)
		assert_ne(int(mesa.get("_pad_fileira")), TableScript.FILEIRA_MAO, "Baixo %d: nunca vai à mão." % k)


func test_bug6_rival_vazio_menu_LP_dano_ATK_cheio_e_IA_direta() -> void:
	# (6) Rival vazio: menu oferece o LP (direto com ATK cheio, Battle real) + IA direta.
	# Parte A: menu na mesa real. Parte B: IA real ataca direto com campo vazio.
	var mesa = await _mesa_nova()
	var fim: Dictionary = _fluxo_completo_ate_campo(mesa, false, 0)
	var st = mesa.get("_st")
	var slot_atk: int = int(fim["slot"])
	assert_eq(int(mesa.get("_fase_jogador")), TableScript.FASE_CAMPO, "Preparo: fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Preparo: BATTLE da mesa.")
	# Só organiza dado ANTES de escolher: rival sem monstros + turno liberado
	# p/ p0 atacar (turno 1 bloqueia, D17; menu só mostra Atacar se can_attack ok).
	for i in range(5):
		(st.players[1] as Dictionary)["monster"][i] = null
	assert_false(BattleSystem.has_monsters(st, 1), "Preparo: rival sem monstros.")
	st.set("turn_number", 3)
	# Escolhe o atacante (cursor real no próprio campo).
	mesa.set("_pad_fileira", TableScript.FILEIRA_MEU_CAMPO)
	mesa.set("_pad_col", slot_atk)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sel_atk")), slot_atk, "Atacante escolhido no próprio campo.")
	# Mira no campo rival vazio: abre o menu de alvo com o LP.
	mesa.set("_pad_fileira", TableScript.FILEIRA_RIVAL_CAMPO)
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	var popup: Control = mesa.get("_popup")
	assert_true(popup.visible, "Rival vazio: menu de alvo abriu.")
	assert_eq(str(mesa.get("_popup_modo")), "alvo", "Menu está no modo alvo (LP).")
	var b0: Label = (mesa.get("_popup_botoes") as Array)[0]
	assert_true(str(b0.text).contains("LP"), "Menu oferece o LP rival (texto '%s')." % str(b0.text))
	# Magia rival vazia também oferece o direto (mesma regra, sem alvo em magia).
	mesa.set("_pad_popup_idx", 1)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_false(popup.visible, "Cancelar fecha o menu de alvo.")
	mesa.set("_pad_fileira", TableScript.FILEIRA_RIVAL_MAGIA)
	mesa.set("_pad_col", 0)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_true(popup.visible, "Magia rival vazia também oferece o direto.")
	assert_eq(str(mesa.get("_popup_modo")), "alvo", "Magia: menu também é de alvo (LP).")
	mesa.set("_pad_popup_idx", 0)
	var inst_atk: Dictionary = (st.players[0] as Dictionary)["monster"][slot_atk] as Dictionary
	var atk_esperado: int = int(inst_atk.get("atk", 0))
	assert_true(atk_esperado > 0, "Preparo: atacante tem ATK %d." % atk_esperado)
	var lp_antes: int = int((st.players[1] as Dictionary)["lp"])
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_false(popup.visible, "Confirmar o LP fecha o menu.")
	var lp_depois: int = int((st.players[1] as Dictionary)["lp"])
	assert_eq(lp_antes - lp_depois, atk_esperado, "Direto via menu: dano ATK cheio (%d) no Battle real." % atk_esperado)
	# Parte B: IA real ataca direto com seu campo vazio (mesa real, espera o turno dela).
	var mesa2 = await _mesa_nova()
	_fluxo_completo_ate_campo(mesa2, false, 0)
	var st2 = mesa2.get("_st")
	_garantir_monstros_na_mao(st2, 1, 1)
	for i in range(5):
		(st2.players[0] as Dictionary)["monster"][i] = null
		(st2.players[1] as Dictionary)["monster"][i] = null
	assert_false(BattleSystem.has_monsters(st2, 0), "Preparo: seu campo vazio p/ a IA direta.")
	var lp_voce_antes: int = int((st2.players[0] as Dictionary)["lp"])
	Input.action_press("pausar")
	mesa2.call("_no_start_passar_turno")
	Input.action_release("pausar")
	assert_eq(int(st2.current_player), 1, "START passou o turno ao rival (IA joga).")
	await wait_seconds(5.0)
	assert_true(is_instance_valid(mesa2), "Mesa segue válida após o turno da IA.")
	var lp_voce_depois: int = int((st2.players[0] as Dictionary)["lp"])
	assert_true(lp_voce_depois < lp_voce_antes, "IA direta: seu LP caiu (%d -> %d)." % [lp_voce_antes, lp_voce_depois])
	var atk_ia := 0
	for m in ((st2.players[1] as Dictionary)["monster"] as Array):
		if m is Dictionary and not (m as Dictionary).is_empty():
			atk_ia = maxi(atk_ia, int((m as Dictionary).get("atk", 0)))
	assert_true(atk_ia > 0, "Preparo: rival tem atacante (ATK %d)." % atk_ia)
	assert_true(lp_voce_antes - lp_voce_depois >= atk_ia, "IA direta: dano >= ATK cheio do rival (%d)." % atk_ia)
	assert_eq(int(st2.current_player), 0, "IA devolveu sua vez.")
