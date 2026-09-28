extends Node3D

## mesa_3d_test — MESA 3D EXPERIMENTAL (teste D23, NÃO é o duelo oficial).
## Só DESENHA o mesmo estado real do 2D (DuelManager/GameState + sistemas
## reais Summon/Battle/Position/Turn). Zero regra aqui (R1): cada jogada
## chama o sistema real e redesenha. Nada deste arquivo é lido pelo duelo
## 2D (duel_table/duel_board/game_state/duel_manager intactos).
## Controle 100% joypad (D19): só as 11 ações custom, sem mouse/teclado.
## Uso headless p/ validação: `-- --mesa3d-sair=5` sai sozinho após N segundos.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")

## Conversão desenho 2D->3D (só desenho): campo 2D centrado em x=1158.
const DIV := 150.0
const CENTRO_X := 1158.0
const CENTRO_Y := 540.0
const TOPO := 0.35

const LARG_CARTA := 1.0
const ALT_CARTA := 1.43
const GROSS_CARTA := 0.06

const FILEIRA_MAO := 0
const FILEIRA_MEU_M := 1
const FILEIRA_MEU_S := 2
const FILEIRA_RIVAL_M := 3
const FILEIRA_RIVAL_S := 4
const ORDEM_FILEIRAS := [0, 1, 2, 3, 4]
const PAD_REPETE := 0.25

var _duel = null
var _st = null
var _cartas: Dictionary = {}
var _base_dir := ""
var _artes_ok := 0

var _cam: Camera3D = null
var _no_cartas: Node3D = null
var _no_slots: Node3D = null
var _cursor3d: MeshInstance3D = null
var _flash: OmniLight3D = null
var _deck_pos := [Vector3(3.6, 0.6, 0.4), Vector3(-3.6, 0.6, -0.4)]

var _lbl_lp_rival: Label = null
var _lbl_mao_rival: Label = null
var _lbl_fase: Label = null
var _lbl_log: Label = null
var _lbl_lp_voce: Label = null
var _lbl_dica: Label = null
var _log: Array = []

var _fileira := FILEIRA_MAO
var _col := 0
var _sel_atk := -1
var _pad_dir := Vector2i.ZERO
var _pad_tempo := 0.0
var _orb_t := 0.0
var _foco := Vector3.ZERO
var _pulso := 0.0


func _ready() -> void:
	_construir_ambiente()
	_construir_mesa()
	_construir_hud()
	# Duelo REAL (mesma fonte do 2D): ProjectLoader + DuelManager.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	_base_dir = str(data.get("base_dir", ""))
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	_fala("Mesa 3D de teste: duelo real carregado.")
	_duel.advance_phase() # DRAW inicial -> MAIN (igual ao 2D, mão 5/5 sem extra).
	_fileira = FILEIRA_MAO
	_col = 0
	_sel_atk = -1
	_redesenhar(false)
	_atualizar_hud()
	print("[MESA3D] Pronta: mão p0=%d p1=%d, artes carregadas=%d." % [
		((_st.players[0] as Dictionary)["hand"] as Array).size(),
		((_st.players[1] as Dictionary)["hand"] as Array).size(), _artes_ok])
	_ver_autoquit()


func _ver_autoquit() -> void:
	# Só p/ validação headless (`-- --mesa3d-sair=5`). Sem o argumento, nada muda.
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--mesa3d-sair="):
			var n := float(s.trim_prefix("--mesa3d-sair="))
			if n > 0.0:
				await get_tree().create_timer(n).timeout
				print("[MESA3D] Autoquit de validação após %s s." % str(n))
				get_tree().quit()


func _sem_render() -> bool:
	if not is_inside_tree():
		return true
	return DisplayServer.get_name() == "headless"


# ---- AMBIENTE (WorldEnvironment + luzes + câmera) ----

