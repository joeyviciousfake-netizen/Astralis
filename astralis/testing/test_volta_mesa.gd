extends "res://testing/astralis_test_base.gd"

## test_volta_mesa - A VOLTA DA MESA (D47): a tela do duelo passa a ser a
## perspectiva de QUEM ESTA JOGANDO do jeito do Forbidden Memories, e a
## CAMERA que da a volta - as cartas NAO se mexem.
##
## O que mudou de verdade (e por que e MAIS SIMPLES que antes): a tela nao
## finge mais a perspectiva movendo as cartas. A camera e filha de um PIVO no
## centro do campo e quem gira 180 graus; cada carta continua no seu lugar do
## MUNDO, e e a camera que vai para o outro lado da mesa. Consequencia: a
## sua fileira vai para o topo da tela de cabeca para baixo, a do rival vem
## para baixo de frente, a sua mao vai para o topo pelas costas, e nada
## esmaece, nada teleporta e o estado do jogo nao se mexe (R1).
##
## O QUE ESTE ARQUIVO TRAVA:
## (1) a camera e filha do pivo, nao se move, e o pivo e quem gira;
## (2) a lente continua NO EIXO (`frustum_offset` = 0) e o centro do campo
##     continua no mesmo lugar da tela - a perspectiva e simetrica, entao o
##     campo tem a mesma cara dos dois lados;
## (3) a volta vai a 180 e VOLTA a 0, e o estado final e o mesmo com e sem
##     render (teste/headless included);
## (4) AS CARTAS NAO SE MEXEM: a posicao de mundo de cada carta do campo e
##     identica antes e depois da volta (esta e a trava que substitui toda a
##     antiga maquina de perspectiva das etapas 1 a 3 do doc 16);
## (5) no GameState, cada carta continua no mesmo indice;
## (6) cada jogador ve a PROPRIA fileira na ordem normal (o espelho do rival
##     no dado, D18, e a volta de 180 se cancelam);
## (7) o HUD 2D nao gira: ele vira de carta, e o conteudo troca nos 90
##     graus, quando o bloco esta com largura ZERO;
## (8) o painel esquerdo continua sem nenhum dado na vez do rival (D46b);
## (9) o controle fica travado enquanto a mesa gira.
##
## Sem Fake (R2): a cena 3D real + o GameState real do DuelManager.

const SummonSys := preload("res://duel/summon_system.gd")
const TurnManager := preload("res://duel/turn_manager.gd")

const CARTAS := "Camada3D/JanelaCampo/Viewport3D/Cartas"
const PIVO := "Camada3D/JanelaCampo/Viewport3D/PivoMesa"
const CAMERA := "Camada3D/JanelaCampo/Viewport3D/PivoMesa/Camera3D"
const COLUNAS := 5


## Carta de DADO no campo, pelo CONSTRUTOR REAL do jogo
## (`SummonSys.construir_instancia` - o unico lugar que monta instancia, R1).
## Este arquivo nao testa regra de invocacao, so o desenho.
## O no da vista e da volta (D47): a camera, o pivo e o numero do giro moram
## nele (`vista_3d.gd`), entao e ele que os testes falam.
func _vista(mesa: Node) -> Node:
	return mesa.get("_vista") as Node


func _poe_no_campo(mesa: Node, st, lado: int, i: int) -> bool:
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


## A carta desenhada de um slot do DADO (pelo meta `slot_id`, que e a
## identidade dela no DADO - a camera nao muda isso).
func _carta_do_campo(mesa: Node, lado: int, i: int) -> Node3D:
	var cartas: Node = mesa.get_node(CARTAS)
	var alvo := "p%d_m%d" % [lado, i]
	for f in cartas.get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == alvo:
			return f as Node3D
	return null


## Posicao de mundo de toda carta do campo, pelo slot do dado.
func _posicoes(mesa: Node) -> Dictionary:
	var out: Dictionary = {}
	var cartas: Node = mesa.get_node(CARTAS)
	for f in cartas.get_children():
		if (f as Node).has_meta("slot_id"):
			out[str((f as Node).get_meta("slot_id"))] = (f as Node3D).position
	return out


## Coloca 5 cartas de verdade em cada fileira, dos dois lados.
func _campo_cheio(mesa: Node, st) -> void:
	for lado in [0, 1]:
		for i in range(COLUNAS):
			_poe_no_campo(mesa, st, lado, i)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)


## (1) A camera e FILHA do pivo, nao se move, e quem gira e o pivo.
func test_a_camera_e_filha_do_pivo_e_nao_se_move() -> void:
	var mesa: Node = await _mesa3d_nova()
	var pivo := mesa.get_node_or_null(PIVO) as Node3D
	var cam := mesa.get_node_or_null(CAMERA) as Camera3D
	assert_true(pivo != null, "O pivo da mesa existe (e o ponto da volta).")
	assert_true(cam != null, "A camera existe DENTRO do pivo.")
	if pivo == null or cam == null:
		return
	assert_eq(cam.get_parent(), pivo, "A camera e filha do pivo (e o pivo que da a volta).")
	assert_true(cam.current, "A camera e a atual.")
	# A camera NAO se move: a posicao local e a de sempre (com o pivo em 0 a
	# imagem e a mesma de antes da D47).
	assert_eq(cam.position, Vector3(0.0, 16.8, 20.9), "A camera nao se move (posicao local fixa).")
	# E o pivo comeca em 0: a primeira tela e a do jogador, igual sempre foi.
	assert_eq(pivo.rotation_degrees.y, 0.0, "A mesa comeca na visao do JOGADOR (pivo em 0).")
	assert_eq(float(_vista(mesa).get("giro_campo")), 0.0, "O numero da volta comeca em 0.")


