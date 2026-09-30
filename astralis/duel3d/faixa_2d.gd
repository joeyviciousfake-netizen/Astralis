extends PanelContainer

## faixa_2d — A FAIXA DO MEIO (D45, item 2), um assunto so.
##
## E a barra que fica no VAO entre as fileiras de monstros, dentro do HUD 2D.
## Antes era 3D (caixas deitadas no chao) e virou 2D porque em 3D a posicao de um
## objeto no chao e a soma de tres numeros (z da fileira + meia profundidade do
## ladrilho + profundidade do objeto) e "a altura do chao" na tela e uma FAIXA, nao
## uma linha; em 2D a posicao e o pixel.
##
## As 7 celulas seguem a ordem que o usuario ditou (D45b): MeuCemiterio, MeuDeck,
## LpVoce, Turno, LpVocal, LpRival, DeckRival, CemRival - o TURNO fica no meio
## porque e o unico que nao tem dono. Cada celula mostra SO o dado real do
## GameState (R1/R3): contagem de cartas do baralho e do cemiterio dos dois lados,
## o LP de cada um, o turno, e a FOTO quadrada da ultima carta que foi para cada
## cemiterio. Nada aqui calcula regra.
##
## A posicao NAO e chutada: a barra se encaixa entre as bordas REAIS das duas
## fileiras de monstros, medidas do dado + da camera (`medir_borda` e
## `medir_extensao`, que a mesa passa aqui - sao medicao, nao estado).
##
## D47: a linha das celulas e o que se espelha na volta da mesa (`espelhar`): a
## ordem dos filhos do HBoxContainer E a ordem na tela, entao espelhar e reverter
## a lista. Com 7 celulas (impar) a do meio continua no meio, que e o Turno.

## Altura da barra (o vao entre as fileiras tem 87 px).
const ALT := 64
## Vao entre as celulas.
const GAP := 6
## Folga da faixa ate a borda da fileira.
const MARGEM_L := 10.0
const FONDO := Color(0.043, 0.063, 0.145, 0.86)
const ARO := Color(0.36, 0.52, 0.92, 0.95)
## Todo numero da faixa e BRANCO (D45, item 4 e 7).
const COR_NUM := Color(1, 1, 1, 1)
const FONTE_NUM := 34
const FONTE_CONT := 30
## Cores de identidade: azul = voce, vermelho = rival, preto = os DOIS
## cemiterios. O DONO delas e a mesa (a tela inteira usa os mesmos tres
## conjuntos - a faixa, os retratos e a placa de nome), entao a faixa recebe em
## vez de declarar: dois donos do mesmo numero e exatamente o que o D48/D50
## proibiram na arena.
var cor_azul_borda := Color(0, 0, 0, 0)
var cor_azul_fundo := Color(0, 0, 0, 0)
var cor_verm_borda := Color(0, 0, 0, 0)
var cor_verm_fundo := Color(0, 0, 0, 0)
var cor_preto_borda := Color(0, 0, 0, 0)
var cor_preto_fundo := Color(0, 0, 0, 0)

## O GameState e o dicionario de cartas do duelo (so leitura, R1/R3). A faixa
## NAO GUARDA uma copia: ela PERGUNTA a mesa na hora de atualizar. Guarda foi o
## que a fez mostrar o turno velho quando o duelo mudou em tempo de execucao (o
## duelo pode ser trocado - e o proprio teste do D42 troca).
var estado: Callable
var cartas_de: Callable
## Medicao da tela: a mesa passa as duas funcoes porque elas leem a camera e o
## layout da arena, que moram la (aqui seria estado de outro assunto).
var medir_borda: Callable
var medir_extensao: Callable
## Cache de textura da mesa (a arte do cemiterio nao rele o disco a cada vez).
var tex_cache: Callable
## Fala no log da mesa (so a linha de diagnostico da montagem).
var avisar: Callable

