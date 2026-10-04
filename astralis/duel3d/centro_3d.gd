extends CanvasLayer

## centro_3d — O PALCO DO CENTRO: a janela onde a carta segurada aparece GRANDE,
## por cima do 2D. Um assunto só: o palco (a janela, o mundo e o olho).
##
## Por que uma janela própria: a segurada tem de passar NA FRENTE da faixa do
## meio e da mão do rival, e o 3D do campo nunca passa na frente do 2D do HUD —
## a ordem é das camadas, não dos objetos (doc do motor,
## `Godot Documentation/classes/class_canvaslayer.rst`: a cena sem camada é o
## índice 0, e camada 1 desenha por cima). Então o centro é outra janela, com
## mundo próprio e fundo transparente, na camada 1 como os menus mas ANTES deles
## na árvore (a mesa cria este nó antes do MenuLayer): a faixa fica embaixo da
## carta e o menu da estrela continua por cima dela. É o mesmo truque da carta
## do painel esquerdo (`painel_carta_3d.gd`).
##
## O olho é ortogonal e de frente, como o do painel: de frente a carta é lida
## inteira dos dois lados, e de lado (perspectiva com inclinação) o verso sai
## achatado. A peça é a mesma do campo (a fábrica da mesa monta); o olho é outro.
##
## NADA AQUI CALCULA REGRA (R1/R3): o nó chega montado e a face que vale é a da
## mesa. Este nó só mostra, gira e esconde.

## As duas caixas na tela (dono: este arquivo, que é o dono do palco). A carta
## preenche a altura da caixa (a câmera tem `size` = altura dela), então a
## proporção da caixa tem de caber a largura: 370/527 e 330/466 passam com folga
## dos 59/86 da peça. A de cima termina 14 px antes do menu da estrela.
const CAIXA_FACE := Rect2(775, 96, 370, 527)
const CAIXA_ESTRELA := Rect2(795, 20, 330, 466)

## A entrada (a carta cresce no lugar). Curta de propósito: é só o aparecer, e
## a decisão é o giro — uma entrada longa aqui é o jogador esperando à toa.
const TEMPO_ENTRADA := 0.18
## O giro de UMA troca de face (meia volta para a direita). Dono: este arquivo,
## que é quem anima. A mesa só diz o ângulo acumulado.
const TEMPO_GIRO := 0.22
## A câmera fica a esta distância à frente da carta. Ortogonal não muda o
## tamanho com a distância: só precisa estar na frente, dentro do clip.
const DIST_CAM := 5.0

## A altura da carta em unidades de mundo. Dono: a mesa (a mesma medida da
## fábrica e do painel, um dono só). Sem ela a câmera não sabe o `size`.
var altura_carta: float
## A caixa em uso agora (para teste e para quem posiciona em volta).
var caixa := Rect2()

var _janela: SubViewportContainer = null
var _vp: SubViewport = null
var _mundo: Node3D = null
var _cam: Camera3D = null
var _carta: Node3D = null
## O giro em curso (só um escreve na rotação por vez): começar outro mata este.
var _tw: Tween = null


func _ready() -> void:
	name = "CentroLayer"
	# Camada 1 como os menus, mas ANTES deles na árvore: mesma camada desenha
	# na ordem dos irmãos, então a faixa (cena 0) fica embaixo da carta e o menu
	# da estrela (camada 1, depois) continua por cima dela.
	layer = 1
	_janela = SubViewportContainer.new()
	_janela.name = "CentroJanela"
	# Sem stretch: a janela tem sempre o tamanho da caixa, 1:1, e o tamanho do
	# viewport pode mudar sem o motor reclamar.
	_janela.stretch = false
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_janela)
	_vp = SubViewport.new()
	_vp.name = "CentroViewport"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_janela.add_child(_vp)
	_mundo = Node3D.new()
	_mundo.name = "CentroMundo"
	_vp.add_child(_mundo)
	_cam = Camera3D.new()
	_cam.name = "CentroCam"
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.position = Vector3(0.0, 0.0, DIST_CAM)
	_vp.add_child(_cam)
	_cam.current = true
	visible = false


## Tem carta no palco.
func mostrando() -> bool:
	return _carta != null and is_instance_valid(_carta)


## Mostra o nó no palco, na caixa do passo (`alta` = estrela, com o menu
## embaixo; senão a face, no meio). Troca sem piscar: o que estava sai junto.
func mostrar(no: Node3D, face_baixo: bool, alta: bool) -> void:
	assert(altura_carta > 0.0,
		"centro_3d: altura_carta vem da mesa (ela é o dono da medida). Vazia aqui = câmera sem size.")
	_liberar_carta()
	if no == null or not is_instance_valid(no):
		return
	caixa = CAIXA_ESTRELA if alta else CAIXA_FACE
	_janela.position = caixa.position
	_janela.size = caixa.size
	_vp.size = caixa.size
	_cam.size = altura_carta
	_mundo.add_child(no)
	no.position = Vector3.ZERO
	no.rotation_degrees = Vector3(0.0, 180.0 if face_baixo else 0.0, 0.0)
	no.scale = Vector3.ONE * 0.35
	_carta = no
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = true
	var tw := _carta.create_tween()
	tw.tween_property(_carta, "scale", Vector3.ONE, TEMPO_ENTRADA) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Gira a carta até o ângulo acumulado (radianos, sempre crescendo para a
## direita): começar outro mata o anterior, então dois giros nunca brigam.
func girar_para(rad: float) -> void:
	if _carta == null or not is_instance_valid(_carta):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	var tw := _carta.create_tween()
	tw.tween_property(_carta, "rotation:y", rad, TEMPO_GIRO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw = tw


## Tira a carta do palco e apaga a janela: sem carta não há desenho nem custo.
func esconder() -> void:
	_liberar_carta()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	visible = false


func _liberar_carta() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	if _carta != null and is_instance_valid(_carta):
		_carta.queue_free()
	_carta = null
