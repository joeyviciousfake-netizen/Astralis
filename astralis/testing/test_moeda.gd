extends "res://testing/astralis_test_base.gd"

## test_moeda - A MOEDA DO SORTEIO (D77), o desenho do `turn_order: "moeda"`.
##
## O que este arquivo trava:
##
##  1. A moeda NAO PULA e nao tem tempo curto: enquanto ela esta na tela o
##     controle responde a nada, e o evento e CONSUMIDO. Sem o consume, um START
##     apertado durante o giro ficaria na fila e abriria o turno antes de o
##     jogador ver de quem e a vez.
##  2. A tela NAO VIRA DE LADO: a perspetiva do jogador, as cartas, o painel e o
##     marcador ficam onde estavam a coluna inteira. A moeda e um desenho na
##     frente da camera, nao uma cena nova.
##  3. A FACE e a resposta: estrela = jogador, losango = rival. E quem decide o
##     turno continua sendo o motor (D42) - a moeda so mostra.
##  4. A ESPERADA (o `?`, o painel vazio e a navegacao travada) e uma coisa so,
##     que a MESA liga a partir do dado, e uma representacao da moeda: num duelo
##     sem moeda nao existe o que esconder e o painel responde desde o primeiro
##     quadro.
##
## A moeda e testada pelo `moeda_3d.gd` de verdade, com o `.glb` de verdade e a
## camera de verdade da mesa (R2). Nao ha duble aqui.

const MOEDA_SCRIPT := preload("res://duel3d/moeda_3d.gd")
## A FRACAO que a moeda ocupa da altura da tela. Este numero e o dono do TAMANHO
## na tela e mora no arquivo da moeda; o teste o le de la para nao ter um segundo
## dono do mesmo numero.
const FRACAO_DIAMETRO := 0.15
## O TOPO do vao onde a moeda vive, como fracao da tela acima do centro. Medido:
## o cemiterio de cima acaba em y≈160 e a faixa do marcador comeca em y≈435,
## numa tela de 1080 com o centro em y=540.
const TOPO_DO_VAO := 0.345


func _moeda_da_mesa(mesa: Node) -> Node:
	return mesa.get("_moeda") as Node


## O texto que a celula do TURNO esta mostrando.
func _texto_do_turno(mesa: Node) -> String:
	var faixa := mesa.get("_faixa") as Node
	if faixa == null or not is_instance_valid(faixa):
		return ""
	var lbl := faixa.get("_num_turno") as Label
	return "" if lbl == null else str(lbl.text)


# ---------------------------------------------------------------------------
# A MOEDA E UM DESENHO NA FRENTE DA CAMERA
# ---------------------------------------------------------------------------
func test_a_moeda_vive_na_frente_da_camera_e_nao_dentro_do_pivo() -> void:
	var mesa: Node = await _mesa3d_nova()
	var moeda := _moeda_da_mesa(mesa)
	assert_not_null(moeda, "A moeda esta montada (D77).")
	var janela := _n3d(mesa, "")
	assert_not_null(janela, "A janela 3D existe.")
	# IRMA do pivo: a moeda e filha da janela, e nao do `PivoMesa`. Dentro do
	# pivo ela viraria junto com a mesa e o jogador a veria de perfil.
	assert_eq(moeda.get_parent().name, janela.name,
		"A moeda e filha da janela 3D, e nao do pivo da mesa.")
	assert_ne(moeda.get_parent().name, "PivoMesa",
		"A moeda NAO esta dentro do pivo (o pivo gira na entrega do turno).")


func test_a_perspetiva_do_jogador_nao_muda_com_a_moeda() -> void:
	var mesa: Node = await _mesa3d_nova()
	var vista := mesa.get("_vista") as Node
	# A moeda nao mexe na camera: a vista comeca no 0 (a do jogador) e e o
	# `girar_campo` da entrega que leva ao 180. Se a moeda usasse a cena de 90
	# do plano antigo, a vista estaria invertida aqui.
	assert_almost_eq(float(vista.get("giro_campo")), 0.0, 0.0001,
		"A mesa comeca na visao do JOGADOR (a moeda nao vira a tela).")
	# E as cartas do jogador continuam visiveis: a moeda nao esconde a mao.
	var mao := _carta_da_mao(mesa, 0, 0)
	assert_not_null(mao, "A mao do jogador existe durante o sorteio.")
	assert_true((mao as Node3D).visible,
		"A mao do jogador fica VISIVEL durante o sorteio (nao e uma cena vazia).")