var _linha: HBoxContainer = null
var _turno_cel: PanelContainer = null
var _arte_meu_cem: TextureRect = null
var _arte_cem_rival: TextureRect = null
var _num_meu_deck: Label = null
var _num_meu_cem: Label = null
var _num_lp_voce: Label = null
var _num_turno: Label = null
var _num_lp_rival: Label = null
var _num_cem_rival: Label = null
var _num_deck_rival: Label = null


## Monta a faixa dentro do HUD. `hud` e o Control do HUD (a barra vira filha
## dele, com o nome "Faixa2D" porque o teste do D45 le a ordem das celulas
## direto da tela).
func construir(hud: Control) -> void:
	if hud == null:
		return
	name = "Faixa2D"
	add_theme_stylebox_override("panel", _estilo_barra())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# O vao: entre a base da fileira de monstro do RIVAL e o topo da SUA.
	var y_topo: float = float(medir_borda.call(1, "monstro", true))
	var y_base: float = float(medir_borda.call(0, "monstro", false))
	var alt := clampf(y_base - y_topo - 10.0, 40.0, float(ALT))
	var y := y_topo + ((y_base - y_topo) - alt) * 0.5
	var ex: Vector2 = medir_extensao.call(0, "monstro")
	var x0: float = ex.x + MARGEM_L
	var x1: float = ex.y - MARGEM_L
	var larg := maxf(x1 - x0, 200.0)
	position = Vector2(x0, y)
	size = Vector2(larg, alt)
	custom_minimum_size = Vector2(larg, alt)
	hud.add_child(self)

	_linha = HBoxContainer.new()
	_linha.name = "Celulas"
	_linha.add_theme_constant_override("separation", int(GAP))
	_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.set_anchors_preset(Control.PRESET_FULL_RECT)
	_linha.offset_left = 6.0
	_linha.offset_right = -6.0
	_linha.offset_top = 5.0
	_linha.offset_bottom = -5.0
	add_child(_linha)

	var larg_cel: float = (larg - 12.0 - GAP * 6.0) / 7.0
	var alt_cel := alt - 10.0
	var cel_meu_cem := _celula("MeuCemiterio", larg_cel, alt_cel, cor_preto_borda, cor_preto_fundo, "arte_esq")
	var cel_meu_deck := _celula("MeuDeck", larg_cel, alt_cel, cor_azul_borda, cor_azul_fundo, "numero")
	var cel_lp_voce := _celula("LpVoce", larg_cel, alt_cel, cor_azul_borda, cor_azul_fundo, "numero")
	var cel_turno := _celula("Turno", larg_cel, alt_cel, cor_azul_borda, cor_azul_fundo, "numero")
	var cel_lp_rival := _celula("LpRival", larg_cel, alt_cel, cor_verm_borda, cor_verm_fundo, "numero")
	var cel_deck_rival := _celula("DeckRival", larg_cel, alt_cel, cor_verm_borda, cor_verm_fundo, "numero")
	var cel_cem_rival := _celula("CemRival", larg_cel, alt_cel, cor_preto_borda, cor_preto_fundo, "arte_dir")
	_arte_meu_cem = cel_meu_cem.get_node("Caixa/Arte") as TextureRect
	_num_meu_cem = cel_meu_cem.get_node("Caixa/Numero") as Label
	_num_meu_deck = cel_meu_deck.get_node("Caixa/Numero") as Label
	_num_lp_voce = cel_lp_voce.get_node("Caixa/Numero") as Label
	_turno_cel = cel_turno as PanelContainer
	_num_turno = cel_turno.get_node("Caixa/Numero") as Label
	_num_lp_rival = cel_lp_rival.get_node("Caixa/Numero") as Label
	_num_deck_rival = cel_deck_rival.get_node("Caixa/Numero") as Label
	_arte_cem_rival = cel_cem_rival.get_node("Caixa/Arte") as TextureRect
	_num_cem_rival = cel_cem_rival.get_node("Caixa/Numero") as Label

	atualizar()
	if avisar.is_valid():
		avisar.call("Faixa 2D: 7 celulas em x=%.0f..%.0f y=%.0f..%.0f (vao das fileiras %.0f..%.0f px)." % [
			x0, x0 + larg, y, y + alt, y_topo, y_base])


