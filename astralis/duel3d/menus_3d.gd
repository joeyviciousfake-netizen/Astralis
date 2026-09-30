extends CanvasLayer

## menus_3d — OS MENUS QUE ABREM SOBRE A CENA (a carta do centro e o popup
## da estrela / do alvo). Um assunto so.
##
## Sao dois blocos 2D por cima do campo 3D, e nenhum dos dois e clique: o
## controle e 100% joypad (D19) e o que abre o menu e o metodo real da mesa.
##   - CENTRO: a carta que o jogador escolheu (nome + face + slot). Fica
##     ACIMA do HUD e ABAIXO do popup.
##   - POPUP: a escolha de dentro de um passo. "estrela" = as 2 guardian stars
##     do DADO real; "alvo" = atacar o LP do rival no direto (so aparece
##     quando o rival nao tem monstros). O "> " marca a opcao atual.
##
## NADA AQUI CALCULA REGUA (R1/R3): as opcoes e os textos chegam prontos da
## mesa (a lista de estrelas do DADO, o nome da carta do centro). Este no so
## escreve o que a mesa mandou na tela.
##
## O `MenuLayer` e este no, e ele e filho da MESA (nao do HUD) de proposito: o
## CanvasLayer desenha em espaco de tela, acima do painel esquerdo, que e a
## ordem de desenho que a D45 montou.

var _painel_centro: PanelContainer = null
var _lbl_centro: Label = null
var _popup: PanelContainer = null
var _popup_titulo: Label = null
var _popup_ops: Array = []
## "estrela" ou "alvo": qual dos dois o popup esta mostrando.
var modo := "estrela"
## Qual opcao esta sob o cursor (0 = a primeira).
var idx := 0
## As opcoes do popup, vindas da mesa: as 2 guardian stars do DADO no modo
## estrela, e nada no modo alvo (a unica opcao real e o LP).
var ops: Array = []
## O texto da carta do centro. A mesa monta, porque o nome vem do cursor.
var texto_centro := ""


func _ready() -> void:
	name = "MenuLayer"
	_construir_centro()
	_construir_popup()
	atualizar()


func _construir_centro() -> void:
	_painel_centro = PanelContainer.new()
	_painel_centro.name = "CentroCarta"
	_painel_centro.add_theme_stylebox_override("panel", _estilo(Color(0.02, 0.02, 0.06, 0.92), Color(1.0, 0.9, 0.4)))
	_painel_centro.position = Vector2(700, 300)
	_painel_centro.size = Vector2(520, 120)
	_painel_centro.visible = false
	_painel_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_centro = Label.new()
	_lbl_centro.name = "TextoCentro"
	_lbl_centro.add_theme_font_size_override("font_size", 26)
	_lbl_centro.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_lbl_centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_centro.add_child(_lbl_centro)
	add_child(_painel_centro)


func _construir_popup() -> void:
	_popup = PanelContainer.new()
	_popup.name = "MenuEstrela"
	_popup.add_theme_stylebox_override("panel", _estilo(Color(0.03, 0.03, 0.08, 0.95), Color(1.0, 0.9, 0.4)))
	_popup.position = Vector2(700, 440)
	_popup.size = Vector2(520, 220)
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa := VBoxContainer.new()
	caixa.name = "Caixa"
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(caixa)
	_popup_titulo = Label.new()
	_popup_titulo.name = "Titulo"
	_popup_titulo.text = "Escolha a estrela guardiã"
	_popup_titulo.add_theme_font_size_override("font_size", 28)
	_popup_titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	_popup_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(_popup_titulo)
	_popup_ops = []
	for i in range(3):
		var b := Label.new()
		b.name = "Op%d" % i
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(b)
		_popup_ops.append(b)
	add_child(_popup)


func _estilo(fundo: Color, borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## Mostra a carta do centro (a que o jogador escolheu) com a face escolhida.
func mostrar_centro(texto: String) -> void:
	texto_centro = texto
	if _painel_centro == null or _lbl_centro == null:
		return
	_lbl_centro.text = texto
	_painel_centro.visible = true
	atualizar()


func esconder_centro() -> void:
	if _painel_centro != null:
		_painel_centro.visible = false


## Abre o popup da estrela, com as 2 guardian stars do DADO real.
func mostrar_estrela(estrelas: Array) -> void:
	modo = "estrela"
	ops = estrelas
	idx = 0
	if _popup_titulo != null:
		_popup_titulo.text = "Escolha a estrela guardiã"
	atualizar()
	if _popup != null:
		_popup.visible = true


## Abre o popup de alvo: so o ataque direto no LP do rival (que e a unica
## coisa que existe quando ele nao tem monstros).
func mostrar_alvo() -> void:
	modo = "alvo"
	ops = []
	idx = 0
	if _popup_titulo != null:
		_popup_titulo.text = "Alvo: rival sem monstros"
	atualizar()
	if _popup != null:
		_popup.visible = true


func esconder_popup() -> void:
	if _popup != null:
		_popup.visible = false
	modo = "estrela"
	idx = 0
	ops = []
	atualizar()


func popup_aberto() -> bool:
	return _popup != null and _popup.visible


## O "> " marca a opcao atual. So desenho.
func atualizar() -> void:
	if _painel_centro != null and _lbl_centro != null:
		_lbl_centro.text = texto_centro
	if _popup == null or _popup_ops.size() < 3:
		return
	if modo == "alvo":
		(_popup_ops[0] as Label).text = ("▶ " if idx == 0 else "   ") + "Atacar LP rival (direto)"
		(_popup_ops[0] as Label).visible = true
		(_popup_ops[1] as Label).text = ("▶ " if idx == 1 else "   ") + "Cancelar"
		(_popup_ops[1] as Label).visible = true
		(_popup_ops[2] as Label).visible = false
	else:
		var n_ops := clampi(ops.size(), 0, 2)
		for i in range(3):
			var b := _popup_ops[i] as Label
			if i < n_ops:
				b.text = ("▶ " if idx == i else "   ") + str(ops[i])
				b.visible = true
			else:
				b.text = ""
				b.visible = false
