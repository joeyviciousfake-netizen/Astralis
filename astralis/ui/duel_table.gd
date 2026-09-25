extends Control

## DuelTable — mesa JOGÁVEL fiel ao original (lógica de verdade, sem Fake R2).
## A tela só CHAMA os sistemas reais (Duel/Turn/Summon/Battle/Damage/Position)
## e mostra o resultado. Turno do jogador tem 2 fases:
## FASE DA MÃO (trava total, só joypad D19):
##  AVULSA (0 levantadas):
##   1. Confirmar monstro -> vai ao CENTRO e para.
##   2. Esq/dir alterna face p/ cima / p/ baixo. Confirmar trava a face.
##   3. Escolhe 1 dos 5 slots próprios (vazio OU ocupado, mostra qual tem carta).
##   4. Confirmar no slot -> menu no centro com as 2 guardian stars
##      (dado fm guardian_star_1/2, gravada na instância).
##   5. Desce ao slot SEMPRE em Ataque (vertical) COM a face escolhida.
##      Slot ocupado = encontro: tenta fusão campo+mão (regra par-a-par real);
##      falhou -> o do campo é descartado e a da mão desce.
##  COMBINAÇÃO (2+ levantadas):
##   1. Confirmar -> ESCOLHE O SLOT PRIMEIRO (5 próprios, vazio ou ocupado).
##   2. Fila animada no centro EM ORDEM (flash/chacoalhada, sem mudar resultado).
##   3. Carta FINAL + menu da estrela (igual ao da avulsa).
##   4. Desce ao slot escolhido face-up em Ataque.
##      Slot ocupado = encontro: a final tenta fusão com ele (par-a-par real);
##      falhou -> o do campo é descartado e a final desce.
##  Fim da fase da mão (MAIN -> BATTLE automático).
## FASE DE CAMPO (SÓ os 20 slots do campo, sem LP e sem mão):
##  - 2 fileiras de monstro + 2 de magia (próprias + rival), por posição
##    de tela (direita sempre anda p/ direita visível, espelho incluso).
##  - Cima no topo não sai do lugar. Com campo rival vazio, o menu de alvo
##    oferece o LP rival (direto com ATK cheio, regra no BattleSystem).
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
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const FusionSystem := preload("res://duel/fusion_system.gd")
const CardViewScript := preload("res://ui/card_view.gd")
const BoardScript := preload("res://ui/duel_board.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")

const ESCALA_CAMPO := 0.85
## Mão p1 (rival) em miniatura de costas: cabe no topo (y=20) sem
## cobrir os slots do rival. p0 fica tamanho cheio embaixo (y=980).
const ESCALA_MAO_P1 := 0.55
## Mão RETA (sem leque): carta levantada (cima) sobe + cresce + vizinhas abrem.
const LEVANTA_DY := 38.0
const LEVANTA_ESCALA := 1.15
const LEVANTA_AFASTAMENTO := 26.0
## Voo curto da animação: nasce perto do destino, não do deck oposto.
const VOO_OFFSET_P0 := Vector2(0, 36)
const VOO_OFFSET_P1 := Vector2(0, -28)
## Carta no centro da tela 1920x1080 (centro 960,540 menos metade da carta).
const CENTRO_CARTA := Vector2(895, 447)

