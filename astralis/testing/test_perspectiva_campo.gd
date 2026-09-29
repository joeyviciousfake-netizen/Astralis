extends "res://testing/astralis_test_base.gd"

## test_perspectiva_campo — a CAMADA DE PERSPECTIVA do doc 16 / D46.
##
## A tela do duelo é a perspectiva de QUEM ESTA JOGANDO. NADA GIRA: nem a
## câmera (D41), nem o campo, nem o céu. O que muda é PARA ONDE cada carta é
## desenhada, e quem decide isso é UMA função só, `_vis`.
##
## ESTE ARQUIVO CRESCEU COM CADA ETAPA do doc 16 §16.6:
##   ETAPA 1 (FEITA) — a camada existe, todo o desenho passa por ela, e a
##                      perspectiva fica travada no jogador 0: a tela sai
##                      IDÊNTICA (foto comparada pixel a pixel).
##   ETAPA 2 (FEITA) — a perspectiva segue `current_player`: a carta ESMAECE
##                      onde está e aparece esmaecendo do lado e da coluna
##                      opostos, a de cima vira 180°, e o painel esquerdo na
##                      vez do rival mostra a imagem padronizada (D46b).
##   ETAPA 3 — as mãos (a de baixo é a de quem joga, a de cima sempre virada).
##
## O QUE ESTE ARQUIVO TRAVA:
## (1) `_vis` segue o turno: identidade na vez do jogador 0, mesa virada na
##     vez do rival, e a volta desfaz exatamente;
## (2) a carta desenhada está EXATAMENTE onde `_vis` mandou, e o giro de 180°
##     segue o LADO VISUAL (D6), não o lado do dado;
## (3) o ESTADO NÃO SE MOVE: a mesma carta continua no mesmo índice do
##     `GameState` depois de redesenhar e depois da troca (a troca é só desenho);
## (4) andar pela posição visível (direita = direita na tela) continua certo
##     nos DOIS lados, porque o vizinho passa pela mesma função que desenha;
## (5) a faixa do meio e as placas de nome NÃO espelham (D8);
## (6) a TROCA manda a carta para o outro lado, espelha a coluna, vira a de
##     cima de cabeça para baixo, e a volta é reversível;
## (7) a troca não deixa carta fantasma pendurada nem material transparente;
## (8) D46b: na vez do rival o painel esquerdo fica sem nenhum dado da carta e
##     mostra a imagem padronizada.
##
## Sem Fake (R2): a cena 3D real + o GameState real do DuelManager. Nada
## aqui duplica regra — o teste só pergunta ao desenho da mesa.

const Mesa3DScene := preload("res://duel3d/mesa_3d.tscn")

## Onde as cartas desenhadas ficam (mesmo caminho que o jogo usa).
const CARTAS := "Camada3D/JanelaCampo/Viewport3D/Cartas"
## Colunas do campo (5 slots por fileira, D15/D17).
const COLUNAS := 5


func _mesa3d_nova() -> Node:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


## A carta desenhada de um slot do DADO (lado, i), pelo meta `slot_id` (que é
## o ID do DADO, nunca o da tela — a troca de perspectiva é só desenho).
func _carta_do_campo(mesa: Node, lado: int, tipo: String, i: int) -> Node3D:
	var cartas: Node = mesa.get_node(CARTAS)
	var letra := "m" if tipo == "monstro" else "s"
	var alvo := "p%d_%s%d" % [lado, letra, i]
	for f in cartas.get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == alvo:
			return f as Node3D
	return null


## A carta desenhada NO LADrilho VISUAL (lado_visual, coluna_visual). O
## `slot_id` que a carta carrega é sempre do DADO (é a identidade dela), então
## para a perspectiva do rival o caminho é o contrário: procuramos pelo LUGAR
## onde ela está na tela.
func _carta_por_slot_visual(mesa: Node, lado_visual: int, tipo: String, col_visual: int) -> Node3D:
	var cartas: Node = mesa.get_node(CARTAS)
	var alvo: Vector3 = mesa.call("_pos_slot", lado_visual, tipo, col_visual) as Vector3
	for f in cartas.get_children():
		if not (f as Node).has_meta("slot_id"):
			continue
		var p: Vector3 = (f as Node3D).position
		if absf(p.x - alvo.x) < 0.0001 and absf(p.z - alvo.z) < 0.0001:
			return f as Node3D
	return null


