extends Node3D
## A MOEDA DO SORTEIO (D77). A tela que diz de quem e a vez.
##
## A moeda e um desenho na FRENTE DA CAMERA, no meio da tela de quem esta
## assistindo — ela nao pertence a nenhuma cena do campo. Nao ha piso, nao ha
## prancheta, nao ha mesa virada de lado: a mao, as cartas, o painel e o HUD
## ficam onde estavam, na perspectiva NORMAL, e a moeda aparece no ar em cima do
## marcador de turno. Por isso ela e IRMA do pivo da mesa e e posicionada no
## SISTEMA DA CAMERA, e nao em coordenadas do tabuleiro.
##
## A pose de frente para a camera e montada UMA vez, antes do primeiro quadro, e
## vale o giro inteiro. E o giro e em torno do eixo VERTICAL DA TELA (a moeda
## tomba como quem rola uma moeda na beira do dedo), e nao em torno da propria
## normal da face: girar na propria normal deixa a face sempre virada para a
## camera e o giro some da tela.
##
## A face mostrada e a ESTRELA quando o JOGADOR comeca e o LOSANGO quando comeca
## o RIVAL (D42). Nao ha nome escrito: a face e a resposta, e um desenho e lido
## mais rapido que um texto. Isso e desenho, nao regra — quem decide o turno e o
## motor, e a moeda so conta o que ele ja decidiu.
##
## Nao existe pulo. Quem assiste nao pode apressar o sorteio, e nao existe
## tempo curto: a leitura do resultado e o que importa aqui, e um atalho
## economiza o unico momento em que o jogador descobre de quem e a vez.
##
## O `tocar()` nao devolve nada e nao e uma corrotina para quem chama: ele
## espera a animacao inteira e so entao devolve controle. Quem chama precisa
## de `await` porque precisa saber quando acabou.

# ---------------------------------------------------------------------------
# AS MEDIDAS (o dono de cada numero esta aqui; R10)
# ---------------------------------------------------------------------------
## A DISTANCIA da moeda na frente da câmera, em unidades de mundo. O dono deste
## número: é o dono do QUÃO PERTO a moeda nasce. Perto demais e ela invade as
## cartas do jogador (que estão no mesmo eixo de profundidade) e toma foco; longe
## demais e ela vira uma plaquinha no meio do campo.
const DISTANCIA := 9.5

## O TAMANHO da moeda na tela, como FRAÇÃO da altura da tela. O dono deste
## número: é o dono do TAMANHO NA TELA, e é uma fração de propósito — a
## câmera da mesa é de perspectiva (`CAM_FOV` = 20°, telefoto), então o tamanho
## em unidades de mundo depende da distância e do FOV, e quem escreve em fração
## não precisa ser corrigido quando um dos dois muda. Um diâmetro em unidades de
## mundo aqui seria um número que mente sobre o tamanho sempre que a câmera muda.
##
## O tamanho é limitado pelo VAO onde a moeda vive: o espaço entre as cartas do
## cemitério de cima e a faixa do marcador tem 275 px numa tela de 1080, e uma
## moeda maior que isso invade as cartas e some atrás delas (o 3D as desenha
## depois). 0.15 deixa a moeda com folga dos dois lados.
const FRACAO_DIAMETRO := 0.15

## A ALTURA FINAL do centro da moeda, como fração da altura da tela e em relação
## ao centro. POSITIVO é ACIMA do centro, porque o Y da base da câmera aponta
## para cima da tela — é o eixo de quem assiste, não o do mundo. O dono deste
## número: é o que segura a moeda no vao entre o CEMITÉRIO de cima e o MARCADOR
## de turno. Medido na tela: o cemitério acaba em y≈160 e a faixa do marcador
## começa em y≈435, então o meio do vao é y≈297 — e o meio da tela é y=540, o
## que dá 0,225. Desceu de 0.30 porque a 0.30 o topo da moeda entrava em y≈124 e
## ficava atrás das cartas do inimigo.
const ALTURA_FINAL := 0.225