var _duel
var _st
var _cartas: Dictionary = {}
var _fusions_data: Dictionary = {"schema_version": 1, "recipes": [], "rules": []}
## Levantadas p/ fusão (ordem em que levantou, índices da mão p0).
## 0 = avulsa (fluxo D24), 1 = bloqueia e avisa, 2+ = combina no confirmar.
var _levantadas: Array = []
## Trava simples da animação da fila (só controle, sem regra): evita
## confirmar 2 fusões ao mesmo tempo; sempre solta no fim (sem travar input).
var _fusao_animando := false
## Combinação (2+ levantadas): confirmar -> escolhe o SLOT primeiro (vazio ou
## ocupado) -> fila no centro -> FINAL + menu da estrela -> desce face-up ATK.
## Avulsa em slot ocupado: mesma regra de encontro (campo+mão, falhou descarta
## o campo). Só controle; a regra par-a-par é o FusionSystem real.
var _combinando := false
var _fusao_ordem: Array = []
var _fusao_final: Dictionary = {}
var _fusao_descartes: Array = []
var _fusao_passos: Array = []
var _sel_mao := -1
var _sel_atk := -1
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
const FILEIRA_RIVAL_MAGIA := 4
const FILEIRA_MEU_MAGIA := 5
## Ordem visual de cima p/ baixo só com os 20 slots do campo (bug 3+5):
## magia rival (128) -> monstro rival (317) -> meu monstro (600) -> minha magia (789).
const ORDEM_CAMPO := [4, 1, 2, 5]
## Ordem livre p/ observar na vez do rival (LP + 20 slots + mão).
const ORDEM_LIVRE := [0, 4, 1, 2, 5, 3]
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
var _estrela_ops: Array = []
var _vista_centro: Control = null
## Menu central tem 2 modos (mesmo popup, sem regra nova): "estrela" (invocar)
## ou "alvo" (direto no LP rival com campo vazio, bug 6).
var _popup_modo := "estrela"

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
	# O campo (Board) também: sem handler ligado ele não fazia nada, mas
	# a garantia do D19 é estrutural — nenhum Control da mesa é clicável.
	var board: Node = get_node_or_null(^"Board")
	if board is Control:
		(board as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	# Arena do duel_setup (só DESENHO): com --project válido sai da pasta
	# informada; sem o argumento (ou pasta inválida), da embutida.
	var arena_id := str((data.get("duel_setup", {}) as Dictionary).get("arena_id", "arena_starter"))
	_arena_data = BoardLayoutScript.load_arena_data(BoardLayoutScript.project_arena_path(arena_id))
	_arena_layout = (_arena_data.get("slots", {}) as Dictionary)
	if _arena_layout.is_empty():
		print("[TABLE] Aviso: arena não carregou, usando grade padrão.")
	else:
		var h0: Dictionary = BoardLayoutScript.get_hand(_arena_data, 0)
		var h1: Dictionary = BoardLayoutScript.get_hand(_arena_data, 1)
		print("[TABLE] Arena carregada: %d slots + mão p0(%d,%d,%d) p1(%d,%d,%d)." % [_arena_layout.size(), int(h0["x"]), int(h0["y"]), int(h0["step"]), int(h1["x"]), int(h1["y"]), int(h1["step"])])
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	_fusions_data = _fusoes_do_data(data)
	_fala("Duelo começou! Sua vez.")
	_duel.advance_phase() # DRAW inicial -> MAIN (mão 5/5 SEM extra, FM fiel).
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_levantadas = []
	_combinando = false
	_fusao_ordem = []
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_fusao_animando = false
	_sel_mao = -1
	_sel_atk = -1
	_slot_alvo = -1
	_estrela_ops = []
	_pad_fileira = FILEIRA_MAO
	_pad_col = 0
	_fala("Sua FASE DA MÃO: escolha o monstro.")
	_atualizar(true)


func _montar_painel() -> void:
	# LP do rival: só mostra (sem clique). A fileira RIVAL_LP existe, mas
	# o cursor nunca chega nela (FASE_DE_CAMPO força fileira de campo); o
	# ataque direto acontece pelo MENU de alvo ao mirar no campo vazio.
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


## FUSÕES (só DADO, nunca regra): usa o que o DataLoader JÁ leu e validou
## (data["fusions"]). NÃO relê o fusions.json do disco — 2,3 MB / 25 mil
## receitas eram parseados 2x por boot e a 1ª cópia jogada fora.
## A regra mora no FusionSystem real. Vazio/ausente = lista vazia + aviso
## PT-BR (o jogo nunca quebra por causa de fusão).
func _fusoes_do_data(data: Dictionary) -> Dictionary:
	var bruto = data.get("fusions", null)
	if not (bruto is Dictionary) or (bruto as Dictionary).is_empty():
		print("[TABLE] Aviso: fusões não vieram no projeto (sem fusão).")
		return {"schema_version": 1, "recipes": [], "rules": []}
	# Cópia rasa: normaliza as listas sem mexer no dict do DataLoader.
	var out: Dictionary = (bruto as Dictionary).duplicate()
	if not (out.get("recipes", []) is Array):
		out["recipes"] = []
	if not (out.get("rules", []) is Array):
		out["rules"] = []
	print("[TABLE] Fusões carregadas: %d receitas + %d regras." % [(out["recipes"] as Array).size(), (out["rules"] as Array).size()])
	return out


# ---- MÃO RETA + LEVANTADAS (só controle/visual, sem regra nova) ----

## Levantada? Ordem 1-based (selo 1,2,3...), 0 = abaixada.
func _ordem_levantada(hand_idx: int) -> int:
	var pos := _levantadas.find(hand_idx)
	if pos < 0:
		return 0
	return pos + 1


func _eh_levantada(hand_idx: int) -> bool:
	return _levantadas.has(hand_idx)


## Tira índices inválidos (mão encolheu após invocar/fundir/comprar).
func _limpar_levantadas() -> void:
	if _st == null:
		_levantadas = []
		return
	var n: int = (((_st.players[0] as Dictionary)["hand"]) as Array).size()
	var novas: Array = []
	for h in _levantadas:
		if h is int and int(h) >= 0 and int(h) < n and not novas.has(int(h)):
			novas.append(int(h))
	_levantadas = novas


## Cima levanta (só monstro/equip, sem duplicar). Baixo abaixa e renumera sozinho.
func _levantar_carta(hand_idx: int) -> void:
	_limpar_levantadas()
	if _st == null:
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if hand_idx < 0 or hand_idx >= mao.size():
		return
	if _levantadas.has(hand_idx):
		return
	var carta = mao[hand_idx]
	if not (carta is Dictionary):
		return
	var t := str((carta as Dictionary).get("card_type", ""))
	if t != "monster" and t != "equip":
		_fala("Só monstro (e equip) levanta p/ fusão.")
		return
	_levantadas.append(hand_idx)
	print("[SOM] levantar carta %d (selo %d)." % [hand_idx, _levantadas.size()])
	_fala("Levantada %d (%d p/ fundir)." % [_levantadas.size(), _levantadas.size()])
	_atualizar()


func _abaixar_carta(hand_idx: int) -> void:
	if not _levantadas.has(hand_idx):
		return
	_levantadas.erase(hand_idx)
	print("[SOM] abaixar carta %d." % hand_idx)
	_fala("Abaixou. Restam %d levantadas." % _levantadas.size())
	_atualizar()


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
		FILEIRA_RIVAL_MAGIA:
			return 5
		FILEIRA_MEU_MAGIA:
			return 5
		FILEIRA_MAO:
			if _st == null:
				return 1
			var n: int = (((_st.players[0] as Dictionary)["hand"]) as Array).size()
			return maxi(n, 1)
	return 1


func _eh_fileira_campo(f: int) -> bool:
	return f == FILEIRA_RIVAL_MAGIA or f == FILEIRA_RIVAL_CAMPO or f == FILEIRA_MEU_CAMPO or f == FILEIRA_MEU_MAGIA


func _lado_tipo_de_fileira(f: int) -> Array:
	match f:
		FILEIRA_RIVAL_MAGIA:
			return [1, "magia"]
		FILEIRA_RIVAL_CAMPO:
			return [1, "monstro"]
		FILEIRA_MEU_CAMPO:
			return [0, "monstro"]
		FILEIRA_MEU_MAGIA:
			return [0, "magia"]
	return []


func _centro_campo(f: int, col: int) -> Vector2:
	var lt := _lado_tipo_de_fileira(f)
	if lt.is_empty():
		return Vector2.ZERO
	return BoardScript.slot_rect(int(lt[0]), str(lt[1]), clampi(col, 0, 4), _arena_layout).get_center()


## Vizinho por POSIÇÃO de tela (bug 4): direita sempre anda p/ direita
## visível, nos 2 lados. O rival é espelho (índice 0 à direita), então andar
## por índice espelhava o controle. Aqui anda por X de tela, nunca por índice.
func _vizinho_horizontal_por_posicao(f: int, col_atual: int, dx: int) -> int:
	if not _eh_fileira_campo(f):
		var larg := _pad_largura_fileira(f)
		if larg > 1:
			return posmod(col_atual + dx, larg)
		return 0
	var atual := _centro_campo(f, col_atual)
	var melhor := col_atual
	var melhor_dist := 1e20
	var achou := false
	for i in range(5):
		if i == col_atual:
			continue
		var delta := _centro_campo(f, i).x - atual.x
		if dx > 0 and delta > 1.0 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
		elif dx < 0 and delta < -1.0 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
	if achou:
		return melhor
	# Na borda: volta p/ o extremo oposto (mesma volta de antes, mas por posição).
	if dx > 0:
		var minx := 1e20
		var mini := col_atual
		for i in range(5):
			var cx := _centro_campo(f, i).x
			if cx < minx:
				minx = cx
				mini = i
		return mini
	else:
		var maxx := -1e20
		var maxi := col_atual
		for i in range(5):
			var cx2 := _centro_campo(f, i).x
			if cx2 > maxx:
				maxx = cx2
				maxi = i
		return maxi


func _pad_ao_trocar(nova: int) -> void:
	# Campo -> campo preserva a COLUNA VISÍVEL (X de tela, bug 4): o espelho
	# do rival tem o índice invertido, então manter o índice teleportava o
	# cursor p/ o outro lado. Fora do campo mantém a proporção de antes.
	if _eh_fileira_campo(_pad_fileira) and _eh_fileira_campo(nova):
		var atual_x := _centro_campo(_pad_fileira, _pad_col).x
		var melhor := clampi(_pad_col, 0, 4)
		var melhor_dist := 1e20
		for i in range(5):
			var d := absf(_centro_campo(nova, i).x - atual_x)
			if d < melhor_dist:
				melhor_dist = d
				melhor = i
		_pad_col = melhor
		_pad_fileira = nova
		return
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
## CAMPO anda SÓ nos 20 slots do campo (bug 3+5): 2 fileiras de monstro +
## 2 de magia, sem LP e sem mão (cima no topo não sai do lugar).
func _pad_mover(dx: int, dy: int) -> void:
	# SEM guarda de fusão aqui de propósito: durante a fila o _sub_mao já é
	# SUB_SLOT, e este ramo só mexe no cursor (_pad_fileira/_pad_col) — não
	# escreve _sub_mao nem _slot_alvo. O slot da fusão foi copiado numa
	# variável local ANTES do await (em _fluxo_escolher_slot_fusao), então
	# o cursor andando durante a animação não troca o alvo nem reinicia nada.
	if _st == null or bool(_st.over):
		return
	# Menu central (estrela ou alvo): só cima/baixo troca a opção.
	if _popup.visible:
		if dy != 0 and _popup_botoes.size() > 0:
			var max_idx := 1
			if _popup_modo == "estrela":
				max_idx = 2
				if _estrela_ops.size() < 2:
					max_idx = 1
			else:
				max_idx = 1
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
				# Só os 5 slots de monstro do próprio lado, por posição (bug 4).
				if dx != 0:
					_pad_fileira = FILEIRA_MEU_CAMPO
					_pad_col = _vizinho_horizontal_por_posicao(FILEIRA_MEU_CAMPO, _pad_col, dx)
					_atualizar_cursor()
				return
			_:
				# Escolha da carta: esq/dir anda na mão; cima levanta p/ fusão,
				# baixo abaixa (selo renumera sozinho). Nunca sai da mão.
				if dy < 0:
					_pad_fileira = FILEIRA_MAO
					_levantar_carta(clampi(_pad_col, 0, maxi(_pad_largura_fileira(FILEIRA_MAO) - 1, 0)))
					_atualizar_cursor()
					return
				if dy > 0:
					_pad_fileira = FILEIRA_MAO
					_abaixar_carta(clampi(_pad_col, 0, maxi(_pad_largura_fileira(FILEIRA_MAO) - 1, 0)))
					_atualizar_cursor()
					return
				if dx != 0:
					_pad_fileira = FILEIRA_MAO
					var larg := _pad_largura_fileira(FILEIRA_MAO)
					if larg > 1:
						_pad_col = posmod(_pad_col + dx, larg)
						_atualizar_cursor()
				return
	# FASE DE CAMPO (seu turno): SÓ os 20 slots (bug 3+5), por posição (bug 4).
	if _fase_jogador == FASE_CAMPO and meu_turno:
		if not _eh_fileira_campo(_pad_fileira):
			_pad_fileira = FILEIRA_MEU_CAMPO
			_pad_col = clampi(_pad_col, 0, 4)
		if dx != 0:
			_pad_col = _vizinho_horizontal_por_posicao(_pad_fileira, _pad_col, dx)
			_atualizar_cursor()
		if dy != 0:
			var idx := ORDEM_CAMPO.find(_pad_fileira)
			if idx < 0:
				idx = ORDEM_CAMPO.find(FILEIRA_MEU_CAMPO)
			var novo_idx := clampi(idx + dy, 0, ORDEM_CAMPO.size() - 1)
			if novo_idx != idx:
				_pad_ao_trocar(int(ORDEM_CAMPO[novo_idx]))
				_atualizar_cursor()
			# Cima no topo / baixo na base: não sai do lugar (bug 5).
		return
	# Fora do seu fluxo (vez do rival): cursor anda livre p/ observar.
	if dx != 0:
		if _eh_fileira_campo(_pad_fileira):
			_pad_col = _vizinho_horizontal_por_posicao(_pad_fileira, _pad_col, dx)
			_atualizar_cursor()
		else:
			var larg2 := _pad_largura_fileira(_pad_fileira)
			if larg2 > 1:
				_pad_col = posmod(_pad_col + dx, larg2)
				_atualizar_cursor()
	if dy != 0:
		var idx2 := ORDEM_LIVRE.find(_pad_fileira)
		if idx2 < 0:
			_pad_fileira = FILEIRA_MAO
			_pad_col = 0
			_atualizar_cursor()
			return
		var novo2 := clampi(idx2 + dy, 0, ORDEM_LIVRE.size() - 1)
		if novo2 != idx2:
			_pad_ao_trocar(int(ORDEM_LIVRE[novo2]))
			_atualizar_cursor()


func _pad_confirmar() -> void:
	if _st == null:
		return
	if bool(_st.over):
		get_tree().reload_current_scene()
		return
	if _popup.visible:
		if _popup_modo == "alvo":
			_confirmar_alvo_menu()
		else:
			_confirmar_estrela()
		return
	var meu_turno: bool = int(_st.current_player) == 0
	if not meu_turno:
		_fala("Aguarde o rival.")
		return
	# FASE DA MÃO: avulsa = centro -> face -> slot -> estrela.
	# Com levantadas: 0 = avulsa (fluxo D24), 1 = bloqueia e avisa,
	# 2+ = combina (escolhe o SLOT primeiro, depois fila+estrela).
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				_limpar_levantadas()
				if _levantadas.size() == 1:
					_fala("Só 1 levantada: levante +1 p/ fundir ou abaixe p/ invocar avulsa.")
					print("[TABLE] Fusão bloqueada: só 1 levantada.")
					return
				if _levantadas.size() >= 2:
					_iniciar_escolha_slot_fusao()
					return
				_fluxo_escolher_carta()
				return
			SUB_FACE:
				_fluxo_travar_face()
				return
			SUB_SLOT:
				if _combinando:
					_fluxo_escolher_slot_fusao()
				else:
					_fluxo_escolher_slot()
				return
			SUB_ESTRELA:
				_fala("Escolha a estrela no menu.")
				return
		return
	# FASE DE CAMPO: SÓ os 20 slots do campo (bug 3+5, sem LP e sem mão).
	# A fileira do LP rival NÃO tem caso aqui: em FASE_DE_CAMPO o cursor é
	# forçado para uma fileira de campo, e o ataque direto existe só pelo
	# menu de alvo que abre ao mirar no campo rival vazio (bug 6).
	if _fase_jogador == FASE_CAMPO:
		match _pad_fileira:
			FILEIRA_MEU_CAMPO:
				_confirmar_meu_campo()
				return
			FILEIRA_MEU_MAGIA:
				_confirmar_meu_magia()
				return
			FILEIRA_RIVAL_CAMPO:
				_confirmar_alvo_rival(clampi(_pad_col, 0, 4))
				return
			FILEIRA_RIVAL_MAGIA:
				_confirmar_alvo_rival_magia(clampi(_pad_col, 0, 4))
				return
			_:
				_fala("Fase de campo: use os 20 slots do campo.")
				return
		return


## 1) Confirmar carta monstro -> ela vai ao CENTRO da tela e para.
## Não-monstro: fluxo mínimo mantido (só avisa, sem centro).
## Slot ocupado liberado: qualquer dos 5 serve (vazio ou encontro).
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
	_mao_idx = _pad_col
	_sel_mao = _pad_col
	_sel_atk = -1
	_face_baixo = false
	_combinando = false
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
	_combinando = false
	_slot_alvo = -1
	_pad_fileira = FILEIRA_MEU_CAMPO
	var livre := SummonSystem.free_monster_slot(_st, 0)
	_pad_col = clampi(livre, 0, 4) if livre >= 0 else 0
	_fala("Face travada (%s). Escolha 1 dos 5 slots (%s)." % [("p/ baixo" if _face_baixo else "p/ cima"), _resumo_slots()])
	_atualizar_cursor()


## 3) 1 dos 5 slots próprios (vazio OU ocupado) -> abre menu da estrela.
## Mostra qual tem carta (log + desenho do campo). Ocupado = encontro na descida.
func _fluxo_escolher_slot() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_atualizar()
		return
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var slot := clampi(_pad_col, 0, 4)
	if slot < 0 or slot >= zona.size():
		return
	_slot_alvo = slot
	_combinando = false
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
	_pad_popup_idx = 0
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	if zona[slot] != null:
		_fala("Slot %d ocupado por %s: vai tentar fusão. Escolha a estrela." % [slot, _nome_no_slot(slot)])
	else:
		_fala("Escolha 1 das 2 guardian stars.")
	_atualizar_cursor()


## Resumo curto dos 5 slots p/ o log (mostra qual tem carta, sem regra nova).
func _resumo_slots() -> String:
	if _st == null:
		return "5 slots"
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var vazios: Array = []
	var ocupados: Array = []
	for i in range(zona.size()):
		if zona[i] == null:
			vazios.append(str(i))
		else:
			ocupados.append("%d:%s" % [i, _nome_no_slot(i)])
	var txt := "vazios %s" % ("+".join(vazios) if not vazios.is_empty() else "nenhum")
	if not ocupados.is_empty():
		txt += " | ocupados %s" % (" ".join(ocupados))
	return txt


## Nome curto do que está no slot (p/ mostrar qual tem carta no log).
func _nome_no_slot(slot: int) -> String:
	if _st == null:
		return "?"
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "vazio"
	var m := zona[slot] as Dictionary
	var cid := str(m.get("card_id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return str((_cartas[cid] as Dictionary).get("name", cid))
	var nome := str(m.get("nome", cid))
	return nome if not nome.is_empty() else cid


## Instância do campo -> carta completa p/ fusão (par-a-par real).
## Junta o DADO real (_cartas) pelo card_id; sem DADO usa o básico da instância.
func _carta_completa_do_campo(inst: Dictionary) -> Dictionary:
	var cid := str(inst.get("card_id", ""))
	var base: Dictionary = {}
	if not cid.is_empty() and _cartas.has(cid):
		base = (_cartas[cid] as Dictionary).duplicate(true)
	else:
		base = {"id": cid, "name": _nome_da_inst(inst, cid), "card_type": "monster", "monster_type": "beast", "attribute": "earth", "attack": int(inst.get("atk", 0)), "defense": int(inst.get("def", 0))}
	if str(base.get("id", "")).is_empty():
		base["id"] = cid
	return base


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
	_popup_modo = "estrela"
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
	# Menu sempre POR CIMA da carta central (bug 2): popup acima do centro, cursor no topo.
	if _vista_centro != null and is_instance_valid(_vista_centro):
		_vista_centro.move_to_front()
	_popup.move_to_front()
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.move_to_front()


## 4) Menu no centro: 1 das 2 guardian stars -> desce ao slot em Ataque.
## Avulsa desce COM a face; combinação desce face-up (FINAL já pronto).
func _confirmar_estrela() -> void:
	# Fusão animando: NÃO entra no menu. Sem esta guarda, o "Cancelar" daqui
	# escreveria _sub_mao = SUB_SLOT no meio da fila e o próximo confirmar
	# cairia em _fluxo_escolher_slot_fusao por cima da fila que já está
	# rodando (2º await _animar_fila_fusao). A 1ª corrotina continuaria viva
	# e o estado da mão ficaria inconsistente. A fila termina e aí sim o menu
	# abre (a própria fila chama _mostrar_popup_estrela no fim).
	if _fusao_animando: # Barreira de reentrada (ver comentário acima).
		_fala("Aguarde a fusão terminar.")
		return
	if _sub_mao != SUB_ESTRELA or _slot_alvo < 0:
		_popup.visible = false
		_pad_popup_idx = 0
		return
	if _combinando and _fusao_final.is_empty():
		_popup.visible = false
		_pad_popup_idx = 0
		return
	if not _combinando and _mao_idx < 0:
		_popup.visible = false
		_pad_popup_idx = 0
		return
	if _pad_popup_idx == 2:
		# Cancelar volta p/ escolha do slot (avulsa volta ao slot, fusão ao slot da fusão).
		_popup.visible = false
		_pad_popup_idx = 0
		_sub_mao = SUB_SLOT
		_pad_fileira = FILEIRA_MEU_CAMPO
		_pad_col = clampi(_slot_alvo, 0, 4)
		_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
		_atualizar_cursor()
		return
	var estrela := str(_estrela_ops[clampi(_pad_popup_idx, 0, 1)])
	if _combinando:
		_executar_fusao_fiel(estrela)
	else:
		_executar_summon_fiel(estrela)


## 5) Carta vai ao slot COM a face escolhida, SEMPRE em Ataque (vertical).
## Slot OCUPADO = encontro (mesma regra par-a-par real): tenta fusão campo+mão;
## falhou -> a do campo é descartada e a da mão desce com a face escolhida.
func _executar_summon_fiel(estrela: String) -> void:
	_popup.visible = false
	_popup_modo = "estrela"
	_pad_popup_idx = 0
	if _mao_idx < 0 or _slot_alvo < 0:
		return
	var hand_idx := _mao_idx
	var slot_n := _slot_alvo
	var face: bool = _face_baixo
	var p: Dictionary = _st.players[0] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	if hand_idx < 0 or hand_idx >= mao.size():
		_fala("Carta saiu da mão.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_sel_mao = -1
		_slot_alvo = -1
		_esconder_centro()
		_pad_fileira = FILEIRA_MAO
		_pad_col = 0
		_atualizar()
		return
	if slot_n < 0 or slot_n >= zona.size():
		_fala("Slot inválido.")
		return
	var carta_mao := (mao[hand_idx] as Dictionary).duplicate(true)
	# Slot vazio: fluxo normal (sistema real).
	if zona[slot_n] == null:
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
		_combinando = false
		_estrela_ops = []
		_levantadas = []
		_sub_mao = SUB_MAO_ESCOLHA
		_duel.advance_phase()
		_fase_jogador = FASE_CAMPO
		_sel_atk = -1
		_pad_fileira = FILEIRA_MEU_CAMPO
		_pad_col = clampi(slot_n, 0, 4)
		_atualizar()
		return
	# Slot OCUPADO: encontro campo+mão (regra par-a-par real, sem Fake).
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 invocação normal por turno.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_sel_mao = -1
		_slot_alvo = -1
		_esconder_centro()
		_pad_fileira = FILEIRA_MAO
		_pad_col = 0
		_atualizar()
		return
	var ocupante := zona[slot_n] as Dictionary
	var nome_campo := _nome_no_slot(slot_n)
	var campo_full := _carta_completa_do_campo(ocupante)
	var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, carta_mao, _fusions_data, _cartas)
	if bool(tent.get("ok", false)):
		var rid := str(tent.get("result_id", ""))
		var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
		var real: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
		var tipo_res := str(real.get("card_type", dado.get("card_type", "monster")))
		if tipo_res == "monster":
			mao.remove_at(hand_idx)
			# Instância: construtor ÚNICO do motor (SummonSystem), nunca
			# literal montado na tela (R1 — o formato vive em 1 lugar só).
			zona[slot_n] = SummonSystem.construir_instancia(dado, face, "ATK", estrela, real, rid)
			_st.normal_summon_used = true
			_fala("Fusão com campo! %s + %s = %s." % [nome_campo, str(carta_mao.get("id", "?")), rid])
			var modo2 := "virada p/ baixo" if face else "p/ cima"
			_fala("Desceu %s em Ataque (estrela %s)!" % [modo2, estrela])
			print("[SOM] encontro fundiu no slot %d." % slot_n)
		else:
			(p["graveyard"] as Array).append(str(ocupante.get("card_id", "")))
			mao.remove_at(hand_idx)
			zona[slot_n] = SummonSystem.construir_instancia(carta_mao, face, "ATK", estrela)
			_st.normal_summon_used = true
			_fala("Resultado %s não é monstro: %s descartado, a da mão desce." % [rid, nome_campo])
	else:
		(p["graveyard"] as Array).append(str(ocupante.get("card_id", "")))
		mao.remove_at(hand_idx)
		zona[slot_n] = SummonSystem.construir_instancia(carta_mao, face, "ATK", estrela)
		_st.normal_summon_used = true
		_fala("Não fundiu: %s descartado." % nome_campo)
		var modo3 := "virada p/ baixo" if face else "p/ cima"
		_fala("Desceu %s em Ataque (estrela %s)!" % [modo3, estrela])
		print("[SOM] encontro falhou, campo descartado no slot %d." % slot_n)
	_esconder_centro()
	_mao_idx = -1
	_sel_mao = -1
	_slot_alvo = -1
	_combinando = false
	_estrela_ops = []
	_levantadas = []
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase()
	_fase_jogador = FASE_CAMPO
	_sel_atk = -1
	_pad_fileira = FILEIRA_MEU_CAMPO
	_pad_col = clampi(slot_n, 0, 4)
	_atualizar()


## COMBINAÇÃO (2+ levantadas): confirmar -> ESCOLHE O SLOT PRIMEIRO
## (5 próprios, vazio ou ocupado, mostra qual tem carta). Depois a fila
## anima no centro, a FINAL vai ao slot + menu da estrela e desce face-up ATK.
## Só controle; a regra par-a-par é o FusionSystem real.
func _iniciar_escolha_slot_fusao() -> void:
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	_limpar_levantadas()
	if _levantadas.size() < 2:
		return
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "MAIN":
		_fala("Fusão só na sua MAIN.")
		return
	if bool(_st.normal_summon_used):
		_fala("Só 1 jogada por turno (fusão conta como a jogada).")
		return
	_combinando = true
	_fusao_ordem = _levantadas.duplicate()
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_mao_idx = -1
	_sel_mao = -1
	_sub_mao = SUB_SLOT
	_slot_alvo = -1
	_pad_fileira = FILEIRA_MEU_CAMPO
	_pad_col = 0
	_fala("Fusão: escolha 1 dos 5 slots (%s)." % _resumo_slots())
	_atualizar_cursor()


## Slot da fusão escolhido -> fila no centro -> FINAL + menu da estrela.
func _fluxo_escolher_slot_fusao() -> void:
	if not _combinando:
		_fluxo_escolher_slot()
		return
	if _fusao_animando:
		# Barreira de reentrada: sem ela, um 2º fluxo de fusão roda por cima
		# da fila que já está animando (2º await _animar_fila_fusao).
		_fala("Aguarde a fusão terminar.")
		return
	_limpar_levantadas()
	var ordem: Array = _fusao_ordem.duplicate() if not _fusao_ordem.is_empty() else _levantadas.duplicate()
	if ordem.size() < 2:
		_fala("Fusão precisa de 2+ levantadas.")
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_atualizar()
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_combinando = false
		_fusao_animando = false
		_atualizar()
		return
	var slot := clampi(_pad_col, 0, 4)
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	if slot < 0 or slot >= zona.size():
		return
	_slot_alvo = slot
	var mao_atual: Array = (_st.players[0] as Dictionary)["hand"]
	var em_ordem: Array = []
	for h in ordem:
		var hi := int(h)
		if hi >= 0 and hi < mao_atual.size() and (mao_atual[hi] is Dictionary):
			em_ordem.append((mao_atual[hi] as Dictionary).duplicate(true))
	if em_ordem.size() < 2:
		_fala("Cartas saíram da mão.")
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_atualizar()
		return
	var previa: Dictionary = FusionSystem.resolve_chain(em_ordem, _fusions_data, _cartas)
	if not bool(previa.get("ok", false)):
		_fala("Não deu: " + str(previa.get("erro", "Fusão falhou.")))
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_atualizar()
		return
	var passos_prev: Array = previa.get("passos", []) as Array
	_fusao_animando = true
	await _animar_fila_fusao(em_ordem, passos_prev, ordem)
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_fusao_animando = false
		_combinando = false
		_atualizar()
		return
	# FINAL precisa ser monstro p/ descer (equip puro ainda sem tabela não desce).
	var final_card: Dictionary = (previa.get("final_card", {}) as Dictionary).duplicate(true)
	var final_id := str(previa.get("final_id", ""))
	var real: Dictionary = (_cartas.get(final_id, {}) as Dictionary) if _cartas.has(final_id) else final_card
	var tipo_final := str(real.get("card_type", final_card.get("card_type", "monster")))
	if tipo_final != "monster":
		_fusao_animando = false
		_combinando = false
		_slot_alvo = -1
		_fala("Equip ainda sem tabela: resultado %s não desce (pendente)." % final_id)
		print("[TABLE] Fusão equip pendente (final): " + final_id)
		_pad_fileira = FILEIRA_MAO
		_pad_col = 0
		_sub_mao = SUB_MAO_ESCOLHA
		_atualizar()
		return
	_fusao_final = final_card
	if _fusao_final.get("id", "") == null or str(_fusao_final.get("id", "")).is_empty():
		_fusao_final["id"] = final_id
	_fusao_descartes = (previa.get("descartes", []) as Array).duplicate()
	_fusao_passos = (previa.get("passos", []) as Array).duplicate()
	for p in _fusao_passos:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p as Dictionary
		var tipo_p := str(pd.get("tipo", ""))
		if tipo_p == "receita" or tipo_p == "regra":
			_fala("Fusão! %s + %s = %s." % [str(pd.get("a", "")), str(pd.get("b", "")), str(pd.get("result_id", ""))])
		elif tipo_p == "equip_pendente":
			_fala("Equip pendente: %s + %s não fundiu." % [str(pd.get("a", "")), str(pd.get("b", ""))])
		else:
			_fala("Não fundiu: %s + %s (descarta %s)." % [str(pd.get("a", "")), str(pd.get("b", "")), str(pd.get("a", ""))])
	if _fusao_descartes.size() > 0:
		_fala("%d acumulada(s) ao cemitério." % _fusao_descartes.size())
	_fusao_animando = false
	_estrela_ops = _estrelas_da_carta(_fusao_final)
	_pad_popup_idx = 0
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	if zona[slot] != null:
		_fala("FINAL %s no slot %d ocupado por %s: escolha a estrela." % [final_id, slot, _nome_no_slot(slot)])
	else:
		_fala("FINAL %s: escolha 1 das 2 guardian stars." % final_id)
	_atualizar_cursor()


## FINAL desce ao slot escolhido face-up em Ataque (com a estrela do menu).
## Slot ocupado = encontro: a FINAL tenta fusão com ele (par-a-par real);
## falhou -> o do campo é descartado e a FINAL desce.
func _executar_fusao_fiel(estrela: String) -> void:
	_popup.visible = false
	_popup_modo = "estrela"
	_pad_popup_idx = 0
	if not _combinando or _fusao_final.is_empty() or _slot_alvo < 0:
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		return
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 jogada por turno.")
		_combinando = false
		_fusao_final = {}
		_popup.visible = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_atualizar()
		return
	var ordem: Array = _fusao_ordem.duplicate() if not _fusao_ordem.is_empty() else _levantadas.duplicate()
	var p: Dictionary = _st.players[0] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	var slot_n := _slot_alvo
	for h in ordem:
		var hi := int(h)
		if hi < 0 or hi >= mao.size():
			_fala("Cartas saíram da mão.")
			_combinando = false
			_fusao_final = {}
			_sub_mao = SUB_MAO_ESCOLHA
			_slot_alvo = -1
			_atualizar()
			return
	var final_id := str(_fusao_final.get("id", ""))
	if final_id.is_empty():
		final_id = str(_fusao_final.get("card_id", "?"))
	var final_carta := _fusao_final.duplicate(true)
	final_carta["id"] = final_id
	# Tira as levantadas da mão do maior p/ o menor (sem embaralhar o resto).
	var para_tirar: Array = ordem.duplicate()
	para_tirar.sort()
	para_tirar.reverse()
	for h in para_tirar:
		mao.remove_at(int(h))
	var cem: Array = p["graveyard"]
	for d in _fusao_descartes:
		cem.append(str(d))
	var descer_id := final_id
	var descer_carta := final_carta.duplicate(true)
	if zona[slot_n] != null:
		var ocupante := zona[slot_n] as Dictionary
		var nome_campo := _nome_no_slot(slot_n)
		var campo_full := _carta_completa_do_campo(ocupante)
		var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, final_carta, _fusions_data, _cartas)
		if bool(tent.get("ok", false)):
			var rid := str(tent.get("result_id", ""))
			var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
			var real2: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
			var tipo2 := str(real2.get("card_type", dado.get("card_type", "monster")))
			if tipo2 == "monster":
				descer_id = rid
				descer_carta = dado.duplicate(true) if not dado.is_empty() else real2.duplicate(true)
				descer_carta["id"] = rid
				_fala("Fusão com campo! %s + %s = %s." % [nome_campo, final_id, rid])
			else:
				cem.append(str(ocupante.get("card_id", "")))
				_fala("Resultado %s não é monstro: %s descartado, a FINAL desce." % [rid, nome_campo])
		else:
			cem.append(str(ocupante.get("card_id", "")))
			_fala("Não fundiu com campo: %s descartado." % nome_campo)
			print("[SOM] encontro da fusão falhou no slot %d." % slot_n)
	var real_f: Dictionary = (_cartas.get(descer_id, {}) as Dictionary) if _cartas.has(descer_id) else descer_carta
	# Instância: construtor ÚNICO do motor (SummonSystem), nunca literal
	# montado na tela (R1 — o formato vive em 1 lugar só). Face p/ cima
	# porque a combinação sempre desce virada (D24/D25).
	zona[slot_n] = SummonSystem.construir_instancia(descer_carta, false, "ATK", estrela, real_f, descer_id)
	_st.normal_summon_used = true
	_fala("Fundiu %s em Ataque p/ cima (estrela %s)!" % [descer_id, estrela])
	print("[SOM] fusão pronta no slot %d." % slot_n)
	_combinando = false
	_fusao_ordem = []
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_levantadas = []
	_mao_idx = -1
	_sel_mao = -1
	_sel_atk = -1
	_slot_alvo = -1
	_estrela_ops = []
	_esconder_centro()
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase()
	_fase_jogador = FASE_CAMPO
	_pad_fileira = FILEIRA_MEU_CAMPO
	_pad_col = clampi(slot_n, 0, 4)
	_atualizar()


## Sem render (headless ou fora da árvore): pula a animação sem quebrar.
func _sem_render() -> bool:
	if not is_inside_tree():
		return true
	return DisplayServer.get_name() == "headless"


## Fila calma da fusão (só visual + som, sem regra nova):
## a 1ª voa ao centro e para mais à direita; a 2ª desliza até ela e tenta
## fundir (flash + som no sucesso, chacoalhada na falha); quem fica (fundida
## ou novata) ocupa a ponta direita e a próxima vem; até acabar a fila.
## Passos curtos (~0.3-0.5s), sem travar o input depois (solta a trava no fim).
## Headless tolera sem render (só prints, sem tween).
func _animar_fila_fusao(em_ordem: Array, passos: Array, indices_mao: Array) -> void:
	if em_ordem.size() < 2:
		return
	if _sem_render():
		for k in range(em_ordem.size()):
			var cid := str((em_ordem[k] as Dictionary).get("id", "")) if em_ordem[k] is Dictionary else "?"
			print("[SOM] fila fusão %d/%d (%s) sem render." % [k + 1, em_ordem.size(), cid])
		return
	var ponta_direita := CENTRO_CARTA + Vector2(90, 0)
	var vistas: Array = []
	for k in range(em_ordem.size()):
		var carta = em_ordem[k]
		if not (carta is Dictionary):
			vistas.append(null)
			continue
		var vista: CardView = CardViewScript.new()
		add_child(vista)
		vista.setup(carta as Dictionary)
		vista.set_facedown(false)
		vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hi := int(indices_mao[k]) if k < indices_mao.size() else -1
		var mao_n: int = maxi(int(((_st.players[0] as Dictionary)["hand"] as Array).size()), 1)
		if hi >= 0 and hi < mao_n:
			vista.position = _pos_mao_visual(hi, mao_n)
		else:
			vista.position = ponta_direita + Vector2(-260, 60)
		vista.scale = Vector2(LEVANTA_ESCALA, LEVANTA_ESCALA)
		vista.pivot_offset = CardViewScript.TAM / 2.0
		vistas.append(vista)
	# 1ª voa à ponta direita.
	var primeira = vistas[0]
	if is_instance_valid(primeira):
		print("[SOM] fila 1/%d à direita (%s)." % [vistas.size(), str((em_ordem[0] as Dictionary).get("id", ""))])
		var tw0 = (primeira as CardView).create_tween().set_parallel(true)
		tw0.tween_property(primeira, "position", ponta_direita, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw0.tween_property(primeira, "scale", Vector2.ONE, 0.3)
		await get_tree().create_timer(0.42).timeout
	# As próximas deslizam até a ponta e tentam fundir, uma por vez.
	var dona = primeira
	for k in range(1, vistas.size()):
		var nova = vistas[k]
		if not is_instance_valid(nova):
			continue
		if not is_instance_valid(dona):
			# Dona caiu (falha anterior sem vista): a novata ocupa a ponta.
			(nova as CardView).position = ponta_direita
			dona = nova
			continue
		print("[SOM] fila %d/%d desliza até a ponta." % [k + 1, vistas.size()])
		var tw = (nova as CardView).create_tween().set_parallel(true)
		tw.tween_property(nova, "position", ponta_direita, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(nova, "scale", Vector2.ONE, 0.3)
		await get_tree().create_timer(0.42).timeout
		if not is_instance_valid(nova) or not is_instance_valid(dona):
			continue
		var passo: Dictionary = (passos[k - 1] as Dictionary) if (k - 1) < passos.size() and (passos[k - 1] is Dictionary) else {}
		var tipo_p := str(passo.get("tipo", "falha"))
		if tipo_p == "receita" or tipo_p == "regra":
			print("[SOM] fusão! %s + %s." % [str(passo.get("a", "")), str(passo.get("b", ""))])
			_flash_fusao()
			(nova as Node).queue_free()
			# A fundida fica na ponta direita (pisca um pouco e segue).
			if is_instance_valid(dona):
				var twf = (dona as CardView).create_tween()
				twf.tween_property(dona, "scale", Vector2(1.12, 1.12), 0.14)
				twf.tween_property(dona, "scale", Vector2.ONE, 0.16)
				await get_tree().create_timer(0.36).timeout
		else:
			print("[SOM] não fundiu: chacoalha (%s + %s)." % [str(passo.get("a", "")), str(passo.get("b", ""))])
			_sacudir_fusao(nova)
			await get_tree().create_timer(0.36).timeout
			# A acumulada cai; a novata ocupa a ponta direita e continua.
			if is_instance_valid(dona):
				(dona as Node).queue_free()
			dona = nova
	# Respira na ponta e limpa a fila (a lógica real já desceu ao campo).
	await get_tree().create_timer(0.22).timeout
	for v in vistas:
		if is_instance_valid(v):
			(v as Node).queue_free()


## Voo ao centro EM ORDEM. Hoje só o teste de animação chama (a mesa usa
## _animar_fila_fusao direto): mantida p/ não quebrar esse teste.
func _animar_voo_centro(ordem: Array) -> void:
	if _st == null or _sem_render() or not is_inside_tree():
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	var em_ordem: Array = []
	for h in ordem:
		var hi := int(h)
		if hi >= 0 and hi < mao.size() and (mao[hi] is Dictionary):
			em_ordem.append((mao[hi] as Dictionary).duplicate(true))
	if em_ordem.size() < 2:
		return
	var previa: Dictionary = FusionSystem.resolve_chain(em_ordem, _fusions_data, _cartas)
	var passos: Array = previa.get("passos", []) as Array if bool(previa.get("ok", false)) else []
	await _animar_fila_fusao(em_ordem, passos, ordem)


## Flash simples na fusão (só visual): retângulo branco que some.
## Headless tolera sem render (só som, sem tween).
func _flash_fusao() -> void:
	print("[SOM] flash na fusão.")
	if _sem_render():
		return
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.55)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.move_to_front()
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.move_to_front()
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)


## Chacoalhada na falha (só visual): balança a carta p/ os lados.
## Headless tolera sem render.
func _sacudir_fusao(vista: Control) -> void:
	print("[SOM] chacoalhada na falha.")
	if _sem_render() or vista == null or not is_instance_valid(vista):
		return
	var x0: float = (vista as Control).position.x
	var tw := (vista as Control).create_tween()
	tw.tween_property(vista, "position:x", x0 - 14.0, 0.07)
	tw.tween_property(vista, "position:x", x0 + 14.0, 0.07)
	tw.tween_property(vista, "position:x", x0 - 8.0, 0.06)
	tw.tween_property(vista, "position:x", x0, 0.08)


## Campo (fase de campo, fluxo fiel):
## - BATTLE + sua carta VÁLIDA = marca o atacante; inválida = avisa e esconde "Atacar".
## - Só mostra "Atacar" se o can_attack real deixar (turno 1, já atacou, virada, DEF, etc.).
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
	# Menu da carta SÓ com ação válida: consulta o can_attack real e esconde
	# "Atacar" quando trava (vale p/ qualquer trava, não só turno 1).
	var pode: Dictionary = BattleSystem.can_attack(_st, 0, slot)
	if not bool(pode.get("ok", false)):
		_sel_atk = -1
		_fala("Não pode atacar: " + str(pode.get("erro", "")))
		_atualizar()
		return
	_sel_atk = slot
	_sel_mao = -1
	_fala("Atacante escolhido. Mire no campo rival.")
	_pad_ao_trocar(FILEIRA_RIVAL_CAMPO)
	_atualizar()


## Mira do ataque (fase de campo): confirmar no campo rival ataca, se há atacante.
## Com campo rival vazio, o menu de alvo oferece o LP do rival (bug 6):
## direto com ATK cheio (regra já existe no BattleSystem).
func _confirmar_alvo_rival(alvo_slot: int) -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	if not BattleSystem.has_monsters(_st, 1):
		_mostrar_popup_alvo()
		_fala("Rival sem monstros: mire no LP p/ ataque direto.")
		return
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	var slot := clampi(alvo_slot, 0, 4)
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		_fala("Escolha um monstro rival (slot vazio).")
		return
	_atacar(_sel_atk, slot)


## Magia própria: só navega (20 slots), sem ação (efeitos fora da mesa, D30).
func _confirmar_meu_magia() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	_fala("Magia: sem ação na mesa (só navega).")


## Magia rival: não é alvo de ataque; com campo vazio oferece o direto.
func _confirmar_alvo_rival_magia(alvo_slot: int) -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	if not BattleSystem.has_monsters(_st, 1):
		_mostrar_popup_alvo()
		_fala("Rival sem monstros: mire no LP p/ ataque direto.")
		return
	_fala("Magia não é alvo: mire num monstro rival.")


## Menu de alvo (bug 6): campo rival vazio -> oferece o LP do rival.
func _mostrar_popup_alvo() -> void:
	_popup_modo = "alvo"
	if _popup_titulo != null and is_instance_valid(_popup_titulo):
		_popup_titulo.text = "Alvo: rival sem monstros"
	for i in range(_popup_botoes.size()):
		var b := _popup_botoes[i] as Label
		if i == 0:
			b.text = "Atacar LP rival (direto)"
			b.visible = true
		elif i == 1:
			b.text = "Cancelar"
			b.visible = true
		else:
			b.visible = false
	_pad_popup_idx = 0
	_popup.visible = true
	if _vista_centro != null and is_instance_valid(_vista_centro):
		_vista_centro.move_to_front()
	_popup.move_to_front()
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.move_to_front()
	_atualizar_cursor()


func _confirmar_alvo_menu() -> void:
	if _popup_modo != "alvo":
		return
	if _pad_popup_idx == 1:
		_popup.visible = false
		_popup_modo = "estrela"
		_pad_popup_idx = 0
		_fala("Ataque direto cancelado. Mire de novo.")
		_atualizar_cursor()
		return
	_popup.visible = false
	_popup_modo = "estrela"
	_pad_popup_idx = 0
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		_atualizar_cursor()
		return
	if BattleSystem.has_monsters(_st, 1):
		_fala("Rival tem monstros: direto bloqueado.")
		_atualizar_cursor()
		return
	_atacar(_sel_atk, -1)


func _pad_cancelar() -> void:
	if _st == null:
		return
	# 1ª TRAVA da função, de propósito: com a fila da fusão rodando, nenhum
	# caminho de cancelar pode reescrever _sub_mao (= SUB_SLOT no cancel do
	# menu da estrela, linha ~1554, e ~1575), senão o confirmar seguinte
	# reentraria em _fluxo_escolher_slot_fusao por cima da fila.
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	if _popup.visible:
		if _popup_modo == "alvo":
			_popup.visible = false
			_popup_modo = "estrela"
			_pad_popup_idx = 0
			_fala("Ataque direto cancelado. Mire de novo.")
			_atualizar_cursor()
			return
		# Volta do menu da estrela p/ escolha do slot (avulsa ou fusão).
		_popup.visible = false
		_pad_popup_idx = 0
		if _fase_jogador == FASE_MAO and _sub_mao == SUB_ESTRELA:
			_sub_mao = SUB_SLOT
			_pad_fileira = FILEIRA_MEU_CAMPO
			_pad_col = clampi(_slot_alvo, 0, 4)
			_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
			_atualizar_cursor()
			return
		_fala("Invocação cancelada.")
		_atualizar_cursor()
		return
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0:
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				# Cancelar abaixa a última levantada (renumera sozinho).
				if not _levantadas.is_empty():
					var ultima := int(_levantadas.back())
					_levantadas.pop_back()
					print("[SOM] abaixar carta %d (cancelar)." % ultima)
					_fala("Abaixou a última. Restam %d levantadas." % _levantadas.size())
					_atualizar()
					return
			SUB_ESTRELA:
				_sub_mao = SUB_SLOT
				_pad_fileira = FILEIRA_MEU_CAMPO
				_pad_col = clampi(_slot_alvo, 0, 4)
				_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
				_atualizar_cursor()
				return
			SUB_SLOT:
				if _combinando:
					_combinando = false
					_fusao_ordem = []
					_fusao_final = {}
					_fusao_descartes = []
					_fusao_passos = []
					_slot_alvo = -1
					_sub_mao = SUB_MAO_ESCOLHA
					_pad_fileira = FILEIRA_MAO
					_pad_col = 0
					_fala("Fusão cancelada. Escolha de novo.")
					_atualizar_cursor()
					return
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
				return Rect2(_pos_mao_visual(c0, n0), CardViewScript.TAM)
	match _pad_fileira:
		FILEIRA_RIVAL_LP:
			return Rect2(_lbl_rival.position, _lbl_rival.size)
		FILEIRA_RIVAL_MAGIA:
			return BoardScript.slot_rect(1, "magia", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_RIVAL_CAMPO:
			return BoardScript.slot_rect(1, "monstro", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_MEU_CAMPO:
			return BoardScript.slot_rect(0, "monstro", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_MEU_MAGIA:
			return BoardScript.slot_rect(0, "magia", clampi(_pad_col, 0, 4), _arena_layout)
		FILEIRA_MAO:
			var mao: Array = (_st.players[0] as Dictionary)["hand"]
			var n := mao.size()
			if n <= 0:
				return Rect2(Vector2(1140, 980), Vector2(200, 60))
			var c := clampi(_pad_col, 0, n - 1)
			return Rect2(_pos_mao_visual(c, n), CardViewScript.TAM)
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
	if _popup.visible and _popup_modo == "alvo":
		_pad_popup_idx = clampi(_pad_popup_idx, 0, 1)
	var r := _retangulo_cursor()
	_cursor.position = r.position - Vector2(6, 6)
	_cursor.size = r.size + Vector2(12, 12)
	_cursor.visible = true
	# Ordem certa (bug 2): centro embaixo, menu POR CIMA do centro, cursor no topo.
	if _vista_centro != null and is_instance_valid(_vista_centro):
		_vista_centro.move_to_front()
	if _popup.visible:
		_popup.move_to_front()
	if _overlay != null and is_instance_valid(_overlay) and _overlay.visible:
		_overlay.move_to_front()
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
	_levantadas = []
	_combinando = false
	_fusao_ordem = []
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_fusao_animando = false
	_slot_alvo = -1
	_estrela_ops = []
	_popup.visible = false
	_popup_modo = "estrela"
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
	# Menu sempre POR CIMA da carta central (bug 2): centro embaixo, popup acima.
	_vista_centro.move_to_front()
	if _popup.visible:
		_popup.move_to_front()
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
	_limpar_levantadas()
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
## MÃO RETA: sempre reta (sem leque/curva), centralizada no campo.
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
	return Vector2(x, y0)


## MÃO RETA: sem leque/rotação (sempre 0 — D25). O desenho põe rotação 0
## direto; esta função existe p/ o teste de mão reta continuar travando.
func _giro_mao(_i: int, _n: int) -> float:
	return 0.0


## Visual da mão p0 com levantadas: base reta + vizinhas se afastam p/ dar
## espaço + levantada sobe. Só desenho, nunca regra.
func _pos_mao_visual(i: int, n: int) -> Vector2:
	var base := _pos_mao(i, n, 0)
	var afast := 0.0
	for lv in _levantadas:
		var li := int(lv)
		if i < li:
			afast -= LEVANTA_AFASTAMENTO
		elif i > li:
			afast += LEVANTA_AFASTAMENTO
	var y := base.y
	if _eh_levantada(i):
		y -= LEVANTA_DY
	return Vector2(base.x + afast, y)


## Selo pequeno numerado (1,2,3...) no canto, na ordem em que levantou.
## Abaixar renumera sozinho (ordem = posição em _levantadas).
func _por_selo(vista: CardView, ordem: int) -> void:
	var fundo := Panel.new()
	fundo.position = Vector2(CardViewScript.TAM.x - 38.0, 4.0)
	fundo.size = Vector2(32, 32)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.06, 0.02, 0.95)
	estilo.border_color = Color(1.0, 0.9, 0.4)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(16)
	fundo.add_theme_stylebox_override("panel", estilo)
	vista.add_child(fundo)
	var num := Label.new()
	num.text = str(ordem)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 22)
	num.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	num.position = Vector2(0, 0)
	num.size = Vector2(32, 32)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(num)


func _desenhar_mao(com_efeito: bool) -> void:
	# p0: aberta na MAIN (carta real, só o cursor escolhe, sem clique).
	# p1: só contagem, de costas, sem id/nome (nunca vazar dado do rival).
	# MÃO RETA: sempre retas (sem leque/rotação), centralizadas no campo.
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	var n := mao.size()
	for i in range(n):
		var vista: CardView = CardViewScript.new()
		_camada_mao.add_child(vista)
		vista.setup(mao[i] as Dictionary)
		vista.set_selected(i == _sel_mao)
		var alvo := _pos_mao_visual(i, n)
		var ordem := _ordem_levantada(i)
		var escala_final := Vector2.ONE
		if ordem > 0:
			escala_final = Vector2(LEVANTA_ESCALA, LEVANTA_ESCALA)
			_por_selo(vista, ordem)
		# Alinhamento: pivô no centro (setup já põe TAM/2), reta sem giro.
		vista.pivot_offset = CardViewScript.TAM / 2.0
		vista.rotation = 0.0
		if com_efeito:
			vista.position = alvo + VOO_OFFSET_P0
			vista.scale = escala_final * 0.9
			vista.modulate.a = 0.0
			var tw := vista.create_tween().set_parallel(true)
			tw.tween_property(vista, "position", alvo, 0.25).set_delay(0.05 + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(vista, "scale", escala_final, 0.22).set_delay(0.05 + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(vista, "modulate:a", 1.0, 0.18).set_delay(0.05 + i * 0.05)
		else:
			vista.position = alvo
			vista.scale = escala_final
			vista.modulate.a = 1.0
	# p1: mini de costas no topo. Só a QUANTIDADE, nunca a carta real.
	# Também reta (sem leque), centralizada.
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
		costas.pivot_offset = CardViewScript.TAM / 2.0
		costas.rotation = 0.0
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
			# Face p/ baixo desce virada de verdade (bug 1): vale p/ os 2 lados.
			var esconder: bool = bool(m.get("face_down", false))
			vista.set_facedown(esconder)
			# Centro do slot = centro da carta (nos 2 lados): o pivô é o centro,
			# então o centro visual é position+pivô (escala não entra na conta).
			vista.pivot_offset = CardViewScript.TAM / 2.0
			vista.scale = Vector2(ESCALA_CAMPO, ESCALA_CAMPO)
			vista.position = r.get_center() - CardViewScript.TAM / 2.0
			# Lado 1 de cabeça p/ cima p/ o rival no topo (frente e verso):
			# base 180°; DEF soma 90° (deitada, mas virada p/ ele).
			var base := 0.0
			if lado == 1:
				base = PI
			if str(m.get("position", "ATK")) == "DEF":
				vista.rotation = base + PI / 2.0
			else:
				vista.rotation = base
			vista.set_selected(lado == 0 and i == _sel_atk)


## O motor guarda a instância enxuta; a tela veste com os dados reais da carta.
func _fantasia_de_inst(m: Dictionary) -> Dictionary:
	var cid := str(m.get("card_id", ""))
	var real: Dictionary = _cartas.get(cid, {}) as Dictionary
	if real.is_empty():
		return {"name": _nome_da_inst(m, cid), "monster_type": "beast", "attribute": "earth", "attack": int(m.get("atk", 0)), "defense": int(m.get("def", 0)), "card_type": "monster"}
	return real


## Nome da instância p/ tela: o "nome" do motor; vazio = cai no card_id
## (a instância real sempre traz o nome, mas carta fora do _cartas
##  mostrava linha em branco sem esta rede).
func _nome_da_inst(inst: Dictionary, cid: String) -> String:
	var nome := str(inst.get("nome", ""))
	return nome if not nome.is_empty() else (cid if not cid.is_empty() else "?")


# ---- jogadas do jogador (fluxo fiel, só controle) ----

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


# ---- Escolha de ataque da IA (FM fiel: FindKiller + FindBestAttack) ----
# Regras do original (decomp: ai_script_find_killer.c + ai_script_find_best_attack.c):
# 1) Seu campo vazio -> direto com o ATK não-usado mais forte.
# 2) FindKiller: p/ cada seu monstro, o rival não-usado mais FRACO que vence
#    (ATK vs ATK ou ATK vs DEF, diferença > 0; empate NÃO vence, igual ao código).
# 3) Sem kill -> FindBestAttack: maior margem (atk - atk do alvo) SÓ contra
#    seus monstros em Ataque face-up (DEF e viradas ignoradas); só ataca se margem >= 0.
# 4) Guardiã ±500 ADIADO: stats crus abaixo. PONTO EXATO p/ ligar depois =
#    _ia_bonus_guardia() (hoje retorna 0; quando ligar, some no `d` do Killer
#    e na `margem` do Best, igual ao Duel_CalcGuardianStarMatchup do original).
# Só ESCOLHA (atacante+alvo). Invocação, fases e dano intactos; o ataque real
# continua no BattleSystem.attack (sem Fake, sem schema novo).
func _ia_bonus_guardia(_estrela_atac: String, _estrela_alvo: String) -> int:
	# PONTO EXATO DA GUARDIÃ: trocar `return 0` pelo ±500 do original
	# (Duel_CalcGuardianStarMatchup: +500 se a estrela do atacante vence a do
	# alvo, -500 se perde, 0 senão; ciclos 1-6 e 7-10). Hoje sempre 0 (adiado).
	return 0


func _ia_atk_bruto(m: Dictionary) -> int:
	return clampi(int(m.get("atk", 0)), 0, 9999)


func _ia_valor_alvo(alvo: Dictionary) -> int:
	# Alvo em ATK vale ATK; em DEF (inclui virada p/ baixo, que entra em DEF)
	# vale DEF. Cru (sem guardiã; ver _ia_bonus_guardia).
	var pos := str(alvo.get("position", "ATK"))
	if pos == "ATK":
		return clampi(int(alvo.get("atk", 0)), 0, 9999)
	return clampi(int(alvo.get("def", 0)), 0, 9999)


func _ia_atacantes_usaveis() -> Array:
	# Rival não-usado: em campo, face-up em ATK e sem has_attacked.
	# (can_attack da fase/vez vale na hora do BattleSystem.attack real.)
	var fora: Array = []
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	for s in range(zona.size()):
		var m = zona[s]
		if not (m is Dictionary):
			continue
		if bool((m as Dictionary).get("face_down", false)):
			continue
		if str((m as Dictionary).get("position", "ATK")) != "ATK":
			continue
		if bool((m as Dictionary).get("has_attacked", false)):
			continue
		fora.append(s)
	return fora


func _ia_mais_forte_usavel(usaveis: Array) -> int:
	var melhor := -1
	var melhor_atk := -1
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	for s in usaveis:
		var m: Dictionary = zona[int(s)] as Dictionary
		var a := _ia_atk_bruto(m)
		if a > melhor_atk:
			melhor_atk = a
			melhor = int(s)
	return melhor


func _ia_find_killer_para(alvo_slot: int, usaveis: Array) -> int:
	# Um alvo (seu monstro): o rival não-usado mais FRACO cujo
	# (ATK + guardiã) - valor_do_alvo > 0. Empate (== 0) NÃO vence.
	var zona_r: Array = (_st.players[1] as Dictionary)["monster"]
	var zona_p: Array = (_st.players[0] as Dictionary)["monster"]
	if alvo_slot < 0 or alvo_slot >= zona_p.size() or zona_p[alvo_slot] == null:
		return -1
	var alvo: Dictionary = zona_p[alvo_slot] as Dictionary
	var alvo_val := _ia_valor_alvo(alvo)
	var estrela_alvo := str(alvo.get("guardian_star", ""))
	var melhor := -1
	var melhor_atk := 10000 # CARD_STAT_MAX do original: quer o mais fraco que vence
	for s in usaveis:
		var m: Dictionary = zona_r[int(s)] as Dictionary
		var d := _ia_atk_bruto(m) - alvo_val + _ia_bonus_guardia(str(m.get("guardian_star", "")), estrela_alvo)
		if d > 0:
			var a := _ia_atk_bruto(m)
			if a < melhor_atk:
				melhor_atk = a
				melhor = int(s)
	return melhor


func _ia_escolher_ataque() -> Array:
	# Retorna [] (passar) ou [atacante_slot, alvo_slot] (alvo -1 = direto).
	# Ordem FM: 1) direto se seu campo vazio; 2) Killer por alvo; 3) Best.
	var usaveis: Array = _ia_atacantes_usaveis()
	if usaveis.is_empty():
		return []
	# 1) Seu campo vazio -> direto com o ATK não-usado mais forte.
	if not BattleSystem.has_monsters(_st, 0):
		var forte := _ia_mais_forte_usavel(usaveis)
		if forte < 0:
			return []
		return [forte, -1]
	# 2) FindKiller: p/ cada seu monstro (ordem de slots), o mais fraco que mata.
	var zona_p: Array = (_st.players[0] as Dictionary)["monster"]
	for alvo in range(zona_p.size()):
		if zona_p[alvo] == null:
			continue
		var killer := _ia_find_killer_para(alvo, usaveis)
		if killer >= 0:
			return [killer, alvo]
	# 3) FindBestAttack: maior margem SÓ contra seus ATK face-up; margem >= 0.
	var melhor_atac := -1
	var melhor_alvo := -1
	var melhor_margem := -1
	var zona_r: Array = (_st.players[1] as Dictionary)["monster"]
	for s in usaveis:
		var m: Dictionary = zona_r[int(s)] as Dictionary
		var atk: int = _ia_atk_bruto(m)
		var estrela_atac := str(m.get("guardian_star", ""))
		for alvo2 in range(zona_p.size()):
			var t = zona_p[alvo2]
			if not (t is Dictionary):
				continue
			if bool((t as Dictionary).get("face_down", false)):
				continue
			if str((t as Dictionary).get("position", "ATK")) != "ATK":
				continue
			var margem := atk - clampi(int((t as Dictionary).get("atk", 0)), 0, 9999) + _ia_bonus_guardia(estrela_atac, str((t as Dictionary).get("guardian_star", "")))
			if margem > melhor_margem:
				melhor_margem = margem
				melhor_atac = int(s)
				melhor_alvo = alvo2
	if melhor_atac >= 0 and melhor_margem >= 0:
		return [melhor_atac, melhor_alvo]
	return []

func _primeiro_monstro(jogador: int) -> int:
	var mao: Array = (_st.players[jogador] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			return i
	return -1


## Turno do RIVAL (IA). É async e chamada sem await (fire-and-forget).
## Se o jogador confirmar no overlay de fim de jogo, reload_current_scene()
## libera este nó: os timers acordam depois e get_tree() pode estar nulo.
## Por isso há guarda `is_inside_tree()` no topo e logo após CADA await.
## Nenhum outro comportamento da IA muda por causa disso.
func _ia_inimiga() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
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
	if not is_inside_tree():
		return
	if bool(_st.over):
		_atualizar()
		return
	_duel.advance_phase() # MAIN -> BATTLE
	var _guarda_ia := 0
	while not bool(_st.over) and _guarda_ia < 5:
		_guarda_ia += 1
		var escolha: Array = _ia_escolher_ataque()
		if escolha.is_empty():
			break
		var s: int = int(escolha[0])
		var alvo: int = int(escolha[1])
		var ra: Dictionary = BattleSystem.attack(_st, 1, s, 0, alvo)
		if not bool(ra.get("ok", false)):
			break
		if bool(ra.get("direto", false)):
			_fala("Rival direto: %d em você!" % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_alvo", false)) and bool(ra.get("destruiu_atacante", false)):
			_fala("Rival atacou: empate, os dois caíram.")
		elif bool(ra.get("destruiu_alvo", false)):
			_fala("Rival destruiu seu monstro (%d de dano)." % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_atacante", false)):
			_fala("Rival quebrou a cara no seu monstro!")
		else:
			_fala("Rival atacou: nada acontece.")
		_atualizar()
		await get_tree().create_timer(0.7).timeout
		if not is_inside_tree():
			return
	if bool(_st.over):
		_atualizar()
		return
	_duel.advance_phase() # BATTLE -> END
	_duel.advance_phase() # END -> sua DRAW (completa até 5, FM fiel)
	_duel.advance_phase() # DRAW -> sua MAIN
	_fala("Seu turno. Mão completada até %d." % (((_st.players[0] as Dictionary)["hand"] as Array).size()))
	_sel_mao = -1
	_mao_idx = -1
	_sel_atk = -1
	_slot_alvo = -1
	_levantadas = []
	_combinando = false
	_fusao_ordem = []
	_fusao_final = {}
	_fusao_descartes = []
	_fusao_passos = []
	_fusao_animando = false
	_estrela_ops = []
	_popup_modo = "estrela"
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