## (2) A lente continua no eixo e o centro do campo continua no mesmo lugar da
## tela: a perspectiva e simetrica, entao o campo tem a MESMA cara dos dois
## lados (doc 15 15.4 intacto - e a trava que garante a volta nao distorcer).
func test_a_lente_continua_no_eixo_e_o_centro_do_campo_no_lugar() -> void:
	var mesa: Node = await _mesa3d_nova()
	var cam := mesa.get_node(CAMERA) as Camera3D
	assert_eq(cam.frustum_offset, Vector2.ZERO,
		"D47: a lente continua NO EIXO (frustum_offset = 0) - nada de torto na volta.")
	# Tudo medido na MESMA passagem, antes e depois: y de tela do centro da
	# fileira de cada lado.
	var y_meu_0: float = cam.unproject_position(mesa.call("_pos_slot", 0, "monstro", 2)).y
	var y_rival_0: float = cam.unproject_position(mesa.call("_pos_slot", 1, "monstro", 2)).y
	var x_meu_0: float = cam.unproject_position(mesa.call("_pos_slot", 0, "monstro", 2)).x
	# Na visão do JOGADOR a fileira dele é a de baixo (y MAIOR = mais embaixo).
	assert_true(y_meu_0 > y_rival_0,
		"Visão do jogador: a fileira dele é de BAIXO (y dele %.0f > y do rival %.0f)." % [
			y_meu_0, y_rival_0])
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	var y_meu_180: float = cam.unproject_position(mesa.call("_pos_slot", 0, "monstro", 2)).y
	var y_rival_180: float = cam.unproject_position(mesa.call("_pos_slot", 1, "monstro", 2)).y
	var x_meu_180: float = cam.unproject_position(mesa.call("_pos_slot", 0, "monstro", 2)).x
	# Na visão do RIVAL a fileira do JOGADOR é a de cima (y MENOR).
	assert_true(y_meu_180 < y_rival_180,
		"Visão do RIVAL: a fileira do jogador é a de CIMA (y %.0f < y do rival %.0f) - a câmera que virou." % [
			y_meu_180, y_rival_180])
	# E o centro do campo continua no MESMO x da tela: a volta ESPELHA, não
	# desloca (é o que mantém o doc 15 §15.4 de pé).
	assert_almost_eq(x_meu_180, x_meu_0, 0.001,
		"Na volta de 180 o centro do campo continua no MESMO x da tela.")
	# (NÃO se compara "subiu X e desceu X": a projeção tem divisão de
	# perspectiva, então a distância na tela não é linear na vertical — as duas
	# fileiras estão a distâncias diferentes da câmera. O que vale é a ordem,
	# que é a de cima/baixo, e ela é a que os dois asserts acima cravam.)
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)


## (2b) D51 — A VISTA DO RIVAL É O ESPELHO EXATO DA DO JOGADOR. A trava que
## garante que a faixa 2D do meio (que NÃO se mexe, nunca) caia no vão entre
## as duas fileiras de monstro nas DUAS perspectivas, sem gambiarra nenhuma.
## O que a D47 deixou torto: o pivô da volta está na origem (0,0,0) e o campo
## NÃO é simétrico em relação a ela — o plano de simetria do campo (a média
## das duas fileiras de monstro da arena oficial) está em outro Z. Girando em
## torno da origem, a câmera do rival chega perto demais da mesa, o campo
## aparece mais para baixo e a faixa sai do vão. Aqui a trava: a câmera do
## jogador é a de sempre (byte a byte) e a do rival cai no MESMO vão, com as
## mesmas margens.
func test_a_vista_do_rival_e_o_espelho_exato_da_do_jogador() -> void:
	var mesa: Node = await _mesa3d_nova()
	var cam := mesa.get_node(CAMERA) as Camera3D
	var pos_0 := cam.position
	# (a) A VISTA DO JOGADOR NÃO MUDA: a câmera local é a de sempre, e a
	# correção do ângulo do rival vale 0 em 0 graus.
	var z0: float = float(_vista(mesa).call("_z_local_da_camera", 0.0))
	assert_almost_eq(z0, pos_0.z, 0.0001,
		"D51: em 0 graus a câmera do jogador é a de sempre (nada muda na sua vez).")
	# (b) O PLANO DE SIMETRIA VEM DO DADO: a média das duas fileiras de monstro
	# da arena oficial (a de cima e a de baixo da tela, na vista do jogador).
	var sim: float = float(_vista(mesa).get("z_simetria"))
	var z_p1 := (mesa.call("_pos_slot", 1, "monstro", 2) as Vector3).z
	var z_p0 := (mesa.call("_pos_slot", 0, "monstro", 2) as Vector3).z
	assert_almost_eq(sim, (z_p1 + z_p0) * 0.5, 0.0001,
		"D51: o plano de simetria do campo é a média das duas fileiras de monstro do DADO.")
	# (c) A CÂMERA DO RIVAL VAI AO ESPELHO: 2x o desvio do pivô para o lado de
	# dentro, para a distância em relação ao plano do campo ser a mesma dos
	# dois lados.
	var z180: float = float(_vista(mesa).call("_z_local_da_camera", 180.0))
	assert_almost_eq(z180, pos_0.z - 2.0 * sim, 0.0001,
		"D51: em 180 graus a câmera recua exatamente o desvio do pivô (o espelho).")
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	assert_almost_eq(cam.position.z, z180, 0.0001,
		"D51: depois da volta a câmera está no ponto do espelho.")
	# (d) A TRAVA DE VERDADE: o VÃO entre as duas fileiras de monstro é o MESMO
	# nas duas vistas.
	var vao_jogador := _vao_das_fileiras(mesa)
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	var vao_rival := _vao_das_fileiras(mesa)
	assert_almost_eq(vao_rival.x, vao_jogador.x, 1.0,
		"D51: o topo do vão entre as fileiras é o MESMO nas duas vistas (%.1f vs %.1f)." % [
			vao_rival.x, vao_jogador.x])
	assert_almost_eq(vao_rival.y, vao_jogador.y, 1.0,
		"D51: a base do vão entre as fileiras é a MESMA nas duas vistas (%.1f vs %.1f)." % [
			vao_rival.y, vao_jogador.y])
	# E a ida e volta devolve a SUA câmera exatamente onde estava.
	assert_eq(cam.position, pos_0,
		"D51: depois de ir ao rival e voltar, a câmera do jogador está no mesmo lugar (byte a byte).")
	# (f) E a fileira de cada jogador cai no MESMO retângulo de tela que a do
	# jogador na outra vista (é o espelho, não um redimensionamento).
	for lado in [0, 1]:
		var j := _fileira_de_monstro(mesa, lado)
		mesa.call("_girar_campo", 180.0)
		await wait_process_frames(2)
		var r := _fileira_de_monstro(mesa, 1 - lado)
		mesa.call("_girar_campo", 0.0)
		await wait_process_frames(2)
		assert_almost_eq(r.x, j.x, 1.0,
			"D51: a fileira p%d ocupa o MESMO retângulo de tela nas duas vistas (topo %.1f vs %.1f)." % [
				lado, r.x, j.x])
		assert_almost_eq(r.y, j.y, 1.0,
			"D51: a fileira p%d ocupa o MESMO retângulo de tela nas duas vistas (base %.1f vs %.1f)." % [
				lado, r.y, j.y])