## Carta de DADO no campo, montada pelo CONSTRUTOR REAL
## (`SummonSystem.construir_instancia` — o único lugar do jogo que monta
## instância, R1) e colocada no slot pedido. Este arquivo não está testando
## regra de invocação (aí entram fase, mão e `normal_summon`), só o DESENHO:
## por isso usa o construtor direto, que é o mesmo caminho do jogo.
func _poe_no_campo(mesa: Node, st, lado: int, i: int) -> bool:
	var SummonSys := preload("res://duel/summon_system.gd")
	var cartas: Dictionary = mesa.get("_cartas")
	var cid := ""
	for k in cartas:
		if str((cartas[k] as Dictionary).get("card_type", "")) == "monster":
			cid = str(k)
			break
	if cid.is_empty():
		return false
	var real: Dictionary = cartas[cid] as Dictionary
	var inst: Dictionary = SummonSys.construir_instancia(real, false, "ATK", "", real, cid)
	(st.players[lado] as Dictionary)["monster"][i] = inst
	return true


## (1) A camada de perspectiva: a tela é a de QUEM ESTÁ JOGANDO, e `_vis` é o
## único lugar que decide. Na vez do jogador 0 ela é a identidade; na vez do
## rival cada coisa vai para o lado E a coluna opostas (a mesa virada).
func test_vis_segue_o_turno_e_a_mesa_virada() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	st.set("current_player", 0)
	assert_eq(int(mesa.call("_perspectiva")), 0, "Na vez do jogador 0 a tela é a dele.")
	for lado in [0, 1]:
		for i in range(COLUNAS):
			var v: Vector2i = mesa.call("_vis", lado, i)
			assert_eq(v, Vector2i(lado, i),
				"Na vez do jogador 0, o lugar do dado (%d,%d) é ele mesmo." % [lado, i])
	# Vez do RIVAL: lado oposto, MESMA coluna. A inversão de TELA vem sozinha
	# do espelho de X que o lado 1 da arena já tem no dado (D18) — por isso a
	# coluna NÃO é espelhada aqui (ver o teste (9), que mede na tela).
	st.set("current_player", 1)
	assert_eq(int(mesa.call("_perspectiva")), 1, "Na vez do rival a tela é a DELE.")
	for lado in [0, 1]:
		for i in range(COLUNAS):
			var v2: Vector2i = mesa.call("_vis", lado, i)
			assert_eq(v2, Vector2i(1 - lado, i),
				"Na vez do rival, o dado (%d,%d) vai para (%d,%d) (lado oposto, coluna igual)." % [
					lado, i, 1 - lado, i])
	# A fileira de BAIXO é sempre a de quem joga: o p1 em baixo, o p0 em cima.
	for i in range(COLUNAS):
		assert_eq((mesa.call("_vis", 0, i) as Vector2i).x, 1,
			"Na vez do rival, o p0 vai para a fileira de CIMA (coluna %d)." % i)
	# E a troca é uma involução: voltar a vez desfaz exatamente (D46 "Volta").
	assert_eq(int(mesa.call("_perspectiva")), 1, "Preparo: ainda na vez do rival.")
	st.set("current_player", 0)
	for lado in [0, 1]:
		for i in range(COLUNAS):
			assert_eq(mesa.call("_vis", lado, i), Vector2i(lado, i),
				"Voltou a vez: a tela é a do jogador de novo, carta por carta no mesmo lugar (%d,%d)." % [lado, i])
	# Coluna fora de 0..4 não derruba nada (blindagem, como o resto da tela).
	assert_eq(mesa.call("_vis", 0, -3), Vector2i(0, 0), "Coluna -3 trava em 0 (nunca crash).")
	assert_eq(mesa.call("_vis", 1, 99), Vector2i(1, 4), "Coluna 99 trava em 4 (nunca crash).")
	st.set("current_player", 1)
	assert_eq(mesa.call("_vis", 0, -3), Vector2i(1, 0), "Coluna -3 trava em 0 também na vez do rival.")
	assert_eq(mesa.call("_vis", 1, 99), Vector2i(0, 4), "Coluna 99 trava em 4 também na vez do rival.")