## Estilo da barra: vidro escuro com aro metalico e um brilho fino de cima - o
## mesmo "metal com bisel" da referencia, em vez de chapa.
func _estilo_barra() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FONDO
	s.border_color = ARO
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 4
	return s


## Uma celula. SO DUAS formas, porque o usuario pediu bloco limpo (D45 item 3:
## sem palavra e sem icone):
##   "numero"  - so o NUMERO, branco, grande e centralizado (deck, LP, turno);
##   "arte_esq" / "arte_dir" - a FOTO quadrada da ultima carta do CEMITERIO
##   preenchendo a ponta ESQUERDA (a sua) ou DIREITA (a do rival), com a
##   contagem de cartas do lado oposto.
func _celula(nome: String, larg: float, alt: float, cor_borda: Color,
		cor_fundo: Color, tipo: String) -> Control:
	var cel := PanelContainer.new()
	cel.name = nome
	cel.add_theme_stylebox_override("panel", _estilo_celula(cor_borda, cor_fundo))
	cel.custom_minimum_size = Vector2(larg, alt)
	cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cel.clip_contents = true
	cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linha.add_child(cel)

	var h := HBoxContainer.new()
	h.name = "Caixa"
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cel.add_child(h)

	var num := _rotulo("Numero", "0", FONTE_CONT if tipo != "numero" else FONTE_NUM)
	num.add_theme_color_override("font_color", COR_NUM)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if tipo == "numero":
		num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(num)
		return cel

	# Cemiterio: a foto QUADRADA da ultima carta que foi para la, na ponta que
	# o usuario pediu (esquerda no seu, direita no do rival), e a contagem do
	# lado oposto. A arte e um CORTE quadrado da imagem real (nunca esticada).
	var arte := TextureRect.new()
	arte.name = "Arte"
	arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arte.size_flags_vertical = Control.SIZE_FILL
	arte.custom_minimum_size = Vector2(alt, alt)
	arte.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if tipo == "arte_esq" else Control.SIZE_SHRINK_END
	arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arte.visible = false
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tipo == "arte_esq":
		h.add_child(arte)
		h.add_child(num)
	else:
		h.add_child(num)
		h.add_child(arte)
	return cel


