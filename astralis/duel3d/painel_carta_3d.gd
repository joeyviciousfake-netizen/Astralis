extends Control

## painel_carta_3d — O PAINEL ESQUERDO: a carta que o cursor esta apontando.
## Um assunto so.
##
## De cima para baixo, nas faixas medidas no doc 15 §15.3: o fundo (que e irmao
## deste no, desenhado pela mesa), a CARTA (y 16..562), a faixa de ATK/DEF com
## os dois orbes e o contador de copias (y 562..648), o NOME em amarelo
## (y 670..756), o TIPO verde entre colchetes (y 756..799) e a DESCRICAO branca
## com a barra laranja de rolagem (y 810..1080).
##
## A CARTA aqui e a CARTA 3D DE VERDADE, a mesma peca que o campo e a mao
## desenham: nao existe uma imagem 2D imitando a carta neste painel. A peca e
## montada pela MESMA fabrica (`carta_3d.gd`), com o mesmo dado, e o que aparece
## e o resultado — corpo do `.glb` com o canto arredondado, moldura, arte na
## janela, orbe, fileira de estrelas, nome e ATK/DEF impressos. Uma diferenca
## de desenho entre a carta do campo e a do painel seria duas cartas, e o painel
## nao pode ser um duble do que a mesa mostra.
##
## A vista e RETA, de frente, por uma camera ORTOGONAL: o painel e lugar de
## informacao, entao a carta e lida sem perspectiva nem distorcao. Isso nao
## muda a peca, muda o olho — e o olho aqui nao e o da mesa (o da mesa esta
## preso em D41/D47), e um olho so deste painel.
##
## D46b (sobreviveu dentro da D47): na vez do RIVAL o painel CONTINUA VIVO (o
## jogador pode focar o que quiser) mas nao entrega a carta - mostra a carta de
## costas, a imagem PADRONIZADA do jogo (o verso, que ja e asset) e NENHUM
## dado. E o que o rival esta vendo, e o rival nao pode saber o que voce tem.
##
## O no se chama "PainelCarta" e e filho direto do HUD: e por isso que nenhuma
## trava de teste mudou de caminho.

## Onde o painel comeca e acaba, em px do canvas 1920x1080 (doc 15 §15.3). Sao
## da TELA, entao a mesa e que passa (o mesmo numero diz onde o campo 3D
## comeca).
var largura := 431
var altura := 1080
## As DUAS medidas da carta em unidades de mundo, e o DONO delas e a mesa (a
## carta 3D do campo usa as mesmas). O painel usa as duas para dar a
## proporcao real (59 x 86) ao retangulo da carta e para armar a camera
## ortogonal. Sem default de proposito, pelo mesmo motivo dos outros
## receptores: valor escrito aqui seria a segunda fonte da mesma medida.
var larg_carta: float
var alt_carta: float

const CARTA_Y0 := 16
const CARTA_Y1 := 562
## Distancia da camera ortogonal ate a carta. Ela NAO muda o tamanho do desenho
## (e ortogonal, nao perspectiva): existe so para a carta ficar entre os planos
## near e far da camera.
const DIST_CAM_CARTA := 2.0
const STATS_Y0 := 562
const STATS_Y1 := 648
const NOME_Y0 := 670
const NOME_Y1 := 756
const TIPO_Y0 := 756
const TIPO_Y1 := 799
const DESC_Y0 := 810
const COR_LP_VALOR := Color(1.0, 0.83, 0.00, 1.0)
const COR_NOME := Color(1.0, 0.85, 0.15, 1.0)
const COR_TIPO := Color(0.30, 0.95, 0.45, 1.0)
const COR_DESCRICAO := Color(0.92, 0.94, 1.00, 1.0)
const COR_SCROLL := Color(1.0, 0.55, 0.00, 1.0)