## Quantas MEIAS VOLTAS a moeda da no giro. O dono deste numero: e o dono do
## TEMPO DE LEITURA e do GASTO DE TEMPO. E grande o bastante para o olho
## acompanhar (uma volta e meia parece que travou) e pequeno o bastante para nao
## cansar. E PAR: as duas faces da moeda se alternam a cada meia volta, entao um
## total par devolve a moeda a face de onde ela saiu.
const VOLTAS := 8.0

## A MEIA VOLTA EXTRA do rival, e o tempo que ela leva. O dono do angulo e a
## `MEIA_VOLTA`; o dono do TEMPO e este numero, e ele e o que faz o truque
## funcionar.
##
## A moeda COMECA SEMPRE na estrela, seja qual for o resultado: comecar na face que vai
## aparecer e dar a resposta antes da hora. O resultado vem de uma meia volta a
## mais no LOSANGO — e essa meia volta entra no instante de MAIOR velocidade do
## giro, que e o comeco (o `EASE_OUT` arranca com tudo). Uma meia volta a essa
## velocidade e meio giro de relogio: some no vao, e o que o olho ve e um giro so.
## Se ela entrasse no fim, o jogador a veria parar, virar e continuar — o truque
## viraria uma pista.
const MEIA_VOLTA := PI
const DURACAO_GIRO_EXTRA := 0.09

## O tempo que dura a ENTRADA (o efeito de ela aparecer), em segundos. O dono
## deste numero: e o dono da APARICAO. Durante a entrada a moeda ja esta de
## frente e ja esta girando, e o que cresce e a escala com a luz de borda — se
## a entrada fosse uma subida, a moeda estaria de lado durante a subida.
const DURACAO_ENTRADA := 0.34

## O tempo que dura o GIRO, em segundos. O dono deste numero: e o dono da
## PACIENCIA. Com `VOLTAS` fixo, mudar este numero muda o ritmo sem mexer na
## quantidade de voltas — e a soma das duas coisas que o olho acompanha (quantas
## voltas, e quao devagar).
const DURACAO_GIRO := 1.7

## O tempo que a moeda fica PARADA mostrando a face antes do estouro final, em
## segundos. O dono: e o dono da TESE. O jogador precisa de um instante em que a
## face esta visivel e parada para ler de quem e a vez; sem essa parada o
## resultado e uma informacao que passou.
const DURACAO_OSTRO := 0.55

## O tempo do ESTOURO final (particulas + anel) antes de a moeda sumir, em
## segundos. O dono: e o dono do FECHO. E curto de proposito — o estouro diz
## "acabou" e segura a tela, mas segurar mais que isso atrasa o turno.
const DURACAO_BOCA := 0.34

## A escala MENOR que a moeda tem no primeiro quadro da entrada, em fracao do
## tamanho final. O dono: e o dono do TAMANHO DA CHEGADA — 1.0 faria a entrada
## sumir (nao ha entrada), e um valor muito pequeno faz a moeda brotar do nada.
const ESCALA_ENTRADA := 0.35

## A forca da LUZ de borda durante a entrada, em energia. O dono: e o dono do
## CLARAO. A entrada tem que ter brilho porque uma moeda que so cresce no escuro
## parece um defeito de carregamento, e nao uma escolha de quem começa.
const LUZ_ENTRADA := 3.4

## A LUZ DE REPOUSO, em energia. O dono: e o dono do BRILHO no AR em volta da
## moeda. A moeda e `UNSHADED` como o resto da tela (entao a cor dela nao depende
## de luz nenhuma), mas a luz existe para o clarão do ESTOURO e para a face ficar
## com brilho de metal no meio do vidro. E uma luz BAIXA de proposito: e o bastante
## para a face aparecer, e nao o bastante para a moeda virar o ponto mais
## brilhante da tela e roubar a atencao das cartas.
const LUZ_REPOUSO := 0.85

## O alcance da luz que acompanha a moeda. O dono: e o dono da BANHA de luz; um
## alcance curto deixa a luz como um halo colado na moeda, e um alcance longo
## acende as cartas do fundo.
const LUZ_RAIO := 4.2