## Texto claro gravado na placa colorida (D19: sem clique).
func _rotulo(nome: String, texto: String, tam: int) -> Label:
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_celula(cor_borda: Color, cor_fundo: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor_fundo
	s.border_color = cor_borda
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s


## Escreve na faixa o que o estado REAL manda. A COR da celula do turno alterna
## com quem esta jogando (azul = voce, vermelho = rival, o mesmo conjunto de cores
## do LP daquele lado) e vem do `current_player` do motor, nunca de um contador
## solto (R3). Vitoria/derrota aparecem no lugar do numero do turno.
func atualizar() -> void:
	if not is_instance_valid(self) or not estado.is_valid():
		return
	var st = estado.call()
	var cartas: Dictionary = cartas_de.call() as Dictionary
	if st == null:
		return
	if _num_meu_deck != null:
		_num_meu_deck.text = "%d" % _lista(st, 0, "deck").size()
	if _num_meu_cem != null:
		_num_meu_cem.text = "%d" % _lista(st, 0, "graveyard").size()
	if _num_deck_rival != null:
		_num_deck_rival.text = "%d" % _lista(st, 1, "deck").size()
	if _num_cem_rival != null:
		_num_cem_rival.text = "%d" % _lista(st, 1, "graveyard").size()
	# A foto do cemiterio: a arte REAL da ultima carta que foi para la (ou nada,
	# se estiver vazio - nunca uma imagem inventada, R3).
	for par in [[0, _arte_meu_cem], [1, _arte_cem_rival]]:
		var arte := par[1] as TextureRect
		if arte == null:
			continue
		var tex := _arte_real(_carta_do_cemiterio(int(par[0])))
		arte.texture = tex
		arte.visible = tex != null
	if _num_lp_voce != null:
		_num_lp_voce.text = "%d" % _int(st, 0, "lp")
	if _num_lp_rival != null:
		_num_lp_rival.text = "%d" % _int(st, 1, "lp")
	if _num_turno != null:
		if bool(st.over):
			_num_turno.text = "VITORIA!" if int(st.winner) == 0 else "DERROTA"
		else:
			_num_turno.text = "%d" % int(st.turn_number)
	_tingir_turno(st)


## D45 (item 7): a celula do TURNO muda de cor com quem esta jogando.
func _tingir_turno(st) -> void:
	if _turno_cel == null or not is_instance_valid(_turno_cel):
		return
	var meu: bool = int(st.current_player) == 0
	_turno_cel.add_theme_stylebox_override("panel", _estilo_celula(
		cor_azul_borda if meu else cor_verm_borda,
		cor_azul_fundo if meu else cor_verm_fundo))


## D47: espelhar a faixa e REVERTER a lista de celulas (a ordem dos filhos do
## HBox e a ordem na tela). Com 7 celulas (impar) a do meio continua no meio, que
## e o Turno. Nao usa `move_child` dentro do laco (cada movimento empurra os
## outros) nem `add_child` de um no que JA e filho (que remexe ele para o fim em
## vez de copiar): tira todas e devolve na ordem nova, que sao os MESMOS nos.
func espelhar() -> void:
	if _linha == null or not is_instance_valid(_linha):
		return
	var celulas := _linha.get_children()
	if celulas.is_empty():
		return
	var nova := celulas.duplicate()
	nova.reverse()
	for c in celulas:
		_linha.remove_child(c as Node)
	for c2 in nova:
		_linha.add_child(c2 as Node)


## D47: a barra vira de carta como o resto do HUD (encolhe no eixo X com
## `abs(cos(graus))` e some nos 90).
func virar(esc: float) -> void:
	if not is_instance_valid(self):
		return
	pivot_offset = size * 0.5
	scale = Vector2(esc, 1.0)


## Carta REAL do topo do cemiterio de um lado: a ULTIMA do dado (a que foi para
## la por ultimo), com a roupa do dado. Vazio = {} - nunca uma carta inventada.
func _carta_do_cemiterio(lado: int) -> Dictionary:
	var cem := _lista(estado.call(), lado, "graveyard")
	if cem.is_empty():
		return {}
	var cartas: Dictionary = cartas_de.call() as Dictionary
	var cid := str(cem[cem.size() - 1])
	if cid.is_empty() or not cartas.has(cid):
		return {}
	return cartas[cid] as Dictionary


## Arte REAL da carta, pelo CACHE de textura (a faixa nao rele a imagem do disco a
## cada atualizacao) e nulo quando o dado nao tem arte.
func _arte_real(carta: Dictionary) -> Texture2D:
	var rel := str(carta.get("artwork", "")).strip_edges()
	if rel.is_empty():
		return null
	return tex_cache.call(rel) as Texture2D


## Leitura blindada da zona de um jogador: sempre um Array, nunca um erro.
func _lista(st, lado: int, chave: String) -> Array:
	var p = st.get("players")
	if p == null or not (p is Array) or lado < 0 or lado >= (p as Array).size():
		return []
	var jogador = (p as Array)[lado]
	if not (jogador is Dictionary):
		return []
	var v = (jogador as Dictionary).get(_traduz_chave(chave), null)
	return v as Array if v is Array else []


## Leitura blindada de um numero do jogador (lp, max_lp...).
func _int(st, lado: int, chave: String) -> int:
	var p = st.get("players")
	if p == null or not (p is Array) or lado < 0 or lado >= (p as Array).size():
		return 0
	var jogador = (p as Array)[lado]
	if not (jogador is Dictionary):
		return 0
	return int((jogador as Dictionary).get(chave, 0))


## Traduz o nome da zona ("monstro" ou "monster" valem os dois).
func _traduz_chave(chave: String) -> String:
	match chave:
		"monstro", "monsters":
			return "monster"
		"magia", "spell", "spells":
			return "spell"
	return chave
