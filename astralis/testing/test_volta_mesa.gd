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

const Mesa3DScene := preload("res://duel3d/mesa_3d.tscn")
const SummonSys := preload("res://duel/summon_system.gd")

const CARTAS := "Camada3D/JanelaCampo/Viewport3D/Cartas"
const PIVO := "Camada3D/JanelaCampo/Viewport3D/PivoMesa"
const CAMERA := "Camada3D/JanelaCampo/Viewport3D/PivoMesa/Camera3D"
const COLUNAS := 5


func _mesa3d_nova() -> Node:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


## Carta de DADO no campo, pelo CONSTRUTOR REAL do jogo
## (`SummonSys.construir_instancia` - o unico lugar que monta instancia, R1).
## Este arquivo nao testa regra de invocacao, so o desenho.
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
	assert_eq(float(mesa.get("_giro_campo")), 0.0, "O numero da volta comeca em 0.")


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
	var z0: float = float(mesa.call("_z_local_da_camera", 0.0))
	assert_almost_eq(z0, pos_0.z, 0.0001,
		"D51: em 0 graus a câmera do jogador é a de sempre (nada muda na sua vez).")
	# (b) O PLANO DE SIMETRIA VEM DO DADO: a média das duas fileiras de monstro
	# da arena oficial (a de cima e a de baixo da tela, na vista do jogador).
	var sim: float = float(mesa.get("_z_simetria"))
	var z_p1 := (mesa.call("_pos_slot", 1, "monstro", 2) as Vector3).z
	var z_p0 := (mesa.call("_pos_slot", 0, "monstro", 2) as Vector3).z
	assert_almost_eq(sim, (z_p1 + z_p0) * 0.5, 0.0001,
		"D51: o plano de simetria do campo é a média das duas fileiras de monstro do DADO.")
	# (c) A CÂMERA DO RIVAL VAI AO ESPELHO: 2x o desvio do pivô para o lado de
	# dentro, para a distância em relação ao plano do campo ser a mesma dos
	# dois lados.
	var z180: float = float(mesa.call("_z_local_da_camera", 180.0))
	assert_almost_eq(z180, pos_0.z - 2.0 * sim, 0.0001,
		"D51: em 180 graus a câmera recua exatamente o desvio do pivô (o espelho).")
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	assert_almost_eq(cam.position.z, z180, 0.0001,
		"D51: depois da volta a câmera está no ponto do espelho.")
	# (d) A TRAVA DE VERDADE: o VÃO entre as duas fileiras de monstro é o MESMO
	# nas duas vistas. A faixa do meio é 2D, não se mexe, e foi montada com a
	# medida do vão da vista do jogador — então é isso que garante que ela
	# caia entre os slots de monstro dos dois lados.
	var vao_jogador := _vao_das_fileiras(mesa)
	var faixa := mesa.get("_faixa2d") as Control
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
	# (e) E a faixa do meio cai DENTRO do vão, com a mesma folga em cima e em
	# baixo — que é o "exatamente certa entre os slots de monstro" do usuário.
	if faixa != null:
		var folga_cima := faixa.position.y - vao_rival.x
		var folga_baixo := vao_rival.y - (faixa.position.y + faixa.size.y)
		assert_true(folga_cima > 0.0 and folga_baixo > 0.0,
			"D51: a faixa do meio está DENTRO do vão na vista do rival (folgas %.1f / %.1f)." % [
				folga_cima, folga_baixo])
		assert_almost_eq(folga_cima, folga_baixo, 1.0,
			"D51: a faixa fica CENTRADA no vão da vista do rival (folgas %.1f / %.1f)." % [
				folga_cima, folga_baixo])
		var folga_cima_j := faixa.position.y - vao_jogador.x
		var folga_baixo_j := vao_jogador.y - (faixa.position.y + faixa.size.y)
		assert_almost_eq(folga_cima, folga_cima_j, 1.0,
			"D51: a folga de cima é a mesma nas duas vistas (a faixa não se mexe).")
		assert_almost_eq(folga_baixo, folga_baixo_j, 1.0,
			"D51: a folga de baixo é a mesma nas duas vistas (a faixa não se mexe).")
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