## O NOME de quem começa NAO aparece na moeda, e isso e uma decisao: a face e a
## resposta. A ESTRELA e o jogador e o LOSANGO e o rival, e um desenho de duas
## faces e mais rapido de ler do que um texto — ver a silhueta leva um quinto de
## segundo, ler um nome leva um segundo inteiro. Escrever o nome em cima da
## moeda seria traduzir a resposta que o jogador ja recebeu, e traduzir atrasa.

## O RAIOS e a quantidade de PARTICULAS do estouro. O dono: e o dono da FORCA
## do estouro. 40 e o que cabe no espaco entre a moeda e o HUD sem virar um
## borrão.
const PARTICULAS := 40

## O tempo de vida de uma PARTICULA, em segundos, e o alcance da explosao. O
## dono: sao os donos da DENSIDADE do estouro — vida curta e velocidade alta
## leem como faisca, vida longa le como fumaca.
const PARTICULA_VIDA := 0.7
const PARTICULA_VEL := Vector2(1.4, 4.2)

# ---------------------------------------------------------------------------
# AS CORES
# ---------------------------------------------------------------------------
## A cor do METAL da moeda e a do clarão. Sao a MESMA cor porque o clarão e a
## moeda pegando luz, e nao uma luz de outro objeto: duas cores aqui leem como
## duas coisas diferentes no mesmo instante.
const COR_QUENTE := Color(1.0, 0.72, 0.34)

## DE QUEM E A VEZ, em numero: 0 = o jogador, 1 = o rival. Este numero nao diz
## QUEM VENCE — quem ganhou e o motor (D42), e a moeda so o mostra. O dono: e o
## dono de QUAL FACE fica virada para quem assiste (a estrela no 0, o losango no
## 1), e e o unico lugar do arquivo que sabe qual face e de quem.
var _vencedor := 0

# ---------------------------------------------------------------------------
# O QUE ESTA MONTADO
# ---------------------------------------------------------------------------
var _no := Node3D.new()
var _corpo: MeshInstance3D = null
var _luz: OmniLight3D = null
var _particulas: GPUParticles3D = null
var _anel: Sprite3D = null

## O EIXO do giro. O X local deste no (que e filho da `_no`, a pose de frente)
## e a DIREITA DA TELHA: e o eixo em volta do qual a moeda tomba como quem rola
## uma moeda na beira do dedo, e e o unico giro que o olho ve de frente — girar
## em volta da propria normal da face (o que a moeda estava fazendo antes) deixa
## a face sempre virada para a camera e o giro some.
var _eixo := Node3D.new()

## O GIRO aplicado ao eixo, em radianos. O dono: e o dono do ANGULO, e nao do
## EIXO (o eixo e o da direita da tela) nem do COMECO (que e sempre a estrela).
var _giro := 0.0

## A MEIA VOLTA EXTRA ja entrou: e o que separa o losango da estrela sem
## denuncia. O dono do sinal e o MOTOR (D42): quem comeca e o motor que
## decidimos, e a moeda so conta. Vem antes do `_girar` porque `tocar` escreve
## zero aqui — a moeda nasce na estrela para os DOIS lados.
var _giro_extra := 0.0

## O FATOR de escala, medido da malha: e o dono do TAMANHO na tela. O diametro
## do `.glb` em escala 1 sai da medicao da sua caixa, entao o que decide quantas
## unidades de tela a moeda ocupa e a fracao pedida dividida por essa medida. Se
## o publicador trocar o `.glb` por outro, o tamanho na tela continua o mesmo sem
## editar nada.
var _esc := 1.0

## O `_tween` e guardado porque o `custom_step` de uma prova pode chegar antes
## do fim: e ele que sabe se ainda pode rodar. Se o objeto nao existir (a mesa
## foi embora) o passo nao faz nada.
var _tween: Tween = null

