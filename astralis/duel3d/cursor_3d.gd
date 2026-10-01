extends Node3D

## cursor_3d — O CURSOR DE FOCO: o retangulo AZUL BRILHANTE que ABRAÇA a coisa
## focada, mais a MAO BRANCA no centro dela. Um assunto so.
##
## Ele nao sabe o que esta focado: quem molda o cursor e a mesa, que mede a coisa
## (a carta da mao ou o ladrilho) e passa largura, altura, inclinacao e escala.
## Por isso o mesmo cursor serve na mao E no campo (ref, doc 15 §15.3).
##
## A moldura e desenhada no PLANO DA CARTA (XY local dentro do `Grupo`), e o
## grupo gira junto com a focada - entao a moldura sai colada nela, nas DUAS
## situacoes.
##
## Zero regra (R1): isto e desenho puro.

## Espessura do vidro do ladrilho (a moldura sai aFrente dele, nao dentro).
var espessura_carta := 0.05
## Cor do foco: o azul brilhante da ref.
var cor := Color(0.25, 0.55, 1.0)
## Material UNSHADED: a mesa passa o dela (tudo na cena e sem luz).
var mat: Callable
## Fabrica de caixa da mesa (a mesma que monta o corpo das cartas).
var caixa: Callable

var _grupo: Node3D = null
var _moldura: Node3D = null
var _mao: Node3D = null


func _ready() -> void:
	name = "Cursor3D"
	_grupo = Node3D.new()
	_grupo.name = "Grupo"
	add_child(_grupo)
	_moldura = Node3D.new()
	_moldura.name = "Moldura"
	_grupo.add_child(_moldura)
	_construir_mao()


## Redesenha a moldura do foco com o tamanho e a inclinacao da focada.
## `larg`/`alt` sao as medidas da COISA focada e `rot` a rotacao dela; a
## moldura sai 6% maior, no plano da coisa, com a grossura proporcional
## (nada de moldura fininha num lado e grossa no outro).
func moldar(larg: float, alt: float, rot: Vector3, escala_mao: float) -> void:
	if _grupo == null:
		return
	_grupo.rotation_degrees = rot
	for f in _moldura.get_children():
		(f as Node).queue_free()
	var w := larg * 1.06
	var h := alt * 1.06
	var t := maxf(larg, alt) * 0.055
	var z := espessura_carta / 2.0 + 0.012
	var m := mat.call(cor, 0.85) as Material
	_moldura.add_child(caixa.call("Aba", Vector3(w, t, 0.03), Vector3(0, h / 2.0, z), m) as Node)
	_moldura.add_child(caixa.call("Abaixo", Vector3(w, t, 0.03), Vector3(0, -h / 2.0, z), m) as Node)
	_moldura.add_child(caixa.call("Esq", Vector3(t, h, 0.03), Vector3(-w / 2.0, 0, z), m) as Node)
	_moldura.add_child(caixa.call("Dir", Vector3(t, h, 0.03), Vector3(w / 2.0, 0, z), m) as Node)
	if _mao != null:
		_mao.scale = Vector3.ONE * escala_mao
		_mao.position = Vector3(0, 0, z)


## MAO BRANCA no centro do cursor (ref): palma + 4 dedos + polegar, feita de
## caixas brancas. Montada na escala de UMA carta (largura 1,0) - quem chama e
## que escala pelo tamanho da coisa focada, entao ela e a mesma na mao e no
## ladrilho.
func _construir_mao() -> void:
	var mao := Node3D.new()
	mao.name = "Mao"
	var branco := mat.call(Color(1.0, 1.0, 1.0), 0.55) as Material
	var w := 0.048
	mao.add_child(caixa.call("Palma", Vector3(w * 2.2, w * 1.5, 0.02), Vector3.ZERO, branco) as Node)
	# dedos: 4 barras curtas em cima da palma, do maior pro menor
	var alturas := [0.100, 0.130, 0.125, 0.095]
	for i in range(4):
		var alt: float = float(alturas[i])
		var x := (-1.5 + float(i)) * w * 1.05
		mao.add_child(caixa.call("Dedo%d" % i, Vector3(w * 0.80, alt, 0.02), Vector3(x, alt * 0.5 + w * 0.75, 0), branco) as Node)
	# polegar: barra curta diagonal a esquerda da palma
	var pol := caixa.call("Polegar", Vector3(w * 0.80, w * 1.3, 0.02), Vector3(-w * 1.9, w * 0.1, 0), branco) as Node3D
	pol.rotation_degrees = Vector3(0, 0, 40)
	mao.add_child(pol)
	_mao = mao
	_grupo.add_child(mao)
