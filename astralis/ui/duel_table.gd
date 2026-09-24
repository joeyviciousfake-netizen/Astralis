extends Control

## DuelTable — mesa JOGÁVEL fiel ao original (lógica de verdade, sem Fake R2).
## A tela só CHAMA os sistemas reais (Duel/Turn/Summon/Battle/Damage/Position)
## e mostra o resultado. Turno do jogador tem 2 fases:
## FASE DA MÃO (trava total, só joypad D19):
##  1. Confirmar monstro -> vai ao CENTRO e para.
##  2. Esq/dir alterna face p/ cima / p/ baixo. Confirmar trava a face.
##  3. Trava nova: só os 5 slots de monstro do próprio lado navegáveis.
##  4. Confirmar no slot -> menu no centro com as 2 guardian stars
##     (dado fm guardian_star_1/2, gravada na instância).
##  5. Carta vai ao slot COM a face escolhida, SEMPRE em Ataque (vertical).
##     Fim da fase da mão (MAIN -> BATTLE automático).
## FASE DE CAMPO (livre: próprio campo + campo do rival + LP rival p/ direto):
##  - Com cursor na própria carta: L1/RB alterna Ataque/Defesa, só se
##    !has_attacked (trava pós-ataque FM, via PositionSystem real).
##  - START (pausar, botão 6) passa o turno ao oponente. Sem fileira
##    "Passar" no cursor (não existe no original). START na fase da mão
##    não faz nada (tem que descer 1 carta antes).
## Não-monstro: fluxo mínimo mantido (avisa "Só monstro", sem centro).
## Controle 100% gamepad (D19): SÓ as 11 ações custom de controle;
## sem mouse e sem teclado. Desenho 1920x1080 e espelho intactos.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const TurnManager := preload("res://duel/turn_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const CardViewScript := preload("res://ui/card_view.gd")
const BoardScript := preload("res://ui/duel_board.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")

const ESCALA_CAMPO := 0.85
## Mão p1 (rival) em miniatura de costas: cabe no topo (y=20) sem
## cobrir os slots do rival. p0 fica tamanho cheio embaixo (y=980).
const ESCALA_MAO_P1 := 0.55
## Voo curto da animação: nasce perto do destino, não do deck oposto.
const VOO_OFFSET_P0 := Vector2(0, 36)
const VOO_OFFSET_P1 := Vector2(0, -28)
## Carta no centro da tela 1920x1080 (centro 960,540 menos metade da carta).
const CENTRO_CARTA := Vector2(895, 447)

var _duel
var _st
var _cartas: Dictionary = {}
var _sel_mao := -1
var _sel_atk := -1
var _popup_slot := -1
var _log: Array = []
var _arena_layout: Dictionary = {}
var _arena_data: Dictionary = {}

## Cursor de CONTROLE (D19, sem regra nova).
## Fileiras de cima p/ baixo: LP rival -> campo rival -> meu campo -> mão.
## Sem fileira "Passar" (não existe no original; START passa o turno).
## Esq/dir anda na fileira, cima/baixo troca (só na fase de campo).
const FILEIRA_RIVAL_LP := 0
const FILEIRA_RIVAL_CAMPO := 1
const FILEIRA_MEU_CAMPO := 2
const FILEIRA_MAO := 3
const PAD_REPETE := 0.25
var _pad_fileira := FILEIRA_MAO
var _pad_col := 0
var _pad_popup_idx := 0
var _pad_dir_atual := Vector2i.ZERO
var _pad_tempo := 0.0
var _cursor: Panel
var _popup_botoes: Array = []
var _popup_titulo: Label
var _lbl_novamente: Label

## Fluxo fiel do turno (só controle de tela, regra nos sistemas reais).
const FASE_MAO := 0
const FASE_CAMPO := 1
const SUB_MAO_ESCOLHA := 0
const SUB_FACE := 1
const SUB_SLOT := 2
const SUB_ESTRELA := 3
var _fase_jogador := FASE_MAO
var _sub_mao := SUB_MAO_ESCOLHA
var _mao_idx := -1
var _face_baixo := false
var _slot_alvo := -1
var _estrela_idx := 0
var _estrela_ops: Array = []
var _vista_centro: Control = null

var _camada_mao: Control
var _camada_campo: Control
var _lbl_rival: Label
var _lbl_mao_rival: Label
var _lbl_voce: Label
var _lbl_fase: Label
var _lbl_log: Label
var _popup: PanelContainer
var _overlay: PanelContainer
var _lbl_fim: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sem mouse (D19): a mesa nunca recebe clique.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_mao = $Hand
	_camada_mao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_mao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_campo = Control.new()
	_camada_campo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_campo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_camada_campo)
	move_child(_camada_campo, 1)
	_montar_painel()
	_criar_cursor()
	_arena_data = BoardLayoutScript.load_arena_data(BoardLayoutScript.starter_arena_path())
	_arena_layout = (_arena_data.get("slots", {}) as Dictionary)
	if _arena_layout.is_empty():
		print("[TABLE] Aviso: arena não carregou, usando grade padrão.")
	else:
		var h0: Dictionary = BoardLayoutScript.get_hand(_arena_data, 0)
		var h1: Dictionary = BoardLayoutScript.get_hand(_arena_data, 1)
		print("[TABLE] Arena carregada: %d slots + mão p0(%d,%d,%d) p1(%d,%d,%d)." % [_arena_layout.size(), int(h0["x"]), int(h0["y"]), int(h0["step"]), int(h1["x"]), int(h1["y"]), int(h1["step"])])
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	_fala("Duelo começou! Sua vez.")
	_duel.advance_phase() # DRAW inicial -> MAIN (compra do turno 1 já veio).
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_sel_mao = -1
	_sel_atk = -1
	_pad_fileira = FILEIRA_MAO
	_pad_col = 0
	_fala("Sua FASE DA MÃO: escolha o monstro.")
	_atualizar(true)


