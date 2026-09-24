class_name CardView
extends Control

## CardView — carta na tela (só mostra DADO, sem regra R1/R3).
## Desenho procedural: nome, arte colorida pelo atributo + letra do tipo,
## ATK/DEF. Sem clique (D26 parcial, 100% controle): só mostra, o cursor
## da mesa navega no controle. Vira p/ baixo e marca seleção.

const TAM := Vector2(130, 186)

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


func _ready() -> void:
	# Sem mouse (D26 parcial): a carta nunca recebe clique.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_facedown(v: bool) -> void:
	_face_down = v
	for f in get_children():
		(f as Control).visible = not v
	queue_redraw()


func set_selected(v: bool) -> void:
	_selecionada = v
	queue_redraw()


func setup(carta: Dictionary) -> void:
	_carta = carta
	custom_minimum_size = TAM
	size = TAM
	pivot_offset = TAM / 2.0
	var nome := Label.new()
	nome.text = str(carta.get("name", "?"))
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.add_theme_font_size_override("font_size", 15)
	nome.position = Vector2(8, 6)
	nome.size = Vector2(114, 40)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nome)
	var arte := ColorRect.new()
	arte.color = cor_atributo(str(carta.get("attribute", ""))).darkened(0.45)
	arte.position = Vector2(15, 50)
	arte.size = Vector2(100, 80)
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arte)
	var letra := Label.new()
	letra.text = str(carta.get("monster_type", "?")).left(1).to_upper()
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letra.add_theme_font_size_override("font_size", 56)
	letra.add_theme_color_override("font_color", cor_atributo(str(carta.get("attribute", ""))))
	letra.position = Vector2(15, 50)
	letra.size = Vector2(100, 80)
	letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(letra)
	var stats := Label.new()
	stats.text = "ATK %d\nDEF %d" % [int(carta.get("attack", 0)), int(carta.get("defense", 0))]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 15)
	stats.position = Vector2(8, 134)
	stats.size = Vector2(114, 44)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	queue_redraw()


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
	draw_style_box(fundo, r)
	if _selecionada:
		draw_rect(r.grow(5), Color(1.0, 0.9, 0.4), false, 5.0)
