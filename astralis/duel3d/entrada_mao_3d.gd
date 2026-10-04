extends RefCounted

## entrada_mao_3d — COMO A CARTA QUE COMPROU CHEGA ATÉ O LUGAR DELA NA MÃO.
## Um assunto só: o movimento de pôr a carta na mão.
##
## São DOIS movimentos no mesmo instante, e um sem o outro fica torto:
##
##   1. a(s) carta(s) que comprou **voa** do baralho até o lugar novo, em arco; e
##   2. as que já estavam na mão **deslizam** para o lugar novo delas.
##
## Por que as duas: a mão é centrada, então comprar uma carta muda o lugar de
## TODAS as outras. Sem o deslize elas aparecem no lugar novo de um quadro para o
## outro, e é esse salto — não o voo — que faz a compra parecer quebrada. Com as
## duas, a mão inteira se acomoda como uma coisa só.
##
## Zero regra (R1): isto é desenho puro. Nenhuma carta é criada, destruída nem
## movida no DADO, e o tempo daqui não é tempo de jogo: o motor já devolveu a
## mão nova antes de qualquer coisa aqui saber que ela mudou.
##
## O DONO do baralho, do lugar e da pose é a mesa: quem chama diz de onde a carta
## sai e onde cada uma fica. Aqui mora só o TEMPO e a FORMA do trajeto — e quem
## decide de QUEM é a compra também é a mesa, porque a mão que comprou é a única
## que se mexe.
##
## Sem trava de render de propósito: o trajeto é curtinho e não depende de
## render, então o mesmo caminho roda no jogo e no teste headless, e o teste
## continua VENDO quem animou. Se isto ganhasse trava de render, o defeito
## voltaria a passar sem ninguém enxergar.

## O voo de UMA carta, do baralho ao lugar. Curto de propósito: a mão é lugar de
## jogar, e uma animação longa aqui é o jogador esperando para poder jogar.
const DURACAO_VOO := 0.42
## O atraso entre duas cartas da mesma compra. Uma compra pode trazer mais de uma
## carta (a mão completa até 5), e o escalonamento é o que faz parecer que alguém
## está repartindo cartas — todas de uma vez parece um bloco só.
const INTERVALO := 0.11
## O deslize das que já estavam. Mais curto que o voo: elas precisam estar
## acomodadas quando a carta nova assenta, e não depois dela.
const DURACAO_GLIDE := 0.32
## O quanto o voo se ABAULA em relação à linha reta, em unidades de mundo: para
## cima (a carta é levantada) e para a frente (vem na direção de quem olha). É
## o que separa "uma carta deslizando" de "uma carta sendo posta na mão".
const INCLINACAO := Vector3(0.0, 1.8, 1.3)
## A carta entra MENOR e cresce. Chega com um pastelhinho de escala a mais e
## volta em 1,0: é o "assentar" de uma carta batendo na mão, e é o que dá peso
## ao pouso sem precisar de som.
const ESCALA_ENTRADA := 0.72
const ESCALA_EXAGERO := 1.07
## A pose de partida. A carta sai TOMBADA (deitada, como quem tira do baralho)
## e um pouco ROLHADA de lado, e as duas coisas se acertam na chegada.
const TOMBADA_GRAUS := 64.0
const ROLLO_GRAUS := 9.0


## Põe a(s) carta(s) nova(s) na mão e acomoda as que já estavam.
##
## `novas` = as cartas que entraram, JÁ no lugar final (a mesa mediu). `origem` =
## de onde elas saem (o baralho). `deslizes` = as outras, cada uma como
## `{"no": Node3D, "de": Vector3}`: `de` é onde ela ESTAVA antes da compra, e o
## destino é o lugar onde a mesa já a colocou. `ao_assentar` (se vier) é chamada
## com a carta quando ela pousa, para a mesa restaurar a camada de mão.
static func tocar(novas: Array, origem: Vector3, deslizes: Array, ao_assentar: Callable = Callable()) -> void:
	for i in range(novas.size()):
		var no := novas[i] as Node3D
		if no == null or not is_instance_valid(no):
			continue
		_voar(no, origem, float(i) * INTERVALO, ao_assentar)
	_deslizar(deslizes)