func _construir_ambiente() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.02, 0.03, 0.09)
	mat_ceu.sky_horizon_color = Color(0.10, 0.12, 0.30)
	mat_ceu.ground_bottom_color = Color(0.01, 0.01, 0.03)
	mat_ceu.ground_horizon_color = Color(0.06, 0.05, 0.16)
	ceu.sky_material = mat_ceu
	env.sky = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.09, 0.20)
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 34.0
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.name = "SolDirecional"
	sol.rotation_degrees = Vector3(-52, 28, 0)
	sol.light_energy = 1.1
	sol.light_color = Color(1.0, 0.96, 0.88)
	sol.shadow_enabled = false
	add_child(sol)
	var mesa_luz := OmniLight3D.new()
	mesa_luz.name = "LuzMesa"
	mesa_luz.position = Vector3(0, 5.5, 0.5)
	mesa_luz.light_color = Color(1.0, 0.9, 0.7)
	mesa_luz.light_energy = 0.7
	mesa_luz.omni_range = 14.0
	add_child(mesa_luz)
	var luz_rival := OmniLight3D.new()
	luz_rival.name = "LuzRival"
	luz_rival.position = Vector3(0, 3.0, -3.4)
	luz_rival.light_color = Color(0.55, 0.6, 1.0)
	luz_rival.light_energy = 0.5
	luz_rival.omni_range = 8.0
	add_child(luz_rival)
	var luz_voce := OmniLight3D.new()
	luz_voce.name = "LuzVoce"
	luz_voce.position = Vector3(0, 3.0, 3.4)
	luz_voce.light_color = Color(1.0, 0.8, 0.5)
	luz_voce.light_energy = 0.5
	luz_voce.omni_range = 8.0
	add_child(luz_voce)
	_flash = OmniLight3D.new()
	_flash.name = "FlashEfeito"
	_flash.position = Vector3(0, 2.0, 0)
	_flash.light_color = Color(1, 1, 1)
	_flash.light_energy = 0.0
	_flash.omni_range = 10.0
	add_child(_flash)
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.position = Vector3(0, 6.8, 8.2)
	_cam.fov = 55.0
	_cam.current = true
	add_child(_cam)
	_cam.look_at(Vector3(0, 0.4, 0.3))
	print("[MESA3D] Ambiente: WorldEnvironment + 1 direcional + 3 omni + flash + Camera3D.")


# ---- MESA (tampo + moldura + emblema + 20 marcas de slot + decks) ----