## (11) D53 — ANDAR NA MÃO NÃO MOVE NADA QUE NÃO SEJA O CURSOR. O bug que o
## usuário reportou: "quando eu estou navegando pelas cartas da minha mão eu vejo
## que as cartas da mão do inimigo que estão no outro lado do campo parece que se
## movimentam junto". São TRÊS defeitos da mesma família (um desenho que se mexe
## sem precisar), e os três são travados aqui:
##
## (a) A COMPRA ANIMADA ESTAVA NA MÃO ERRADA. O tween da compra estava fixo na
##     `mao0` (a do jogador), então na vez do RIVAL — quando, com a D52, a mão
##     do jogador é o LUGAR DE CIMA da tela — a compra DELE arrastava a SUA mão
##     pelo meio do campo. E a invocação (`_terminar_jogada_mao`) animava a mão
##     sem ter comprado nada (a carta DESCE da mão para o campo).
## (b) A CHACOALHADA DA FUSÃO SACUDIA A MESA INTEIRA: era
##     `_sacudir(_no_cartas)`, e `_no_cartas` é o guarda-chuva das 20+ cartas
##     (as 4 fileiras e as DUAS mãos) — as cartas se moviam JUNTAS.
## (c) ANDAR NA MÃO REDESENHAVA A TELA 3D INTEIRA a cada passo: `_redesenhar`
##     destrói e recria todas as cartas (`queue_free`), e o que muda ao andar é
##     só o cursor e o painel da esquerda.
func test_andar_na_mao_nao_move_a_mao_do_outro_lado() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cartas := mesa.get_node(CARTAS) as Node3D
	var no_cartas := mesa.get("_no_cartas") as Node3D
	st.set("current_player", 0)
	st.set("phase", "MAIN")
	mesa.set("_fase_jogador", 0) # FASE_MAO
	mesa.set("_fileira", 0)     # FILEIRA_MAO
	mesa.set("_sub_mao", 0)     # SUB_MAO_ESCOLHA
	mesa.set("_col", 0)
	await wait_process_frames(2)
	# Preparo: tem que estar NA FASE DA MÃO de verdade, senão o `_mover` cai
	# noutro ramo e o teste mede outra coisa (foi o que aconteceu na 1ª vez).
	assert_eq(int(mesa.get("_fase_jogador")), 0, "D53: preparo: estamos na FASE_MAO.")
	assert_eq(int(mesa.get("_fileira")), 0, "D53: preparo: o cursor está na fileira da MÃO.")
	var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var n1: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
	var n_antes: int = cartas.get_child_count()
	var rival_antes := _carta_da_mao(mesa, 0, 1)
	assert_true(rival_antes != null, "D53: preparo: a carta 0 da mao do rival esta desenhada.")
	var id_antes: int = (rival_antes as Node).get_instance_id() if rival_antes != null else 0
	var x_rival_antes: float = (rival_antes as Node3D).position.x if rival_antes != null else 0.0
	# --- (c) andar na mao NAO recria as cartas ---
	mesa.call("_mover", 1, 0)
	await wait_process_frames(2)
	assert_eq(cartas.get_child_count(), n_antes,
		"D53: andar na mao nao cria nem destroy carta nenhuma (filhos %d -> %d)." % [
			n_antes, cartas.get_child_count()])
	var rival_depois := _carta_da_mao(mesa, 0, 1)
	var id_depois: int = (rival_depois as Node).get_instance_id() if rival_depois != null else 0
	assert_eq(id_depois, id_antes,
		"D53: a carta da mao do rival e o MESMO no (o desenho nao foi refeito).")
	assert_almost_eq((rival_depois as Node3D).position.x, x_rival_antes, 0.0001,
		"D53: e a mao do outro lado nao mudou de lugar (%.3f -> %.3f)." % [
			x_rival_antes, (rival_depois as Node3D).position.x])
	assert_eq(int(mesa.get("_col")), 1, "D53: o cursor andou uma carta para a direita.")
	# --- (a) a compra animada e da mao que COMPROU, e so da carta que COMPROU
	#     (medido na hora, sem esperar o tween correr, que em headless anda na
	#     velocidade do process) ---
	#     A mao tem que CRESCER de verdade, e quem compra e o MOTOR: encher a mao
	#     na mao faria a entrada achar que nada entrou, e o teste mediria uma tela
	#     parada fingindo que animou.
	var deck: Array = mesa.get("_deck_pos")
	var mao_rival: Array = ((st.players[1] as Dictionary)["hand"] as Array)
	mao_rival.pop_back()                                   # em 4, como apos invocar
	var n_antes_rival: int = mao_rival.size()
	mesa.call("_redesenhar", false)
	st.set("current_player", 1)
	TurnManager.draw_for_current(st)
	var idx_nova_rival: int = mao_rival.size() - 1
	mesa.call("_redesenhar", true, 1) # compra do RIVAL
	var nova_rival := _carta_da_mao(mesa, idx_nova_rival, 1) as Node3D
	var dele := _carta_da_mao(mesa, 0, 1) as Node3D
	var eu := _carta_da_mao(mesa, 0, 0) as Node3D
	assert_almost_eq(nova_rival.position.x, float(deck[1].x), 0.001,
		"D53: na compra do RIVAL a carta QUE COMPROU e que sai do baralho DELE (x %.2f)." % float(deck[1].x))
	# As OUTRAS nao saem do baralho: elas estao onde a mao as tinha e vao
	# DESLIZAR ate o lugar novo. Medir o comeco do deslize (e nao o fim) e o que
	# prova que elas andam — no fim as duas medidas dariam o mesmo numero.
	assert_almost_eq(dele.position.x, (mesa.call("_pos_mao_arco", 0, n_antes_rival, 1) as Vector3).x, 0.0001,
		"D53: as OUTRAS cartas da mao dele nao saem do baralho, elas DESLIZAM (x %.3f = lugar antigo)." % dele.position.x)
	assert_true(dele.position.distance_to(Vector3(deck[1].x, deck[1].y, deck[1].z)) > 1.0,
		"D53: e nenhuma delas ficou no baralho.")
	assert_almost_eq(eu.position.x, (mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3).x, 0.0001,
		"D53: e a SUA mao fica no lugar dela (x %.3f) - antes ela era a que animava, e na tela do rival ela e o LUGAR DE CIMA." % eu.position.x)
	var mao_jog: Array = ((st.players[0] as Dictionary)["hand"] as Array)
	mao_jog.pop_back()
	mesa.call("_redesenhar", false)
	st.set("current_player", 0)
	TurnManager.draw_for_current(st)
	var idx_nova_jog: int = mao_jog.size() - 1
	mesa.call("_redesenhar", true, 0) # compra do JOGADOR
	dele = _carta_da_mao(mesa, 0, 1) as Node3D
	eu = _carta_da_mao(mesa, idx_nova_jog, 0) as Node3D
	assert_almost_eq(eu.position.x, float(deck[0].x), 0.001,
		"D53: na compra do JOGADOR a carta QUE COMPROU e que sai do baralho dele (x %.2f)." % float(deck[0].x))
	assert_almost_eq(dele.position.x, (mesa.call("_pos_mao_arco", 0, mao_rival.size(), 1) as Vector3).x, 0.0001,
		"D53: e a mao do rival nao mexe.")
	# --- (b) a chacoalhada NUNCA e da mesa inteira (trava dentro do `_sacudir`) ---
	var x_rival_agora: float = (_carta_da_mao(mesa, 0, 1) as Node3D).position.x
	var x_mesa: float = no_cartas.position.x
	mesa.call("_sacudir", no_cartas)
	await wait_process_frames(4)
	assert_almost_eq(no_cartas.position.x, x_mesa, 0.0001,
		"D53: a mesa inteira (o guarda-chuva das 20+ cartas) NUNCA sacode - era o que movia as DUAS maos juntas (x %.4f)." % no_cartas.position.x)
	assert_almost_eq((_carta_da_mao(mesa, 0, 1) as Node3D).position.x, x_rival_agora, 0.0001,
		"D53: e a mao do outro lado continua no lugar depois da chacoalhada.")
	# --- e nada disso encostou no DADO (R1) ---
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array).size(), n0,
		"R1: a compra mexeu so no desenho - o DADO da mao esta do tamanho de antes, porque o motor trocou uma carta por outra.")