## QUANTO TEMPO a entrada inteira dura com `n` cartas: o voo da última, que é a
## que começa mais tarde, mais o acerto da escala. Quem precisa esperar a mão
## assentar (a vez do rival espera antes de atacar) tira o número daqui.
##
## O DONO deste tempo é este arquivo, e é por isso que a função existe: do lado de
## fora, escrever um número "parecido" com o voo é a segunda fonte da mesma
## medida, e o corte aparece como a carta parando no ar no meio da volta.
static func duracao_total(n: int) -> float:
	if n <= 0:
		return 0.0
	return maxf(float(n - 1), 0.0) * INTERVALO + DURACAO_VOO + DURACAO_VOO * 0.3


## O voo de UMA carta: arco, tombada que se acerta, escala que cresce e assenta.
static func _voar(no: Node3D, origem: Vector3, atraso: float, ao_assentar: Callable) -> void:
	var destino := no.position
	var pose := no.rotation_degrees
	no.position = origem
	no.rotation_degrees = pose + Vector3(TOMBADA_GRAUS, 0.0, ROLLO_GRAUS)
	no.scale = Vector3.ONE * ESCALA_ENTRADA
	var tw := no.create_tween().set_parallel(true)
	# O TRÁJECTO é um método, não um `position` de A para B: reto é linha de trem,
	# e carta que é posta na mão anda em arco.
	#
	# `tween_method` ENTREGA o valor ao callback e não sabe o que fazer com ele:
	# quem escreve no nó é o callback. Por isso o método é `_pos_no_arco` (que
	# escreve) e não um `_arco` que devolvesse a posição — devolver sem escrever
	# deixava a carta parada no baralho, fora da mão, e ela só aparecia no
	# desenho seguinte. Medido: o `position` não mudava em nenhum quadro, com a
	# escala do mesmo tween mudando.
	tw.tween_method(_pos_no_arco.bind(no, origem, destino), 0.0, 1.0, DURACAO_VOO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(atraso)
	tw.tween_property(no, "rotation_degrees", pose, DURACAO_VOO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(atraso)
	tw.tween_property(no, "scale", Vector3.ONE * ESCALA_EXAGERO, DURACAO_VOO * 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(atraso)
	# `chain()` depois do paralelismo: o acerto da escala só começa quando o voo
	# acabou, senão a carta cresce enquanto ainda está no ar.
	tw.chain().tween_property(no, "scale", Vector3.ONE, DURACAO_VOO * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ao_assentar.is_valid():
		tw.chain().tween_callback(ao_assentar.bind(no))


## As que já estavam: de onde a mão as tinha para onde a mão as tem que deixar.
static func _deslizar(deslizes: Array) -> void:
	for d in deslizes:
		if not (d is Dictionary):
			continue
		var no := (d as Dictionary).get("no") as Node3D
		if no == null or not is_instance_valid(no):
			continue
		var de: Vector3 = (d as Dictionary).get("de", no.position) as Vector3
		var para := no.position
		if de.is_equal_approx(para):
			continue
		no.position = de
		var tw := no.create_tween()
		tw.tween_property(no, "position", para, DURACAO_GLIDE) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Escreve na carta o ponto do voo no tempo `t`: uma Bézier quadrática com um
## ponto de controle no meio do caminho, empurrado para cima e para a frente.
## `t` já chega suavizado pelo `TRANS_SINE/EASE_OUT` do tween, então a curva fica
## macia.
##
## Este método ESCREVE no nó de propósito: o tween entrega o valor a quem ele
## chama, e não existe nenhuma propriedade para ele escrever sozinho.
static func _pos_no_arco(t: float, no: Node3D, de: Vector3, para: Vector3) -> void:
	if no == null or not is_instance_valid(no):
		return
	var controle := (de + para) * 0.5 + INCLINACAO
	no.position = de.lerp(controle, t).lerp(para, t)