## Retângulo de tela (topo, base) de uma fileira de monstro, sem depender de
## qual lado a câmera está: as DUAS bordas do ladrilho, e a menor/maior y.
func _fileira_de_monstro(mesa: Node, lado: int) -> Vector2:
	var a := float(mesa.call("_borda_da_fileira_px", lado, "monstro", true))
	var b := float(mesa.call("_borda_da_fileira_px", lado, "monstro", false))
	return Vector2(minf(a, b), maxf(a, b))


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
	assert_eq(float(mesa.get("_giro_campo")), 180.0, "Depois da volta a mesa esta na visao do rival.")
	assert_eq(pivo.rotation_degrees.y, 180.0, "O pivo girou 180 graus.")
	assert_false(bool(mesa.get("_girando")), "A volta acabou (a trava de controle liberou).")
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_eq(float(mesa.get("_giro_campo")), 0.0, "A mesa voltou para a visao do jogador.")
	assert_eq(pivo.rotation_degrees.y, 0.0, "O pivo voltou a 0.")
	# Girar duas vezes no MESMO lugar nao faz nada (idempotente, e nao trava).
	mesa.call("_girar_campo", 0.0)
	await wait_process_frames(2)
	assert_eq(float(mesa.get("_giro_campo")), 0.0, "Girar para o mesmo lugar e no-op.")