## A COMPRA DO RIVAL SÓ CAI DEPOIS QUE A CÂMERA PAROU NA PERSPECTIVA DELE.
## O motor troca o jogador e compra na MESMA chamada de fase, então o tempo da
## compra é escolhido pela MESA: se ela entrasse antes da volta, a carta nova do
## rival aparecia na mão dele com a câmera ainda na sua frente, e o jogador via a
## compra alheia na tela errada.
##
## O teste passa o turno de verdade e olha, a CADA QUADRO, o giro da câmera e o
## tamanho da mão do rival — e afirma que o primeiro quadro em que a mão cresce
## já é com a câmera parada nos 180.
func test_a_compra_do_rival_so_cai_depois_que_a_camera_parou() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var vista := _vista(mesa)
	# Prepara: vez do JOGADOR, fora da fase da mão (START é bloqueado nela), e a
	# mão do RIVAL em 4 — só assim o motor compra algo para ele.
	st.set("current_player", 0)
	st.set("phase", "BATTLE")
	mesa.set("_fase_jogador", 1) # FASE_CAMPO
	var mao_rival: Array = ((st.players[1] as Dictionary)["hand"] as Array)
	mao_rival.pop_back()
	var alvo_n: int = mao_rival.size()
	mesa.call("_redesenhar", false)
	var primeiro_crescimento := -1
	var girando_no_crescimento := true
	var giro_no_crescimento := 0.0
	mesa.call("_passar_turno")   # sem await: o turno roda e o teste observa
	var guarda := 0
	while guarda < 400:
		guarda += 1
		await wait_process_frames(1)
		var n: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
		if n > alvo_n and primeiro_crescimento < 0:
			primeiro_crescimento = guarda
			girando_no_crescimento = bool(vista.get("girando"))
			giro_no_crescimento = float(vista.get("giro_campo"))
		if primeiro_crescimento >= 0 and not bool(vista.get("girando")) and n > alvo_n:
			break
		if not is_instance_valid(mesa):
			break
	assert_true(primeiro_crescimento > 0,
		"A mao do rival cresceu durante o turno (o motor comprou): %d -> %d." % [alvo_n,
			((st.players[1] as Dictionary)["hand"] as Array).size()])
	assert_false(girando_no_crescimento,
		"A compra do rival NAO acontece com a mesa girando (giro %.1f, girando=%s)." % [
			giro_no_crescimento, girando_no_crescimento])
	assert_almost_eq(giro_no_crescimento, 180.0, 0.5,
		"E acontece com a camera JA PARADA na perspectiva do rival: giro %.1f." % giro_no_crescimento)


## Retângulo de tela (topo, base) de uma fileira de monstro, sem depender de
## qual lado a câmera está: as DUAS bordas do ladrilho, e a menor/maior y.
func _fileira_de_monstro(mesa: Node, lado: int) -> Vector2:
	var a := float(mesa.call("_borda_da_fileira_px", lado, "monstro", true))
	var b := float(mesa.call("_borda_da_fileira_px", lado, "monstro", false))
	return Vector2(minf(a, b), maxf(a, b))