## A DURACAO total de uma animacao. Quem mede a cena (uma prova por tempo)
## le este valor em vez de recontar os passos, entao mudar os tempos acima
## arrasta a leitura junto - e um numero so que diz a duracao, e nao uma
## soma escrita a mao que erra quando um tempo muda.
##
## E `static` porque so le CONSTANTES — nao ha nada de instancia aqui, e e por
## isso que o dono do tempo pode ser perguntado sem montar uma moeda. O mesmo
## que `entrada_mao_3d.gd.duracao_total(n)`, e a mesma razao: quem espera a
## animacao nao deveria precisar montar a animacao para saber quanto ela dura.
##
## `vencedor` e o LADO que comeca (0 = jogador, 1 = rival) e nao um parametro
## decorativo: a meia volta extra e do rival e ela dura, entao um tempo so para
## os dois lados seria um tempo que mente para um deles. Quem espera pergunta do
## lado que comeca, igual a mesa pergunta de quem e a vez.
static func duracao_total(vencedor: int) -> float:
	var total := DURACAO_ENTRADA + DURACAO_GIRO + DURACAO_OSTRO + DURACAO_BOCA
	if vencedor == 1:
		total += DURACAO_GIRO_EXTRA
	return total

func _ready() -> void:
	name = "Moeda"
	_no.name = "MoedaNo"
	add_child(_no)
	_eixo.name = "Eixo"
	_no.add_child(_eixo)
	_aplicar_giro(0.0)

	var cena := preload("res://assets/3d/moeda.glb")
	var inst := cena.instantiate()
	_eixo.add_child(inst)
	_corpo = _acha_corpo(inst)
	if _corpo == null:
		push_error("[MOEDA] O .glb nao tem malha: o sorteio nao tem o que mostrar.")
		return
	_pintar_sem_luz(_corpo)

	# A MEDIDA do artefato. A ESCALA que põe a moeda no tamanho da tela é
	# calculada em `tocar()`, não aqui: o tamanho na tela depende do FOV da
	# câmera e da distância, e neste ponto do boot a câmera ainda não existe.
	var caixa := _caixa_do_corpo()
	var largo := maxf(caixa.x, caixa.z)
	if largo <= 0.001:
		push_error("[MOEDA] A malha do .glb tem largura zero.")
		return
	# O eixo da ESPESSURA tem de ser o Y local: e dele que sai a face mostrada.
	# Se o publicador virar o artefato, o dinheiro some e a face lida e a do
	# aro — entao isto avisa em vez de deixar o sorteio mentir em silencio.
	if caixa.y >= largo:
		push_warning("[MOEDA] O .glb tem a espessura no eixo Y = %.4f e o diametro = %.4f: a face da moeda virou de lado." % [caixa.y, largo])

	_luz = OmniLight3D.new()
	_luz.light_color = COR_QUENTE
	_luz.light_energy = 0.0
	_luz.omni_range = LUZ_RAIO
	_luz.shadow_enabled = false
	_no.add_child(_luz)

	_particulas = _cria_particulas(PARTICULAS)
	_no.add_child(_particulas)

	_anel = Sprite3D.new()
	_anel.texture = _textura_do_anel()
	_anel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_anel.pixel_size = 0.01
	_anel.modulate = Color(1.0, 1.0, 1.0, 0)
	_anel.visible = false
	_no.add_child(_anel)

	_corpo.visible = false


## Acha a malha em qualquer profundidade: o importador do Godot embrulha o `.glb`
## num no de raiz, e quem assina e a malha.
func _acha_corpo(no: Node) -> MeshInstance3D:
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		return no as MeshInstance3D
	for f in no.get_children():
		var achado := _acha_corpo(f)
		if achado != null:
			return achado
	return null


## A COR VIVA: a moeda no mesmo modo de sombreamento do resto da tela.
## O dono do comportamento e a CASA (cartas e vidro sao
## `SHADING_MODE_UNSHADED`); aqui so o que se faz com o material da peca.
##
## O `.glb` traz o metal como PBR de verdade (`roughness` 0.25 com clearcoat), e
## PBR sem luz e preto: a cena do duelo nao tem iluminacao e nao vai ter, entao o
## material importado sairia escuro e sem a cor do Blender. `UNSHADED` e o modo
## do RESTO da tela (a carta e o vidro) e por isso que a moeda e
## a unica peca que estava destoando. A luz que acompanha a moeda continua
## existindo, mas nao para iluminar o metal: e o brilho do ESTOURO final.
func _pintar_sem_luz(corpo: MeshInstance3D) -> void:
	# A CONTAGEM das superficies e da MALHA (`mesh`), nao do no: o
	# `get_surface_count` e do `Mesh`, e o `MeshInstance3D` so tem o
	# `get_active_material` (doc do motor).
	var malha := corpo.mesh
	if malha == null:
		return
	for s in malha.get_surface_count():
		var mat := corpo.get_active_material(s) as StandardMaterial3D
		if mat == null:
			continue
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## A caixa da MALHA, e nao a do no: o `dimensions` do embrulho do importador nao
## e a medida da peca.
func _caixa_do_corpo() -> Vector3:
	var caja := _corpo.get_aabb()
	return caja.size