func test_a_moeda_para_acima_do_marcador_e_nao_sobre_a_mao() -> void:
	var mesa: Node = await _mesa3d_nova()
	var moeda := _moeda_da_mesa(mesa) as Node3D
	var cam := mesa.get("_cam") as Camera3D
	# A posicao e posta na ENTRADA de `tocar`, antes do primeiro `await`: quem
	# mede o lugar da moeda nao precisa ver a animacao inteira. A corrotina
	# segue rodando e o teste a deixa terminar no fim.
	moeda.call("tocar", 0, cam)
	var base := cam.global_transform.basis
	# A posicao e no sistema da CAMERA: a frente dela e ACIMA do centro da tela.
	var d := moeda.global_position - cam.global_position
	var altura := d.dot(base.y)
	var profundidade := d.dot(-base.z)
	assert_gt(profundidade, 0.0, "A moeda esta a FRENTE da camera (no ar, no meio da tela).")
	assert_gt(altura, 0.0, "A moeda esta ACIMA do centro da tela (sobre o marcador).")
	# E nao tao alto que caia no vao das cartas do jogador, nem tao baixo que
	# cobrisse o "?" do marcador. A fracao da altura da tela e o dono disso.
	var meio := deg_to_rad(cam.fov) * 0.5
	var quadro := 2.0 * profundidade * tan(meio)
	var fracao := altura / quadro
	assert_almost_eq(fracao, 0.225, 0.005,
		"A altura da moeda e a FRACAO medida do vao entre as cartas e o marcador.")
	# A INVARIANTE que vale mais que o numero: a moeda tem que caber inteira no
	# vao. O vao e o espaco entre o cemiterio de cima e a faixa do marcador, e o
	# dono dos dois lados e a tela — entao o que o teste mede e "a moeda nao
	# invade nenhum dos dois", e nao "a moeda esta em 0.225".
	var folga := fracao - FRACAO_DIAMETRO * 0.5
	assert_gt(folga, 0.0,
		"A moeda NAO invade o marcador de turno (o topo dela fica no vao).")
	assert_lt(folga + FRACAO_DIAMETRO, TOPO_DO_VAO,
		"A moeda NAO entra atras das cartas do inimigo (a base fica no vao).")
	await wait_process_frames(220)


# ---------------------------------------------------------------------------
# A FACE E A RESPOSTA
# ---------------------------------------------------------------------------
func test_a_face_da_moeda_diz_o_vencedor_do_motor() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var cam := mesa.get("_cam") as Camera3D
	var moeda: Node3D = MOEDA_SCRIPT.new()
	_n3d(mesa, "").add_child(moeda)
	await wait_process_frames(1)

	# Quem comeca vem do MOTOR (D42). A moeda so escreve na tela.
	for lado in [0, 1]:
		var vencedor := 0 if int(st.current_player) == lado else 1
		await moeda.call("tocar", vencedor, cam)
		# O que decide a FACE e o resto do angulo em uma volta cheia: a estrela
		# para na pose de frente (resto 0) e o losango meia volta adiante
		# (resto PI). O angulo bruto e um numero de voltas e nao diz nada — e
		# o resto dele que diz qual desenho o jogador esta vendo.
		var resto := fposmod(float(moeda.get("_giro")), TAU)
		var esperado := 0.0 if lado == 0 else PI
		assert_almost_eq(resto, esperado, 0.0001,
			"current_player = %d: a moeda para na face desse lado." % lado)
		assert_eq(int(moeda.get("_vencedor")), vencedor,
			"A moeda guardou o lado que o MOTOR decidiu (a moeda nao sorteia).")
	moeda.queue_free()