## (10) D52 — AS DUAS MÃOS, UMA EM CADA LUGAR, NAS DUAS VISÕES. É o pedido do
## usuário na conversa de 2026-09-30 (itens 1, 2 e 3 dele): na visão do rival a
## SUA mão tem que aparecer do outro lado da tela "igual as cartas do inimigo
## aparecem na minha rodada", e as cartas do rival "posicionadas exatamente como
## aparecem pra mim, mas tapadas". A regra: QUEM ESTÁ JOGANDO ocupa o lugar de
## BAIXO e o outro o de CIMA, e na vista do rival cada lugar é o ESPELHO do
## lugar da sua vista (a D51 já deixou as duas vistas espelhadas).
##
## Antes: a sua mão ficava a 23,6° do eixo da câmera do rival (FOV de 20°, metade
## 10°) e NÃO APARECIA, e a do rival aparecia cortada embaixo. Agora as duas
## aparecem nas duas vistas, e a de baixo do rival é a mesma caixa de tela da de
## baixo do jogador — que é literalmente o "exatamente como aparecem pra mim".
func test_as_duas_maos_trocam_de_lugar_e_as_duas_aparecem() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var n0: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var n1: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
	assert_true(n0 > 0 and n1 > 0, "Preparo: as DUAS mãos têm cartas (se uma estiver vazia não há o que provar).")
	if n0 <= 0 or n1 <= 0:
		return
	var sim: float = float(_vista(mesa).get("z_simetria"))
	# --- SUA VISTA: quem joga embaixo, o outro em cima, e as DUAS na tela ---
	assert_eq(int(mesa.call("_dono_do_lugar_perto")), 0,
		"D52: na sua visão o lugar de baixo é a SUA mão (quem está jogando).")
	var baixo_jogador := _lugar_na_tela(mesa, 0, n0, 0)
	var cima_jogador := _lugar_na_tela(mesa, 0, n1, 1)
	var x_mundo_rival_0 := (mesa.call("_pos_mao_arco", 0, n1, 1) as Vector3).x
	assert_true(baixo_jogador["y"] > 0.0 and baixo_jogador["y"] < float(mesa.get("TELA_A")),
		"D52: na sua visão o topo da carta da sua mão está NA TELA (y %.0f) - ela aparece." % baixo_jogador["y"])
	assert_true(cima_jogador["y"] > 0.0 and cima_jogador["w"] < float(mesa.get("TELA_A")),
		"D52: na sua visão a mão de cima está INTEIRA na tela (%.0f..%.0f)." % [cima_jogador["y"], cima_jogador["w"]])
	# --- VISTA DO RIVAL: as DUAS na tela, e os lugares espelhados ---
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	assert_eq(int(mesa.call("_dono_do_lugar_perto")), 1,
		"D52: na visão do rival o lugar de baixo é a MÃO DELE (quem está jogando).")
	var baixo_rival := _lugar_na_tela(mesa, 0, n1, 1)
	var cima_rival := _lugar_na_tela(mesa, 0, n0, 0)
	assert_true(baixo_rival["y"] > 0.0 and baixo_rival["y"] < float(mesa.get("TELA_A")),
		"D52: na visão do RIVAL a mão DELE aparece embaixo, com o topo na tela (y %.0f)." % baixo_rival["y"])
	assert_true(cima_rival["y"] > 0.0 and cima_rival["w"] < float(mesa.get("TELA_A")),
		"D52: na visão do RIVAL a SUA mão aparece em cima, INTEIRA (%.0f..%.0f) - antes ela nao aparecia." % [
			cima_rival["y"], cima_rival["w"]])
	# E o lugar de baixo do rival é o MESMO LUGAR DE TELHA do de baixo do jogador:
	# mesmo X, mesma altura, mesma base (é o "exatamente como as minhas aparecem
	# pra mim" — e o tamanho também, porque a profundidade é a mesma: 8,2 unidades
	# da câmera dos dois).
	assert_almost_eq(baixo_rival["cx"], baixo_jogador["cx"], 1.0,
		"D52: o lugar de baixo do rival cai no mesmo X de tela do seu (%.0f vs %.0f)." % [
			baixo_rival["cx"], baixo_jogador["cx"]])
	assert_almost_eq(baixo_rival["cy"], baixo_jogador["cy"], 1.0,
		"D52: e na mesma ALTURA (%.0f vs %.0f) - as cartas dele têm o tamanho e a linha das suas." % [
			baixo_rival["cy"], baixo_jogador["cy"]])
	assert_almost_eq(baixo_rival["y"], baixo_jogador["y"], 1.0,
		"D52: o topo da carta cai na mesma linha (%.0f vs %.0f) - a de baixo é cortada embaixo nas DUAS vistas." % [
			baixo_rival["y"], baixo_jogador["y"]])
	assert_almost_eq(baixo_rival["w"], baixo_jogador["w"], 1.0,
		"D52: e a base também (%.0f vs %.0f)." % [baixo_rival["w"], baixo_jogador["w"]])
	assert_almost_eq(cima_rival["cx"], cima_jogador["cx"], 1.0,
		"D52: o lugar de cima do rival cai no mesmo X do seu (%.0f vs %.0f)." % [
			cima_rival["cx"], cima_jogador["cx"]])
	assert_almost_eq(cima_rival["y"], cima_jogador["y"], 1.0,
		"D52: o lugar de cima do rival cai na mesma ALTURA do seu (%.0f vs %.0f)." % [
			cima_rival["y"], cima_jogador["y"]])
	# E o arco: no MUNDO o X espelha (a câmera do rival está do outro lado da
	# mesa), mas na TELHA o índice 0 continua à ESQUERDA — que é a mão do rival
	# vista por ele (D45 item 8 + D18). A trava é no X de mundo: o índice 0 da
	# mão DELE, que na sua vista estava em +1,72 (lugar de cima, espelhado), está
	# em -1,72 na de baixo espelhada do lugar de cima... e o índice 0 da SUA mão
	# na visão do rival é o MESMO número da mão do rival na sua visão (as duas
	# estão no lugar de cima, que é espelhado).
	assert_almost_eq((mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3).x, -1.72, 0.0001,
		"D52: na visão do rival a SUA mão (lugar de cima, espelhado) tem o índice 0 no X de %.2f." % -1.72)
	assert_almost_eq(x_mundo_rival_0, 1.72, 0.0001,
		"D52: na SUA visão a mão do rival (lugar de cima, espelhado) tem o índice 0 no X de %.2f." % 1.72)
	# --- O Z DE CADA LUGAR É O ESPELHO EXATO (2 x z_simetria - z) ---
	var z_baixo := float(mesa.get("LUGAR_PERTO_YZ").y)
	var z_cima := float(mesa.get("LUGAR_LONGE_YZ").y)
	assert_almost_eq((mesa.call("_pos_mao_arco", 0, n1, 1) as Vector3).z, 2.0 * sim - z_baixo, 0.0001,
		"D52: na visão do rival o lugar de baixo está no Z espelhado (%.3f)." % (2.0 * sim - z_baixo))
	assert_almost_eq((mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3).z, 2.0 * sim - z_cima, 0.0001,
		"D52: na visão do rival o lugar de cima está no Z espelhado (%.3f)." % (2.0 * sim - z_cima))
	# --- AS DUAS MÃOS DO RIVAL MOSTRAM O VERSO (nada de nome/ATK por cima) ---
	for dono in [0, 1]:
		var carta := _carta_da_mao(mesa, 0, dono)
		assert_true(carta != null, "D52: a carta 0 da mão do dono %d está desenhada na vista do rival." % dono)
		if carta == null:
			continue
		var nome := carta.get_node_or_null("Nome") as Label3D
		var stats := carta.get_node_or_null("Stats") as Label3D
		var tag := carta.get_node_or_null("TagPos") as Label3D
		assert_true(nome == null or not nome.visible,
			"D52: carta tapada = sem o nome em cima do verso (mão do dono %d)." % dono)
		assert_true(stats == null or not stats.visible,
			"D52: carta tapada = sem ATK/DEF em cima do verso (mão do dono %d)." % dono)
		assert_true(tag == null or not tag.visible,
			"D52: na vista do rival não vaza o selo de fusão da sua mão (dono %d)." % dono)
	# E a inclinação: as duas de pé (o verso de uma carta não é o espelho da
	# frente dela, então na vista do rival as DUAS ficam com a mesma).
	var tilt_perto := float((mesa.call("_pose_da_mao", true) as Dictionary)["tilt"])
	var tilt_longe := float((mesa.call("_pose_da_mao", false) as Dictionary)["tilt"])
	assert_almost_eq(tilt_longe, tilt_perto, 0.0001,
		"D52: na vista do rival as DUAS mãos ficam de pé (a do rival %.1f, a sua %.1f)." % [tilt_longe, tilt_perto])
	assert_true(float(mesa.get("TILT_MAO_LIVRE")) < 0.0 and tilt_perto > 0.0,
		"D52: a inclinação do rival é a da sua espelhada (sua %.0f, rival %.0f)." % [
			float(mesa.get("TILT_MAO_LIVRE")), tilt_perto])
	# --- O CURSOR SOME NA VISTA DO RIVAL (ele ficaria em cima da mão dele) ---
	assert_false((mesa.get("_cursor") as Node3D).visible,
		"D52: na vista do rival o cursor some (senão ficaria em cima da mão dele).")
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_true((mesa.get("_cursor") as Node3D).visible,
		"D52: na sua volta o cursor volta.")
	# --- A TROCA ACONTECE NOS 90 GRAUS (e não antes) ---
	# 89 graus ainda é a sua vista (a sua mão embaixo, o Z de baixo = 12,7) e 91
	# já é a do rival (a sua mão em cima, no Z espelhado). É o instante em que
	# a tela não mostra nada: as mãos estão a 32,7 graus do eixo.
	_vista(mesa).call("_passo", 89.0 / 180.0, 180.0)
	await wait_process_frames(2)
	assert_eq(int(mesa.call("_dono_do_lugar_perto")), 0,
		"D52: em 89 graus ainda é a vista do jogador (a troca é nos 90).")
	assert_almost_eq((mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3).z, z_baixo, 0.0001,
		"D52: em 89 graus a sua mão ainda está no lugar de baixo do jogador.")
	_vista(mesa).call("_passo", 91.0 / 180.0, 180.0)
	await wait_process_frames(2)
	assert_eq(int(mesa.call("_dono_do_lugar_perto")), 1,
		"D52: em 91 graus já é a vista do rival (a troca foi nos 90).")
	assert_almost_eq((mesa.call("_pos_mao_arco", 0, n0, 0) as Vector3).z, 2.0 * sim - z_cima, 0.0001,
		"D52: em 91 graus a sua mão já está no lugar de cima espelhado.")
	# --- E O DADO NAO SE MEXE (R1): as duas mãos são as mesmas cartas, na mesma
	# ordem, dos mesmos donos. A volta é ponto de vista + lugar, nunca regra.
	var antes0: Array = ((st.players[0] as Dictionary)["hand"] as Array).duplicate(true)
	var antes1: Array = ((st.players[1] as Dictionary)["hand"] as Array).duplicate(true)
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["hand"] as Array), antes0,
		"D52: a sua mão no DADO é a mesma depois de ir ao rival e voltar (R1).")
	assert_eq(((st.players[1] as Dictionary)["hand"] as Array), antes1,
		"D52: a mão do rival no DADO é a mesma depois da volta (R1).")


