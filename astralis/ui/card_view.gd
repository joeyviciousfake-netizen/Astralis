class_name CardView
extends Control

## CardView — carta na tela (só mostra DADO, sem regra R1/R3).
## Desenho pelo MOLDE (D23/R3, CardLayout): as 9 peças (name, attribute_orb,
## level_stars, art_window, type_line, text_box, atkdef_bar, footer, frame)
## saem do layouts/ do projeto via --project; sem molde ou molde inválido =
## default embutido (idêntico ao JSON oficial). rect por-mil -> px, style dá
## fonte/negrito/cor/alinhamento/z, visible_when esconde ATK fora de monstro.
## Sem peça nova, sem gameplay. Sem clique (D26 parcial, 100% controle): só
## mostra, o cursor da mesa navega no controle. Vira p/ baixo e marca seleção.

const TAM := Vector2(130, 186)

const LayoutScript := preload("res://core/card_layout.gd")

static func cor_atributo(attr: String) -> Color:
	match attr:
		"light":
			return Color(0.85, 0.78, 0.45)
		"dark":
			return Color(0.45, 0.30, 0.70)
		"fire":
			return Color(0.85, 0.35, 0.15)
		"water":
			return Color(0.20, 0.50, 0.90)
		"earth":
			return Color(0.55, 0.42, 0.25)
		"wind":
			return Color(0.45, 0.85, 0.70)
		"thunder":
			return Color(0.95, 0.85, 0.25)
		_:
			return Color(0.50, 0.50, 0.60)


var _carta: Dictionary = {}
var _face_down := false
var _selecionada := false
## Peças desenhadas, por kind (8: frame vai no _draw). Só p/ teste observar.
var _pecas: Dictionary = {}
## Onde a moldura desenha (rect do frame por-mil -> px; default = carta cheia).
var _moldura_rect := Rect2(Vector2.ZERO, TAM)
## Id do molde que desenhou esta carta (só p/ teste observar).
var _layout_id := ""


func _ready() -> void:
	# Sem mouse (D26 parcial): a carta nunca recebe clique.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_facedown(v: bool) -> void:
	_face_down = v
	_aplicar_visibilidade()
	queue_redraw()


func set_selected(v: bool) -> void:
	_selecionada = v
	queue_redraw()


## Monta a carta pelo molde (só DADO, sem regra). molde vazio = ativo do
## projeto (layouts/ via --project, ou default embutido); molde informado
## (só teste) é validado e, se inválido, cai no default (nunca quebra).
func setup(carta: Dictionary, molde: Dictionary = {}) -> void:
	_carta = carta
	_pecas.clear()
	for f in get_children():
		remove_child(f)
		f.free()
	custom_minimum_size = TAM
	size = TAM
	pivot_offset = TAM / 2.0
	var layout: Dictionary = LayoutScript.load_active()
	if not molde.is_empty():
		var fundido := LayoutScript.validar(molde)
		layout = fundido if not fundido.is_empty() else LayoutScript.default_layout()
	_layout_id = str(layout.get("id", ""))
	var pecas: Dictionary = LayoutScript.pecas_por_kind(layout)
	var moldura: Dictionary = pecas.get("frame", {})
	_moldura_rect = LayoutScript.rect_px(moldura.get("rect", {}) as Dictionary, TAM)
	_fazer_texto("name", pecas, carta, str(carta.get("name", "?")), true)
	_fazer_orbe(pecas, carta)
	var nivel := clampi(int(carta.get("level", 0)), 0, 10)
	_fazer_texto("level_stars", pecas, carta, "★".repeat(nivel), false)
	_fazer_arte(pecas, carta)
	_fazer_texto("type_line", pecas, carta, _texto_tipo(carta), false)
	_fazer_texto("text_box", pecas, carta, str(carta.get("description", "")), true)
	_fazer_texto("atkdef_bar", pecas, carta, "ATK %d  DEF %d" % [int(carta.get("attack", 0)), int(carta.get("defense", 0))], false)
	_fazer_texto("footer", pecas, carta, (str(carta.get("id", "")) + " © ASTRALIS").strip_edges(), false)
	_aplicar_visibilidade()
	queue_redraw()


## Texto de uma peça: rect/style do molde, conteúdo do dado da carta.
func _fazer_texto(kind: String, pecas: Dictionary, carta: Dictionary, texto: String, quebra: bool) -> void:
	var peca: Dictionary = pecas.get(kind, {})
	var r: Rect2 = LayoutScript.rect_px(peca.get("rect", {}) as Dictionary, TAM)
	var style: Dictionary = peca.get("style", {}) as Dictionary
	var rot := Label.new()
	rot.text = texto
	rot.position = r.position
	rot.size = r.size
	rot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rot.horizontal_alignment = _alinh(style.get("align", "left"))
	if quebra:
		rot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rot.clip_text = true
	rot.label_settings = _etiqueta(style)
	rot.set_meta("mostrar", LayoutScript.visivel(peca, carta))
	add_child(rot)
	rot.z_index = int(style.get("z", 5))
	_pecas[kind] = rot