## A ALTURA DO QUADRO: quantas unidades de mundo a câmera enxerga na vertical,
## na distância em que a moeda vive. A câmera é de PERSPECTIVA, então isso é a
## conta do FOV (`2 · d · tan(fov/2)`), não um número fixo do viewport — e é
## daqui que saem o tamanho da moeda e a altura dela, porque as duas são
## frações desta altura.
func _altura_do_quadro(cam: Camera3D) -> float:
	var meio := deg_to_rad(cam.fov) * 0.5
	if absf(meio) < 0.0001:
		return 1.0
	return 2.0 * DISTANCIA * tan(meio)


# ---------------------------------------------------------------------------
# TOCAR O SORTEIO
# ---------------------------------------------------------------------------
## Toca o sorteio inteiro e so volta quando a moeda sumiu.
##
## `cam` e a camera que esta ASSISTINDO, e ela e quem define onde a moeda fica:
## a posicao e montada no SISTEMA DA CAMERA (a frente dela, na horizontal, na
## altura do `ALTURA_FINAL`), porque a moeda e um desenho da tela e nao do
## tabuleiro. Nada aqui usa a transformacao do campo, e por isso a moeda nao
## muda de lugar quando a mesa gira.
func tocar(vencedor: int, cam: Camera3D) -> void:
	print("[DBG] moeda tocar t=", Time.get_ticks_msec())
	_vencedor = vencedor
	if _corpo == null or cam == null:
		return

	# ONDE a moeda nasce: na frente da câmera, na linha do meio da tela, na
	# altura do `ALTURA_FINAL`. E montado no sistema da CÂMERA (a base dela) e
	# não no da mesa, e é por isso que a moeda não sai do lugar quando a câmera
	# olha o campo de lado.
	var base := cam.global_transform.basis
	var quadro := _altura_do_quadro(cam)
	global_position = cam.global_position \
		- base.z * DISTANCIA \
		+ base.y * (ALTURA_FINAL * quadro)

	# O TAMANHO sai daqui, e não do `_ready`: o que ocupa 17% da tela depende do
	# FOV e da distância, e os dois só existem com a câmera em mãos. O `.glb` em
	# escala 1 tem o diâmetro medido da sua caixa, então a escala que põe o
	# diâmetro pedido na tela é a razão entre os dois.
	var largo := maxf(_caixa_do_corpo().x, _caixa_do_corpo().z)
	if largo <= 0.001:
		return
	_esc = (FRACAO_DIAMETRO * quadro) / largo

	# A POSE de frente para a câmera: uma vez só, e vale o giro inteiro. São
	# DOIS passos e nenhum é opcional: o `looking_at` aponta o -Z da base para a
	# câmera, e o giro de +90° no X local leva o +Y — a CARA, que é o eixo da
	# espessura no artefato — para esse -Z. Sem o giro a moeda aparece de perfil,
	# que é a moeda virada de lado: fina e sem leitura nenhuma.
	#
	# O `+90°` (e nao `-90°`) é o que deixa o LOSANGO do artefato virado para
	# quem assiste: o `.glb` traz o losango no +Y e a estrela no -Y, e quem
	# conhece qual face e qual é o próprio `.glb`, não este arquivo.
	var d := (cam.global_position - global_position).normalized()
	_no.basis = Basis.looking_at(d, Vector3.UP).rotated(Vector3.RIGHT, PI * 0.5)

	_luz.light_energy = LUZ_ENTRADA
	_corpo.visible = true
	_corpo.scale = Vector3.ONE * _esc * ESCALA_ENTRADA
	# A moeda COMECA SEMPRE na estrela, para os DOIS lados: comecar na face que vai
	# aparecer seria dar a resposta antes da hora. E o giro que traz o resultado —
	# o rival ganha uma meia volta a mais, feita no instante de maior velocidade
	# (ver `DURACAO_GIRO_EXTRA`), entao os dois comecam iguais e so terminam
	# diferentes.
	_giro_extra = 0.0
	_aplicar_giro(0.0)

	_tween = create_tween()
	# A entrada: a moeda CRESCE no lugar (nao sobe, nao entra de lado) e a luz
	# de borda apaga. E o efeito de ela aparecer.
	_tween.tween_method(Callable(self, "_entrada"), 0.0, 1.0, DURACAO_ENTRADA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# A MEIA VOLTA EXTRA (so no rival): logo no COMECO do giro, que e onde a
	# velocidade e maior. Ela corre em `TRANS_LINEAR` porque nao e um giro e uma
	# virada: uma meia volta em 0,09 s e um piscar, e o que o olho ve em volta e
	# o giro normal. O jogador nao tem esta fatia — os dois veem a MESMA
	# velocidade no primeiro instante.
	if _vencedor == 1:
		_tween.tween_method(Callable(self, "_giro_extra_para"),
			0.0, MEIA_VOLTA, DURACAO_GIRO_EXTRA).set_trans(Tween.TRANS_LINEAR)
	# O giro: em torno do eixo vertical da tela, para a DIREITA, desacelerando.
	_tween.tween_method(Callable(self, "_girar"), 0.0, 1.0, DURACAO_GIRO) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(Callable(self, "_parado"), 0.0, 1.0, DURACAO_OSTRO)
	_tween.tween_callback(Callable(self, "_bocao"))
	_tween.tween_interval(DURACAO_BOCA)
	_tween.tween_callback(Callable(self, "_sumir"))

	await _tween.finished


## A ENTRADA: a escala cresce de `ESCALA_ENTRADA` ate 1 e o clarão DEIXA a luz
## de repouso (nao vai a zero — e o que a moeda continua visivel durante o giro).
## O `custom_step` das provas pode passar por aqui no meio, e por isso a escala e
## escrita a partir do `t` e nao accumulando passo a passo.
func _entrada(t: float) -> void:
	var k := clampf(t, 0.0, 1.0)
	_corpo.scale = Vector3.ONE * _esc * lerpf(ESCALA_ENTRADA, 1.0, k)
	_luz.light_energy = lerpf(LUZ_ENTRADA, LUZ_REPOUSO, k)


## A MEIA VOLTA EXTRA, em radianos (o `tween_method` entrega o proprio angulo, nao
## uma fracao). Ela NAO chama `_aplicar_giro` porque o `_girar` que vem a seguir
## ja escreve o angulo inteiro a partir do `_giro_extra`: o extra e uma BASE que o
## giro soma, e nao um passo do giro.
func _giro_extra_para(angulo: float) -> void:
	_giro_extra = angulo


## O GIRO: o angulo do eixo vai de 0 ate `VOLTAS` meias voltas SOBRE a base do
## extra, e o `TRANS_CUBIC` do tween (que e quem desacelera) faz a parada. O numero
## de voltas e INTEIRO de proposito: uma volta e meia pararia de lado, e a moeda de
## lado nao diz nada.
func _girar(t: float) -> void:
	_aplicar_giro(_giro_extra + VOLTAS * MEIA_VOLTA * clampf(t, 0.0, 1.0))


## A ROTAÇÃO do eixo de giro: uma volta no X local, que e a direita da tela. O
## numero e o angulo em radianos e nao em voltas porque a Ease do tween entrega
## uma fracao — quem converte para radianos e o `_girar`.
func _aplicar_giro(giro: float) -> void:
	_giro = giro
	_eixo.basis = Basis(Vector3.RIGHT, giro)


## A PARADA: a moeda esta parada e de frente, com a luz de repouso. E a janela
## de leitura do resultado — a face do lado que comeca, parada e grande.
func _parado(_t: float) -> void:
	_luz.light_energy = LUZ_REPOUSO


## O ESTOURO: as particulas e o anel saem do centro da moeda, e a moeda some
## depois. O estouro e a ultima coisa antes do turno abrir.
func _bocao() -> void:
	_particulas.position = Vector3.ZERO
	_particulas.amount_ratio = 1.9
	_particulas.restart()
	_particulas.emitting = true
	_anel.visible = true
	_anel.scale = Vector3.ONE * 0.4
	_anel.modulate = Color(1.0, 1.0, 1.0, 0.9)
	_tween_anel()


## O ANEL cresce e some. Ele e um `Sprite3D` com textura de anel (gerada aqui,
## como a arte da carta), e a unica coisa que mostra onde a moeda estava depois
## que ela sai.
func _tween_anel() -> void:
	var t := create_tween()
	t.tween_method(Callable(self, "_anel_para"), 0.0, 1.0, DURACAO_BOCA) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _anel_para(t: float) -> void:
	if _anel == null or not is_instance_valid(_anel):
		return
	var k := clampf(t, 0.0, 1.0)
	_anel.scale = Vector3.ONE * lerpf(0.4, 1.5, k)
	_anel.modulate = Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k))