## Onde o LUGAR de uma mão cai na tela: `cx`/`cy` = o centro da carta projetado,
## `y`/`w` = o topo e a base da carta na tela. Compara o CENTRO (e não a borda)
## porque a câmera do rival espelha o X do mundo: a borda esquerda de uma vista
## é a direita da outra, e o que tem que bater é o miolinho.
func _lugar_na_tela(mesa: Node, idx: int, n: int, dono: int) -> Dictionary:
	var cam := mesa.get_node(CAMERA) as Camera3D
	var perto: bool = dono == int(mesa.call("_dono_do_lugar_perto"))
	var centro: Vector3 = mesa.call("_pos_mao_arco", idx, n, dono)
	var tilt := float((mesa.call("_pose_da_mao", perto) as Dictionary)["tilt"])
	var caixa: Vector4 = mesa.call("_caixa_carta_tela", centro, tilt)
	var q := cam.unproject_position(centro)
	return {"cx": q.x, "cy": q.y, "y": caixa.y, "w": caixa.w}


## O vão entre as DUAS fileiras de monstro, na vista em que a câmera está: a
## base da fileira que está em cima e o topo da que está embaixo.
func _vao_das_fileiras(mesa: Node) -> Vector2:
	var f0 := _fileira_de_monstro(mesa, 0)
	var f1 := _fileira_de_monstro(mesa, 1)
	var cima := f0 if f0.x < f1.x else f1
	var baixo := f1 if f0.x < f1.x else f0
	return Vector2(cima.y, baixo.x)



