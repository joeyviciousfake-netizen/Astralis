extends Node3D

## vista_3d — A VISTA E A VOLTA DA MESA (D47). Um assunto so: para onde a
## camera olha e quanto a mesa girou.
##
## A tela do duelo e a perspectiva de QUEM ESTA JOGANDO, como no Forbidden
## Memories: quando a vez passa, a CAMERA da 180 graus em torno do centro do
## campo. A camera e filha deste no (o pivo) e nunca se move nem gira (o pivo e
## que gira), entao:
##   * a sua fileira continua embaixo NO MUNDO, e a do rival continua no topo;
##   * quando a camera vai para o outro lado, voce passa a ver a SUA fileira no
##     topo da tela e de cabeca para baixo, e a DELE vem para baixo de frente;
##   * nada teleporta, nada esmaece, nenhuma carta troca de lugar.
## E o estado nao se mexe: `players[lado]["monstro"][i]` e a MESMA carta antes e
## depois da volta (R1) - a volta e so o ponto de vista.
##
## O numero que manda em TUDO e `giro_campo` (0 = seu, 180 = do rival). Nao ha
## segunda copia dele: a camera, o HUD e as animacoes leem daqui.
##
## Nao existe "coluna espelhada" como regra: ela sai de graca. O lado 1 da
## arena ja vem espelhado no X (D18) e a volta de 180 graus espelha de novo,
## entao cada jogador ve a PROPRIA fileira na ordem normal (indice 0 a
## esquerda).

## Onde a camera esta pendurada, e de onde ela olha (medidas da cena, D47).
var cam_pos := Vector3(0.0, 9.0, 12.0)
var cam_alvo := Vector3.ZERO
var cam_fov := 55.0
## Duracao da volta, em segundos.
var volta_duracao := 1.0
## De onde a vista traduz o slot do DADO em XZ de mundo (a medida e da mesa).
var pos_slot: Callable
## A mesa sabe se o jogo esta com desenho (teste/headless): sem desenho a volta
## vai direto no estado final.
var sem_render: Callable
## A mesa e quem aplica o resto da vista (a mao e o HUD 2D) a cada passo.
var ao_virar: Callable

## O numero que manda em tudo (0 = visão do jogador, 180 = do rival).
var giro_campo := 0.0
var girando := false
var cam: Camera3D = null
## D51: o plano de simetria do campo em Z de mundo, medido do dado.
var z_simetria := 0.0
## O TOPO (visão de cima na escolha do slot): a câmera sobe e olha para baixo,
## e o campo inteiro aparece de cima. Só desenho: as cartas não se mexem, o
## giro continua valendo e a volta continua proibida de pular — o topo é em
## cima da vista atual, e voltar é pré-requisito da volta (`_girar_campo` volta
## antes de girar).
## A que altura a câmera para, em unidades de mundo. Dono: este arquivo. Com
## FOV 20 a altura visível a essa distância é 2·26·tan(10°) = 9,2: as fileiras
## (8 de vão + o vidro) cabem inteiras e as pilhas ficam nas beiradas.
const TOPO_ALT := 26.0
## O tempo da subida e da descida, em segundos. Curto de propósito: é só a
## troca de ponto de vista, e a decisão é escolher o slot — uma volta longa
## aqui é o jogador esperando à toa.
const TOPO_DURACAO := 0.5
## A câmera está no topo agora. Quem pergunta é a mesa (para não subir duas
## vezes e para a volta saber que precisa descer antes).
var no_topo := false
## A pose de onde a câmera saiu para o topo (para voltar exato). Dono: quem
## sobe guarda, quem desce restaura — ninguém mais escreve aqui.
var _topo_base_pos := Vector3.ZERO
var _topo_base_rot := Vector3.ZERO
## O voo em curso (só um mexe na câmera por vez): começar outro mata este.
var _topo_tw: Tween = null