## O que este painel PRECISA de fora, e nada mais. Tudo e leitura: o painel
## pergunta, e nunca guarda copia (D59 - trocar o duelo em tempo de execucao
## deixaria numero velho na tela).
var estado: Callable
var cartas_de: Callable
## A carta sob o cursor: {"dado", "aberta", "lado", "inst"}.
var foco: Callable
var tex_cache: Callable
var cor_de_atributo: Callable
## As 2 guardian stars do DADO. O dono da leitura e a mesa (o FLUXO tambem
## precisa delas, para as opcoes do menu da estrela), entao o painel pergunta.
var estrelas_da_carta: Callable
## D80: a tela ainda esta ESPERANDO a moeda. Enquanto for verdade o painel fica
## VAZIO — nem a carta do foco, nem o verso do rival. Quem pergunta e a mesa
## (e a mesa sabe: ela e quem mandou a moeda aparecer), e e uma PERGUNTA como as
## outras: o painel nao tem como saber que a moeda existe.
##
## O painel nao usa este estado para se esconder nem para mentir: ele so deixa de
## responder. A razao esta em `_atualizar`.
var esperando_sorteio: Callable
## MONTAR a carta 3D. Quem monta e a fabrica (`carta_3d.gd`) e quem a tem e a
## mesa, entao o painel recebe a operacao, nunca a fabrica: assim o painel nao
## tem como mexer nas medidas nem nas texturas que continuam sendo de um dono so.
var montar_carta: Callable

## Chave da janela quando ela mostra o VERSO PADRONIZADO (nenhum dado, D46b).
## O prefixo `:` nao existe em id de carta (o contrato so aceita
## `^[a-z][a-z0-9_]*$`), entao o verso nunca colide com uma carta.
const CHAVE_VERSO := "verso:padrao"
const PREFIJO_CARTA := "carta:"

var _janela_carta: SubViewportContainer = null
var _vp_carta: SubViewport = null
var _mundo_carta: Node3D = null
var _cam_carta: Camera3D = null
var _carta_no: Node3D = null
## Qual carta esta montada na janela agora. Serve para nao remontar a peca a
## cada passo do cursor — nao e copia do estado do duelo, e o remember do que
## ja foi desenhado: a carta do DADO nao muda enquanto o id nao muda.
var _carta_chave := ""
var _cor_atr: ColorRect = null
var _stats: Label = null
var _orbe_atr: TextureRect = null
var _orbe_tipo: TextureRect = null
var _copias: Label = null
var _nome: Label = null
var _tipo: Label = null
var _desc: Label = null
var _estrelas: Label = null


func _ready() -> void:
	name = "PainelCarta"
	position = Vector2.ZERO
	size = Vector2(largura, altura)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir_carta()
	_construir_faixa_stats()
	_construir_nome_tipo()
	_construir_descricao()


## --- A CARTA (y 16..562). E a CARTA 3D de verdade, entao o retangulo e uma
## JANELA 3D: um SubViewport proprio, com a carta dentro, visto por uma camera
## ORTOGONAL de frente. Ela nao divide o mundo do campo (o campo gira a
## camera 180 e nada aqui pode acompanhar isso), e o fundo e transparente para
## o azul-marinho do painel aparecer atras.
##
## O retangulo tem a PROPORCAO REAL da carta (59 x 86), e nao a da moldura em
## JPG: o que esta desenhado agora e a peca, e a peca mede 59 x 86. Com a altura
## da faixa da ref (546 px) a largura sai 375 px, centrada nos 431 do painel
## (28 px de margem de cada lado, a mesma dos textos).
## Camera ortogonal com `size` = altura da carta e `KEEP_HEIGHT` faz a peca
## preencher o retangulo exatamente: nem sobra, nem corta o canto arredondado.
func _construir_carta() -> void:
	assert(larg_carta > 0.0 and alt_carta > 0.0,
		"painel_carta_3d: larg_carta/alt_carta vem da mesa (ela e o dono da medida, "
		+ "a mesma que a carta 3D do campo usa). Vazia aqui = janela 3D sem medida.")
	var alt_px := float(CARTA_Y1 - CARTA_Y0)
	var larg_px := float(round(alt_px * larg_carta / alt_carta))
	_janela_carta = SubViewportContainer.new()
	_janela_carta.name = "Carta3DJanela"
	_janela_carta.position = Vector2(float(round((largura - larg_px) * 0.5)), float(CARTA_Y0))
	_janela_carta.size = Vector2(larg_px, alt_px)
	_janela_carta.stretch = true
	_janela_carta.stretch_shrink = 1
	_janela_carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_janela_carta)
	_vp_carta = SubViewport.new()
	_vp_carta.name = "Carta3DViewport"
	# Textura 1:1 (mesmo tamanho do retangulo): sem escala/rotação na imagem.
	_vp_carta.size = _janela_carta.size
	# Mundo PROPRIO: o campo 3D tem a camera no pivô da volta da mesa, e nada
	# do painel pode herdar esse mundo.
	_vp_carta.own_world_3d = true
	_vp_carta.transparent_bg = true
	_vp_carta.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_janela_carta.add_child(_vp_carta)
	_mundo_carta = Node3D.new()
	_mundo_carta.name = "Carta3DMundo"
	_vp_carta.add_child(_mundo_carta)
	_cam_carta = Camera3D.new()
	_cam_carta.name = "Carta3DCam"
	# ORTOGONAL, de frente: o painel e lugar de informacao, e a carta e lida sem
	# perspectiva nem distorcao. A peca e a mesma do campo; o olho e outro.
	_cam_carta.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam_carta.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam_carta.size = alt_carta
	_cam_carta.position = Vector3(0.0, 0.0, DIST_CAM_CARTA)
	_vp_carta.add_child(_cam_carta)
	_cam_carta.current = true
	_janela_carta.visible = false