## (3) A volta vai a 180 e VOLTA a 0, e o resultado e o mesmo com e sem render
## (o GUT roda sem render, entao este e o caminho de verdade do estado final).
func test_a_volta_vai_a_180_e_volta_a_zero() -> void:
	var mesa: Node = await _mesa3d_nova()
	var pivo := mesa.get_node(PIVO) as Node3D
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	assert_eq(float(_vista(mesa).get("giro_campo")), 180.0, "Depois da volta a mesa esta na visao do rival.")
	assert_eq(pivo.rotation_degrees.y, 180.0, "O pivo girou 180 graus.")
	assert_false(bool(_vista(mesa).get("girando")), "A volta acabou (a trava de controle liberou).")
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_eq(float(_vista(mesa).get("giro_campo")), 0.0, "A mesa voltou para a visao do jogador.")
	assert_eq(pivo.rotation_degrees.y, 0.0, "O pivo voltou a 0.")
	# Girar duas vezes no MESMO lugar nao faz nada (idempotente, e nao trava).
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_eq(float(_vista(mesa).get("giro_campo")), 0.0, "Girar para o mesmo lugar e no-op.")


## (4) A TRAVA CENTRAL DA D47: as cartas do campo NAO SE MEXEM. Nenhuma posicao
## de mundo muda com a volta. E o que substitui toda a antiga maquina de
## perspectiva (que movia as cartas de ladrilho).
func test_as_cartas_do_campo_nao_se_mexem_na_volta() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	await _campo_cheio(mesa, st)
	var antes := _posicoes(mesa)
	assert_eq(antes.size(), 12, "Preparo: as 10 do campo + os 2 dorsos de baralho estao desenhados.")
	if antes.size() < 12:
		return
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	var depois := _posicoes(mesa)
	assert_eq(depois.size(), 12, "Depois da volta as 12 cartas continuam desenhadas.")
	for sid in antes:
		assert_true(depois.has(sid), "A carta %s continua desenhada depois da volta." % sid)
		if not depois.has(sid):
			continue
		var a: Vector3 = antes[sid] as Vector3
		var b: Vector3 = depois[sid] as Vector3
		assert_almost_eq(b.x, a.x, 0.0001, "A carta %s nao mudou de X no mundo." % sid)
		assert_almost_eq(b.y, a.y, 0.0001, "A carta %s nao mudou de Y no mundo." % sid)
		assert_almost_eq(b.z, a.z, 0.0001, "A carta %s nao mudou de Z no mundo (viajou ZERO)." % sid)
	# E as MAOS: ate a D52 elas tambem ficavam paradas no mundo, e a volta
	# so mudava de que lado elas eram vistas. O usuario trocou isso (decisao
	# D52): na visao do rival a mao de quem JOGA tem que estar embaixo, grande
	# e tapada, e a outra em cima — as duas trocam de LUGAR. O que continua
	# travado e que nada disso encosta no DADO: as duas maos continuam as
	# mesmas cartas dos mesmos donos, no mesmo indice, e a ida e volta devolve
	# cada uma ao seu lugar (a troca e feita nos 90 graus, com a tela virada).
	var m0 := _carta_da_mao(mesa, 0, 0)
	var m1 := _carta_da_mao(mesa, 0, 1)
	assert_true(m0 != null and m1 != null, "As duas maos estao desenhadas.")
	if m0 != null and m1 != null:
		# Na visao do RIVAL a mao do RIVAL e a que esta embaixo (perto da
		# camera dele) e a do jogador a que esta em cima (longe).
		assert_true(m1.position.z < m0.position.z,
			"D52: na visao do rival a mao do RIVAL e a de baixo (z %.2f < z %.2f)." % [
				m1.position.z, m0.position.z])
		assert_almost_eq(m1.position.x, 2.16, 0.0001,
			"D52: na visao do rival a mao DELE e a de baixo, com o indice 0 no X de mundo ESPELHADO (+2,16) - na TELHA ele ve a propria mao na ordem normal.")
		assert_almost_eq(m0.position.x, -1.72, 0.0001,
			"D52: na visao do rival a sua mao e a de cima (indice 0 no X de -1,72, o lugar espelhado).")
		mesa.call("_girar_campo", 0.0)
		await wait_process_frames(2)
		var v0 := _carta_da_mao(mesa, 0, 0)
		var v1 := _carta_da_mao(mesa, 0, 1)
		assert_true(v0 != null and v1 != null, "As maos continuam desenhadas depois de voltar.")
		if v0 != null and v1 != null:
			assert_true(v0.position.z > v1.position.z,
				"D52: voltou a visao do jogador e a mao do jogador e a de baixo (z %.2f > z %.2f)." % [
					v0.position.z, v1.position.z])
			assert_almost_eq(v0.position.x, -2.16, 0.0001,
				"D52: a sua mao voltou EXATAMENTE onde estava (indice 0 do arco de baixo).")
			assert_almost_eq(v1.position.x, 1.72, 0.0001,
				"D52: a mao do rival voltou EXATAMENTE onde estava (indice 0 do arco de cima espelhado).")


## (5) O GameState nao se mexe: a carta continua no mesmo indice (R1).
func test_o_estado_nao_se_mexe_na_volta() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	await _campo_cheio(mesa, st)
	var antes: Array = ((st.players[0] as Dictionary)["monster"] as Array).duplicate(true)
	var antes1: Array = ((st.players[1] as Dictionary)["monster"] as Array).duplicate(true)
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["monster"] as Array), antes,
		"O campo do jogador e o MESMO depois da volta (a volta e so o ponto de vista).")
	assert_eq(((st.players[1] as Dictionary)["monster"] as Array), antes1,
		"O campo do rival e o MESMO depois da volta.")
	# E a carta desenhada em m2 continua sendo a do indice 2 (identidade).
	for lado in [0, 1]:
		var esperado: Dictionary = (st.players[lado] as Dictionary)["monster"][2] as Dictionary
		var carta: Node3D = _carta_do_campo(mesa, lado, 2)
		assert_true(carta != null, "A carta do p%d m2 continua desenhada." % lado)
		if carta != null:
			assert_eq(str(carta.get_meta("card_id")), str(esperado.get("card_id", "")),
				"A carta desenhada em m2 do p%d e a do indice 2 (a volta nao troca as cartas de lugar)." % lado)