func _ready() -> void:
	name = "PivoMesa"
	position = cam_alvo
	# CÂMERA FIXA da ref: atrás/acima do SEU campo, tilt p/ o rival longe.
	# `position` aqui e LOCAL (a filha do pivo), entao continua sendo `cam_pos` -
	# com o pivo em 0° a imagem e byte a byte a de antes.
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.position = cam_pos
	cam.fov = cam_fov
	cam.current = true
	add_child(cam)
	# O olhar para o centro e a inclinacao local do pivo (o `look_at` de todo
	# frame saia: com o pivo girando, ele brigaria com a volta).
	cam.rotation_degrees = Vector3(-rad_to_deg(atan2(cam_pos.y, cam_pos.z)), 0.0, 0.0)
	# LENTE NO EIXO (doc 15 §15.4): deslocar o frustum deforma a imagem (um lado
	# estica, o outro comprime) e o campo fica torto. Quem joga o campo p/ a
	# direita e a JANELA do campo, criada pela mesa.
	cam.frustum_offset = Vector2.ZERO


## D51: MEDE O PLANO DE SIMETRIA DO CAMPO, em Z de mundo, direto do dado: a
## media das DUAS fileiras de monstro da arena oficial. E o plano em que o
## campo e espelhado - o mesmo para os dois lados, porque a arena oficial e
## simetrica (D49: 237 de vao acima e abaixo, 300 entre as fileiras).
## RODA UMA VEZ, quando a arena ja esta lida, e fica memorizado como um float.
func medir_plano_de_simetria() -> void:
	var soma := 0.0
	var n := 0
	for lado in [0, 1]:
		for i in range(5):
			soma += (pos_slot.call(lado, "monstro", i) as Vector3).z
			n += 1
	z_simetria = 0.0 if n == 0 else soma / float(n)


## D51: ONDE A CAMERA FICA, em Z LOCAL dentro do pivo, para uma vista `giro`.
## A vista do jogador (0°) e a de sempre: `cam_pos` intacto, byte a byte. Na
## volta, a camera recua o MESMO desvio que o pivo tem do plano de simetria do
## campo - porque o pivo esta na origem e o campo e simetrico em torno de
## `z_simetria`. Sem isso a camera do rival chega 2x esse desvio mais perto da
## mesa do que a do jogador, e o campo sai mais para baixo (o vao entre as
## fileiras deixa de bater nas duas vistas).
## Ou seja: a vista do rival e o ESPELHO EXATO da do jogador, e a do jogador
## nao muda em nada.
func _z_local_da_camera(giro: float) -> float:
	return cam_pos.z - 2.0 * z_simetria * (giro / 180.0)


## D51: A VISTA 3D INTEIRA a partir de UM numero so (`giro_campo`): o pivo na
## volta e a camera na distancia certa para ele. Todo mundo que mexe na volta
## chama ISTO (nada de ajustar o pivo por conta propria), para o 3D nao poder
## ficar com a camera de um angulo e a distancia de outro.
func aplicar() -> void:
	rotation_degrees = Vector3(0.0, giro_campo, 0.0)
	if cam != null and is_instance_valid(cam):
		cam.position = Vector3(cam_pos.x, cam_pos.y, _z_local_da_camera(giro_campo))


## A escala da virada de carta do HUD 2D: 1 no comeco e no fim, ZERO nos 90
## exatos (e por isso a troca de lado acontece num instante invisivel).
func escala_do_virar() -> float:
	return absf(cos(deg_to_rad(giro_campo)))


## A tela ja passou dos 90°? Aí o conteudo 2D esta do outro lado (e o que troca
## os numeros e as posicoes).
func invertida() -> bool:
	return absf(giro_campo) >= 90.0


## De onde a volta começou (0 se a mesa nunca girou, senao o 0 ou o 180 mais
## proximo do alvo) - e o que permite a mesma rotina ir e voltar sem estado
## guardado em outro lugar.
func _giro_de_onde() -> float:
	return 0.0 if giro_campo < 90.0 else 180.0