## (9) A REGRA DO USUÁRIO, medida na TELA (o que ele viu na foto da etapa 2):
## "se na minha vez eu colocar uma carta no meu slot 1 de monstro (esquerda
## pra direita), quando for a vez do rival aquela minha carta tem que aparecer
## no slot 5 do campo (esquerda pra direita)" — e vale para as cartas dos DOIS
## lados.
##
## O que é medido é a POSIÇÃO NA TELA (a ordem das 5 cartas pelo X projetado
## pela câmera de verdade, da esquerda para a direita), e NÃO o índice do
## dado: na fileira do rival o próprio dado já vem espelhado (D18), então
## "dado 0" e "slot 1 da tela" são coisas diferentes. A regra é: a carta que
## está no slot P da tela vai para o slot COLUNAS+1-P quando a vez passa.
func test_a_inversao_das_colunas_e_em_colunas_de_tela() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cam: Camera3D = mesa.get("_cam") as Camera3D
	assert_true(cam != null, "A mesa tem a câmera real (a projeção é o que prova a tela).")
	if cam == null:
		return
	for lado in [0, 1]:
		for i in range(COLUNAS):
			assert_true(_poe_no_campo(mesa, st, lado, i), "Preparo: p%d m%d tem carta." % [lado, i])
		var tela_minha := {}
		var tela_rival := {}
		st.set("current_player", 0)
		mesa.call("_redesenhar", false)
		await wait_process_frames(2)
		for i in range(COLUNAS):
			var c: Node3D = _carta_do_campo(mesa, lado, "monstro", i)
			if c != null:
				tela_minha[i] = cam.unproject_position(c.position).x
		st.set("current_player", 1)
		mesa.call("_redesenhar", false)
		await wait_process_frames(2)
		for i in range(COLUNAS):
			var c2: Node3D = _carta_do_campo(mesa, lado, "monstro", i)
			if c2 != null:
				tela_rival[i] = cam.unproject_position(c2.position).x
		if tela_minha.size() != COLUNAS or tela_rival.size() != COLUNAS:
			fail_test("Preparo: as 5 cartas do p%d ficaram desenhadas nos 2 turnos." % lado)
			continue
		# Posição na TELA (1 = mais à esquerda) de cada carta do dado.
		var p_minha := _posicao_na_tela(tela_minha)
		var p_rival := _posicao_na_tela(tela_rival)
		for i in range(COLUNAS):
			assert_eq(int(p_rival[i]), COLUNAS + 1 - int(p_minha[i]),
				"p%d: a carta que estava no slot %d da tela foi para o slot %d quando a vez passou." % [
					lado, int(p_minha[i]), int(p_rival[i])])
		# E o caso que o usuário citou: o slot 1 vira o slot 5, e vice-versa.
		var i_do_1 := -1
		var i_do_5 := -1
		for i in range(COLUNAS):
			if int(p_minha[i]) == 1:
				i_do_1 = i
			if int(p_minha[i]) == COLUNAS:
				i_do_5 = i
		assert_true(i_do_1 >= 0 and i_do_5 >= 0, "Preparo: achei as cartas das pontas do p%d." % lado)
		if i_do_1 >= 0:
			assert_eq(int(p_rival[i_do_1]), COLUNAS,
				"p%d: a carta no slot 1 da tela foi para o slot 5 na vez do rival." % lado)
		if i_do_5 >= 0:
			assert_eq(int(p_rival[i_do_5]), 1,
				"p%d: a carta no slot 5 da tela foi para o slot 1 na vez do rival." % lado)
		# E a fileira inteira é a imagem espelhada: slot 2 <-> 4, meio fica.
		for i in range(COLUNAS):
			assert_eq(int(p_rival[i]), COLUNAS + 1 - int(p_minha[i]),
				"p%d: a fileira inteira inverte de lugar na tela (dado %d: slot %d -> %d)." % [
					lado, i, int(p_minha[i]), int(p_rival[i])])