## (6) Cada jogador ve a PROPRIA fileira na ordem normal. O lado 1 da arena ja
## vem espelhado no X (D18) e a volta de 180 espelha de novo, entao os dois se
## cancelam: indice 0 sempre a esquerda. E o que o usuario pediu em 2026-09-28
## ("a minha carta do slot 1 tem que aparecer no slot 5") - e aqui sai de graca.
func test_cada_jogador_ve_a_propria_fileira_na_ordem_normal() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	await _campo_cheio(mesa, st)
	var cam := mesa.get_node(CAMERA) as Camera3D
	for giro in [0.0, 180.0]:
		mesa.call("_girar_campo", giro)
		await wait_process_frames(2)
		for lado in [0, 1]:
			var x0: float = cam.unproject_position(mesa.call("_pos_slot", lado, "monstro", 0)).x
			var x4: float = cam.unproject_position(mesa.call("_pos_slot", lado, "monstro", 4)).x
			# Na visao do jogador: o indice 0 dele e o da esquerda. Na visao do
			# rival: a fileira do RIVAL e a de baixo e o indice 0 dele e o da
			# esquerda tambem (e a do jogador, que e a de cima, e espelhada -
			# que e o ponto de vista do outro, nao o seu).
			if lado == giro / 180.0:
				assert_true(x0 < x4,
					"Volta %.0f: a fileira de quem joga tem o indice 0 a ESQUERDA (%.0f < %.0f)." % [
						giro, x0, x4])
			else:
				assert_true(x0 > x4,
					"Volta %.0f: a fileira do outro ve o indice 0 a DIREITA (%.0f > %.0f) - e o espelho, de proposito." % [
						giro, x0, x4])
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)


## (7) O HUD 2D NAO gira: ele vira de carta. A escala e 1 em 0 e em 180, e 0
## (invisivel) em 90 - que e onde o conteudo troca, entao ninguem ve a troca.
func test_o_hud_vira_de_carta_e_troca_nos_90_graus() -> void:
	var mesa: Node = await _mesa3d_nova()
	var bloco := mesa.get_node("HUD/RetratoVoce") as Control
	assert_true(bloco != null, "O retrato existe (e vira de carta).")
	if bloco == null:
		return
	_vista(mesa).set("giro_campo", 0.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(bloco.scale.x, 1.0, 0.001, "Em 0 graus o bloco esta com a largura inteira.")
	_vista(mesa).set("giro_campo", 45.0)
	mesa.call("_aplicar_vista_hud")
	var meio: float = bloco.scale.x
	assert_true(meio < 0.75 and meio > 0.25,
		"Em 45 graus o bloco ja esta encolhendo (%.2f) - ele vira, nao some de uma vez." % meio)
	_vista(mesa).set("giro_campo", 90.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(bloco.scale.x, 0.0, 0.001,
		"Em 90 graus o bloco tem largura ZERO (e o e o instante da troca, invisivel).")
	_vista(mesa).set("giro_campo", 180.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(bloco.scale.x, 1.0, 0.001, "Em 180 graus o bloco volta a ter a largura inteira.")


## (8) D46b continua valendo: na vez do rival o painel esquerdo mostra so a
## imagem padronizada, sem nenhum dado da carta.
func test_o_painel_esquerdo_continua_neutro_na_vez_do_rival() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var painel: Control = mesa.get("_painel") as Control
	var lbl_nome: Label = painel.get_node("FocoNome") as Label
	var lbl_stats: Label = painel.get_node("FocoFaixa/FocoStats") as Label
	var lbl_tipo: Label = painel.get_node("FocoTipo") as Label
	var lbl_desc: Label = painel.get_node("BlocoDesc/FocoDesc") as Label
	assert_true(lbl_nome != null and lbl_stats != null, "O painel esquerdo tem as pecas de texto.")
	if lbl_nome == null or lbl_stats == null or lbl_tipo == null or lbl_desc == null:
		return
	st.set("current_player", 0)
	mesa.call("_atualizar_painel_foco")
	assert_false(lbl_nome.text.is_empty(), "Na sua vez o painel mostra a carta de verdade.")
	st.set("current_player", 1)
	mesa.call("_atualizar_painel_foco")
	assert_eq(lbl_nome.text, "", "D46b: na vez do rival o nome some.")
	assert_eq(lbl_stats.text, "", "D46b: na vez do rival o ATK/DEF some.")
	assert_eq(lbl_tipo.text, "", "D46b: na vez do rival o tipo some.")
	assert_eq(lbl_desc.text, "", "D46b: na vez do rival a descricao some.")
	st.set("current_player", 0)


## (9) O controle fica TRAVADO enquanto a mesa gira (sem isto a carta focada
## andaria de um lado para o outro da tela no meio do giro).
func test_o_controle_fica_travado_enquanto_a_mesa_gira() -> void:
	var mesa: Node = await _mesa3d_nova()
	# Headless nao anima, entao o teste trava a bandeira na mao e prova as DUAS
	# coisas: que a bandeira existe e que a entrada respeita ela.
	_vista(mesa).set("girando", true)
	assert_true(bool(_vista(mesa).get("girando")), "A mesa sabe que esta girando.")
	var log_antes: int = (mesa.get("_log") as Array).size()
	# Chama o que a entrada chamaria: nao pode mexer em nada enquanto gira.
	var sel_antes: int = int(mesa.get("_sel_atk"))
	mesa.call("_mover", 1, 0)
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sel_atk")), sel_antes,
		"Girando: a entrada nao mexe no atacante escolhido.")
	_vista(mesa).set("girando", false)
	assert_true((mesa.get("_log") as Array).size() >= log_antes,
		"A tela continua viva (o bloqueio e so do controle, nao da tela).")


## (12) O TOPO na escolha do slot: a câmera sobe e olha para baixo no passo
## do slot, e desce ANTES da estrela (o palco da segurada é calculado dela).
func test_topo_na_escolha_do_slot_e_volta_antes_da_estrela() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var vista := _vista(mesa)
	var cam := vista.get("cam") as Camera3D
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão tem monstro.")
	mesa.set("_fileira", 0)
	mesa.set("_col", idx)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), 2, "Preparo: face travada, passo do slot.")
	assert_true(bool(vista.get("no_topo")), "No passo do slot a câmera está no topo.")
	assert_almost_eq(cam.position.y, 26.0, 0.001, "Topo: câmera a 26 de altura.")
	assert_almost_eq(cam.rotation.x, -PI * 0.5, 0.001, "Topo: câmera olhando para baixo.")
	var slot: int = SummonSys.free_monster_slot(st, 0)
	mesa.set("_col", slot)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), 3, "Slot escolhido, passo da estrela.")
	assert_false(bool(vista.get("no_topo")), "Escolhido o slot, a câmera desceu do topo.")
	assert_eq(cam.position, Vector3(0.0, 16.8, 20.9), "A câmera voltou exata para a vista.")