## A MOEDA SAI. Ela fica invisivel e sem luz, e o proximo turno e do motor.
func _sumir() -> void:
	if _corpo != null and is_instance_valid(_corpo):
		_corpo.visible = false
	if _luz != null and is_instance_valid(_luz):
		_luz.light_energy = 0.0
	if _anel != null and is_instance_valid(_anel):
		_anel.visible = false
	if _particulas != null and is_instance_valid(_particulas):
		_particulas.emitting = false


## Deixa o no pronto para o proximo sorteio: e o que a mesa chama antes de
## `tocar()`, para um sorteio seguido nao herdar o brilho do anterior.
func reset() -> void:
	_sumir()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _no != null and is_instance_valid(_no):
		_no.rotation = Vector3.ZERO
		_no.position = Vector3.ZERO


## O passo de uma prova: `custom_step` avanca o tween na mao, e o `t` que ele
## entrega e o tempo do tween. Se o tween ja acabou (ou nunca existiu), o passo
## nao faz nada — a prova so precisa que o RELOGIO ande, nao que a cena mude.
func custom_step(delta: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.custom_step(delta)


# ---------------------------------------------------------------------------
# AS TEXTURAS (geradas no jogo, como a arte da carta)
# ---------------------------------------------------------------------------
## O anel e o ponto sao FEITOS AQUI, e nao num asset: sao dois borroes, e um PNG
## de 128×128 no repo seria peso sem informacao. O anel e um smoothstep em cima
## de `|dist - r|`, que e o que da a borda macia sem textura.

static func _textura_do_anel() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in range(n):
		for x in range(n):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - absf(d - 0.70) / 0.26, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)