func _mat(cor: Color, emissao: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = 0.55
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


func _caixa(nome: String, tamanho: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var malha := BoxMesh.new()
	malha.size = tamanho
	mi.mesh = malha
	mi.position = pos
	mi.material_override = material
	return mi


func _construir_mesa() -> void:
	var mesa := Node3D.new()
	mesa.name = "Mesa"
	add_child(mesa)
	mesa.add_child(_caixa("Tampo", Vector3(7.6, 0.3, 6.4), Vector3(0, 0.0, 0), _mat(Color(0.03, 0.03, 0.08))))
	var ouro := _mat(Color(0.78, 0.64, 0.32), 0.25, 0.6)
	mesa.add_child(_caixa("MolduraN", Vector3(7.8, 0.34, 0.12), Vector3(0, 0.0, -3.26), ouro))
	mesa.add_child(_caixa("MolduraS", Vector3(7.8, 0.34, 0.12), Vector3(0, 0.0, 3.26), ouro))
	mesa.add_child(_caixa("MolduraL", Vector3(0.12, 0.34, 6.4), Vector3(-3.86, 0.0, 0), ouro))
	mesa.add_child(_caixa("MolduraO", Vector3(0.12, 0.34, 6.4), Vector3(3.86, 0.0, 0), ouro))
	var emb := MeshInstance3D.new()
	emb.name = "Emblema"
	var toro := TorusMesh.new()
	toro.inner_radius = 0.28
	toro.outer_radius = 0.38
	emb.mesh = toro
	emb.position = Vector3(0, 0.18, 0)
	emb.rotation_degrees = Vector3(90, 0, 0)
	emb.material_override = ouro
	mesa.add_child(emb)
	_no_slots = Node3D.new()
	_no_slots.name = "Slots"
	mesa.add_child(_no_slots)
	# 20 marcas de slot (5+5 por lado, espelho do 2D via BoardLayout real).
	for lado in [0, 1]:
		for i in range(5):
			_no_slots.add_child(_marca_slot(lado, "monstro", i))
			_no_slots.add_child(_marca_slot(lado, "magia", i))
	var decks := Node3D.new()
	decks.name = "Decks"
	mesa.add_child(decks)
	decks.add_child(_caixa("DeckRival", Vector3(1.0, 0.35, 1.43), Vector3(3.3, TOPO + 0.17, -2.2), _mat(Color(0.16, 0.12, 0.26))))
	decks.add_child(_caixa("DeckVoce", Vector3(1.0, 0.35, 1.43), Vector3(3.3, TOPO + 0.17, 1.6), _mat(Color(0.20, 0.16, 0.05))))
	_no_cartas = Node3D.new()
	_no_cartas.name = "Cartas"
	add_child(_no_cartas)
	_cursor3d = _caixa("Cursor3D", Vector3(1.18, 0.06, 1.62), Vector3(0, TOPO, 3.8), _mat(Color(1.0, 0.9, 0.4), 1.6))
	add_child(_cursor3d)
	print("[MESA3D] Mesa: tampo + moldura + emblema + 20 marcas + 2 decks + Cursor3D.")


func _cor_slot(lado: int, tipo: String) -> Color:
	if lado == 1 and tipo == "monstro":
		return Color(0.66, 0.56, 0.96)
	if lado == 1:
		return Color(0.96, 0.56, 0.30)
	if lado == 0 and tipo == "monstro":
		return Color(0.96, 0.80, 0.40)
	return Color(0.36, 0.95, 0.90)


func _marca_slot(lado: int, tipo: String, indice: int) -> MeshInstance3D:
	var p := _pos_slot(lado, tipo, indice)
	var marca := _caixa("Marca_p%d_%s%d" % [lado, ("m" if tipo == "monstro" else "s"), indice],
		Vector3(1.06, 0.04, 1.5), Vector3(p.x, 0.17, p.z), _mat(_cor_slot(lado, tipo), 0.35))
	return marca


func _pos_slot(lado: int, tipo: String, indice: int) -> Vector3:
	# Lê o XY do 2D (BoardLayout real, com espelho do rival) e converte p/ XZ.
	var sid := BoardLayoutScript.slot_id(lado, tipo, indice)
	var p2 := BoardLayoutScript.default_pos(sid)
	return Vector3((p2.x - CENTRO_X) / DIV, TOPO, (p2.y - CENTRO_Y) / DIV)


# ---- CARTA 3D (caixa fina + frente com arte/nome/ATK + verso) ----

func _cor_atributo(attr: String) -> Color:
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
	return Color(0.50, 0.50, 0.60)


func _textura_arte(carta: Dictionary) -> Texture2D:
	# Tenta a arte REAL do projeto (caminho do dado, relativo à base).
	# Inexistente (dívida conhecida: FM sem assets) = volta nulo e usa cor.
	var arq := str(carta.get("artwork", ""))
	if arq.is_empty():
		return null
	var tentativas: Array = []
	if not _base_dir.is_empty():
		tentativas.append(_base_dir.path_join(arq))
	tentativas.append(ProjectSettings.globalize_path("res://").path_join(arq))
	tentativas.append(ProjectSettings.globalize_path("res://").path_join("../schemas/examples").path_join(arq))
	for t in tentativas:
		if FileAccess.file_exists(str(t)):
			var img := Image.load_from_file(str(t))
			if img != null:
				_artes_ok += 1
				return ImageTexture.create_from_image(img)
	return null


func _rotulo3d(texto: String, tamanho: int, cor: Color) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tamanho
	l.pixel_size = 0.0038
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate = cor
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.9)
	# Sem mouse_filter aqui de propósito: Label3D é 3D, não Control (D19
	# já vale — nada nesta cena recebe clique).
	return l


func _fazer_carta(dado: Dictionary, face_down: bool, lado: int, em_defesa: bool) -> Node3D:
	var no := Node3D.new()
	no.name = "Carta3D"
	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	var malha := BoxMesh.new()
	malha.size = Vector3(LARG_CARTA, ALT_CARTA, GROSS_CARTA)
	corpo.mesh = malha
	corpo.material_override = _mat(Color(0.10, 0.10, 0.16))
	no.add_child(corpo)
	# Frente: arte real (ou cor do atributo) + nome + ATK/DEF.
	var frente := MeshInstance3D.new()
	frente.name = "Frente"
	var qf := QuadMesh.new()
	qf.size = Vector2(LARG_CARTA - 0.08, ALT_CARTA - 0.08)
	frente.mesh = qf
	frente.position = Vector3(0, 0, GROSS_CARTA / 2.0 + 0.002)
	var mat_f := StandardMaterial3D.new()
	var tex := _textura_arte(dado)
	if tex != null:
		mat_f.albedo_texture = tex
	else:
		mat_f.albedo_color = _cor_atributo(str(dado.get("attribute", ""))).darkened(0.25)
	mat_f.roughness = 0.4
	frente.material_override = mat_f
	no.add_child(frente)
	var faixa := MeshInstance3D.new()
	faixa.name = "FaixaNome"
	var qx := QuadMesh.new()
	qx.size = Vector2(LARG_CARTA - 0.08, 0.30)
	faixa.mesh = qx
	faixa.position = Vector3(0, ALT_CARTA / 2.0 - 0.24, GROSS_CARTA / 2.0 + 0.004)
	faixa.material_override = _mat(Color(0.05, 0.05, 0.10))
	no.add_child(faixa)
	var nome := _rotulo3d(str(dado.get("name", "?")), 42, Color(1, 0.95, 0.8))
	nome.name = "Nome"
	nome.position = Vector3(0, ALT_CARTA / 2.0 - 0.24, GROSS_CARTA / 2.0 + 0.01)
	no.add_child(nome)
	var stats := _rotulo3d("A%d/D%d" % [int(dado.get("attack", 0)), int(dado.get("defense", 0))], 44, Color(1, 1, 1))
	stats.name = "Stats"
	stats.position = Vector3(0, -ALT_CARTA / 2.0 + 0.22, GROSS_CARTA / 2.0 + 0.01)
	no.add_child(stats)
	# Verso: azul escuro + cruz clara (igual ao 2D).
	var verso := MeshInstance3D.new()
	verso.name = "Verso"
	var qv := QuadMesh.new()
	qv.size = Vector2(LARG_CARTA - 0.08, ALT_CARTA - 0.08)
	verso.mesh = qv
	verso.position = Vector3(0, 0, -GROSS_CARTA / 2.0 - 0.002)
	verso.rotation_degrees = Vector3(0, 180, 0)
	verso.material_override = _mat(Color(0.14, 0.10, 0.24), 0.3)
	no.add_child(verso)
	var cruz := _rotulo3d("+", 220, Color(0.88, 0.82, 1.0))
	cruz.name = "Cruz"
	cruz.position = Vector3(0, 0, -GROSS_CARTA / 2.0 - 0.01)
	cruz.rotation_degrees = Vector3(0, 180, 0)
	no.add_child(cruz)
	# Posição: DEF deita (gira Y 90°); virada mostra o verso (gira Y 180°).
	var giro_y := 0.0
	if em_defesa:
		giro_y += PI / 2.0
	if face_down:
		giro_y += PI
	no.rotation.y = giro_y
	# Rival de cabeça p/ baixo (homenagem ao 2D) só no ATK aberto — eixos
	# combinados em DEF ficam estranhos, então DEF do rival fica normal.
	if lado == 1 and not face_down and not em_defesa:
		no.rotation.z = PI
	return no


func _fantasia(inst: Dictionary) -> Dictionary:
	# O motor guarda instância enxuta; a roupa vem do dado real (igual ao 2D).
	var cid := str(inst.get("card_id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return _cartas[cid] as Dictionary
	return {"name": str(inst.get("nome", cid)), "monster_type": "beast",
		"attribute": "earth", "attack": int(inst.get("atk", 0)), "defense": int(inst.get("def", 0))}


# ---- DESENHO A PARTIR DO ESTADO REAL (só leitura, sem regra) ----

func _pos_mao_arco(i: int, n: int, lado: int) -> Vector3:
	var t := float(i) - float(maxi(n - 1, 0)) / 2.0
	if lado == 0:
		return Vector3(t * 1.05, 1.35 + (0.10 * absf(t)) + (0.35 if _fileira == FILEIRA_MAO and i == _col else 0.0), 3.9 + 0.10 * absf(t))
	return Vector3(t * 0.85, 1.35 + 0.08 * absf(t), -3.9 - 0.10 * absf(t))


func _limpar_cartas() -> void:
	for f in _no_cartas.get_children():
		(f as Node).queue_free()


func _redesenhar(com_efeito: bool) -> void:
	_limpar_cartas()
	if _st == null:
		return
	_artes_ok = 0
	# Campo: 5+5 monstros + magias (se houver, ex. test_state) por lado.
	for lado in [0, 1]:
		for zona_nome in ["monster", "spell"]:
			var zona: Array = (_st.players[lado] as Dictionary)[zona_nome]
			for i in range(zona.size()):
				if zona[i] == null:
					continue
				var m := zona[i] as Dictionary
				var tipo := "monstro" if zona_nome == "monster" else "magia"
				var carta := _fazer_carta(_fantasia(m), bool(m.get("face_down", false)), lado, str(m.get("position", "ATK")) == "DEF")
				carta.position = _pos_slot(lado, tipo, i) + Vector3(0, ALT_CARTA / 2.0 + 0.02, 0)
				carta.set_meta("slot_id", "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), i])
				carta.set_meta("card_id", str(m.get("card_id", "")))
				_no_cartas.add_child(carta)
	# Mãos em arco: p0 aberta, p1 de costas (só contagem, sem vazar dado).
	var mao0: Array = (_st.players[0] as Dictionary)["hand"]
	for i in range(mao0.size()):
		var c := _fazer_carta(mao0[i] as Dictionary, false, 0, false)
		c.position = _pos_mao_arco(i, mao0.size(), 0)
		c.rotation_degrees.x = -12.0
		c.set_meta("mao_idx", i)
		_no_cartas.add_child(c)
		if com_efeito and not _sem_render():
			var alvo: Vector3 = c.position
			c.position = _deck_pos[0]
			var tw := c.create_tween().set_parallel(true)
			tw.tween_property(c, "position", alvo, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var mao1: Array = (_st.players[1] as Dictionary)["hand"]
	for j in range(mao1.size()):
		var v := _fazer_carta({}, true, 1, false)
		v.position = _pos_mao_arco(j, mao1.size(), 1)
		v.rotation_degrees.x = 12.0
		_no_cartas.add_child(v)
	_atualizar_hud()
	_posicionar_cursor()


func _posicionar_cursor() -> void:
	if _cursor3d == null or _st == null:
		return
	var alvo := Vector3(0, TOPO, 3.9)
	match _fileira:
		FILEIRA_MAO:
			var n: int = ((_st.players[0] as Dictionary)["hand"] as Array).size()
			if n > 0:
				alvo = _pos_mao_arco(clampi(_col, 0, n - 1), n, 0) + Vector3(0, -ALT_CARTA / 2.0 - 0.05, 0)
		FILEIRA_MEU_M:
			alvo = _pos_slot(0, "monstro", clampi(_col, 0, 4)) + Vector3(0, -0.12, 0)
		FILEIRA_MEU_S:
			alvo = _pos_slot(0, "magia", clampi(_col, 0, 4)) + Vector3(0, -0.12, 0)
		FILEIRA_RIVAL_M:
			alvo = _pos_slot(1, "monstro", clampi(_col, 0, 4)) + Vector3(0, -0.12, 0)
		FILEIRA_RIVAL_S:
			alvo = _pos_slot(1, "magia", clampi(_col, 0, 4)) + Vector3(0, -0.12, 0)
	_foco = alvo
	_cursor3d.position = alvo


# ---- HUD (só mostra: LP, fase, turno, log, dica) ----

func _rotulo_hud(nome: String, texto: String, pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _construir_hud() -> void:
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_lbl_lp_rival = _rotulo_hud("LpRival", "RIVAL", Vector2(40, 24), 34, Color(0.75, 0.7, 1.0))
	hud.add_child(_lbl_lp_rival)
	_lbl_mao_rival = _rotulo_hud("MaoRival", "", Vector2(40, 68), 24, Color(0.7, 0.7, 0.8))
	hud.add_child(_lbl_mao_rival)
	_lbl_fase = _rotulo_hud("Fase", "", Vector2(40, 110), 28, Color(1, 1, 1))
	hud.add_child(_lbl_fase)
	_lbl_log = _rotulo_hud("Log", "", Vector2(40, 160), 22, Color(0.85, 0.85, 0.9))
	_lbl_log.size = Vector2(620, 160)
	_lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(_lbl_log)
	_lbl_lp_voce = _rotulo_hud("LpVoce", "VOCÊ", Vector2(40, 880), 40, Color(0.95, 0.85, 0.55))
	hud.add_child(_lbl_lp_voce)
	_lbl_dica = _rotulo_hud("Dica", "", Vector2(40, 990), 24, Color(1.0, 0.9, 0.4))
	_lbl_dica.size = Vector2(1840, 80)
	hud.add_child(_lbl_dica)


func _fala(texto: String) -> void:
	_log.append(texto)
	while _log.size() > 4:
		_log.pop_front()
	if _lbl_log != null:
		_lbl_log.text = "\n".join(_log)
	print("[MESA3D] " + texto)


func _atualizar_hud() -> void:
	if _st == null or _lbl_lp_voce == null:
		return
	_lbl_lp_rival.text = "RIVAL — LP %d" % int((_st.players[1] as Dictionary)["lp"])
	_lbl_mao_rival.text = "Mão do rival: %d cartas" % (((_st.players[1] as Dictionary)["hand"] as Array).size())
	_lbl_lp_voce.text = "VOCÊ — LP %d" % int((_st.players[0] as Dictionary)["lp"])
	var vez := "Sua vez" if int(_st.current_player) == 0 else "Vez do rival"
	_lbl_fase.text = "Turno %d — %s — %s" % [int(_st.turn_number), String(_st.phase), vez]
	_lbl_dica.text = "Mão/MEU/RIVAL: direcional • Confirmar: invocar/atacar • L1/R1: ATK/DEF • START: passar turno • X: detalhes"
	if bool(_st.over):
		_lbl_fase.text += (" — VITÓRIA!" if int(_st.winner) == 0 else " — DERROTA")


# ---- EFEITOS VISUAIS (só visual: flash + solavanco + voo) ----

func _flash_efeito() -> void:
	print("[SOM] flash 3D.")
	if _sem_render() or _flash == null:
		return
	_flash.light_energy = 3.0
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "light_energy", 0.0, 0.4)


func _sacudir(no: Node3D) -> void:
	if _sem_render() or no == null or not is_instance_valid(no):
		return
	var x0: float = no.position.x
	var tw := no.create_tween()
	tw.tween_property(no, "position:x", x0 - 0.25, 0.07)
	tw.tween_property(no, "position:x", x0 + 0.25, 0.07)
	tw.tween_property(no, "position:x", x0, 0.08)


func _achar_carta_campo(lado: int, zona_nome: String, slot: int) -> Node3D:
	var sid := "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), slot]
	for f in _no_cartas.get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == sid:
			return f as Node3D
	return null


# ---- JOGADAS (só chamam os sistemas reais e redesenham) ----

func _invocar3d() -> void:
	if int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_fala("Invocação só na sua MAIN.")
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	var idx := clampi(_col, 0, maxi(int(mao.size()) - 1, 0))
	if idx < 0 or idx >= mao.size():
		return
	if str((mao[idx] as Dictionary).get("card_type", "")) != "monster":
		_fala("Só monstro pode ser invocado.")
		return
	var slot := SummonSystem.free_monster_slot(_st, 0)
	if slot < 0:
		_fala("Sem slot livre no seu campo.")
		return
	var r: Dictionary = SummonSystem.normal_summon(_st, 0, idx, slot, false, "ATK")
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		return
	_fala("Invocou em Ataque no slot %d!" % slot)
	_redesenhar(true)
	_flash_efeito()
	_duel.advance_phase() # MAIN -> BATTLE (igual ao 2D após descer).
	_fileira = FILEIRA_MEU_M
	_col = clampi(slot, 0, 4)
	_redesenhar(false)


func _atacar3d(alvo_slot: int) -> void:
	var r: Dictionary = BattleSystem.attack(_st, 0, _sel_atk, 1, alvo_slot)
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		_sel_atk = -1
		_redesenhar(false)
		return
	# Voo de ataque (só visual): avança e volta.
	var no_atk := _achar_carta_campo(0, "monster", _sel_atk)
	if no_atk != null and not _sem_render():
		var p0: Vector3 = no_atk.position
		var tw := no_atk.create_tween()
		tw.tween_property(no_atk, "position", p0 + Vector3(0, 0.4, -1.2), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(no_atk, "position", p0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
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
	_flash_efeito()
	_sel_atk = -1
	_redesenhar(false)


func _rival_auto() -> void:
	# Rival automático simples (padrão do main.gd: invoca + ataca com o
	# núcleo real). A escolha fina da IA mora no 2D; aqui é só p/ testar.
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or bool(_st.over):
		_redesenhar(false)
		return
	_duel.advance_phase() # -> MAIN do rival
	var mao: Array = (_st.players[1] as Dictionary)["hand"]
	var idx := -1
	for i in range(mao.size()):
		if str((mao[i] as Dictionary).get("card_type", "")) == "monster":
			idx = i
			break
	var slot := SummonSystem.free_monster_slot(_st, 1)
	if idx >= 0 and slot >= 0:
		var r: Dictionary = SummonSystem.normal_summon(_st, 1, idx, slot, false, "ATK")
		if bool(r.get("ok", false)):
			_fala("Rival invocou em Ataque.")
	_redesenhar(true)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree() or bool(_st.over):
		_redesenhar(false)
		return
	_duel.advance_phase() # MAIN -> BATTLE
	var zona: Array = (_st.players[1] as Dictionary)["monster"]
	for s in range(zona.size()):
		if bool(_st.over):
			break
		if zona[s] == null:
			continue
		var alvo: int = BattleSystem.first_monster_slot(_st, 0)
		var ra: Dictionary = BattleSystem.attack(_st, 1, s, 0, alvo)
		if not bool(ra.get("ok", false)):
			continue
		if bool(ra.get("direto", false)):
			_fala("Rival direto: %d em você!" % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_alvo", false)):
			_fala("Rival destruiu seu monstro (%d de dano)." % int(ra.get("dano", 0)))
		elif bool(ra.get("destruiu_atacante", false)):
			_fala("Rival quebrou a cara no seu monstro!")
		else:
			_fala("Rival atacou: nada acontece.")
		_redesenhar(false)
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
	if bool(_st.over):
		_redesenhar(false)
		return
	_duel.advance_phase() # BATTLE -> END
	_duel.advance_phase() # END -> sua DRAW (refill até 5, regra real)
	_duel.advance_phase() # DRAW -> sua MAIN
	_fala("Seu turno. Mão com %d cartas." % (((_st.players[0] as Dictionary)["hand"] as Array).size()))
	_sel_atk = -1
	_fileira = FILEIRA_MAO
	_col = 0
	_redesenhar(true)


func _passar_turno() -> void:
	if int(_st.current_player) != 0 or bool(_st.over):
		return
	if String(_st.phase) == "DRAW":
		_fala("Aguarde a fase passar.")
		return
	_sel_atk = -1
	var dono := int(_st.current_player)
	var guarda := 0
	while int(_st.current_player) == dono and not bool(_st.over) and guarda < 8:
		_duel.advance_phase()
		guarda += 1
	if bool(_st.over):
		_redesenhar(false)
		return
	_fala("Turno do rival... (START)")
	_redesenhar(false)
	_rival_auto()


# ---- CONTROLE (D19: só as 11 ações joypad) ----

func _larg_fileira(f: int) -> int:
	match f:
		FILEIRA_MAO:
			if _st == null:
				return 1
			return maxi((((_st.players[0] as Dictionary)["hand"]) as Array).size(), 1)
		FILEIRA_MEU_M, FILEIRA_MEU_S, FILEIRA_RIVAL_M, FILEIRA_RIVAL_S:
			return 5
	return 1


func _mover(dx: int, dy: int) -> void:
	if _st == null or bool(_st.over):
		return
	if dx != 0:
		_col = posmod(_col + dx, _larg_fileira(_fileira))
		_posicionar_cursor()
		return
	if dy != 0:
		var idx := ORDEM_FILEIRAS.find(_fileira)
		if idx < 0:
			idx = 0
		var novo := clampi(idx + dy, 0, ORDEM_FILEIRAS.size() - 1)
		if novo != idx:
			_fileira = int(ORDEM_FILEIRAS[novo])
			_col = clampi(_col, 0, _larg_fileira(_fileira) - 1)
			_posicionar_cursor()


func _confirmar() -> void:
	if _st == null:
		return
	if bool(_st.over):
		get_tree().reload_current_scene()
		return
	if int(_st.current_player) != 0:
		_fala("Aguarde o rival.")
		return
	match _fileira:
		FILEIRA_MAO:
			_invocar3d()
		FILEIRA_MEU_M:
			if String(_st.phase) != "BATTLE":
				_fala("Ataque só na sua BATTLE.")
				return
			var slot := clampi(_col, 0, 4)
			var zona: Array = (_st.players[0] as Dictionary)["monster"]
			if slot < 0 or slot >= zona.size() or zona[slot] == null:
				_fala("Slot vazio, sem atacante.")
				return
			var pode: Dictionary = BattleSystem.can_attack(_st, 0, slot)
			if not bool(pode.get("ok", false)):
				_fala("Não pode atacar: " + str(pode.get("erro", "")))
				return
			_sel_atk = slot
			_fala("Atacante escolhido. Mire no campo rival.")
			_fileira = FILEIRA_RIVAL_M
			_posicionar_cursor()
		FILEIRA_MEU_S:
			_fala("Magia: sem ação na mesa (só navega).")
		FILEIRA_RIVAL_M:
			if _sel_atk < 0:
				_fala("Escolha seu atacante primeiro (seu campo).")
				return
			if not BattleSystem.has_monsters(_st, 1):
				_fala("Rival sem monstros: direto!")
				_atacar3d(-1)
				return
			var alvo := clampi(_col, 0, 4)
			var zr: Array = (_st.players[1] as Dictionary)["monster"]
			if alvo < 0 or alvo >= zr.size() or zr[alvo] == null:
				_fala("Escolha um monstro rival (slot vazio).")
				return
			_atacar3d(alvo)
		FILEIRA_RIVAL_S:
			_fala("Magia não é alvo: mire num monstro rival.")


func _cancelar() -> void:
	if _st == null:
		return
	if _sel_atk >= 0:
		_sel_atk = -1
		_fala("Ataque desfeito.")
		_redesenhar(false)


func _alternar_posicao() -> void:
	if _st == null or bool(_st.over) or int(_st.current_player) != 0:
		return
	if _fileira != FILEIRA_MEU_M:
		_fala("Mire numa carta sua p/ trocar Ataque/Defesa.")
		return
	var r: Dictionary = PositionSystem.toggle_position(_st, 0, clampi(_col, 0, 4))
	if not bool(r.get("ok", false)):
		_fala("Não deu: " + str(r.get("erro", "")))
		return
	_fala("Agora em %s." % ("Ataque" if str(r.get("position", "ATK")) == "ATK" else "Defesa"))
	_redesenhar(false)


func _detalhes() -> void:
	if _st == null:
		return
	var txt := "Detalhes: "
	if _fileira == FILEIRA_MAO:
		var mao: Array = (_st.players[0] as Dictionary)["hand"]
		var i := clampi(_col, 0, maxi(int(mao.size()) - 1, 0))
		if i >= 0 and i < mao.size():
			var c := mao[i] as Dictionary
			txt += "%s A%d/D%d" % [str(c.get("name", "?")), int(c.get("attack", 0)), int(c.get("defense", 0))]
	else:
		txt += "slot %d fileira %d" % [_col, _fileira]
	_fala(txt)


func _process(delta: float) -> void:
	# Órbita suave da câmera (deriva lenta + segue o cursor de leve).
	_orb_t += delta * 0.12
	_pulso += delta * 4.0
	if _cam != null:
		_cam.position = Vector3(sin(_orb_t) * 1.4, 6.8 + sin(_orb_t * 0.7) * 0.3, 8.2)
		_cam.look_at(Vector3(_foco.x * 0.25, 0.4, _foco.z * 0.25 + 0.3))
	if _cursor3d != null:
		var s := 1.0 + 0.04 * sin(_pulso)
		_cursor3d.scale = Vector3(s, 1.0, s)
	if _st == null:
		return
	# Repetição do direcional (igual ao 2D).
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
		_pad_dir = Vector2i.ZERO
		_pad_tempo = 0.0
		return
	if desejado != _pad_dir:
		_pad_dir = desejado
		_pad_tempo = 0.0
		_mover(desejado.x, desejado.y)
		return
	_pad_tempo += delta
	if _pad_tempo >= PAD_REPETE:
		_pad_tempo = 0.0
		_mover(desejado.x, desejado.y)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("confirmar"):
		_confirmar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("cancelar"):
		_cancelar()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("sair_duelo"):
		print("[MESA3D] sair_duelo sem tela de desistência (não existe).")
		_fala("Sair do duelo: sem tela de desistência (não existe).")
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("pausar"):
		_passar_turno()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("posicao_l1") or evento.is_action_pressed("posicao_r1"):
		_alternar_posicao()
		get_viewport().set_input_as_handled()
		return
	if evento.is_action_pressed("detalhes"):
		_detalhes()
		get_viewport().set_input_as_handled()
		return