func _montar_painel() -> void:
	# LP do rival: só mostra (sem clique). O cursor usa
	# a fileira RIVAL_LP e o confirmar chama _no_rival_lp().
	_lbl_rival = Label.new()
	_lbl_rival.position = Vector2(60, 100)
	_lbl_rival.size = Vector2(430, 70)
	_lbl_rival.add_theme_font_size_override("font_size", 34)
	_lbl_rival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_rival)
	_lbl_mao_rival = _rotulo(Vector2(60, 180), 30, Color(0.7, 0.7, 0.8))
	_lbl_fase = _rotulo(Vector2(60, 300), 32, Color(1, 1, 1))
	_lbl_log = _rotulo(Vector2(60, 370), 23, Color(0.85, 0.85, 0.9))
	_lbl_log.size = Vector2(640, 190)
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_voce = _rotulo(Vector2(60, 600), 40, Color(0.95, 0.85, 0.55))
	# Janela central (menu da estrela guardiã no fluxo fiel).
	# Só mostra (sem clique); o cursor navega nas opções e o confirmar
	# chama _confirmar_estrela().
	_popup = PanelContainer.new()
	_popup.position = Vector2(700, 380)
	_popup.size = Vector2(440, 380)
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.12)
	estilo.border_color = Color(0.85, 0.72, 0.38)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(12)
	_popup.add_theme_stylebox_override("panel", estilo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(caixa)
	var titulo := Label.new()
	titulo.text = "Escolha a estrela guardiã"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(titulo)
	_popup_titulo = titulo
	for texto_op in ["estrela 1", "estrela 2", "Cancelar", ""]:
		var b := Label.new()
		b.text = texto_op
		b.add_theme_font_size_override("font_size", 24)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(380, 64)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(b)
		_popup_botoes.append(b)
	_popup_botoes[3].visible = false
	add_child(_popup)
	# Fim de jogo.
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0, 0, 0, 0.75)
	_overlay.add_theme_stylebox_override("panel", fundo)
	var centro := VBoxContainer.new()
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 24)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(centro)
	_lbl_fim = Label.new()
	_lbl_fim.add_theme_font_size_override("font_size", 96)
	_lbl_fim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_fim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_lbl_fim)
	# "Jogar de novo": só mostra (sem clique). No fim, o confirmar
	# recarrega a cena direto (_pad_confirmar).
	var de_novo := Label.new()
	de_novo.text = "Jogar de novo"
	de_novo.add_theme_font_size_override("font_size", 32)
	de_novo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	de_novo.custom_minimum_size = Vector2(360, 90)
	de_novo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_novamente = de_novo
	var meio := HBoxContainer.new()
	meio.alignment = BoxContainer.ALIGNMENT_CENTER
	meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meio.add_child(de_novo)
	centro.add_child(meio)
	add_child(_overlay)


func _rotulo(pos: Vector2, fonte_tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(640, 60)
	l.add_theme_font_size_override("font_size", fonte_tam)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _fala(texto: String) -> void:
	_log.append(texto)
	while _log.size() > 4:
		_log.pop_front()
	_lbl_log.text = "\n".join(_log)
	print("[TABLE] " + texto)


# ---- cursor de CONTROLE (D19, só input+cursor, sem regra nova) ----

func _criar_cursor() -> void:
	_cursor = Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0)
	estilo.border_color = Color(1.0, 0.9, 0.4)
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(10)
	estilo.draw_center = false
	_cursor.add_theme_stylebox_override("panel", estilo)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = true
	add_child(_cursor)
	_pad_fileira = FILEIRA_MAO
	_pad_col = 0


func _pad_largura_fileira(f: int) -> int:
	match f:
		FILEIRA_RIVAL_LP:
			return 1
		FILEIRA_RIVAL_CAMPO:
			return 5
		FILEIRA_MEU_CAMPO:
			return 5
		FILEIRA_MAO:
			if _st == null:
				return 1
			var n: int = (((_st.players[0] as Dictionary)["hand"]) as Array).size()
			return maxi(n, 1)
	return 1


func _pad_ao_trocar(nova: int) -> void:
	var antiga_larg := _pad_largura_fileira(_pad_fileira)
	var nova_larg := _pad_largura_fileira(nova)
	if nova_larg <= 1:
		_pad_col = 0
	elif antiga_larg <= 1:
		_pad_col = nova_larg / 2
	else:
		var prop := float(_pad_col) / float(maxi(antiga_larg - 1, 1))
		_pad_col = clampi(int(round(prop * float(nova_larg - 1))), 0, nova_larg - 1)
	_pad_fileira = nova