## (4) A TRAVA CENTRAL DA D47: as cartas do campo NAO SE MEXEM. Nenhuma posicao
## de mundo muda com a volta. E o que substitui toda a antiga maquina de
## perspectiva (que movia as cartas de ladrilho).
func test_as_cartas_do_campo_nao_se_mexem_na_volta() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	await _campo_cheio(mesa, st)
	var antes := _posicoes(mesa)
	assert_eq(antes.size(), 10, "Preparo: as 10 cartas do campo estao desenhadas.")
	if antes.size() < 10:
		return
	mesa.call("_girar_campo", 180.0)
	await wait_process_frames(2)
	var depois := _posicoes(mesa)
	assert_eq(depois.size(), 10, "Depois da volta as 10 cartas continuam desenhadas.")
	for sid in antes:
		assert_true(depois.has(sid), "A carta %s continua desenhada depois da volta." % sid)
		if not depois.has(sid):
			continue
		var a: Vector3 = antes[sid] as Vector3
		var b: Vector3 = depois[sid] as Vector3
		assert_almost_eq(b.x, a.x, 0.0001, "A carta %s nao mudou de X no mundo." % sid)
		assert_almost_eq(b.y, a.y, 0.0001, "A carta %s nao mudou de Y no mundo." % sid)
		assert_almost_eq(b.z, a.z, 0.0001, "A carta %s nao mudou de Z no mundo (viajou ZERO)." % sid)
	# E a mao tambem: a sua mao continua no mesmo lugar do mundo (o que muda e
	# que ela passa a ser vista pelas costas, que e a camera fazendo o trabalho).
	var mao0 := _carta_da_mao(mesa, 0)
	var mao1 := _carta_da_mao(mesa, 1)
	assert_true(mao0 != null and mao1 != null, "As duas maos estao desenhadas.")
	if mao0 != null and mao1 != null:
		var p0 := mao0.position
		var p1 := mao1.position
		mesa.call("_girar_campo", 0.0)
		await wait_process_frames(2)
		var m0 := _carta_da_mao(mesa, 0)
		var m1 := _carta_da_mao(mesa, 1)
		assert_true(m0 != null and m1 != null, "As maos continuam desenhadas depois de voltar.")
		if m0 != null and m1 != null:
			assert_almost_eq(m0.position.x, p0.x, 0.0001, "A sua mao nao mudou de X.")
			assert_almost_eq(m1.position.x, p1.x, 0.0001, "A mao do rival nao mudou de X.")


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
	var faixa := mesa.get("_faixa2d") as Control
	assert_true(faixa != null, "A faixa do meio existe (e vira de carta).")
	if faixa == null:
		return
	mesa.set("_giro_campo", 0.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(faixa.scale.x, 1.0, 0.001, "Em 0 graus a faixa esta com a largura inteira.")
	mesa.set("_giro_campo", 45.0)
	mesa.call("_aplicar_vista_hud")
	var meio: float = faixa.scale.x
	assert_true(meio < 0.75 and meio > 0.25,
		"Em 45 graus a faixa ja esta encolhendo (%.2f) - ela vira, nao some de uma vez." % meio)
	mesa.set("_giro_campo", 90.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(faixa.scale.x, 0.0, 0.001,
		"Em 90 graus a faixa tem largura ZERO (e o e o instante da troca, invisivel).")
	mesa.set("_giro_campo", 180.0)
	mesa.call("_aplicar_vista_hud")
	assert_almost_eq(faixa.scale.x, 1.0, 0.001, "Em 180 graus a faixa volta a ter a largura inteira.")


## (7b) E o conteudo da faixa se ESPELHA na virada: o seu deck e o seu LP ficam
## do lado que agora e o seu na tela, e a cor viaja com o numero.
func test_a_faixa_do_meio_se_espelha_na_volta() -> void:
	var mesa: Node = await _mesa3d_nova()
	var linha := mesa.get("_faixa_linha") as Node
	assert_true(linha != null, "A linha de celulas da faixa existe.")
	if linha == null:
		return
	var nomes := _nomes_das_celulas(linha)
	assert_eq(nomes.size(), 7, "A faixa tem as 7 celulas.")
	if nomes.size() != 7:
		return
	assert_eq(nomes[0], "MeuCemiterio", "Ordem normal comeca no seu cemiterio (esquerda).")
	assert_eq(nomes[3], "Turno", "O turno fica no meio (nao tem dono).")
	mesa.set("_giro_campo", 180.0)
	mesa.call("_aplicar_vista_hud")
	var espelhado := _nomes_das_celulas(linha)
	assert_eq(espelhado[0], "CemRival", "Virada: o cemiterio do RIVAL foi para a esquerda (invertido).")
	assert_eq(espelhado[1], "DeckRival", "Virada: o deck do RIVAL foi para o segundo lugar.")
	assert_eq(espelhado[3], "Turno", "Virada: o turno continua no meio.")
	assert_eq(espelhado[6], "MeuCemiterio", "Virada: o seu cemiterio foi para a direita.")
	# Volta: a ordem normal volta exatamente.
	mesa.set("_giro_campo", 0.0)
	mesa.call("_aplicar_vista_hud")
	assert_eq(_nomes_das_celulas(linha), nomes, "Voltou a visao do jogador: a faixa volta a ordem normal.")


func _nomes_das_celulas(linha: Node) -> Array:
	var out: Array = []
	for c in linha.get_children():
		out.append(str((c as Node).name))
	return out


## (8) D46b continua valendo: na vez do rival o painel esquerdo mostra so a
## imagem padronizada, sem nenhum dado da carta.
func test_o_painel_esquerdo_continua_neutro_na_vez_do_rival() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var lbl_nome: Label = mesa.get("_lbl_foco_nome") as Label
	var lbl_stats: Label = mesa.get("_lbl_foco_stats") as Label
	var lbl_tipo: Label = mesa.get("_lbl_foco_tipo") as Label
	var lbl_desc: Label = mesa.get("_lbl_foco_desc") as Label
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
	mesa.set("_girando", true)
	assert_true(bool(mesa.get("_girando")), "A mesa sabe que esta girando.")
	var log_antes: int = (mesa.get("_log") as Array).size()
	# Chama o que a entrada chamaria: nao pode mexer em nada enquanto gira.
	var sel_antes: int = int(mesa.get("_sel_atk"))
	mesa.call("_mover", 1, 0)
	await wait_process_frames(2)
	assert_eq(int(mesa.get("_sel_atk")), sel_antes,
		"Girando: a entrada nao mexe no atacante escolhido.")
	mesa.set("_girando", false)
	assert_true((mesa.get("_log") as Array).size() >= log_antes,
		"A tela continua viva (o bloqueio e so do controle, nao da tela).")


## A carta da mao no indice pedido, pelo meta `mao_idx`.
func _carta_da_mao(mesa: Node, idx: int) -> Node3D:
	var cartas: Node = mesa.get_node(CARTAS)
	var achada: Node3D = null
	for f in cartas.get_children():
		if (f as Node).has_meta("mao_idx") and int((f as Node).get_meta("mao_idx")) == idx:
			# D47: a mao de baixo e a do JOGADOR (a unica aberta).
			if (f as Node).get_node_or_null("Nome") != null:
				var nome := (f as Node).get_node("Nome") as Label3D
				if nome != null and nome.visible:
					achada = f as Node3D
	return achada