## --- Faixa de ATK/DEF (y 562..648): "ATK/3000 DEF/2000" + os 2 orbes + o
## contador de copias da carta no baralho do jogador (dado real).
func _construir_faixa_stats() -> void:
	var faixa := HBoxContainer.new()
	faixa.name = "FocoFaixa"
	faixa.position = Vector2(28, STATS_Y0)
	faixa.size = Vector2(largura - 56, STATS_Y1 - STATS_Y0)
	faixa.custom_minimum_size = faixa.size
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_theme_constant_override("separation", 10)
	faixa.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(faixa)
	_cor_atr = ColorRect.new()
	_cor_atr.name = "FocoAttrIcon"
	_cor_atr.custom_minimum_size = Vector2(26, 26)
	_cor_atr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cor_atr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(_cor_atr)
	_stats = _rotulo("FocoStats", "", 26, COR_LP_VALOR)
	faixa.add_child(_stats)
	_orbe_atr = TextureRect.new()
	_orbe_atr.name = "FocoOrbeFaixa"
	_orbe_atr.custom_minimum_size = Vector2(52, 52)
	_orbe_atr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orbe_atr.stretch_mode = TextureRect.STRETCH_SCALE
	_orbe_atr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_orbe_atr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(_orbe_atr)
	_orbe_tipo = TextureRect.new()
	_orbe_tipo.name = "FocoOrbeTipo"
	_orbe_tipo.custom_minimum_size = Vector2(52, 52)
	_orbe_tipo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orbe_tipo.stretch_mode = TextureRect.STRETCH_SCALE
	_orbe_tipo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_orbe_tipo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(_orbe_tipo)
	_copias = _rotulo("FocoCopias", "", 26, COR_DESCRICAO)
	_copias.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	faixa.add_child(_copias)


## --- NOME (y 670..756) em amarelo, do lado esquerdo como na ref. E o TIPO
## (y 756..799) verde entre colchetes.
func _construir_nome_tipo() -> void:
	_nome = _rotulo("FocoNome", "\u2014", 30, COR_NOME)
	_nome.position = Vector2(28, NOME_Y0)
	_nome.size = Vector2(largura - 56, NOME_Y1 - NOME_Y0)
	_nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nome.clip_text = true
	add_child(_nome)
	_tipo = _rotulo("FocoTipo", "", 24, COR_TIPO)
	_tipo.position = Vector2(28, TIPO_Y0)
	_tipo.size = Vector2(largura - 56, TIPO_Y1 - TIPO_Y0)
	_tipo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tipo.clip_text = true
	add_child(_tipo)
	_estrelas = _rotulo("FocoEstrelas", "", 18, COR_NOME)
	_estrelas.visible = false
	add_child(_estrelas)


