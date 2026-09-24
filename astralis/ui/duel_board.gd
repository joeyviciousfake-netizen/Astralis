class_name DuelBoard
extends Control

## DuelBoard — campo de duelo (visual permanente, base da 1ª tela D17).
## Resolução fixa 1920x1080 (D21). Desenha: fundo, moldura dourada,
## 5 slots monstro + 5 slots magia por lado, decks laterais, divisória
## e emblema central. Sem regra aqui (R1): só mostra.
## Posições prontas p/ colocar as cartas depois via slot_rect().
## ESPELHO do rival (só DESENHO, IDs/lógica intactos): lado 1 com X
## invertido (índice 0 à direita) + monstro perto do centro (317) e
## magia longe (128), espelhando você (600/789).

const SLOT := 165.0
const GAP := 24.0
const GRID_X := 780.0
const COL_DECK_X := 1728.0
const DECK_W := 105.0
const DECK_H := 165.0

## Fileiras em ESPELHO (só desenho, igual ao BoardLayout):
## monstro sempre perto do centro, magia sempre longe.
const Y_RIVAL_MONSTRO := 317.0
const Y_RIVAL_MAGIA := 128.0
const Y_DIVISORIA := 540.0
const Y_VOCE_MONSTRO := 600.0
const Y_VOCE_MAGIA := 789.0

const COR_FUNDO := Color(0.03, 0.03, 0.07)
const COR_DOURADO := Color(0.78, 0.64, 0.32)
const COR_RIVAL_MONSTRO := Color(0.66, 0.56, 0.96)
const COR_RIVAL_MAGIA := Color(0.96, 0.56, 0.30)
const COR_VOCE_MONSTRO := Color(0.96, 0.80, 0.40)
const COR_VOCE_MAGIA := Color(0.36, 0.95, 0.90)