## Posição na TELA (1 = mais à esquerda) de cada carta, a partir do X projetado
## pela câmera. É o "slot 1..5" que o usuário conta olhando a foto.
func _posicao_na_tela(xs: Dictionary) -> Dictionary:
	var pares: Array = []
	for i in xs:
		pares.append([float(xs[i]), int(i)])
	pares.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Dictionary = {}
	var p := 1
	for par in pares:
		out[int(par[1])] = p
		p += 1
	return out


## (2) A carta desenhada está EXATAMENTE onde `_vis` mandou, e o giro de 180°
## da fileira de cima decide pelo LADO VISUAL (D6).
func test_carta_do_campo_vai_onde_a_perspectiva_mandou() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# Coloca carta de verdade nos DOIS lados, em colunas DIFERENTES de
	# propósito (a 2), para uma coluna errada aparecer na prova.
	var ok0 := _poe_no_campo(mesa, st, 0, 2)
	var ok1 := _poe_no_campo(mesa, st, 1, 2)
	assert_true(ok0, "Preparo: o p0 tem carta no campo.")
	assert_true(ok1, "Preparo: o p1 tem carta no campo.")
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	for lado in [0, 1]:
		var carta: Node3D = _carta_do_campo(mesa, lado, "monstro", 2)
		assert_true(carta != null, "A carta do dado (p%d, m2) está desenhada." % lado)
		if carta == null:
			continue
		var v: Vector2i = mesa.call("_vis", lado, 2)
		var esperado: Vector3 = mesa.call("_pos_slot", v.x, "monstro", v.y) as Vector3
		assert_almost_eq(carta.position.x, esperado.x, 0.0001,
			"A carta do p%d m2 está no X que a perspectiva mandou." % lado)
		assert_almost_eq(carta.position.z, esperado.z, 0.0001,
			"A carta do p%d m2 está no Z que a perspectiva mandou." % lado)
		# O giro de 180° vem do LADO VISUAL, não do lado do dado.
		var virada := bool(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("face_down", false))
		var em_defesa := str(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("position", "ATK")) == "DEF"
		var rot: Vector3 = mesa.call("_rot_deitada", virada, v.x, em_defesa) as Vector3
		assert_almost_eq(carta.rotation_degrees.y, rot.y, 0.0001,
			"A carta do p%d m2 gira pelo LADO VISUAL (%.0f = %.0f graus)." % [lado, carta.rotation_degrees.y, rot.y])
		# E a carta desenhada é a do DADO daquele índice (nada trocou de lugar).
		assert_eq(str(carta.get_meta("card_id")),
			str(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("card_id", "")),
			"A carta desenhada em m2 é a carta do DADO do índice 2 do p%d." % lado)


## (3) R1 na prática: redesenhar NÃO mexe no estado. A troca de perspectiva da
## etapa 2 vai ser só de desenho; o `GameState` tem que ficar igual.
func test_o_estado_nao_se_move_no_redesenho() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_poe_no_campo(mesa, st, 0, 0), "Preparo: o p0 tem carta no campo.")
	assert_true(_poe_no_campo(mesa, st, 1, 0), "Preparo: o p1 tem carta no campo.")
	var antes0: Array = ((st.players[0] as Dictionary)["monster"] as Array).duplicate(true)
	var antes1: Array = ((st.players[1] as Dictionary)["monster"] as Array).duplicate(true)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["monster"] as Array), antes0,
		"O campo do p0 é o MESMO depois de redesenhar (nada entrou, nada saiu).")
	assert_eq(((st.players[1] as Dictionary)["monster"] as Array), antes1,
		"O campo do p1 é o MESMO depois de redesenhar.")
	# E a carta continua no MESMO índice, desenhada, dos dois lados.
	for lado in [0, 1]:
		var esperado: Dictionary = (st.players[lado] as Dictionary)["monster"][0] as Dictionary
		assert_false(esperado.is_empty(), "Preparo: o p%d tem carta no índice 0." % lado)
		var carta: Node3D = _carta_do_campo(mesa, lado, "monstro", 0)
		assert_true(carta != null, "A carta do p%d m0 está desenhada." % lado)
		if carta != null:
			assert_eq(str(carta.get_meta("card_id")), str(esperado.get("card_id", "")),
				"A carta desenhada no m0 do p%d é a do índice 0 (a troca é só desenho)." % lado)


