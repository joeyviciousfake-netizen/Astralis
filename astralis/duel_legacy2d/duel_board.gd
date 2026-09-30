class_name DuelBoard
extends Control

## DuelBoard — campo de duelo (visual permanente, base da 1ª tela D17).
## Resolução fixa 1920x1080 (D21). Desenha: fundo, moldura dourada,
## 5 slots monstro + 5 slots magia por lado, decks laterais, divisória
## e emblema central. Sem regra aqui (R1): só mostra.
## Posições prontas p/ colocar as cartas depois via slot_rect().
## ESPELHO do rival (só DESENHO, IDs/lógica intactos): o lado 1 vem espelhado
## no X e com as fileiras trocadas — mas quem decide isso é o DADO da arena
## oficial, não este arquivo (D50).

## D50: A MESA É O DADO, E HÁ SÓ UM DELES. Este arquivo NÃO tem mais
## GRID_X/GAP/Y_* nem nenhuma grade: a posicao de cada slot vem SO do
## `layout` que o jogo carregou da arena oficial
## (`schemas/examples/arenas/arena_starter.json`). `Peca` e o LADO do ladrilho
## em pixels 2D, que é desenho de tela e não dado da mesa.

## Lado do ladrilho desenhado (2D, herda da medida real do card scan).
const PECA := 165.0
const COL_DECK_X := 1728.0
const DECK_W := 105.0
const DECK_H := 165.0
## Divisória no meio da tela (linha, não dado da mesa).
const Y_DIVISORIA := 540.0

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
## D50: a posição vem SÓ do `layout` (a arena oficial do jogo). Não existe
## mais nenhuma grade neste arquivo — era a segunda cópia da mesa, e foi
## apagada. Sem o ID no layout, devolve um Rect2 vazio: quem desenha pula.
static func slot_rect(lado: int, tipo: String, indice: int, layout: Dictionary = {}) -> Rect2:
	var sid := BoardLayoutScript.slot_id(lado, tipo, indice)
	if sid == "":
		return Rect2()
	var p := BoardLayoutScript.get_pos(layout, sid)
	if p == BoardLayoutScript.NULO:
		return Rect2()
	return Rect2(p, Vector2(PECA, PECA))


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
	# D50: etiquetas e divisória saem do DADO (a arena oficial), não de
	# números do código. Sem layout, o desenho do 2D legado fica vazio — é o
	# preço de não ter uma segunda mesa escondida aqui.
	var lay: Dictionary = _layout_do_jogo()
	if lay.is_empty():
		return
	var fonte := ThemeDB.fallback_font
	var p_rival_s := BoardLayoutScript.get_pos(lay, "p1_s0")
	var p_voce_m := BoardLayoutScript.get_pos(lay, "p0_m0")
	var x_esq := minf(BoardLayoutScript.get_pos(lay, "p1_m4").x, BoardLayoutScript.get_pos(lay, "p0_m0").x)
	var x_dir := maxf(BoardLayoutScript.get_pos(lay, "p1_m0").x, BoardLayoutScript.get_pos(lay, "p0_m4").x)
	draw_string(fonte, Vector2(x_esq, p_rival_s.y - 21.0), "RIVAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color(0.7, 0.65, 0.9))
	draw_string(fonte, Vector2(x_esq, p_voce_m.y - 21.0), "VOCÊ", HORIZONTAL_ALIGNMENT_LEFT, -1, 33, Color(0.95, 0.85, 0.55))
	# Divisória com emblema no meio (linha no meio do campo, medida no dado).
	var cx := (x_esq + x_dir) / 2.0
	var y_div := (BoardLayoutScript.get_pos(lay, "p1_m0").y + BoardLayoutScript.get_pos(lay, "p0_m0").y) / 2.0
	var cor_linha := Color(0.4, 0.4, 0.5, 0.5)
	draw_line(Vector2(x_esq, y_div), Vector2(cx - 66.0, y_div), cor_linha, 3.0)
	draw_line(Vector2(cx + 66.0, y_div), Vector2(x_dir, y_div), cor_linha, 3.0)
	_emblema(Vector2(cx, y_div))
	# Slots: 5 monstro + 5 magia por lado.
	for i in range(5):
		_slot(slot_rect(1, "monstro", i, lay), COR_RIVAL_MONSTRO, Color(0.13, 0.09, 0.22))
		_slot(slot_rect(1, "magia", i, lay), COR_RIVAL_MAGIA, Color(0.22, 0.09, 0.06))
		_slot(slot_rect(0, "monstro", i, lay), COR_VOCE_MONSTRO, Color(0.17, 0.14, 0.06))
		_slot(slot_rect(0, "magia", i, lay), COR_VOCE_MAGIA, Color(0.05, 0.17, 0.17))
	# Laterais: deck roxo + carta dourada por lado.
	_carta_costas(Rect2(COL_DECK_X, p_rival_s.y, DECK_W, DECK_H), COR_RIVAL_MONSTRO, Color(0.16, 0.12, 0.26), true)
	_carta_costas(Rect2(COL_DECK_X, BoardLayoutScript.get_pos(lay, "p1_m0").y, DECK_W, DECK_H), COR_DOURADO, Color(0.20, 0.16, 0.05), false)
	_carta_costas(Rect2(COL_DECK_X, p_voce_m.y, DECK_W, DECK_H), COR_DOURADO, Color(0.20, 0.16, 0.05), false)
	_carta_costas(Rect2(COL_DECK_X, BoardLayoutScript.get_pos(lay, "p0_s0").y, DECK_W, DECK_H), COR_RIVAL_MONSTRO, Color(0.16, 0.12, 0.26), true)


## D50: o layout que o 2D legado desenha é o da arena oficial (uma só), lido
## uma vez e guardado. Sem o arquivo, fica vazio e o desenho sai limpo.
var _lay_cache: Dictionary = {}
var _lay_pronto := false


func _layout_do_jogo() -> Dictionary:
	if not _lay_pronto:
		_lay_pronto = true
		_lay_cache = BoardLayoutScript.load_arena(BoardLayoutScript.arena_oficial_path())
	return _lay_cache


func _slot(r: Rect2, cor_borda: Color, cor_fundo: Color) -> void:
	if r.size.x <= 0.0:
		return
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