const BoardLayoutScript := preload("res://core/board_layout.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	print("[BOARD] Campo pronto: 20 slots (5+5 por lado) + 4 laterais + emblema.")


## Retorna o retângulo do slot. lado: 0 = você (baixo), 1 = rival (cima).
## tipo: "monstro" ou "magia". indice: 0..4.
## layout opcional (D24, Dict slot_id->Vector2 da arena): se tem o ID,
## usa o XY dele; senão usa a grade padrão em ESPELHO do BoardLayout
## (lado 1 com X invertido + fileiras trocadas). A lógica continua no índice.
static func slot_rect(lado: int, tipo: String, indice: int, layout: Dictionary = {}) -> Rect2:
	var sid := BoardLayoutScript.slot_id(lado, tipo, indice)
	var padrao := BoardLayoutScript.default_pos(sid)
	if sid == "" or padrao.x < 0.0:
		# Tipo/índice inválido: mantém tamanho p/ não quebrar o desenho.
		var x_q := GRID_X + indice * (SLOT + GAP)
		if lado == 1:
			x_q = GRID_X + (4 - indice) * (SLOT + GAP)
		padrao = Vector2(x_q, Y_VOCE_MONSTRO)
	if layout.is_empty():
		return Rect2(padrao, Vector2(SLOT, SLOT))
	var p := BoardLayoutScript.get_pos(layout, sid, padrao)
	return Rect2(p, Vector2(SLOT, SLOT))


static func _fundo_rect(cor_borda: Color, cor_fundo: Color) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = cor_fundo
	e.border_color = cor_borda
	e.set_border_width_all(3)
	e.set_corner_radius_all(15)
	return e


func _draw() -> void:
	var vista := get_rect()
	# Fundo.
	draw_rect(vista, COR_FUNDO)
	# Moldura dourada + pontos nos cantos.
	var moldura := Rect2(21, 21, vista.size.x - 42, vista.size.y - 42)
	draw_style_box(_fundo_rect(COR_DOURADO, Color(0, 0, 0, 0)), moldura)
	for canto in [moldura.position, Vector2(moldura.end.x, moldura.position.y), Vector2(moldura.position.x, moldura.end.y), moldura.end]:
		draw_circle(canto, 8, COR_DOURADO)
	# Etiquetas dos lados (acima da fileira de cima de cada lado:
	# rival = magia longe 128, você = monstro perto 600).
	var fonte := ThemeDB.fallback_font
	draw_string(fonte, Vector2(GRID_X, Y_RIVAL_MAGIA - 21), "RIVAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color(0.7, 0.65, 0.9))
	draw_string(fonte, Vector2(GRID_X, Y_VOCE_MONSTRO - 21), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color(0.95, 0.85, 0.55))
	# Divisória com emblema no meio.
	var cx := GRID_X + (5 * SLOT + 4 * GAP) / 2.0
	var cor_linha := Color(0.4, 0.4, 0.5, 0.5)
	draw_line(Vector2(GRID_X, Y_DIVISORIA), Vector2(cx - 66, Y_DIVISORIA), cor_linha, 3.0)
	draw_line(Vector2(cx + 66, Y_DIVISORIA), Vector2(GRID_X + 5 * SLOT + 4 * GAP, Y_DIVISORIA), cor_linha, 3.0)
	_emblema(Vector2(cx, Y_DIVISORIA))
	# Slots: 5 monstro + 5 magia por lado.
	for i in range(5):
		_slot(slot_rect(1, "monstro", i), COR_RIVAL_MONSTRO, Color(0.13, 0.09, 0.22))
		_slot(slot_rect(1, "magia", i), COR_RIVAL_MAGIA, Color(0.22, 0.09, 0.06))
		_slot(slot_rect(0, "monstro", i), COR_VOCE_MONSTRO, Color(0.17, 0.14, 0.06))
		_slot(slot_rect(0, "magia", i), COR_VOCE_MAGIA, Color(0.05, 0.17, 0.17))
	# Laterais: deck roxo + carta dourada por lado.
	_carta_costas(Rect2(COL_DECK_X, Y_RIVAL_MONSTRO, DECK_W, DECK_H), COR_RIVAL_MONSTRO, Color(0.16, 0.12, 0.26), true)
	_carta_costas(Rect2(COL_DECK_X, Y_RIVAL_MAGIA, DECK_W, DECK_H), COR_DOURADO, Color(0.20, 0.16, 0.05), false)
	_carta_costas(Rect2(COL_DECK_X, Y_VOCE_MONSTRO, DECK_W, DECK_H), COR_DOURADO, Color(0.20, 0.16, 0.05), false)
	_carta_costas(Rect2(COL_DECK_X, Y_VOCE_MAGIA, DECK_W, DECK_H), COR_RIVAL_MONSTRO, Color(0.16, 0.12, 0.26), true)


func _slot(r: Rect2, cor_borda: Color, cor_fundo: Color) -> void:
	draw_style_box(_fundo_rect(cor_borda, cor_fundo), r)
	# Cantos em L mais claros (charme da referência).
	var clara := cor_borda.lightened(0.45)
	var comp := 27.0
	var larg := 4.0
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if c.x < r.position.x + r.size.x / 2.0 else -1.0
		var sy := 1.0 if c.y < r.position.y + r.size.y / 2.0 else -1.0
		draw_line(c, c + Vector2(sx * comp, 0), clara, larg)
		draw_line(c, c + Vector2(0, sy * comp), clara, larg)


func _emblema(c: Vector2) -> void:
	draw_arc(c, 48, 0, TAU, 48, COR_DOURADO, 4.0)
	draw_arc(c, 36, 0, TAU, 48, Color(0.78, 0.64, 0.32, 0.5), 2.0)
	var cima := PackedVector2Array([c + Vector2(0, -39), c + Vector2(33, 20), c + Vector2(-33, 20), c + Vector2(0, -39)])
	var baixo := PackedVector2Array([c + Vector2(0, 39), c + Vector2(33, -20), c + Vector2(-33, -20), c + Vector2(0, 39)])
	draw_polyline(cima, COR_DOURADO, 4.0)
	draw_polyline(baixo, COR_DOURADO, 4.0)


func _carta_costas(r: Rect2, cor_borda: Color, cor_fundo: Color, cruz: bool) -> void:
	draw_style_box(_fundo_rect(cor_borda, cor_fundo), r)
	var dentro := r.grow(-15)
	draw_rect(dentro, Color(0, 0, 0, 0), false, 2.0)
	var meio := r.get_center()
	var icone := cor_borda.lightened(0.4)
	if cruz:
		draw_line(meio + Vector2(0, -18), meio + Vector2(0, 18), icone, 4.0)
		draw_line(meio + Vector2(-14, 4), meio + Vector2(14, 4), icone, 4.0)
	else:
		var losango := PackedVector2Array([meio + Vector2(0, -21), meio + Vector2(14, 0), meio + Vector2(0, 21), meio + Vector2(-14, 0), meio + Vector2(0, -21)])
		draw_polyline(losango, icone, 4.0)