## (4) Andar pela posição visível: a DIREITA é a direita que se VÊ, nos DOIS
## lados. O vizinho pergunta ao X de quem é DESENHADO (`_x_do_slot`, que já
## passa pela perspectiva), nunca ao índice — e o lado 1 é ESPELHADO no dado
## (D18: lá a coluna 0 é a da DIREITA). Se um dia alguém voltar a andar pelo
## índice, esta trava pega.
func test_direita_na_tela_e_direita_nos_dois_lados() -> void:
	var mesa: Node = await _mesa3d_nova()
	# O espelho do D18, que a perspectiva reaproveita: a coluna 4 é a da
	# direita no lado 0 e a coluna 0 é a da direita no lado 1.
	var x0_0: float = mesa.call("_x_do_slot", 0, "monstro", 0)
	var x4_0: float = mesa.call("_x_do_slot", 0, "monstro", 4)
	var x0_1: float = mesa.call("_x_do_slot", 1, "monstro", 0)
	var x4_1: float = mesa.call("_x_do_slot", 1, "monstro", 4)
	assert_true(x4_0 > x0_0, "Lado 0: a coluna 4 fica à direita da coluna 0 (%.3f > %.3f)." % [x4_0, x0_0])
	assert_true(x0_1 > x4_1, "Lado 1 (espelho D18): a coluna 0 fica à direita da coluna 4 (%.3f > %.3f)." % [x0_1, x4_1])
	# Andar para a DIREITA aumenta o X de tela; para a ESQUERDA, diminui.
	# Testado no MEIO da fileira, que não está na borda.
	for lado in [0, 1]:
		var meio: float = mesa.call("_x_do_slot", lado, "monstro", 2)
		var dir: int = mesa.call("_vizinho3d", lado, "monstro", 2, 1)
		var esq: int = mesa.call("_vizinho3d", lado, "monstro", 2, -1)
		assert_true(float(mesa.call("_x_do_slot", lado, "monstro", dir)) > meio,
			"No lado %d, andar para a DIREITA aumenta o X de tela (coluna %d)." % [lado, dir])
		assert_true(float(mesa.call("_x_do_slot", lado, "monstro", esq)) < meio,
			"No lado %d, andar para a ESQUERDA diminui o X de tela (coluna %d)." % [lado, esq])


