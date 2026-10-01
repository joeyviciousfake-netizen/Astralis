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
## A carta e a carta REAL: moldura, arte, nome, orbe do atributo, fileira de
## estrelas-imagem e todos os numeros vem do DADO (R3). Este painel nao calcula
## regra nenhuma - ele pergunta o que esta sob o cursor e escreve.
##
## D46b (sobreviveu dentro da D47): na vez do RIVAL o painel CONTINUA VIVO (o
## jogador pode focar o que quiser) mas nao entrega a carta - mostra a imagem
## PADRONIZADA do jogo (o verso, que ja e asset) e NENHUM dado. E o que o rival
## esta vendo, e o rival nao pode saber o que voce tem.
##
## O no se chama "PainelCarta" e e filho direto do HUD, com os mesmos filhos de
## antes: e por isso que nenhuma trava de teste mudou de caminho.

## Onde o painel comeca e acaba, em px do canvas 1920x1080 (doc 15 §15.3). Sao
## da TELA, entao a mesa e que passa (o mesmo numero diz onde o campo 3D
## comeca).
var largura := 562
var altura := 1080
## Janela de arte DENTRO da moldura real (832x1248), em fracao: a arte preenche
## a janela sem sobra, e ancorar em % faz a peca acompanhar o tamanho do molde.
## A JANELA e do CONTRATO da carta, entao o dono dela e a mesa (a carta 3D usa
## a mesma); o painel recebe.
var janela_art := Vector4(0.1190, 0.1827, 0.8918, 0.7099)

const CARTA_Y0 := 16
const CARTA_Y1 := 562
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
var textura_arte: Callable
var moldura_da_carta: Callable
## As 2 guardian stars do DADO. O dono da leitura e a mesa (o FLUXO tambem
## precisa delas, para as opcoes do menu da estrela), entao o painel pergunta.
var estrelas_da_carta: Callable

var _moldura: TextureRect = null
var _arte: TextureRect = null
var _cor_arte: ColorRect = null
var _orbe_molde: TextureRect = null
var _nome_molde: Label = null
var _caixa_estrelas: HBoxContainer = null
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


## --- A CARTA (y 16..562). A moldura real e 832x1248 (0,667), entao numa caixa
## de 546 de altura a carta tem 364 de largura, CENTRADA na faixa.
func _construir_carta() -> void:
	var molde := Control.new()
	molde.name = "CartaMolde"
	var alt_carta := float(CARTA_Y1 - CARTA_Y0)
	var larg_carta := alt_carta * (832.0 / 1248.0)
	molde.position = Vector2(round((largura - larg_carta) * 0.5), CARTA_Y0)
	molde.size = Vector2(round(larg_carta), alt_carta)
	molde.custom_minimum_size = molde.size
	molde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(molde)
	_moldura = TextureRect.new()
	_moldura.name = "Moldura"
	_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_moldura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_moldura.stretch_mode = TextureRect.STRETCH_SCALE
	_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_moldura)
	_arte = TextureRect.new()
	_arte.name = "FocoArte"
	_ancorar(_arte, janela_art.x, janela_art.y, janela_art.z, janela_art.w)
	_arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arte.stretch_mode = TextureRect.STRETCH_SCALE
	_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_arte)
	_cor_arte = ColorRect.new()
	_cor_arte.name = "FocoCor"
	_ancorar(_cor_arte, janela_art.x, janela_art.y, janela_art.z, janela_art.w)
	_cor_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_cor_arte)
	_nome_molde = _rotulo("FocoNomeMolde", "", 15, Color(0.12, 0.07, 0.03))
	_ancorar(_nome_molde, 0.054, 0.027, 0.674, 0.078)
	_nome_molde.clip_text = true
	molde.add_child(_nome_molde)
	_orbe_molde = TextureRect.new()
	_orbe_molde.name = "FocoOrbe"
	_ancorar(_orbe_molde, 0.833, 0.044, 0.928, 0.109)
	_orbe_molde.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_orbe_molde.stretch_mode = TextureRect.STRETCH_SCALE
	_orbe_molde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_orbe_molde)
	_caixa_estrelas = HBoxContainer.new()
	_caixa_estrelas.name = "FocoEstrelasBox"
	_ancorar(_caixa_estrelas, 0.40, 0.118, 0.92, 0.172)
	_caixa_estrelas.alignment = BoxContainer.ALIGNMENT_END
	_caixa_estrelas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa_estrelas.add_theme_constant_override("separation", 1)
	molde.add_child(_caixa_estrelas)


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