## --- DESCRICAO (y 810..1080): bloco de tamanho FIXO (texto longo nunca muda o
## tamanho do painel, corta com clip) + barra laranja de rolagem.
func _construir_descricao() -> void:
	var bloco := Control.new()
	bloco.name = "BlocoDesc"
	bloco.position = Vector2(28, DESC_Y0)
	bloco.size = Vector2(largura - 56, altura - DESC_Y0 - 10)
	bloco.custom_minimum_size = bloco.size
	bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bloco)
	# SEM linha de atributo aqui (D5): na ref, depois do [TIPO] vem direto a
	# descricao. O atributo ja aparece como ORBE na faixa de ATK/DEF e no canto
	# da carta - repetir o nome em texto era so ruido.
	_desc = _rotulo("FocoDesc", "", 21, COR_DESCRICAO)
	_desc.position = Vector2(0, 4)
	_desc.size = Vector2(bloco.size.x - 22, bloco.size.y - 4)
	_desc.custom_minimum_size = _desc.size
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.clip_text = true
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bloco.add_child(_desc)
	var barra := ColorRect.new()
	barra.name = "BarraVermelha"
	barra.color = COR_SCROLL
	barra.position = Vector2(bloco.size.x - 10, 0)
	barra.size = Vector2(10, bloco.size.y)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco.add_child(barra)