## (6) ETAPA 2 — a TROCA: quando a vez muda, a carta do p0 some do lado de
## baixo e aparece no de cima (e o inverso), e o ESTADO NÃO SE MEXE. Aqui as
## duas metades são desenhadas ao mesmo tempo (a que esmaece e a que entra),
## então no headless o que se prova é o resultado final: a carta está no lado
## novo, com a coluna espelhada e girada, e a mesma carta continua no mesmo
## índice do `GameState`.
func test_a_troca_manda_a_carta_para_o_outro_lado_sem_mexer_no_estado() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_poe_no_campo(mesa, st, 0, 0), "Preparo: o p0 tem carta no m0.")
	assert_true(_poe_no_campo(mesa, st, 1, 0), "Preparo: o p1 tem carta no m0.")
	st.set("current_player", 0)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var minha: Node3D = _carta_do_campo(mesa, 0, "monstro", 0)
	assert_true(minha != null, "Na vez do jogador a carta do p0 está desenhada.")
	if minha == null:
		return
	var pos_antes: Vector3 = minha.position
	var cid_antes := str(minha.get_meta("card_id"))
	var idx_antes: int = -1
	for i in range(5):
		var inst = (st.players[0] as Dictionary)["monster"][i]
		if inst is Dictionary and str((inst as Dictionary).get("card_id", "")) == cid_antes:
			idx_antes = i
	assert_eq(idx_antes, 0, "Preparo: a carta do p0 está no índice 0 do estado.")
	# ---- A VEZ PASSA. O motor muda o current_player; a tela segue.
	st.set("current_player", 1)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	# 1) a carta do p0 foi desenhada no LADO DE CIMA (visual), coluna espelhada
	var v := mesa.call("_vis", 0, 0) as Vector2i
	var no_visual: Node3D = _carta_por_slot_visual(mesa, v.x, "monstro", v.y)
	assert_true(no_visual != null,
		"Na vez do rival, a carta do p0 está desenhada no ladrilho VISUAL (%d,%d)." % [v.x, v.y])
	if no_visual != null:
		var esperado: Vector3 = mesa.call("_pos_slot", v.x, "monstro", v.y) as Vector3
		assert_almost_eq(no_visual.position.x, esperado.x, 0.0001, "No X do ladrilho visual.")
		assert_almost_eq(no_visual.position.z, esperado.z, 0.0001, "No Z do ladrilho visual.")
		assert_true(no_visual.position.z < pos_antes.z,
			"A carta do p0 foi para o LADO DE CIMA do campo (Z %.3f < %.3f, mais longe da câmera)." % [
				no_visual.position.z, pos_antes.z])
		# E, o que o usuário vê: ela SOBIU na tela.
		var cam: Camera3D = mesa.get("_cam") as Camera3D
		if cam != null:
			var y_antes := cam.unproject_position(pos_antes).y
			var y_depois := cam.unproject_position(no_visual.position).y
			assert_true(y_depois < y_antes,
				"Na TELA a carta do p0 subiu (y %.0f -> %.0f px; menor y = mais alto)." % [
					y_antes, y_depois])
		# e a carta de cima é lida de CABEÇA PARA BAIXO (D6): 180 graus
		assert_almost_eq(no_visual.rotation_degrees.y, 180.0, 0.0001,
			"A carta da fileira de cima está de cabeça para baixo (180 graus).")
		assert_eq(str(no_visual.get_meta("card_id")), cid_antes,
			"É a MESMA carta do p0 que mudou de lado (o meta é o slot do DADO).")
	# 2) o ESTADO NÃO SE MEXE: o p0 continua com a carta no índice 0
	var depois = (st.players[0] as Dictionary)["monster"][0]
	assert_false(depois == null, "O estado do p0 continua com a carta no índice 0.")
	if depois is Dictionary:
		assert_eq(str((depois as Dictionary).get("card_id", "")), cid_antes,
			"A carta do p0 é a MESMA no estado depois da troca (a troca é só desenho).")
	var idx_depois: int = -1
	for i in range(5):
		var inst2 = (st.players[0] as Dictionary)["monster"][i]
		if inst2 is Dictionary and str((inst2 as Dictionary).get("card_id", "")) == cid_antes:
			idx_depois = i
	assert_eq(idx_depois, 0, "A carta do p0 continua no MESMO índice do estado (0).")
	# 3) e o que era do RIVAL desceu para a fileira de baixo, virado para frente
	var vr := mesa.call("_vis", 1, 0) as Vector2i
	var carta_rival: Node3D = _carta_por_slot_visual(mesa, vr.x, "monstro", vr.y)
	assert_true(carta_rival != null, "A carta do p1 está desenhada no ladrilho visual dele.")
	if carta_rival != null:
		assert_almost_eq(carta_rival.rotation_degrees.y, 0.0, 0.0001,
			"A carta de baixo (do rival) está de frente para o dono (0 graus).")
	# 4) a volta desfaz: a tela é a do jogador de novo, no mesmo lugar
	st.set("current_player", 0)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var voltou := _carta_do_campo(mesa, 0, "monstro", 0)
	assert_true(voltou != null, "Voltou a vez: a carta do p0 está desenhada de novo.")
	if voltou != null:
		assert_almost_eq(voltou.position.x, pos_antes.x, 0.0001, "E no MESMO X de antes (a volta é reversível).")
		assert_almost_eq(voltou.position.z, pos_antes.z, 0.0001, "E no MESMO Z de antes.")
		assert_almost_eq(voltou.rotation_degrees.y, 0.0, 0.0001, "E virada para frente de novo.")