## Peca posicionada em % da MOLDE, com ANCORAS: assim ela acompanha o tamanho
## do molde (que estica com o painel) em vez de um px fixo.
func _ancorar(c: Control, x0: float, y0: float, x1: float, y1: float) -> void:
	c.anchor_left = x0
	c.anchor_top = y0
	c.anchor_right = x1
	c.anchor_bottom = y1
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


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
	_nome_molde.text = nome.to_upper()
	_moldura.texture = tex_cache.call(moldura_da_carta.call(real)) as Texture2D
	var nivel := int(real.get("level", dado.get("level", 0)))
	var attr := str(real.get("attribute", dado.get("attribute", "")))
	var ctipo := str(real.get("card_type", dado.get("card_type", "monster")))
	var tex_o := tex_cache.call("assets/attributes/%s.png" % attr.to_lower()) as Texture2D
	_orbe_molde.texture = tex_o
	# As estrelas-imagem da carta (o level vira fileira de estrelas, e so
	# monstro tem): o asset e um, a fileira e o level.
	for f2 in _caixa_estrelas.get_children():
		(f2 as Node).queue_free()
	var tex_e := tex_cache.call("assets/estrelas/estrela.png") as Texture2D
	if tex_e != null and ctipo == "monster":
		for s in range(clampi(nivel, 0, 12)):
			var im := TextureRect.new()
			im.custom_minimum_size = Vector2(20, 20)
			im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			im.stretch_mode = TextureRect.STRETCH_SCALE
			im.texture = tex_e
			im.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_caixa_estrelas.add_child(im)
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
	var tex := textura_arte.call(real) as Texture2D
	if tex != null:
		_arte.texture = tex
		_arte.visible = true
		_cor_arte.visible = false
	else:
		_arte.visible = false
		_cor_arte.visible = true
		_cor_arte.color = cor_de_atributo.call(attr)


## Nada focavel: o painel mostra o traço e diz para mirar.
func _limpar() -> void:
	_nome.text = "\u2014"
	_nome_molde.text = ""
	_stats.text = ""
	_cor_atr.color = Color(0.2, 0.2, 0.25)
	_tipo.text = ""
	_desc.text = "Mire numa carta."
	_copias.text = ""
	_orbe_atr.texture = null
	_orbe_tipo.texture = null
	_orbe_atr.visible = false
	_orbe_tipo.visible = false
	_arte.visible = false
	_cor_arte.color = Color(0.08, 0.08, 0.12)
	_moldura.texture = null
	_orbe_molde.texture = null
	_limpar_estrelas()


## D46b: na vez do RIVAL o quadro fica, a carta some. Imagem PADRONIZADA (o
## verso, que ja e asset do jogo) e NENHUM dado. So DESENHO; o estado nao e
## tocado.
func atualizar_neutro() -> void:
	_nome.text = ""
	_nome_molde.text = ""
	_stats.text = ""
	_tipo.text = ""
	_desc.text = ""
	_copias.text = ""
	_limpar_estrelas()
	_orbe_atr.texture = null
	_orbe_atr.visible = false
	_orbe_tipo.texture = null
	_orbe_tipo.visible = false
	_cor_atr.color = Color(0.2, 0.2, 0.25)
	_moldura.texture = tex_cache.call("assets/frames/normal.jpg") as Texture2D
	_orbe_molde.texture = null
	var verso := tex_cache.call("assets/backs/verso_padrao.png") as Texture2D
	_arte.texture = verso
	_arte.visible = verso != null
	_cor_arte.visible = verso == null
	_cor_arte.color = Color(0.12, 0.12, 0.18)


func _limpar_estrelas() -> void:
	for f in _caixa_estrelas.get_children():
		_caixa_estrelas.remove_child(f as Node)
		# `free()` imediato, nao `queue_free`: a fila so drena no fim do frame, e
		# o GUT conta orfao antes disso.
		(f as Node).free()


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