## Movimento fiel com travas: na FASE DA MÃO o cursor nunca sai do
## lugar permitido (mão -> centro/face -> 5 slots próprios). Na FASE DE
## CAMPO anda livre entre LP rival / campo rival / meu campo.
func _pad_mover(dx: int, dy: int) -> void:
	if _st == null or bool(_st.over):
		return
	# Menu da estrela no centro: só cima/baixo troca a opção.
	if _popup.visible:
		if dy != 0 and _popup_botoes.size() > 0:
			var max_idx := 1
			if _estrela_ops.size() >= 2:
				max_idx = 2
			_pad_popup_idx = posmod(_pad_popup_idx + dy, max_idx + 1)
			_atualizar_cursor()
		return
	var meu_turno: bool = int(_st.current_player) == 0
	# FASE DA MÃO (seu MAIN): trava total.
	if _fase_jogador == FASE_MAO and meu_turno and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				# Esq/dir ALTERNAM face p/ cima / p/ baixo (sem mover cursor).
				if dx != 0:
					_face_baixo = not _face_baixo
					_atualizar_centro_face()
					_fala("Face p/ baixo." if _face_baixo else "Face p/ cima.")
					_atualizar_cursor()
				return
			SUB_SLOT:
				# Só os 5 slots de monstro do próprio lado.
				if dx != 0:
					_pad_fileira = FILEIRA_MEU_CAMPO
					_pad_col = posmod(_pad_col + dx, 5)
					_atualizar_cursor()
				return
			_:
				# Escolha da carta: só a mão anda.
				if dx != 0:
					_pad_fileira = FILEIRA_MAO
					var larg := _pad_largura_fileira(FILEIRA_MAO)
					if larg > 1:
						_pad_col = posmod(_pad_col + dx, larg)
						_atualizar_cursor()
				return
	# FASE DE CAMPO (seu turno): livre nos campos + LP rival.
	if _fase_jogador == FASE_CAMPO and meu_turno:
		if dx != 0:
			var larg := _pad_largura_fileira(_pad_fileira)
			if larg > 1:
				_pad_col = posmod(_pad_col + dx, larg)
				_atualizar_cursor()
		if dy != 0:
			var nova := clampi(_pad_fileira + dy, FILEIRA_RIVAL_LP, FILEIRA_MEU_CAMPO)
			if nova != _pad_fileira:
				_pad_ao_trocar(nova)
				_atualizar_cursor()
		return
	# Fora do seu fluxo (vez do rival): cursor anda livre p/ observar.
	if dx != 0:
		var larg2 := _pad_largura_fileira(_pad_fileira)
		if larg2 > 1:
			_pad_col = posmod(_pad_col + dx, larg2)
			_atualizar_cursor()
	if dy != 0:
		var nova2 := clampi(_pad_fileira + dy, FILEIRA_RIVAL_LP, FILEIRA_MAO)
		if nova2 != _pad_fileira:
			_pad_ao_trocar(nova2)
			_atualizar_cursor()


func _pad_confirmar() -> void:
	if _st == null:
		return
	if bool(_st.over):
		get_tree().reload_current_scene()
		return
	if _popup.visible:
		_confirmar_estrela()
		return
	var meu_turno: bool = int(_st.current_player) == 0
	if not meu_turno:
		_fala("Aguarde o rival.")
		return
	# FASE DA MÃO: sequência centro -> face -> slot -> estrela.
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				_fluxo_escolher_carta()
				return
			SUB_FACE:
				_fluxo_travar_face()
				return
			SUB_SLOT:
				_fluxo_escolher_slot()
				return
			SUB_ESTRELA:
				_fala("Escolha a estrela no menu.")
				return
		return
	# FASE DE CAMPO: livre nos campos.
	if _fase_jogador == FASE_CAMPO:
		match _pad_fileira:
			FILEIRA_MEU_CAMPO:
				_confirmar_meu_campo()
				return
			FILEIRA_RIVAL_CAMPO:
				_confirmar_alvo_rival(clampi(_pad_col, 0, 4))
				return
			FILEIRA_RIVAL_LP:
				_no_rival_lp()
				return
			FILEIRA_MAO:
				_fala("Fase de campo: use seu campo ou o do rival.")
				return
		return
	_fala("Aguarde sua fase.")


## 1) Confirmar carta monstro -> ela vai ao CENTRO da tela e para.
## Não-monstro: fluxo mínimo mantido (só avisa, sem centro).
func _fluxo_escolher_carta() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "MAIN":
		_fala("Invocação só na sua MAIN.")
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _pad_col < 0 or _pad_col >= mao.size():
		return
	var carta = mao[_pad_col] as Dictionary
	if str(carta.get("card_type", "")) != "monster":
		_fala("Só monstro pode ser invocado.")
		return
	if SummonSystem.free_monster_slot(_st, 0) < 0:
		_fala("Sem slot vazio no seu campo.")
		return
	_mao_idx = _pad_col
	_sel_mao = _pad_col
	_sel_atk = -1
	_face_baixo = false
	_sub_mao = SUB_FACE
	_mostrar_centro(carta, false)
	_fala("Carta no centro. Esq/dir: face p/ cima / p/ baixo. Confirme.")
	_atualizar()


## 2) Confirmar trava a face (escolhida com esq/dir no centro).
func _fluxo_travar_face() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_atualizar()
		return
	_sub_mao = SUB_SLOT
	_slot_alvo = -1
	_pad_fileira = FILEIRA_MEU_CAMPO
	_pad_col = clampi(SummonSystem.free_monster_slot(_st, 0), 0, 4)
	_fala("Face travada (%s). Escolha 1 dos 5 slots." % ("p/ baixo" if _face_baixo else "p/ cima"))
	_atualizar_cursor()