## (7) ETAPA 2 — a troca é UMA troca só, sem fila e sem resto: depois dela
## não sobra carta fantasma pendurada na tela, e a carta que fica é a do
## ladrilho, na cara (alfa 1). Também trava que o estado continua igual.
func test_a_troca_nao_deix_sobra_nem_fantasma() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_poe_no_campo(mesa, st, 0, 0), "Preparo: o p0 tem carta no m0.")
	assert_true(_poe_no_campo(mesa, st, 1, 0), "Preparo: o p1 tem carta no m0.")
	st.set("current_player", 0)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var antes_p1: Array = ((st.players[1] as Dictionary)["monster"] as Array).duplicate(true)
	st.set("current_player", 1)
	mesa.call("_redesenhar", false)
	await wait_process_frames(4)
	# Todas as cartas do campo estão no grupo `Cartas` (nenhuma em `Fantasmas`).
	var cartas: Node = mesa.get_node(CARTAS)
	var fantasma: Node = mesa.get_node_or_null("Camada3D/JanelaCampo/Viewport3D/Fantasmas")
	assert_true(fantasma != null, "A camada de fantasmas existe.")
	if fantasma != null:
		assert_eq((fantasma as Node).get_child_count(), 0,
			"NENHUMA carta ficou pendurada na camada de fantasmas depois da troca.")
	# E as cartas que ficaram estão opacas (alfa 1 = o desenho normal).
	for f in cartas.get_children():
		if not (f as Node).has_meta("slot_id"):
			continue
		var corpo := (f as Node3D).get_node_or_null("Frente") as MeshInstance3D
		if corpo == null:
			continue
		var mat = corpo.material_override as BaseMaterial3D
		assert_true(mat != null, "A carta do campo tem material.")
		if mat != null:
			assert_almost_eq(mat.albedo_color.a, 1.0, 0.001,
				"A carta que ficou está OPACA (o esmaecer acabou, sem material transparente sobrando).")
	assert_eq(((st.players[1] as Dictionary)["monster"] as Array), antes_p1,
		"A troca não mexeu no estado do p1.")