## Orbe do atributo (cor vem do dado attribute, posição do molde).
func _fazer_orbe(pecas: Dictionary, carta: Dictionary) -> void:
	var peca: Dictionary = pecas.get("attribute_orb", {})
	var r: Rect2 = LayoutScript.rect_px(peca.get("rect", {}) as Dictionary, TAM)
	var orbe := ColorRect.new()
	orbe.color = cor_atributo(str(carta.get("attribute", "")))
	orbe.position = r.position
	orbe.size = r.size
	orbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbe.set_meta("mostrar", LayoutScript.visivel(peca, carta))
	add_child(orbe)
	orbe.z_index = int((peca.get("style", {}) as Dictionary).get("z", 6))
	_pecas["attribute_orb"] = orbe


## Janela da arte (fundo escurecido + letra do tipo, como era) no rect do molde.
func _fazer_arte(pecas: Dictionary, carta: Dictionary) -> void:
	var peca: Dictionary = pecas.get("art_window", {})
	var r: Rect2 = LayoutScript.rect_px(peca.get("rect", {}) as Dictionary, TAM)
	var arte := ColorRect.new()
	arte.color = cor_atributo(str(carta.get("attribute", ""))).darkened(0.45)
	arte.position = r.position
	arte.size = r.size
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arte.set_meta("mostrar", LayoutScript.visivel(peca, carta))
	add_child(arte)
	arte.z_index = int((peca.get("style", {}) as Dictionary).get("z", 4))
	_pecas["art_window"] = arte
	var letra := Label.new()
	letra.text = str(carta.get("monster_type", "?")).left(1).to_upper()
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letra.add_theme_font_size_override("font_size", 56)
	letra.add_theme_color_override("font_color", cor_atributo(str(carta.get("attribute", ""))))
	letra.position = Vector2.ZERO
	letra.size = r.size
	letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arte.add_child(letra)


## Linha do tipo: monster_type no monstro, card_type fora dele (só dado).
func _texto_tipo(carta: Dictionary) -> String:
	if LayoutScript.eh_monstro(carta):
		return str(carta.get("monster_type", ""))
	return str(carta.get("card_type", ""))


func _alinh(v: Variant) -> HorizontalAlignment:
	match str(v):
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		"right":
			return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT


## Fonte do style (font_size por-mil da altura; bold via embolden, sem fonte nova).
func _etiqueta(style: Dictionary) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = maxi(1, int(round(LayoutScript.fonte_px(style.get("font_size", null), TAM.y, 14.0))))
	ls.font_color = Color.html(str(style.get("color", "#ffffff")))
	if bool(style.get("bold", false)):
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.6
		ls.font = fv
	return ls


## Visibilidade real: visible_when do molde (meta "mostrar") + virada.
## Carta virada esconde tudo; ATK de não-monstro segue escondido ao desvirar.
func _aplicar_visibilidade() -> void:
	for f in get_children():
		var mostrar := true
		if f.has_meta("mostrar"):
			mostrar = bool(f.get_meta("mostrar"))
		(f as Control).visible = mostrar and not _face_down


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, TAM)
	if _face_down:
		# Verso legível até em miniatura (mão p1 usa escala 0.55):
		# fundo escuro + borda clara grossa + moldura interna + cruz central.
		var costas := StyleBoxFlat.new()
		costas.bg_color = Color(0.14, 0.10, 0.24)
		costas.border_color = Color(0.72, 0.62, 1.0)
		costas.set_border_width_all(4)
		costas.set_corner_radius_all(10)
		draw_style_box(costas, r)
		draw_rect(r.grow(-11), Color(0.72, 0.62, 1.0, 0.55), false, 2.0)
		var meio := TAM / 2.0
		var cruz := Color(0.88, 0.82, 1.0)
		draw_circle(meio, 26.0, Color(0.22, 0.16, 0.38))
		draw_arc(meio, 26.0, 0, TAU, 32, cruz, 3.0)
		draw_line(meio + Vector2(0, -18), meio + Vector2(0, 18), cruz, 6.0)
		draw_line(meio + Vector2(-14, 5), meio + Vector2(14, 5), cruz, 6.0)
		return
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.07, 0.07, 0.13)
	fundo.border_color = Color(0.85, 0.72, 0.38)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(10)
	# Moldura = peça frame do molde (default = carta cheia, igual a antes).
	draw_style_box(fundo, _moldura_rect)
	if _selecionada:
		draw_rect(r.grow(5), Color(1.0, 0.9, 0.4), false, 5.0)