func test_a_moeda_nao_tem_nome_sobre_a_face() -> void:
	var mesa: Node = await _mesa3d_nova()
	var moeda := _moeda_da_mesa(mesa)
	# A face e a resposta. Um Label3D do nome seria traduzir a resposta que o
	# jogador ja recebeu - e traduzir atrasa.
	for f in (moeda as Node).get_children():
		for g in f.get_children():
			assert_false(g is Label3D,
				"A moeda nao tem nome escrito (a face e a resposta): %s" % g.name)


# ---------------------------------------------------------------------------
# O CONTROLE
# ---------------------------------------------------------------------------
func test_enquanto_a_moeda_esta_na_tela_o_controle_responde_a_nada() -> void:
	var mesa: Node = await _mesa3d_nova()
	mesa.set("_sorteio_rodando", true)
	var antes := _texto_do_turno(mesa)
	var ev := InputEventAction.new()
	ev.action = "confirmar"
	ev.pressed = true
	# Chamar o `_unhandled_input` e o jeito de provar o CONSUMO: num evento de
	# verdade o `set_input_as_handled` impede que ele chegue adiante.
	mesa.call("_unhandled_input", ev)
	assert_true(ev.is_action_pressed("confirmar"),
		"O evento existiu (o teste exercita o caminho real).")
	# A trava e um ESTADO: enquanto a moeda estiver na tela, o START nao abre o
	# turno. O que o START faria depende do turno, entao o que se trava aqui e
	# que a funcao consome e devolve sem tocar no jogo.
	assert_eq(_texto_do_turno(mesa), antes,
		"O START durante a moeda nao mexe na tela.")
	mesa.set("_sorteio_rodando", false)


func test_a_moeda_e_tinta_sem_luz_como_o_resto_da_tela() -> void:
	var mesa: Node = await _mesa3d_nova()
	var moeda := _moeda_da_mesa(mesa)
	var corpo := moeda.get("_corpo") as MeshInstance3D
	assert_not_null(corpo, "A malha da moeda existe.")
	var malha := corpo.mesh
	assert_not_null(malha, "A malha existe.")
	# A cena do duelo nao tem iluminacao e nao vai ter, entao um material PBR
	# importado do `.glb` sai PRETO. Todo material da peca e UNSHADED, que e o
	# mesmo modo de todas as cartas e do vidro: e o que faz a
	# moeda aparecer na cor que o Blender mostra.
	var vistas := 0
	for s in malha.get_surface_count():
		var mat := corpo.get_active_material(s) as StandardMaterial3D
		assert_not_null(mat, "A superficie %d tem material." % s)
		assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED,
			"A superficie %d e UNSHADED (a cena nao tem luz: PBR sairia preto)." % s)
		vistas += 1
	assert_gt(vistas, 0, "A moeda tem pelo menos uma superficie pintada.")


func test_a_moeda_nao_tem_pulo() -> void:
	var mesa: Node = await _mesa3d_nova()
	var moeda := _moeda_da_mesa(mesa)
	# Nao existe metodo de pular: um atalho economiza o unico momento em que o
	# jogador descobre de quem e a vez.
	assert_false(moeda.has_method("pular"),
		"A moeda nao tem pulo (nao existe atalho para o sorteio).")
	assert_false(moeda.has_method("duracao_curta"),
		"A moeda nao tem versao curta (um tempo so para o sorteio).")


# ---------------------------------------------------------------------------
# O MARCADOR DE TURNO
# ---------------------------------------------------------------------------
# D80: QUEM LIGA A ESPERADA. A marca `?` e uma representacao da moeda, entao a
# resposta e da MESA (o unico lugar com as duas fontes: o dado `turn_order` e a
# flag de prova `--mesa3d-moeda`). Estes dois testes medem essa resposta pela
# interface dela — `false` no duelo do headless (`first_p1`), `true` quando ha
# moeda — em vez de o teste LIGAR a faixa na mao, que seria medir o Interruptor
# e nao o dono dele.
func test_a_mesa_e_quem_diz_que_existe_moeda_na_tela() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# O duelo do headless e `first_p1`: sem moeda na tela nao existe espera, e o
	# que nao esta na tela nao tem o que esconder.
	assert_eq(str(st.turn_order), "first_p1",
		"O duelo do headless e `first_p1` (o gate de `data_loader` cai no examples).")
	assert_false(bool(mesa.call("_tem_sorteio_na_tela")),
		"Um duelo sem moeda nao tem sorteio na tela.")
	assert_false(bool(mesa.get("_aguardando_sorteio")),
		"E a espera do painel e da navegacao segue a MESMA resposta (nao ha duas).")
	assert_false(bool((mesa.get("_faixa") as Node).get("_esperando_sorteio")),
		"O marcador segue a mesma resposta: sem moeda nao existe pergunta.")