## (8) D46b — na vez do rival o painel esquerdo continua vivo, mas mostra a
## imagem PADRONIZADA (o verso) e NENHUM dado da carta.
func test_painel_esquerdo_neutro_na_vez_do_rival() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# Os rótulos saem das próprias variáveis da mesa (mesmo caminho que o
	# desenho usa) — nada de adivinhar nome de nó.
	var lbl_nome: Label = mesa.get("_lbl_foco_nome") as Label
	var lbl_molde: Label = mesa.get("_lbl_foco_nome_molde") as Label
	var lbl_stats: Label = mesa.get("_lbl_foco_stats") as Label
	var lbl_tipo: Label = mesa.get("_lbl_foco_tipo") as Label
	var lbl_desc: Label = mesa.get("_lbl_foco_desc") as Label
	var lbl_copia: Label = mesa.get("_lbl_copia_foco") as Label
	assert_true(lbl_nome != null and lbl_molde != null and lbl_stats != null
		and lbl_tipo != null and lbl_desc != null and lbl_copia != null,
		"O painel esquerdo tem as 6 peças de texto.")
	if lbl_nome == null or lbl_molde == null or lbl_stats == null or lbl_tipo == null \
			or lbl_desc == null or lbl_copia == null:
		return
	# Na vez do JOGADOR: o painel mostra a carta de verdade (dado real).
	st.set("current_player", 0)
	mesa.call("_atualizar_painel_foco")
	assert_false(lbl_nome.text.is_empty(), "Na sua vez o painel mostra o nome da carta focada.")
	assert_true(lbl_stats.text.contains("ATK/"), "Na sua vez o painel mostra ATK/DEF.")
	# Na vez do RIVAL: o mesmo quadro, sem nenhum dado.
	st.set("current_player", 1)
	mesa.call("_atualizar_painel_foco")
	assert_eq(lbl_nome.text, "", "D46b: na vez do rival o nome da carta some.")
	assert_eq(lbl_molde.text, "", "D46b: na vez do rival o nome na moldura some.")
	assert_eq(lbl_stats.text, "", "D46b: na vez do rival o ATK/DEF some.")
	assert_eq(lbl_tipo.text, "", "D46b: na vez do rival o tipo some.")
	assert_eq(lbl_desc.text, "", "D46b: na vez do rival a descrição some.")
	assert_eq(lbl_copia.text, "", "D46b: na vez do rival o contador de cópias some.")
	# E a imagem é a PADRONIZADA (o verso, asset do jogo), não a arte da carta.
	var arte: TextureRect = mesa.get("_tex_foco_arte") as TextureRect
	var moldura: TextureRect = mesa.get("_tex_foco_moldura") as TextureRect
	assert_true(arte != null and moldura != null, "O painel tem a arte e a moldura.")
	if arte != null:
		var verso: Texture2D = mesa.call("_tex_cache", "assets/backs/verso_padrao.png")
		assert_eq(_assinatura(arte.texture), _assinatura(verso),
			"D46b: na vez do rival a imagem é o VERSO padrão, não a arte da carta.")
	# E volta ao normal quando a vez volta.
	st.set("current_player", 0)
	mesa.call("_atualizar_painel_foco")
	assert_false(lbl_nome.text.is_empty(), "Voltou a vez: o painel volta a mostrar a carta.")


## Assinatura de uma textura (caminho + tamanho) para comparar sem pixel.
func _assinatura(t: Texture2D) -> String:
	if t == null:
		return ""
	return "%s|%dx%d" % [t.resource_path, t.get_width(), t.get_height()]


## (5) D8: a faixa do meio e as placas de nome são SEMPRE o painel do jogador.
## A perspectiva troca as cartas de lugar, nunca o painel.
func test_a_faixa_do_meio_nao_espelha() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var hud: Node = mesa.get_node_or_null("HUD")
	assert_true(hud != null, "A mesa tem o HUD.")
	if hud == null:
		return
	st.set("current_player", 0)
	mesa.call("_construir_faixa_2d", hud)
	var faixa_a: Control = mesa.get("_faixa2d") as Control
	assert_true(faixa_a != null, "A faixa 2D existe no HUD.")
	if faixa_a == null:
		return
	var pos_a: Vector2 = faixa_a.position
	var tam_a: Vector2 = faixa_a.size
	# Vira o current_player e reconstrói: a faixa tem que ficar no MESMO lugar.
	# `free()` imediato (não `queue_free`): a fila só drena no fim do frame, e
	# o GUT conta órfão antes disso.
	hud.remove_child(faixa_a)
	faixa_a.free()
	mesa.set("_faixa2d", null)
	st.set("current_player", 1)
	mesa.call("_construir_faixa_2d", hud)
	var faixa_b: Control = mesa.get("_faixa2d") as Control
	assert_true(faixa_b != null, "A faixa 2D foi reconstruída na vez do rival.")
	if faixa_b == null:
		return
	assert_eq(faixa_b.position, pos_a,
		"D8: a faixa do meio fica no MESMO lugar com o rival na vez (não espelha).")
	assert_eq(faixa_b.size, tam_a,
		"D8: a faixa do meio tem o MESMO tamanho com o rival na vez.")
	hud.remove_child(faixa_b)
	faixa_b.free()
	mesa.set("_faixa2d", null)