func _rotulo(nome: String, texto: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Escreve a carta sob o cursor no painel. O dado e real (R3) e o rival de
## costas nunca vaza: e o `aberta` que a mesa traz.
func atualizar() -> void:
	if not foco.is_valid():
		return
	# D80: a tela esta ESPERANDO a moeda, e o painel fica VAZIO. Nao e o verso do
	# rival nem a sua carta: e nada. A razao e o que a tela contaria sem isto —
	# com o motor JA TENDO sorteado (D42) e a tela ainda nao virada, o cursor
	# esta no LUGAR DE BAIXO, que e a mao de quem ganhou. Mostrar o verso dele
	# era mostrar "a sua mao sumiu", e mostrar a sua carta era mostrar "a sua mao
	# continua aqui": os dois lados diziam o resultado antes da moeda. Enquanto
	# nao ha resposta, nao ha o que mostrar.
	if esperando_sorteio.is_valid() and bool(esperando_sorteio.call()):
		_limpar()
		return
	var st = estado.call() if estado.is_valid() else null
	if st != null and int(st.current_player) == 1:
		atualizar_neutro()
		return
	var f: Dictionary = foco.call() as Dictionary
	var dado: Dictionary = f.get("dado", {}) as Dictionary
	if dado.is_empty():
		_limpar()
		return
	var cartas: Dictionary = cartas_de.call() as Dictionary
	var cid := str(dado.get("id", dado.get("card_id", "")))
	var real: Dictionary = dado
	if not cid.is_empty() and cartas.has(cid):
		real = cartas[cid] as Dictionary
	var nome := str(real.get("name", dado.get("name", "?")))
	_nome.text = nome
	var attr := str(real.get("attribute", dado.get("attribute", "")))
	var ctipo := str(real.get("card_type", dado.get("card_type", "monster")))
	var tex_o := tex_cache.call("assets/attributes/%s.png" % attr.to_lower()) as Texture2D
	# A CARTA 3D: a peca real, montada pela mesma fabrica do campo. A posicao no
	# slot vem do DADO (`position`), e nao de um palpite.
	var inst: Dictionary = f.get("inst", {}) as Dictionary
	var em_defesa := str(inst.get("position", "")).to_upper() == "DEF"
	_trocar_carta(real, false, em_defesa, PREFIJO_CARTA + cid)
	_stats.text = "ATK/%d DEF/%d" % [int(real.get("attack", dado.get("attack", 0))), int(real.get("defense", dado.get("defense", 0)))]
	# O atributo NAO vira texto no painel (D5): fica no orbe da faixa e no canto
	# da carta. O quadradinho da faixa usa a cor do atributo real.
	_cor_atr.color = cor_de_atributo.call(attr)
	var tipo := str(real.get("monster_type", dado.get("monster_type", "")))
	_tipo.text = ("[%s]" % tipo.to_upper()) if (ctipo == "monster" and not tipo.is_empty()) else ("[%s]" % ctipo.to_upper())
	var desc := str(real.get("description", dado.get("description", "")))
	if desc.strip_edges().is_empty():
		var ops: Array = estrelas_da_carta.call(dado) as Array
		desc = "Guardiãs %s/%s." % [str(ops[0]), str(ops[1])] if not dado.is_empty() else ""
		if not attr.is_empty():
			desc += (" Atributo %s." % attr) if not desc.is_empty() else ("Atributo %s." % attr)
	_desc.text = desc
	# Orbe 1 = ATRIBUTO; orbe 2 = TIPO, e so existe quando o dado tem atributo
	# de magia/armadilha - carta sem esse atributo nao ganha orbe inventado.
	_orbe_atr.texture = tex_o
	_orbe_atr.visible = tex_o != null
	var tipo_orbe := attr.to_lower() if ctipo == "spell" or ctipo == "trap" else ""
	if not tipo_orbe.is_empty():
		var tex_t := tex_cache.call("assets/attributes/%s.png" % tipo_orbe) as Texture2D
		_orbe_tipo.texture = tex_t
		_orbe_tipo.visible = tex_t != null
	else:
		_orbe_tipo.texture = null
		_orbe_tipo.visible = false
	var copias := contar_copia_carta(cid, st)
	_copias.text = ("x%d" % copias) if copias > 0 else ""


## Troca a carta 3D da JANELA. `chave` e o que esta na janela agora: com a
## mesma chave a peca nao e remontada, porque o cursor anda a cada passo e
## remontar a carta inteira (corpo, face, arte, quads) 60x por segundo e
## desperdicio. A chave e o id do DADO, e a carta do DADO nao muda enquanto o
## id nao muda.
func _trocar_carta(dado: Dictionary, face_down: bool, em_defesa: bool, chave: String) -> void:
	if chave == _carta_chave and is_instance_valid(_carta_no):
		return
	_carta_chave = chave
	if _carta_no != null and is_instance_valid(_carta_no):
		_mundo_carta.remove_child(_carta_no)
		# `free()` imediato, nao `queue_free`: a fila so drena no fim do frame, e
		# o GUT conta orfao antes disso.
		_carta_no.free()
	_carta_no = null
	if dado.is_empty() and not face_down:
		_janela_carta.visible = false
		return
	_carta_no = montar_carta.call(dado, face_down, em_defesa) as Node3D
	_mundo_carta.add_child(_carta_no)
	_janela_carta.visible = true


## Nada focavel: o painel mostra o traço e diz para mirar.
func _limpar() -> void:
	_nome.text = "—"
	_stats.text = ""
	_cor_atr.color = Color(0.2, 0.2, 0.25)
	_tipo.text = ""
	_desc.text = "Mire numa carta."
	_copias.text = ""
	_orbe_atr.texture = null
	_orbe_tipo.texture = null
	_orbe_atr.visible = false
	_orbe_tipo.visible = false
	_trocar_carta({}, false, false, "")


## D46b: na vez do RIVAL o quadro fica, a carta some. A carta de VERSO — a
## imagem PADRONIZADA do jogo — e NENHUM dado. O dado entregue e vazio de
## propósito: quem vira e o que esconde a frente, e o verso e asset do jogo.
## So DESENHO; o estado nao e tocado.
func atualizar_neutro() -> void:
	_nome.text = ""
	_stats.text = ""
	_tipo.text = ""
	_desc.text = ""
	_copias.text = ""
	_orbe_atr.texture = null
	_orbe_atr.visible = false
	_orbe_tipo.texture = null
	_orbe_tipo.visible = false
	_cor_atr.color = Color(0.2, 0.2, 0.25)
	_trocar_carta({}, true, false, CHAVE_VERSO)


## Quantas COPIAS da carta focada estao no BARALHO DO JOGADOR (dado real). So
## conta o estado - devolve 0 se nao achar, e o painel esconde o contador
## quando 0 (nada inventado).
func contar_copia_carta(cid: String, st) -> int:
	if st == null or cid.is_empty():
		return 0
	var p: Dictionary = (st.players[0] as Dictionary)
	var total := 0
	for inst in (p.get("deck", []) as Array):
		if inst is Dictionary and str((inst as Dictionary).get("card_id", (inst as Dictionary).get("id", ""))) == cid:
			total += 1
	return total