## Da a volta na mesa: `alvo` em GRAUS (0 = visao do jogador, 180 = do rival).
## Uma rotina para as DUAS direcoes, porque e a mesma coisa. So a camera se
## mexe - as cartas NAO: a volta e so o ponto de vista (R1).
## Espera a volta terminar, entao quem chama (o START) so segue depois.
func girar_para(alvo: float) -> void:
	if cam == null or is_equal_approx(giro_campo, alvo):
		return
	if girando:
		return
	girando = true
	if sem_render != null and sem_render.call():
		# Sem desenho (teste/headless): o estado final tem que ser o mesmo dos
		# dois jeitos, entao vai direto e aplica a vista final.
		giro_campo = alvo
		aplicar()
		girando = false
		ao_virar.call()
		return
	var tw := create_tween()
	tw.tween_method(Callable(self, "_passo").bind(alvo), 0.0, 1.0, volta_duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	girando = false
	ao_virar.call()


## COLOCA a mesa em `alvo` sem a volta animada, e avisa a mesa pelo mesmo
## `ao_vivar` do giro — só não há tween. É o que o BOOT usa quando o motor já
## disse que o RIVAL começa: a tela é o ponto de vista de quem joga, então ela
## tem de NASCER na vista dele. Sem isto a mesa aparece na sua frente e gira
## depois, e o primeiro quadro do duelo mente sobre quem está jogando.
##
## Não é pular a volta (que na troca de vez do meio do duelo é obrigatória e
## continua passando por `girar_para`): aqui não existe "volta" porque nunca
## houve um lado anterior — a mesa sempre esteve, e desde o primeiro quadro, na
## vista de quem tem a vez.
func colocar_vista(alvo: float) -> void:
	if cam == null:
		return
	giro_campo = alvo
	girando = false
	aplicar()
	ao_virar.call()


## Um passo da volta (0..1 do caminho). O pivo gira na MESMA proporcao, a camera
## recua junto (D51), as MAOS trocam de lugar nos 90° (D52) e o HUD 2D
## acompanha pelo `escala_do_virar`.
func _passo(t: float, alvo: float) -> void:
	var de := _giro_de_onde()
	giro_campo = lerpf(de, alvo, clampf(t, 0.0, 1.0))
	aplicar()
	ao_virar.call()


## Sobe para o TOPO: a câmera vai para cima do centro do campo e olha para
## baixo. O ponto é no eixo (x = 0, z = 0, que o pivô não desloca) com a
## inclinação zerada no eixo X — de cima, sem torto para lado nenhum. Duas
## chamadas seguidas não sobem duas vezes: a segunda é no-op.
## Sem desenho (teste/headless) vai direto, como a volta.
func ir_para_topo() -> void:
	if cam == null or no_topo:
		return
	no_topo = true
	_topo_base_pos = cam.position
	_topo_base_rot = cam.rotation
	if _topo_tw != null and _topo_tw.is_valid():
		_topo_tw.kill()
	_topo_tw = null
	var alvo_pos := Vector3(0.0, TOPO_ALT, 0.0)
	var alvo_rot := Vector3(-PI * 0.5, _topo_base_rot.y, 0.0)
	if sem_render != null and sem_render.call():
		cam.position = alvo_pos
		cam.rotation = alvo_rot
		return
	girando = true
	var tw := cam.create_tween().set_parallel(true)
	tw.tween_property(cam, "position", alvo_pos, TOPO_DURACAO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "rotation", alvo_rot, TOPO_DURACAO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(Callable(self, "_topo_chegou"))
	_topo_tw = tw


## Fim de um voo do topo (só destrava; quem continua o fluxo é a mesa).
func _topo_chegou() -> void:
	_topo_tw = null
	girando = false


## Desce do TOPO de volta para a pose de onde saiu. É `await` de verdade: quem
## chama (a escolha do slot) só segue — segurada, menu — depois que a câmera
## parou, porque o palco da segurada é calculado da câmera. Fora do topo é
## no-op instantâneo. Sem desenho vai direto, como a volta.
func voltar_do_topo() -> void:
	if not no_topo or cam == null:
		return
	no_topo = false
	if _topo_tw != null and _topo_tw.is_valid():
		_topo_tw.kill()
	_topo_tw = null
	if sem_render != null and sem_render.call():
		cam.position = _topo_base_pos
		cam.rotation = _topo_base_rot
		return
	girando = true
	var tw := cam.create_tween().set_parallel(true)
	tw.tween_property(cam, "position", _topo_base_pos, TOPO_DURACAO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "rotation", _topo_base_rot, TOPO_DURACAO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_topo_tw = null
	girando = false