## 3) Trava nova: 1 dos 5 slots do próprio lado -> abre menu da estrela.
func _fluxo_escolher_slot() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_atualizar()
		return
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var slot := clampi(_pad_col, 0, 4)
	if slot < 0 or slot >= zona.size():
		return
	if zona[slot] != null:
		_fala("Slot de monstro ocupado.")
		return
	_slot_alvo = slot
	_popup_slot = slot
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _mao_idx < 0 or _mao_idx >= mao.size():
		_fala("Carta saiu da mão.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_sel_mao = -1
		_esconder_centro()
		_atualizar()
		return
	var carta = mao[_mao_idx] as Dictionary
	_estrela_ops = _estrelas_da_carta(carta)
	_estrela_idx = 0
	_pad_popup_idx = 0
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	_fala("Escolha 1 das 2 guardian stars.")
	_atualizar_cursor()


## Lê as 2 guardian stars do DADO (fm guardian_star_1/2). Sem inventar:
## se o dado não tem, usa "—" p/ não travar o fluxo.
func _estrelas_da_carta(carta: Dictionary) -> Array:
	var real: Dictionary = {}
	var cid := str(carta.get("id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		real = _cartas[cid] as Dictionary
	var s1 := str(carta.get("guardian_star_1", real.get("guardian_star_1", "")))
	var s2 := str(carta.get("guardian_star_2", real.get("guardian_star_2", "")))
	if s1.strip_edges().is_empty():
		s1 = "—"
	if s2.strip_edges().is_empty():
		s2 = "—"
	return [s1, s2]


func _mostrar_popup_estrela() -> void:
	if _popup_titulo != null and is_instance_valid(_popup_titulo):
		_popup_titulo.text = "Escolha a estrela guardiã"
	for i in range(_popup_botoes.size()):
		var b = _popup_botoes[i] as Label
		if i == 0:
			b.text = str(_estrela_ops[0]) if _estrela_ops.size() > 0 else "—"
			b.visible = true
		elif i == 1:
			b.text = str(_estrela_ops[1]) if _estrela_ops.size() > 1 else "—"
			b.visible = true
		elif i == 2:
			b.text = "Cancelar"
			b.visible = true
		else:
			b.visible = false
	_popup.visible = true


## 4) Menu no centro: 1 das 2 guardian stars -> 5) desce ao slot em Ataque.
func _confirmar_estrela() -> void:
	if _sub_mao != SUB_ESTRELA or _mao_idx < 0 or _slot_alvo < 0:
		_popup.visible = false
		_pad_popup_idx = 0
		return
	if _pad_popup_idx == 2:
		# Cancelar volta p/ escolha do slot.
		_popup.visible = false
		_pad_popup_idx = 0
		_sub_mao = SUB_SLOT
		_pad_fileira = FILEIRA_MEU_CAMPO
		_pad_col = clampi(_slot_alvo, 0, 4)
		_fala("Escolha 1 dos 5 slots.")
		_atualizar_cursor()
		return
	var estrela := str(_estrela_ops[clampi(_pad_popup_idx, 0, 1)])
	_executar_summon_fiel(estrela)


## 5) Carta vai ao slot COM a face escolhida, SEMPRE em Ataque (vertical).
func _executar_summon_fiel(estrela: String) -> void:
	_popup.visible = false
	_pad_popup_idx = 0
	if _mao_idx < 0 or _slot_alvo < 0:
		return
	var hand_idx := _mao_idx
	var slot_n := _slot_alvo
	var face: bool = _face_baixo
	_popup_slot = -1
	var r: Dictionary = SummonSystem.normal_summon(_st, 0, hand_idx, slot_n, face, "ATK", estrela)
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_sel_mao = -1
		_slot_alvo = -1
		_esconder_centro()
		_pad_fileira = FILEIRA_MAO
		_pad_col = 0
		_atualizar()
		return
	var modo := "virada p/ baixo" if face else "p/ cima"
	_fala("Invocou %s em Ataque (estrela %s)!" % [modo, estrela])
	_esconder_centro()
	_mao_idx = -1
	_sel_mao = -1
	_slot_alvo = -1
	_estrela_ops = []
	_sub_mao = SUB_MAO_ESCOLHA
	# Fim da fase da mão: MAIN -> BATTLE automático, entra a fase de campo.
	_duel.advance_phase()
	_fase_jogador = FASE_CAMPO
	_sel_atk = -1
	_pad_fileira = FILEIRA_MEU_CAMPO
	_pad_col = clampi(slot_n, 0, 4)
	_atualizar()


## Campo (fase de campo, fluxo fiel):
## - BATTLE + sua carta = marca o atacante; BATTLE + slot vazio = avisa.
func _confirmar_meu_campo() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	var slot := clampi(_pad_col, 0, 4)
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	if slot < 0 or slot >= zona.size():
		return
	if zona[slot] == null:
		_fala("Slot vazio, sem atacante.")
		return
	_sel_atk = slot
	_sel_mao = -1
	_fala("Atacante escolhido. Mire no rival ou no LP.")
	_pad_ao_trocar(FILEIRA_RIVAL_CAMPO)
	_atualizar()


## Mira do ataque (fase de campo): confirmar no campo rival ataca, se há atacante.
func _confirmar_alvo_rival(alvo_slot: int) -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	_atacar(_sel_atk, alvo_slot)


func _pad_cancelar() -> void:
	if _st == null:
		return
	if _popup.visible:
		# Volta do menu da estrela p/ escolha do slot.
		_popup.visible = false
		_pad_popup_idx = 0
		if _fase_jogador == FASE_MAO and _sub_mao == SUB_ESTRELA:
			_sub_mao = SUB_SLOT
			_pad_fileira = FILEIRA_MEU_CAMPO
			_pad_col = clampi(_slot_alvo, 0, 4)
			_fala("Escolha 1 dos 5 slots.")
			_atualizar_cursor()
			return
		_popup_slot = -1
		_fala("Invocação cancelada.")
		_atualizar_cursor()
		return
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0:
		match _sub_mao:
			SUB_ESTRELA:
				_sub_mao = SUB_SLOT
				_pad_fileira = FILEIRA_MEU_CAMPO
				_pad_col = clampi(_slot_alvo, 0, 4)
				_fala("Escolha 1 dos 5 slots.")
				_atualizar_cursor()
				return
			SUB_SLOT:
				_sub_mao = SUB_FACE
				_pad_fileira = FILEIRA_MAO
				_pad_col = clampi(_mao_idx, 0, maxi(_pad_largura_fileira(FILEIRA_MAO) - 1, 0))
				_fala("Face de novo: esq/dir.")
				_atualizar_cursor()
				return
			SUB_FACE:
				_sub_mao = SUB_MAO_ESCOLHA
				_mao_idx = -1
				_sel_mao = -1
				_sel_atk = -1
				_esconder_centro()
				_pad_fileira = FILEIRA_MAO
				_fala("Escolha desfeita.")
				_atualizar()
				return
	if _sel_mao >= 0 or _sel_atk >= 0 or _mao_idx >= 0:
		_sel_mao = -1
		_mao_idx = -1
		_sel_atk = -1
		_fala("Escolha desfeita.")
		_atualizar()


func _pad_sair() -> void:
	# Não há tela de desistência na mesa (grep vazio): só reporta, sem criar fluxo.
	print("[TABLE] sair_duelo sem tela de desistência (não existe).")
	_fala("Sair do duelo: sem tela de desistência (não existe).")


func _retangulo_cursor() -> Rect2:
	var vazio := Rect2(Vector2(-100, -100), Vector2(1, 1))
	if _st == null:
		return vazio
	if bool(_st.over):
		if is_instance_valid(_lbl_novamente):
			var r: Rect2 = (_lbl_novamente as Control).get_global_rect()
			r.position -= get_global_rect().position
			return r.grow(6)
		return vazio
	if _popup.visible:
		if _pad_popup_idx >= 0 and _pad_popup_idx < _popup_botoes.size() and is_instance_valid(_popup_botoes[_pad_popup_idx]):
			var b: Rect2 = ((_popup_botoes[_pad_popup_idx]) as Control).get_global_rect()
			b.position -= get_global_rect().position
			return b.grow(6)
		return Rect2(_popup.position, _popup.size)
	# Fase da mão: cursor travado no passo atual (mão / centro / 5 slots).
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0 and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				return Rect2(CENTRO_CARTA, CardViewScript.TAM)
			SUB_SLOT, SUB_ESTRELA:
				return BoardScript.slot_rect(0, "monstro", clampi(_pad_col, 0, 4), _arena_layout)
			_:
				var mao0: Array = (_st.players[0] as Dictionary)["hand"]
				var n0 := mao0.size()
				if n0 <= 0:
					return Rect2(Vector2(1140, 980), Vector2(200, 60))
				var c0 := clampi(_pad_col, 0, n0 - 1)
				return Rect2(_pos_mao(c0, n0, 0), CardViewScript.TAM)
	match _pad_fileira:
		FILEIRA_RIVAL_LP:
			return Rect2(_lbl_rival.position, _lbl_rival.size)
		FILEIRA_RIVAL_CAMPO:
			return BoardScript.slot_rect(1, "monstro", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_MEU_CAMPO:
			return BoardScript.slot_rect(0, "monstro", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_MAO:
			var mao: Array = (_st.players[0] as Dictionary)["hand"]
			var n := mao.size()
			if n <= 0:
				return Rect2(Vector2(1140, 980), Vector2(200, 60))
			var c := clampi(_pad_col, 0, n - 1)
			return Rect2(_pos_mao(c, n, 0), CardViewScript.TAM)
	return vazio


func _atualizar_cursor() -> void:
	if _cursor == null or not is_instance_valid(_cursor):
		return
	# Garante coluna válida se a mão encolheu.
	var larg := _pad_largura_fileira(_pad_fileira)
	if _fase_jogador == FASE_MAO and int((_st.players[0] as Dictionary)["hand"] is Array):
		if _sub_mao == SUB_SLOT:
			_pad_col = clampi(_pad_col, 0, 4)
		elif _sub_mao == SUB_FACE:
			pass
		elif larg > 1:
			_pad_col = clampi(_pad_col, 0, larg - 1)
		else:
			_pad_col = 0
	elif larg > 1:
		_pad_col = clampi(_pad_col, 0, larg - 1)
	else:
		_pad_col = 0
	_pad_popup_idx = clampi(_pad_popup_idx, 0, 2)
	var r := _retangulo_cursor()
	_cursor.position = r.position - Vector2(6, 6)
	_cursor.size = r.size + Vector2(12, 12)
	_cursor.visible = true
	_cursor.move_to_front()
	if _vista_centro != null and is_instance_valid(_vista_centro):
		_vista_centro.move_to_front()
		_cursor.move_to_front()


func _process(delta: float) -> void:
	if _st == null:
		return
	var dx := 0
	var dy := 0
	if Input.is_action_pressed("mover_esq"):
		dx -= 1
	if Input.is_action_pressed("mover_dir"):
		dx += 1
	if Input.is_action_pressed("mover_cima"):
		dy -= 1
	if Input.is_action_pressed("mover_baixo"):
		dy += 1
	var desejado := Vector2i(dx, dy)
	if desejado == Vector2i.ZERO:
		_pad_dir_atual = Vector2i.ZERO
		_pad_tempo = 0.0
		return
	if desejado != _pad_dir_atual:
		_pad_dir_atual = desejado
		_pad_tempo = 0.0
		_pad_mover(desejado.x, desejado.y)
		return
	_pad_tempo += delta
	if _pad_tempo >= PAD_REPETE:
		_pad_tempo = 0.0
		_pad_mover(desejado.x, desejado.y)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("confirmar"):
		_pad_confirmar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("cancelar"):
		_pad_cancelar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("sair_duelo"):
		_pad_sair()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("pausar"):
		_no_start_passar_turno()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("posicao_l1") or evento.is_action_pressed("posicao_r1"):
		_alternar_posicao()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("detalhes"):
		_no_detalhes_reservado()
		get_viewport().set_input_as_handled()
		return


## START (pausar, botão 6): passa o turno ao oponente, sem fileira Passar.
## Na fase da mão não faz nada (tem que descer 1 carta antes).
func _no_start_passar_turno() -> void:
	if _st == null or bool(_st.over):
		return
	if int(_st.current_player) != 0:
		return
	if _fase_jogador == FASE_MAO:
		_fala("Desça 1 carta primeiro (START não passa na fase da mão).")
		print("[TABLE] START na fase da mão: sem ação (tem que descer 1 carta).")
		return
	var fase := String(_st.phase)
	if fase != "MAIN" and fase != "BATTLE":
		return
	_sel_mao = -1
	_mao_idx = -1
	_sel_atk = -1
	_popup.visible = false
	_pad_popup_idx = 0
	_esconder_centro()
	var dono := int(_st.current_player)
	var guarda := 0
	while int(_st.current_player) == dono and not bool(_st.over) and guarda < 8:
		_duel.advance_phase()
		guarda += 1
	if bool(_st.over):
		_atualizar()
		return
	_pad_ao_trocar(FILEIRA_MEU_CAMPO)
	_pad_fileira = FILEIRA_MEU_CAMPO
	_fala("Turno do rival... (START)")
	_atualizar()
	_ia_inimiga()


## L1/R1 (posicao_l1/r1): alterna Ataque/Defesa da própria carta com
## o cursor, só na fase de campo e só se !has_attacked (trava FM).
func _alternar_posicao() -> void:
	if _st == null or bool(_st.over):
		return
	if int(_st.current_player) != 0:
		return
	if _fase_jogador != FASE_CAMPO:
		_fala("Posição só na fase de campo.")
		print("[TABLE] posicao_l1/r1 na fase da mão: sem ação.")
		return
	if _pad_fileira != FILEIRA_MEU_CAMPO:
		_fala("Mire numa carta sua p/ trocar Ataque/Defesa.")
		return
	var slot := clampi(_pad_col, 0, 4)
	var r: Dictionary = PositionSystem.toggle_position(_st, 0, slot)
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		print("[TABLE] posicao travada: " + str(r.get("erro", "")))
		return
	_fala("Agora em %s." % ("Ataque" if str(r.get("position", "ATK")) == "ATK" else "Defesa"))
	_atualizar()


## Detalhes reservado (sem tela de detalhes na mesa).
func _no_detalhes_reservado() -> void:
	print("[TABLE] detalhes reservado (sem ação).")
	_fala("Detalhes: reservado (sem ação).")


# ---- centro da tela (fluxo fiel) ----

func _mostrar_centro(carta: Dictionary, face_baixo: bool) -> void:
	_esconder_centro()
	var vista: CardView = CardViewScript.new()
	add_child(vista)
	vista.setup(carta)
	vista.set_facedown(face_baixo)
	vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vista.position = CENTRO_CARTA
	vista.scale = Vector2.ONE
	vista.modulate.a = 1.0
	_vista_centro = vista
	_vista_centro.move_to_front()
	_cursor.move_to_front()


func _atualizar_centro_face() -> void:
	if _vista_centro != null and is_instance_valid(_vista_centro):
		(_vista_centro as CardView).set_facedown(_face_baixo)


func _esconder_centro() -> void:
	if _vista_centro != null and is_instance_valid(_vista_centro):
		(_vista_centro as Node).queue_free()
	_vista_centro = null


# ---- desenho a partir do estado real ----

func _atualizar(com_efeito := false) -> void:
	# Limpa o desenho antigo antes de recriar: o tween é preso à carta
	# (vista.create_tween), então morre junto no free.
	for f in _camada_mao.get_children():
		(f as Node).queue_free()
	for f in _camada_campo.get_children():
		(f as Node).queue_free()
	_sel_mao = -1 if _sel_mao >= ((_st.players[0] as Dictionary)["hand"] as Array).size() else _sel_mao
	if _fase_jogador == FASE_MAO and _sub_mao != SUB_MAO_ESCOLHA and _mao_idx >= 0:
		_sel_mao = _mao_idx
	_desenhar_mao(com_efeito)
	_desenhar_campo()
	_lbl_rival.text = "RIVAL — LP %d" % int((_st.players[1] as Dictionary)["lp"])
	_lbl_voce.text = "VOCÊ — LP %d" % int((_st.players[0] as Dictionary)["lp"])
	_lbl_mao_rival.text = "Mão do rival: %d cartas" % (((_st.players[1] as Dictionary)["hand"] as Array).size())
	var vez := "Sua vez" if int(_st.current_player) == 0 else "Vez do rival"
	var nome_fase := "MÃO" if _fase_jogador == FASE_MAO and int(_st.current_player) == 0 else String(_st.phase)
	_lbl_fase.text = "Turno %d — %s — %s" % [int(_st.turn_number), nome_fase, vez]
	if bool(_st.over):
		_lbl_fim.text = "VITÓRIA!" if int(_st.winner) == 0 else "DERROTA"
		_lbl_fim.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if int(_st.winner) == 0 else Color(1.0, 0.4, 0.4))
		_overlay.visible = true
		_fala("Fim de jogo: " + _lbl_fim.text)
	_atualizar_cursor()


## Posição da mão vinda da ARENA (só desenho, nunca regra).
## lado 0 = p0/embaixo (aberta), 1 = p1/topo (de costas).
## x = centro editável esq/dir no JSON, step = espaço entre cartas, y = topo.
## Retorna o canto superior VISUAL (já centrado em x).
func _pos_mao(i: int, n: int, lado: int = 0) -> Vector2:
	var h: Dictionary = BoardLayoutScript.get_hand(_arena_data, lado)
	var cx := float(h.get("x", 1240.0))
	var y0 := float(h.get("y", 980.0 if lado == 0 else 20.0))
	var passo := float(h.get("step", 95.0 if lado == 0 else 60.0))
	var larg_carta := CardViewScript.TAM.x
	if lado == 1:
		larg_carta *= ESCALA_MAO_P1
	var total := larg_carta + float(maxi(n - 1, 0)) * passo
	var x := cx - total / 2.0 + float(i) * passo
	var meio := float(n - 1) / 2.0
	return Vector2(x, y0 + absf(float(i) - meio) * 10.0)


## Leque das cartas (giro final). Pequeno p/ não estourar o alvo.
func _giro_mao(i: int, n: int) -> float:
	if n <= 1:
		return 0.0
	return (float(i) - float(n - 1) / 2.0) * -0.05


func _desenhar_mao(com_efeito: bool) -> void:
	# p0: aberta na MAIN (carta real, só o cursor escolhe, sem clique).
	# p1: só contagem, de costas, sem id/nome (nunca vazar dado do rival).
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	var n := mao.size()
	for i in range(n):
		var vista: CardView = CardViewScript.new()
		_camada_mao.add_child(vista)
		vista.setup(mao[i] as Dictionary)
		vista.set_selected(i == _sel_mao)
		var alvo := _pos_mao(i, n, 0)
		var giro := _giro_mao(i, n)
		# Alinhamento: pivô e rotação no centro (setup já põe TAM/2).
		vista.pivot_offset = CardViewScript.TAM / 2.0
		vista.rotation = giro # inicial = final, sem snap de 0.
		if com_efeito:
			vista.position = alvo + VOO_OFFSET_P0
			vista.scale = Vector2(0.9, 0.9)
			vista.modulate.a = 0.0
			var tw := vista.create_tween().set_parallel(true)
			tw.tween_property(vista, "position", alvo, 0.25).set_delay(0.05 + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(vista, "scale", Vector2.ONE, 0.22).set_delay(0.05 + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(vista, "modulate:a", 1.0, 0.18).set_delay(0.05 + i * 0.05)
		else:
			vista.position = alvo
			vista.scale = Vector2.ONE
			vista.modulate.a = 1.0
	# p1: mini de costas no topo. Só a QUANTIDADE, nunca a carta real.
	var n1: int = (((_st.players[1] as Dictionary)["hand"]) as Array).size()
	var compensa := CardViewScript.TAM / 2.0 * (1.0 - ESCALA_MAO_P1)
	var escala_mini := Vector2(ESCALA_MAO_P1, ESCALA_MAO_P1)
	for j in range(n1):
		var costas: CardView = CardViewScript.new()
		_camada_mao.add_child(costas)
		costas.setup({})
		costas.set_facedown(true)
		costas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var alvo1 := _pos_mao(j, n1, 1)
		var giro1 := _giro_mao(j, n1)
		costas.pivot_offset = CardViewScript.TAM / 2.0
		costas.rotation = giro1
		var final1 := alvo1 - compensa
		if com_efeito:
			costas.position = final1 + VOO_OFFSET_P1
			costas.scale = escala_mini * 0.9
			costas.modulate.a = 0.0
			var tw1 := costas.create_tween().set_parallel(true)
			tw1.tween_property(costas, "position", final1, 0.25).set_delay(0.05 + j * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw1.tween_property(costas, "scale", escala_mini, 0.22).set_delay(0.05 + j * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw1.tween_property(costas, "modulate:a", 1.0, 0.18).set_delay(0.05 + j * 0.05)
		else:
			costas.position = final1
			costas.scale = escala_mini
			costas.modulate.a = 1.0


func _desenhar_campo() -> void:
	for lado in [0, 1]:
		var zona: Array = (_st.players[lado] as Dictionary)["monster"]
		for i in range(zona.size()):
			var inst = zona[i]
			var r: Rect2 = BoardScript.slot_rect(lado, "monstro", i, _arena_layout)
			if inst == null:
				continue
			var m := inst as Dictionary
			var vista: CardView = CardViewScript.new()
			_camada_campo.add_child(vista)
			vista.setup(_fantasia_de_inst(m))
			var esconder: bool = lado == 1 and bool(m.get("face_down", false))
			vista.set_facedown(esconder)
			vista.scale = Vector2(ESCALA_CAMPO, ESCALA_CAMPO)
			vista.position = r.get_center() - CardViewScript.TAM / 2.0 * ESCALA_CAMPO
			if str(m.get("position", "ATK")) == "DEF":
				vista.rotation = PI / 2.0
			vista.set_selected(lado == 0 and i == _sel_atk)


## O motor guarda a instância enxuta; a tela veste com os dados reais da carta.
func _fantasia_de_inst(m: Dictionary) -> Dictionary:
	var real: Dictionary = _cartas.get(str(m.get("card_id", "")), {}) as Dictionary
	if real.is_empty():
		return {"name": str(m.get("nome", "?")), "monster_type": "beast", "attribute": "earth", "attack": int(m.get("atk", 0)), "defense": int(m.get("def", 0)), "card_type": "monster"}
	return real


# ---- jogadas do jogador (fluxo fiel, só controle) ----

func _no_rival_lp() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	if BattleSystem.has_monsters(_st, 1):
		_fala("Ataque direto só sem monstros rivais.")
		return
	_atacar(_sel_atk, -1)


func _atacar(atacante_slot: int, alvo_slot: int) -> void:
	var r: Dictionary = BattleSystem.attack(_st, 0, atacante_slot, 1, alvo_slot)
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		_sel_atk = -1
		_atualizar()
		return
	if bool(r.get("direto", false)):
		_fala("Direto! %d de dano no rival." % int(r.get("dano", 0)))
	elif bool(r.get("destruiu_alvo", false)) and bool(r.get("destruiu_atacante", false)):
		_fala("Empate: os dois caíram.")
	elif bool(r.get("destruiu_alvo", false)):
		_fala("Destruiu! %d de dano no rival." % int(r.get("dano", 0)))
	elif bool(r.get("destruiu_atacante", false)):
		_fala("Seu monstro caiu! %d de dano em você." % int(r.get("dano", 0)))
	else:
		_fala("Nada acontece.")
	_sel_atk = -1
	_atualizar()


# ---- IA simples do rival (usa os mesmos sistemas reais) ----

func _primeiro_monstro(jogador: int) -> int:
	var mao: Array = (_st.players[jogador] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			return i
	return -1


func _ia_inimiga() -> void:
	await get_tree().create_timer(0.7).timeout
	if bool(_st.over):
		_atualizar()
		return
	_duel.advance_phase() # DRAW -> MAIN
	var idx := _primeiro_monstro(1)
	var slot := SummonSystem.free_monster_slot(_st, 1)
	if idx >= 0 and slot >= 0:
		var r: Dictionary = SummonSystem.normal_summon(_st, 1, idx, slot, false, "ATK")
		if bool(r.get("ok", false)):
			_fala("Rival invocou em Ataque.")
	_atualizar()
	await get_tree().create_timer(0.7).timeout
	if bool(_st.over):
		_atualizar()
		return
	_duel.advance_phase() # MAIN -> BATTLE
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	for s in range(zona.size()):
		if bool(_st.over):
			break
		if zona[s] == null:
			continue
		var alvo := BattleSystem.first_monster_slot(_st, 0)
		var ra: Dictionary = BattleSystem.attack(_st, 1, s, 0, alvo)
		if bool(ra.get("ok", false)):
			if bool(ra.get("direto", false)):
				_fala("Rival direto: %d em você!" % int(ra.get("dano", 0)))
			elif bool(ra.get("destruiu_alvo", false)):
				_fala("Rival destruiu seu monstro (%d de dano)." % int(ra.get("dano", 0)))
			elif bool(ra.get("destruiu_atacante", false)):
				_fala("Rival quebrou a cara no seu monstro!")
			else:
				_fala("Rival atacou: empate, os dois caíram.")
		_atualizar()
		await get_tree().create_timer(0.7).timeout
	if bool(_st.over):
		_atualizar()
		return
	_duel.advance_phase() # BATTLE -> END
	_duel.advance_phase() # END -> sua DRAW (compra)
	_duel.advance_phase() # DRAW -> sua MAIN
	_fala("Seu turno. Comprou 1 carta.")
	_sel_mao = -1
	_mao_idx = -1
	_sel_atk = -1
	_slot_alvo = -1
	_estrela_ops = []
	_sub_mao = SUB_MAO_ESCOLHA
	_fase_jogador = FASE_MAO
	_face_baixo = false
	_esconder_centro()
	_popup.visible = false
	_pad_popup_idx = 0
	_pad_fileira = FILEIRA_MAO
	_pad_col = 0
	_fala("Sua FASE DA MÃO: escolha o monstro.")
	_atualizar()