static func _textura_do_ponto() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in range(n):
		for x in range(n):
			var d := clampf(Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			var a := 1.0 - d
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)


func _cria_particulas(quantas: int) -> GPUParticles3D:
	var malha := QuadMesh.new()
	# A FAISCA e pequena: a moeda esta a um FATOR da tela da camera, e um quad
	# grande ali vira um borrao do tamanho de um cartao.
	malha.size = Vector2(0.10, 0.10)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _textura_do_ponto()
	mat.albedo_color = COR_QUENTE
	mat.emission_enabled = true
	mat.emission = COR_QUENTE
	mat.emission_energy_multiplier = 2.0
	malha.material = mat

	var p := GPUParticles3D.new()
	p.amount = maxi(quantas, 1)
	p.lifetime = PARTICULA_VIDA
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.draw_pass_1 = malha
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3.UP
	proc.spread = 180.0
	proc.initial_velocity_min = PARTICULA_VEL.x
	proc.initial_velocity_max = PARTICULA_VEL.y
	proc.gravity = Vector3(0.0, -3.2, 0.0)
	proc.scale_min = 0.5
	proc.scale_max = 1.3
	proc.damping_min = 1.0
	proc.damping_max = 2.6
	proc.color = COR_QUENTE
	p.process_material = proc
	return p