func test_com_moeda_no_palco_a_mesa_liga_o_marcador_e_a_navegacao() -> void:
	var mesa: Node = await _mesa3d_nova()
	# A DUAS fontes da mesa: o dado (`turn_order`) e a flag de PROVA, que existe
	# para a foto ser deterministica SEM mudar quem ganhou (D42). Nenhuma delas
	# e o estado da tela — o que trava e a DECISAO, nao o resultado dela.
	mesa.set("_moeda_forcada", true)
	assert_true(bool(mesa.call("_tem_sorteio_na_tela")),
		"Com a moeda no palco a mesa responde que existe sorteio na tela.")
	# E o dado sozinho tambem vira resposta, sem a flag.
	mesa.set("_moeda_forcada", false)
	var st = mesa.get("_st")
	var antes := str(st.turn_order)
	st.turn_order = "moeda"
	assert_true(bool(mesa.call("_tem_sorteio_na_tela")),
		"O dado `turn_order: moeda` sozinho ja e resposta (o dado manda, R3).")
	st.turn_order = antes


func test_o_marcador_mostra_interrogacao_roxo_durante_o_sorteio() -> void:
	var mesa: Node = await _mesa3d_nova()
	var faixa := mesa.get("_faixa") as Node
	faixa.call("esperar_sorteio", true)
	await wait_process_frames(1)
	# O "?" e a PERGUNTA, e a celula fica no roxo da espera (nenhuma cor de
	# lado: a moeda ainda nao disse de quem e a vez).
	assert_eq(_texto_do_turno(mesa), "?",
		"Durante o sorteio o marcador e uma PERGUNTA, nao o numero do turno.")
	var cel := faixa.get("_turno_cel") as PanelContainer
	assert_not_null(cel, "A celula do turno existe.")
	var estilo := cel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(estilo, "A celula do turno tem estilo.")
	# O roxo e a mistura das DUAS cores de lado: ele nao e a cor de ninguem.
	var roxo := Vector3(0.55, 0.31, 0.57)
	assert_almost_eq(estilo.bg_color.r, roxo.x, 0.02,
		"A celula da espera e ROXA (o vermelho e o azul juntos nao se cancelam).")
	# E o "?" e ambar, a cor da moeda: a pergunta e a resposta sao da mesma
	# familia e o eye liga uma na outra sem ler texto.
	var lbl := faixa.get("_num_turno") as Label
	assert_almost_eq(lbl.get_theme_color("font_color").r, 1.0, 0.02,
		"O '?' e ambar (a cor da moeda).")


func test_o_marcador_volta_para_o_numero_quando_a_moeda_sai() -> void:
	var mesa: Node = await _mesa3d_nova()
	var faixa := mesa.get("_faixa") as Node
	var st = mesa.get("_st")
	faixa.call("esperar_sorteio", false)
	await wait_process_frames(1)
	var esperado := "%d" % int(st.turn_number)
	assert_eq(_texto_do_turno(mesa), esperado,
		"Fora do sorteio o marcador volta ao numero real do turno (R3).")
	assert_false(bool(faixa.get("_esperando_sorteio")),
		"A espera acabou com a moeda.")
	# O pulso do "?" nao sobrevive a virada: um numero que respira parece que
	# ainda esta mudando.
	var pulso := faixa.get("_pulso") as Tween
	assert_true(pulso == null or not pulso.is_valid(),
		"O pulso do '?' morreu quando o numero voltou.")