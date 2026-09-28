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
const FusionSystem := preload("res://duel/fusion_system.gd")
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
## Ordem visual de cima p/ baixo só com os 20 slots (igual ao 2D):
## magia rival -> monstro rival -> meu monstro -> minha magia.
const ORDEM_CAMPO_3D := [4, 3, 1, 2]
const PAD_REPETE := 0.25

## Fluxo fiel do turno (só controle de tela, regra nos sistemas reais).
## Espelha o 2D (duel_table FASE_MAO/SUB_*): carta ao centro -> face ->
## slot (vazio OU ocupado) -> menu da estrela -> desce em Ataque.
## Fusão: 2+ levantadas -> slot PRIMEIRO -> fila -> FINAL + estrela.
const FASE_MAO := 0
const FASE_CAMPO := 1
const SUB_MAO_ESCOLHA := 0
const SUB_FACE := 1
const SUB_SLOT := 2
const SUB_ESTRELA := 3

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
var _lbl_slot: Label = null
var _lbl_fila: Label = null
var _log: Array = []
var _fusions_data: Dictionary = {"schema_version": 1, "recipes": [], "rules": []}
var _arena_data: Dictionary = {}
var _arena_layout: Dictionary = {}

## Estado do fluxo fiel (só controle, sem regra nova).
var _fase_jogador := FASE_MAO
var _sub_mao := SUB_MAO_ESCOLHA
var _mao_idx := -1
var _face_baixo := false
var _slot_alvo := -1
var _estrela_ops: Array = []
var _levantadas: Array = []
var _combinando := false
var _fusao_ordem: Array = []
var _fusao_final: Dictionary = {}
var _fusao_descartes: Array = []
var _fusao_passos: Array = []
var _fusao_animando := false
var _popup_modo := "estrela"
var _pad_popup_idx := 0
var _painel_centro: PanelContainer = null
var _lbl_centro: Label = null
var _popup: PanelContainer = null
var _popup_titulo: Label = null
var _popup_ops: Array = []

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
	_construir_menus()
	# Duelo REAL (mesma fonte do 2D): ProjectLoader + DuelManager.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	_base_dir = str(data.get("base_dir", ""))
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	# Arena REAL do projeto (igual ao 2D): desenho segue o layout, IDs intactos.
	var arena_id := str((data.get("duel_setup", {}) as Dictionary).get("arena_id", "arena_starter"))
	_arena_data = BoardLayoutScript.load_arena_data(BoardLayoutScript.project_arena_path(arena_id))
	_arena_layout = (_arena_data.get("slots", {}) as Dictionary)
	_fusions_data = _fusoes_do_data(data)
	_fala("Mesa 3D de teste: duelo real carregado.")
	_duel.advance_phase() # DRAW inicial -> MAIN (igual ao 2D, mão 5/5 sem extra).
	_fileira = FILEIRA_MAO
	_col = 0
	_sel_atk = -1
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_face_baixo = false
	_slot_alvo = -1
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
	# Lê o XY do 2D (BoardLayout real + layout da arena, com espelho do
	# rival) e converte p/ XZ. Marca E carta usam este ponto: a carta fica
	# EXATAMENTE na marca (mesmo XZ, só o Y muda).
	var sid := BoardLayoutScript.slot_id(lado, tipo, indice)
	var padrao := BoardLayoutScript.default_pos(sid)
	var p2 := BoardLayoutScript.get_pos(_arena_layout, sid, padrao)
	return Vector3((p2.x - CENTRO_X) / DIV, TOPO, (p2.y - CENTRO_Y) / DIV)


func _fusoes_do_data(data: Dictionary) -> Dictionary:
	# Só DADO, nunca regra (igual ao 2D): usa o que o DataLoader JÁ leu.
	var bruto = data.get("fusions", null)
	if not (bruto is Dictionary) or (bruto as Dictionary).is_empty():
		print("[MESA3D] Aviso: fusões não vieram no projeto (sem fusão).")
		return {"schema_version": 1, "recipes": [], "rules": []}
	var out: Dictionary = (bruto as Dictionary).duplicate()
	if not (out.get("recipes", []) is Array):
		out["recipes"] = []
	if not (out.get("rules", []) is Array):
		out["rules"] = []
	print("[MESA3D] Fusões carregadas: %d receitas + %d regras." % [(out["recipes"] as Array).size(), (out["rules"] as Array).size()])
	return out


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
	# Indicador ATK/DEF + face (só desenho, igual ao 2D que mostra a posição).
	var tag_txt := "VIRADA" if face_down else ("DEF" if em_defesa else "ATK")
	var tag_cor := Color(0.7, 0.7, 0.8) if face_down else (Color(0.5, 0.8, 1.0) if em_defesa else Color(1.0, 0.75, 0.35))
	var tag := _rotulo3d(tag_txt, 40, tag_cor)
	tag.name = "TagPos"
	tag.position = Vector3(0, ALT_CARTA / 2.0 + 0.14, 0)
	no.add_child(tag)
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
		# Levantada p/ fusão sobe + selo na etiqueta (igual ao 2D: selo 1-2-3).
		var selo := _levantadas.find(i) + 1
		if selo > 0:
			c.position += Vector3(0, 0.35, 0)
			(c.get_node("TagPos") as Label3D).text = "SELO %d" % selo
		if i == _mao_idx and _sub_mao != SUB_MAO_ESCOLHA:
			c.position += Vector3(0, 0.55, -0.4)
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
	_lbl_lp_voce = _rotulo_hud("LpVoce", "VOCÊ", Vector2(40, 860), 40, Color(0.95, 0.85, 0.55))
	hud.add_child(_lbl_lp_voce)
	_lbl_slot = _rotulo_hud("InfoSlot", "", Vector2(40, 918), 24, Color(0.85, 0.95, 1.0))
	_lbl_slot.size = Vector2(1840, 36)
	hud.add_child(_lbl_slot)
	_lbl_fila = _rotulo_hud("FilaFusao", "", Vector2(40, 952), 22, Color(1.0, 0.8, 0.6))
	_lbl_fila.size = Vector2(1840, 34)
	hud.add_child(_lbl_fila)
	_lbl_dica = _rotulo_hud("Dica", "", Vector2(40, 990), 24, Color(1.0, 0.9, 0.4))
	_lbl_dica.size = Vector2(1840, 80)
	hud.add_child(_lbl_dica)


## Menus 2D sobre a cena 3D (só desenho + controle, D19: tudo IGNORE, sem
## botão e sem clique). Menu da estrela (2 guardian stars do dado real) e
## menu de alvo (LP rival no direto), igual ao popup do 2D. A carta no
## centro mostra a escolha atual (nome + face + slot).
func _construir_menus() -> void:
	var camada := CanvasLayer.new()
	camada.name = "MenuLayer"
	add_child(camada)
	_painel_centro = PanelContainer.new()
	_painel_centro.name = "CentroCarta"
	var est_c := StyleBoxFlat.new()
	est_c.bg_color = Color(0.02, 0.02, 0.06, 0.92)
	est_c.border_color = Color(1.0, 0.9, 0.4)
	est_c.set_border_width_all(3)
	est_c.set_corner_radius_all(10)
	est_c.content_margin_left = 18
	est_c.content_margin_right = 18
	est_c.content_margin_top = 12
	est_c.content_margin_bottom = 12
	_painel_centro.add_theme_stylebox_override("panel", est_c)
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
	camada.add_child(_painel_centro)
	_popup = PanelContainer.new()
	_popup.name = "MenuEstrela"
	var est_p := StyleBoxFlat.new()
	est_p.bg_color = Color(0.03, 0.03, 0.08, 0.95)
	est_p.border_color = Color(1.0, 0.9, 0.4)
	est_p.set_border_width_all(3)
	est_p.set_corner_radius_all(10)
	est_p.content_margin_left = 18
	est_p.content_margin_right = 18
	est_p.content_margin_top = 12
	est_p.content_margin_bottom = 12
	_popup.add_theme_stylebox_override("panel", est_p)
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
	camada.add_child(_popup)
	_atualizar_menus()


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
	_lbl_slot.text = _texto_slot_foco()
	if _lbl_fila != null:
		_lbl_fila.text = _texto_fila()
	_lbl_dica.text = _texto_dica()
	if bool(_st.over):
		_lbl_fase.text += (" — VITÓRIA!" if int(_st.winner) == 0 else " — DERROTA")


## Indicador ATK/DEF + face do foco (só leitura, sem regra).
func _texto_slot_foco() -> String:
	if _st == null:
		return ""
	if _popup != null and _popup.visible:
		return "Menu aberto: cima/baixo escolhe, confirmar trava, cancelar volta."
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0 and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				return "Centro: %s (%s)." % [_nome_carta_mao(_mao_idx), ("face p/ baixo" if _face_baixo else "face p/ cima")]
			SUB_SLOT:
				if _combinando:
					return "Fusão: slot %d (%s)." % [clampi(_col, 0, 4), _resumo_slots()]
				return "Slot %d (%s)." % [clampi(_col, 0, 4), _resumo_slots()]
			SUB_ESTRELA:
				return "Estrela p/ o slot %d." % _slot_alvo
			_:
				var selos := ""
				if not _levantadas.is_empty():
					selos = " Levantadas: %s." % (", ".join(_levantadas.map(func(h): return str(int(h) + 1))))
				return "Mão %d/5.%s" % [(((_st.players[0] as Dictionary)["hand"]) as Array).size(), selos]
	match _fileira:
		FILEIRA_MEU_M:
			return _texto_inst_slot(0, "monster", clampi(_col, 0, 4))
		FILEIRA_MEU_S:
			return _texto_inst_slot(0, "spell", clampi(_col, 0, 4))
		FILEIRA_RIVAL_M:
			return _texto_inst_slot(1, "monster", clampi(_col, 0, 4))
		FILEIRA_RIVAL_S:
			return _texto_inst_slot(1, "spell", clampi(_col, 0, 4))
		_:
			return "Mão %d/5." % [(((_st.players[0] as Dictionary)["hand"]) as Array).size()]


func _texto_inst_slot(lado: int, zona_nome: String, slot: int) -> String:
	var zona: Array = (_st.players[lado] as Dictionary)[zona_nome]
	var sid := "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), slot]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "Slot %s: vazio." % sid
	var m := zona[slot] as Dictionary
	var face := "virada" if bool(m.get("face_down", false)) else "aberta"
	var pos := str(m.get("position", "ATK"))
	return "Slot %s: %s em %s %s." % [sid, _nome_no_slot_lado(lado, zona_nome, slot), pos, face]


func _texto_fila() -> String:
	if _fusao_animando and not _fusao_passos.is_empty():
		var partes: Array = []
		for p in _fusao_passos:
			if p is Dictionary:
				partes.append("%s+%s=%s" % [str((p as Dictionary).get("a", "?")), str((p as Dictionary).get("b", "?")), str((p as Dictionary).get("result_id", "?"))])
		if not partes.is_empty():
			return "Fusão: " + "  ".join(partes)
	if _combinando and not _fusao_ordem.is_empty():
		return "Fusão: %d levantadas, escolha o slot." % _fusao_ordem.size()
	if not _levantadas.is_empty():
		return "Levantadas p/ fusão: %d (selo %s)." % [_levantadas.size(), ", ".join(_levantadas.map(func(h): return str(int(h) + 1)))]
	return ""


func _texto_dica() -> String:
	if _popup != null and _popup.visible:
		return "Cima/baixo: opção • Confirmar: trava • Cancelar: volta"
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0 and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				return "Esq/dir: face p/ cima / p/ baixo • Confirmar: trava • Cancelar: desfaz"
			SUB_SLOT:
				return "Esq/dir: 1 dos 5 slots • Confirmar: abre a estrela • Cancelar: volta"
			SUB_ESTRELA:
				return "Cima/baixo: estrela • Confirmar: desce em Ataque • Cancelar: volta ao slot"
			_:
				return "Mão: confirmar escolhe • Cima levanta p/ fusão, baixo abaixa • L1/R1: ATK/DEF no campo • START: passar turno • X: detalhes"
	return "Mão/MEU/RIVAL: direcional • Confirmar: invocar/atacar • L1/R1: ATK/DEF • START: passar turno • X: detalhes"


## Nome curto da carta da mão (só leitura).
func _nome_carta_mao(idx: int) -> String:
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if idx < 0 or idx >= mao.size():
		return "?"
	var c := mao[idx] as Dictionary
	var cid := str(c.get("id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return str((_cartas[cid] as Dictionary).get("name", cid))
	return str(c.get("name", cid))


## Nome curto do que está no slot (mostra qual tem carta, sem regra nova).
func _nome_no_slot_lado(lado: int, zona_nome: String, slot: int) -> String:
	var zona: Array = (_st.players[lado] as Dictionary)[zona_nome]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "vazio"
	var m := zona[slot] as Dictionary
	var cid := str(m.get("card_id", ""))
	if not cid.is_empty() and _cartas.has(cid):
		return str((_cartas[cid] as Dictionary).get("name", cid))
	var nome := str(m.get("nome", cid))
	return nome if not nome.is_empty() else cid


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
			ocupados.append("%d:%s" % [i, _nome_no_slot_lado(0, "monster", i)])
	var txt := "vazios %s" % ("+".join(vazios) if not vazios.is_empty() else "nenhum")
	if not ocupados.is_empty():
		txt += " | ocupados %s" % (" ".join(ocupados))
	return txt


## Lê as 2 guardian stars do DADO (fm guardian_star_1/2). Sem inventar:
## se o dado não tem, usa "—" p/ não travar o fluxo (igual ao 2D).
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


## Instância do campo -> carta completa p/ fusão (igual ao 2D: junta o
## DADO real pelo card_id; sem DADO usa o básico da instância).
func _carta_completa_do_campo(inst: Dictionary) -> Dictionary:
	var cid := str(inst.get("card_id", ""))
	var base: Dictionary = {}
	if not cid.is_empty() and _cartas.has(cid):
		base = (_cartas[cid] as Dictionary).duplicate(true)
	else:
		base = {"id": cid, "name": str(inst.get("nome", cid)), "card_type": "monster",
			"monster_type": "beast", "attribute": "earth",
			"attack": int(inst.get("atk", 0)), "defense": int(inst.get("def", 0))}
	if str(base.get("id", "")).is_empty():
		base["id"] = cid
	return base


func _mostrar_centro3d(_carta: Dictionary, face_baixo: bool) -> void:
	if _painel_centro == null or _lbl_centro == null:
		return
	_lbl_centro.text = "Centro: %s (%s)" % [_nome_carta_mao(_mao_idx), ("face p/ baixo" if face_baixo else "face p/ cima")]
	_painel_centro.visible = true
	_atualizar_menus()


func _atualizar_centro_face() -> void:
	if _painel_centro == null or _lbl_centro == null:
		return
	_lbl_centro.text = "Centro: %s (%s)" % [_nome_carta_mao(_mao_idx), ("face p/ baixo" if _face_baixo else "face p/ cima")]
	_atualizar_menus()


func _esconder_centro3d() -> void:
	if _painel_centro != null:
		_painel_centro.visible = false


func _mostrar_popup_estrela() -> void:
	_popup_modo = "estrela"
	if _popup_titulo != null:
		_popup_titulo.text = "Escolha a estrela guardiã"
	_atualizar_menus()
	if _popup != null:
		_popup.visible = true


func _mostrar_popup_alvo() -> void:
	_popup_modo = "alvo"
	if _popup_titulo != null:
		_popup_titulo.text = "Alvo: rival sem monstros"
	_pad_popup_idx = 0
	_atualizar_menus()
	if _popup != null:
		_popup.visible = true


func _esconder_popup() -> void:
	if _popup != null:
		_popup.visible = false
	_popup_modo = "estrela"
	_pad_popup_idx = 0
	_atualizar_menus()


## Desenha as opções do menu ("> " marca a atual). Só desenho.
func _atualizar_menus() -> void:
	if _popup == null or _popup_ops.size() < 3:
		return
	if _popup_modo == "alvo":
		(_popup_ops[0] as Label).text = ("▶ " if _pad_popup_idx == 0 else "   ") + "Atacar LP rival (direto)"
		(_popup_ops[0] as Label).visible = true
		(_popup_ops[1] as Label).text = ("▶ " if _pad_popup_idx == 1 else "   ") + "Cancelar"
		(_popup_ops[1] as Label).visible = true
		(_popup_ops[2] as Label).visible = false
	else:
		var n_ops := clampi(_estrela_ops.size(), 0, 2)
		for i in range(3):
			var b := _popup_ops[i] as Label
			if i < n_ops:
				b.text = ("▶ " if _pad_popup_idx == i else "   ") + str(_estrela_ops[i])
				b.visible = true
			elif i == 2:
				b.text = ("▶ " if _pad_popup_idx == 2 else "   ") + "Cancelar"
				b.visible = true
			else:
				b.visible = false


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

func _limpar_levantadas() -> void:
	# Tira índices inválidos (mão encolheu após invocar/fundir/comprar).
	if _st == null:
		_levantadas = []
		return
	var n: int = (((_st.players[0] as Dictionary)["hand"]) as Array).size()
	var novas: Array = []
	for h in _levantadas:
		if h is int and int(h) >= 0 and int(h) < n and not novas.has(int(h)):
			novas.append(int(h))
	_levantadas = novas


## 1) Confirmar carta monstro -> ela vai ao CENTRO e para (igual ao 2D).
func _fluxo_escolher_carta() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "MAIN":
		_fala("Invocação só na sua MAIN.")
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _col < 0 or _col >= mao.size():
		return
	var carta = mao[_col] as Dictionary
	if str(carta.get("card_type", "")) != "monster":
		_fala("Só monstro pode ser invocado.")
		return
	_mao_idx = _col
	_sel_atk = -1
	_face_baixo = false
	_combinando = false
	_sub_mao = SUB_FACE
	_mostrar_centro3d(carta, false)
	_fala("Carta no centro. Esq/dir: face p/ cima / p/ baixo. Confirme.")
	_redesenhar(false)


## 2) Confirmar trava a face -> escolhe 1 dos 5 slots próprios.
func _fluxo_travar_face() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	_sub_mao = SUB_SLOT
	_combinando = false
	_slot_alvo = -1
	_fileira = FILEIRA_MEU_M
	var livre := SummonSystem.free_monster_slot(_st, 0)
	_col = clampi(livre, 0, 4) if livre >= 0 else 0
	_fala("Face travada (%s). Escolha 1 dos 5 slots (%s)." % [("p/ baixo" if _face_baixo else "p/ cima"), _resumo_slots()])
	_redesenhar(false)


## 3) 1 dos 5 slots próprios (vazio OU ocupado) -> menu da estrela.
func _fluxo_escolher_slot() -> void:
	if _mao_idx < 0:
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	var zona: Array = (_st.players[0] as Dictionary)["monster"]
	var slot := clampi(_col, 0, 4)
	if slot < 0 or slot >= zona.size():
		return
	_slot_alvo = slot
	_combinando = false
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if _mao_idx < 0 or _mao_idx >= mao.size():
		_fala("Carta saiu da mão.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_esconder_centro3d()
		_redesenhar(false)
		return
	_estrela_ops = _estrelas_da_carta(mao[_mao_idx] as Dictionary)
	_pad_popup_idx = 0
	_sub_mao = SUB_ESTRELA
	_mostrar_popup_estrela()
	if zona[slot] != null:
		_fala("Slot %d ocupado por %s: vai tentar fusão. Escolha a estrela." % [slot, _nome_no_slot_lado(0, "monster", slot)])
	else:
		_fala("Escolha 1 das 2 guardian stars.")
	_redesenhar(false)


## 4) Menu da estrela: 1 das 2 guardian stars -> desce em Ataque.
func _confirmar_estrela() -> void:
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	if _sub_mao != SUB_ESTRELA or _slot_alvo < 0:
		_esconder_popup()
		return
	if _combinando and _fusao_final.is_empty():
		_esconder_popup()
		return
	if not _combinando and _mao_idx < 0:
		_esconder_popup()
		return
	if _pad_popup_idx == 2:
		_esconder_popup()
		_sub_mao = SUB_SLOT
		_fileira = FILEIRA_MEU_M
		_col = clampi(_slot_alvo, 0, 4)
		_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
		_redesenhar(false)
		return
	var estrela := str(_estrela_ops[clampi(_pad_popup_idx, 0, 1)])
	if _combinando:
		_executar_fusao_fiel(estrela)
	else:
		_executar_summon_fiel(estrela)


## 5) Carta vai ao slot COM a face, SEMPRE em Ataque. Slot OCUPADO =
## encontro (try_fuse_pair real; falhou -> campo descartado e a da mão desce).
func _executar_summon_fiel(estrela: String) -> void:
	_esconder_popup()
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
		_slot_alvo = -1
		_esconder_centro3d()
		_fileira = FILEIRA_MAO
		_col = 0
		_redesenhar(false)
		return
	if slot_n < 0 or slot_n >= zona.size():
		_fala("Slot inválido.")
		return
	var carta_mao := (mao[hand_idx] as Dictionary).duplicate(true)
	if zona[slot_n] == null:
		var r: Dictionary = SummonSystem.normal_summon(_st, 0, hand_idx, slot_n, face, "ATK", estrela)
		if not bool(r.get("ok", false)):
			_fala("Não deu: " + str(r.get("erro", "")))
			_sub_mao = SUB_MAO_ESCOLHA
			_mao_idx = -1
			_slot_alvo = -1
			_esconder_centro3d()
			_fileira = FILEIRA_MAO
			_col = 0
			_redesenhar(false)
			return
		_fala("Invocou %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
		_terminar_jogada_mao(slot_n)
		return
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 invocação normal por turno.")
		_sub_mao = SUB_MAO_ESCOLHA
		_mao_idx = -1
		_slot_alvo = -1
		_esconder_centro3d()
		_fileira = FILEIRA_MAO
		_col = 0
		_redesenhar(false)
		return
	var ocupante := zona[slot_n] as Dictionary
	var nome_campo := _nome_no_slot_lado(0, "monster", slot_n)
	var campo_full := _carta_completa_do_campo(ocupante)
	var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, carta_mao, _fusions_data, _cartas)
	if bool(tent.get("ok", false)):
		var rid := str(tent.get("result_id", ""))
		var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
		var real: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
		if str(real.get("card_type", dado.get("card_type", "monster"))) == "monster":
			mao.remove_at(hand_idx)
			zona[slot_n] = SummonSystem.construir_instancia(dado, face, "ATK", estrela, real, rid)
			_st.normal_summon_used = true
			_fala("Fusão com campo! %s + %s = %s." % [nome_campo, str(carta_mao.get("id", "?")), rid])
			_fala("Desceu %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
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
		_fala("Desceu %s em Ataque (estrela %s)!" % [("virada p/ baixo" if face else "p/ cima"), estrela])
		print("[SOM] encontro falhou, campo descartado no slot %d." % slot_n)
	_terminar_jogada_mao(slot_n)


func _terminar_jogada_mao(slot_n: int) -> void:
	_esconder_centro3d()
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_estrela_ops = []
	_levantadas = []
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase() # MAIN -> BATTLE (igual ao 2D após descer).
	_fase_jogador = FASE_CAMPO
	_sel_atk = -1
	_fileira = FILEIRA_MEU_M
	_col = clampi(slot_n, 0, 4)
	_redesenhar(true)
	_flash_efeito()


## FUSÃO (2+ levantadas): escolhe o SLOT primeiro, depois fila + estrela.
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
	_sub_mao = SUB_SLOT
	_slot_alvo = -1
	_fileira = FILEIRA_MEU_M
	_col = 0
	_fala("Fusão: escolha 1 dos 5 slots (%s)." % _resumo_slots())
	_redesenhar(false)


func _fluxo_escolher_slot_fusao() -> void:
	if not _combinando:
		_fluxo_escolher_slot()
		return
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	_limpar_levantadas()
	var ordem: Array = _fusao_ordem.duplicate() if not _fusao_ordem.is_empty() else _levantadas.duplicate()
	if ordem.size() < 2:
		_fala("Fusão precisa de 2+ levantadas.")
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_combinando = false
		_fusao_animando = false
		_redesenhar(false)
		return
	var slot := clampi(_col, 0, 4)
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
		_redesenhar(false)
		return
	var previa: Dictionary = FusionSystem.resolve_chain(em_ordem, _fusions_data, _cartas)
	if not bool(previa.get("ok", false)):
		_fala("Não deu: " + str(previa.get("erro", "Fusão falhou.")))
		_combinando = false
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_redesenhar(false)
		return
	_fusao_animando = true
	await _animar_fila_fusao(em_ordem, previa.get("passos", []) as Array, ordem)
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		_fusao_animando = false
		_combinando = false
		_redesenhar(false)
		return
	var final_card: Dictionary = (previa.get("final_card", {}) as Dictionary).duplicate(true)
	var final_id := str(previa.get("final_id", ""))
	var real: Dictionary = (_cartas.get(final_id, {}) as Dictionary) if _cartas.has(final_id) else final_card
	if str(real.get("card_type", final_card.get("card_type", "monster"))) != "monster":
		_fusao_animando = false
		_combinando = false
		_slot_alvo = -1
		_fala("Equip ainda sem tabela: resultado %s não desce (pendente)." % final_id)
		_fileira = FILEIRA_MAO
		_col = 0
		_sub_mao = SUB_MAO_ESCOLHA
		_redesenhar(false)
		return
	_fusao_final = final_card
	if str(_fusao_final.get("id", "")).is_empty():
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
		_fala("FINAL %s no slot %d ocupado por %s: escolha a estrela." % [final_id, slot, _nome_no_slot_lado(0, "monster", slot)])
	else:
		_fala("FINAL %s: escolha 1 das 2 guardian stars." % final_id)
	_redesenhar(false)


## FINAL desce ao slot face-up em Ataque (com a estrela do menu).
func _executar_fusao_fiel(estrela: String) -> void:
	_esconder_popup()
	if not _combinando or _fusao_final.is_empty() or _slot_alvo < 0:
		return
	if bool(_st.over) or int(_st.current_player) != 0 or String(_st.phase) != "MAIN":
		return
	if bool(_st.normal_summon_used):
		_fala("Não deu: Só 1 jogada por turno.")
		_combinando = false
		_fusao_final = {}
		_sub_mao = SUB_MAO_ESCOLHA
		_slot_alvo = -1
		_redesenhar(false)
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
			_redesenhar(false)
			return
	var final_id := str(_fusao_final.get("id", ""))
	if final_id.is_empty():
		final_id = str(_fusao_final.get("card_id", "?"))
	var final_carta := _fusao_final.duplicate(true)
	final_carta["id"] = final_id
	var para_tirar: Array = ordem.duplicate()
	para_tirar.sort()
	para_tirar.reverse()
	for h in para_tirar:
		mao.remove_at(int(h))
	for d in _fusao_descartes:
		(p["graveyard"] as Array).append(str(d))
	var descer_id := final_id
	var descer_carta := final_carta.duplicate(true)
	if zona[slot_n] != null:
		var nome_campo := _nome_no_slot_lado(0, "monster", slot_n)
		var campo_full := _carta_completa_do_campo(zona[slot_n] as Dictionary)
		var tent: Dictionary = FusionSystem.try_fuse_pair(campo_full, final_carta, _fusions_data, _cartas)
		if bool(tent.get("ok", false)):
			var rid := str(tent.get("result_id", ""))
			var dado: Dictionary = (tent.get("result_card", {}) as Dictionary).duplicate(true) if (tent.get("result_card", {}) is Dictionary) else {}
			var real2: Dictionary = (_cartas.get(rid, {}) as Dictionary) if _cartas.has(rid) else dado
			if str(real2.get("card_type", dado.get("card_type", "monster"))) == "monster":
				descer_id = rid
				descer_carta = dado.duplicate(true) if not dado.is_empty() else real2.duplicate(true)
				descer_carta["id"] = rid
				_fala("Fusão com campo! %s + %s = %s." % [nome_campo, final_id, rid])
			else:
				(p["graveyard"] as Array).append(str((zona[slot_n] as Dictionary).get("card_id", "")))
				_fala("Resultado %s não é monstro: %s descartado, a FINAL desce." % [rid, nome_campo])
		else:
			(p["graveyard"] as Array).append(str((zona[slot_n] as Dictionary).get("card_id", "")))
			_fala("Não fundiu com campo: %s descartado." % nome_campo)
			print("[SOM] encontro da fusão falhou no slot %d." % slot_n)
	var real_f: Dictionary = (_cartas.get(descer_id, {}) as Dictionary) if _cartas.has(descer_id) else descer_carta
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
	_sel_atk = -1
	_slot_alvo = -1
	_estrela_ops = []
	_esconder_centro3d()
	_sub_mao = SUB_MAO_ESCOLHA
	_duel.advance_phase()
	_fase_jogador = FASE_CAMPO
	_fileira = FILEIRA_MEU_M
	_col = clampi(slot_n, 0, 4)
	_redesenhar(true)
	_flash_efeito()


## Fila da fusão (só visual + som, sem regra): mostra cada passo no HUD
## com flash no sucesso e chacoalhada na falha. Headless: só prints.
func _animar_fila_fusao(_em_ordem: Array, passos: Array, _indices_mao: Array) -> void:
	_fusao_passos = (passos as Array).duplicate()
	_redesenhar(false)
	if _sem_render():
		for p in _fusao_passos:
			if p is Dictionary:
				print("[MESA3D] Fusão: %s + %s = %s." % [str((p as Dictionary).get("a", "?")), str((p as Dictionary).get("b", "?")), str((p as Dictionary).get("result_id", "?"))])
		return
	for p in _fusao_passos:
		if not (p is Dictionary):
			continue
		var pd: Dictionary = p as Dictionary
		_redesenhar(false)
		if str(pd.get("tipo", "")) == "receita" or str(pd.get("tipo", "")) == "regra":
			_flash_efeito()
		else:
			_sacudir(_no_cartas)
		await get_tree().create_timer(0.45).timeout
		if not is_inside_tree():
			return


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
	_fase_jogador = FASE_MAO
	_sub_mao = SUB_MAO_ESCOLHA
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_levantadas = []
	_esconder_popup()
	_esconder_centro3d()
	_fileira = FILEIRA_MAO
	_col = 0
	_redesenhar(true)


func _passar_turno() -> void:
	if int(_st.current_player) != 0 or bool(_st.over):
		return
	if String(_st.phase) == "DRAW":
		_fala("Aguarde a fase passar.")
		return
	# START na fase da mão não faz nada (igual ao 2D: tem que descer 1 carta).
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		_fala("Desça 1 carta antes de passar (START bloqueado na fase da mão).")
		return
	if _popup != null and _popup.visible:
		_fala("Feche o menu antes de passar.")
		return
	_sel_atk = -1
	_esconder_popup()
	_esconder_centro3d()
	_mao_idx = -1
	_slot_alvo = -1
	_combinando = false
	_levantadas = []
	_sub_mao = SUB_MAO_ESCOLHA
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


## Vizinho por POSIÇÃO visível (igual ao 2D): direita sempre anda p/ a
## direita que se vê. O rival é espelho (índice 0 à direita), então andar
## por índice espelhava o controle. Aqui anda por X do slot, nunca por índice.
func _vizinho3d(lado: int, tipo: String, col_atual: int, dx: int) -> int:
	var atual := _pos_slot(lado, tipo, clampi(col_atual, 0, 4)).x
	var melhor := clampi(col_atual, 0, 4)
	var melhor_dist := 1e20
	var achou := false
	for i in range(5):
		if i == clampi(col_atual, 0, 4):
			continue
		var delta := _pos_slot(lado, tipo, i).x - atual
		if dx > 0 and delta > 0.001 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
		elif dx < 0 and delta < -0.001 and absf(delta) < melhor_dist:
			melhor_dist = absf(delta)
			melhor = i
			achou = true
	if achou:
		return melhor
	if dx > 0:
		var minx := 1e20
		var mini_idx := clampi(col_atual, 0, 4)
		for i in range(5):
			var cx := _pos_slot(lado, tipo, i).x
			if cx < minx:
				minx = cx
				mini_idx = i
		return mini_idx
	var maxx := -1e20
	var maxi_idx := clampi(col_atual, 0, 4)
	for i in range(5):
		var cx2 := _pos_slot(lado, tipo, i).x
		if cx2 > maxx:
			maxx = cx2
			maxi_idx = i
	return maxi_idx


func _lado_tipo_da_fileira(f: int) -> Array:
	match f:
		FILEIRA_RIVAL_S:
			return [1, "magia"]
		FILEIRA_RIVAL_M:
			return [1, "monstro"]
		FILEIRA_MEU_M:
			return [0, "monstro"]
		FILEIRA_MEU_S:
			return [0, "magia"]
	return []


func _mover(dx: int, dy: int) -> void:
	if _st == null or bool(_st.over):
		return
	# Menu central (estrela ou alvo): só cima/baixo troca a opção.
	if _popup != null and _popup.visible:
		if dy != 0:
			var max_idx := 1
			if _popup_modo == "estrela":
				max_idx = 2
				if _estrela_ops.size() < 2:
					max_idx = 1
			else:
				max_idx = 1
			_pad_popup_idx = posmod(_pad_popup_idx + dy, max_idx + 1)
			_atualizar_menus()
			_redesenhar(false)
		return
	var meu_turno: bool = int(_st.current_player) == 0
	# FASE DA MÃO (seu MAIN): trava total, igual ao 2D.
	if _fase_jogador == FASE_MAO and meu_turno and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_FACE:
				if dx != 0:
					_face_baixo = not _face_baixo
					_atualizar_centro_face()
					_fala("Face p/ baixo." if _face_baixo else "Face p/ cima.")
					_redesenhar(false)
				return
			SUB_SLOT, SUB_ESTRELA:
				if dx != 0:
					_fileira = FILEIRA_MEU_M
					_col = _vizinho3d(0, "monstro", _col, dx)
					_redesenhar(false)
				return
			_:
				if dy < 0:
					_fileira = FILEIRA_MAO
					_levantar3d(clampi(_col, 0, maxi(_larg_fileira(_fileira) - 1, 0)))
					return
				if dy > 0:
					_fileira = FILEIRA_MAO
					_abaixar3d(clampi(_col, 0, maxi(_larg_fileira(_fileira) - 1, 0)))
					return
				if dx != 0:
					_fileira = FILEIRA_MAO
					var larg := _larg_fileira(_fileira)
					if larg > 1:
						_col = posmod(_col + dx, larg)
						_posicionar_cursor()
						_redesenhar(false)
				return
	# FASE DE CAMPO (seu turno): SÓ os 20 slots (igual ao 2D: sem LP e sem mão).
	if _fase_jogador == FASE_CAMPO and meu_turno:
		if _lado_tipo_da_fileira(_fileira).is_empty():
			_fileira = FILEIRA_MEU_M
			_col = clampi(_col, 0, 4)
		if dx != 0:
			var lt := _lado_tipo_da_fileira(_fileira)
			_col = _vizinho3d(int(lt[0]), str(lt[1]), _col, dx)
			_posicionar_cursor()
			_redesenhar(false)
		if dy != 0:
			var idx := ORDEM_CAMPO_3D.find(_fileira)
			if idx < 0:
				idx = ORDEM_CAMPO_3D.find(FILEIRA_MEU_M)
			var novo_idx := clampi(idx + dy, 0, ORDEM_CAMPO_3D.size() - 1)
			if novo_idx != idx:
				var nova := int(ORDEM_CAMPO_3D[novo_idx])
				# Preserva a COLUNA VISÍVEL (X de tela, igual ao 2D).
				var atual_x := _pos_slot(int((_lado_tipo_da_fileira(_fileira) as Array)[0]), str((_lado_tipo_da_fileira(_fileira) as Array)[1]), clampi(_col, 0, 4)).x
				var mln := int((_lado_tipo_da_fileira(nova) as Array)[0])
				var mlt := str((_lado_tipo_da_fileira(nova) as Array)[1])
				var melhor := 0
				var melhor_dist := 1e20
				for i in range(5):
					var d := absf(_pos_slot(mln, mlt, i).x - atual_x)
					if d < melhor_dist:
						melhor_dist = d
						melhor = i
				_fileira = nova
				_col = melhor
				_posicionar_cursor()
				_redesenhar(false)
		return
	# Fora do seu fluxo (vez do rival): cursor anda livre p/ observar.
	if dx != 0:
		var lt2 := _lado_tipo_da_fileira(_fileira)
		if not lt2.is_empty():
			_col = _vizinho3d(int(lt2[0]), str(lt2[1]), _col, dx)
		else:
			_col = posmod(_col + dx, _larg_fileira(_fileira))
		_posicionar_cursor()
		_redesenhar(false)
		return
	if dy != 0:
		var idx2 := ORDEM_FILEIRAS.find(_fileira)
		if idx2 < 0:
			idx2 = 0
		var novo2 := clampi(idx2 + dy, 0, ORDEM_FILEIRAS.size() - 1)
		if novo2 != idx2:
			_fileira = int(ORDEM_FILEIRAS[novo2])
			_col = clampi(_col, 0, _larg_fileira(_fileira) - 1)
			_posicionar_cursor()
			_redesenhar(false)


## Levantar p/ fusão (só controle/visual, sem regra): selo 1,2,3 na ordem.
func _levantar3d(hand_idx: int) -> void:
	_limpar_levantadas()
	if _levantadas.has(hand_idx):
		return
	var mao: Array = (_st.players[0] as Dictionary)["hand"]
	if hand_idx < 0 or hand_idx >= mao.size():
		return
	_levantadas.append(hand_idx)
	print("[SOM] levantar carta %d (selo %d)." % [hand_idx, _levantadas.size()])
	_fala("Levantada %d (%d p/ fundir)." % [_levantadas.size(), _levantadas.size()])
	_redesenhar(false)


func _abaixar3d(hand_idx: int) -> void:
	_limpar_levantadas()
	if not _levantadas.has(hand_idx):
		return
	_levantadas.erase(hand_idx)
	print("[SOM] abaixar carta %d." % hand_idx)
	_fala("Abaixou. Restam %d levantadas." % _levantadas.size())
	_redesenhar(false)


func _confirmar() -> void:
	if _st == null:
		return
	if bool(_st.over):
		get_tree().reload_current_scene()
		return
	if _popup != null and _popup.visible:
		if _popup_modo == "alvo":
			_confirmar_alvo_menu()
		else:
			_confirmar_estrela()
		return
	if int(_st.current_player) != 0:
		_fala("Aguarde o rival.")
		return
	# FASE DA MÃO: avulsa = centro -> face -> slot -> estrela;
	# 1 levantada bloqueia; 2+ = fusão (slot primeiro, depois fila+estrela).
	if _fase_jogador == FASE_MAO and String(_st.phase) == "MAIN":
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				_limpar_levantadas()
				if _levantadas.size() == 1:
					_fala("Só 1 levantada: levante +1 p/ fundir ou abaixe p/ invocar avulsa.")
					return
				if _levantadas.size() >= 2:
					_iniciar_escolha_slot_fusao()
					return
				_fileira = FILEIRA_MAO
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
	# FASE DE CAMPO: SÓ os 20 slots (igual ao 2D, sem LP e sem mão).
	if _fase_jogador == FASE_CAMPO:
		match _fileira:
			FILEIRA_MEU_M:
				_confirmar_meu_campo3d()
				return
			FILEIRA_MEU_S:
				_fala("Magia: sem ação na mesa (só navega).")
				return
			FILEIRA_RIVAL_M:
				_confirmar_alvo_rival3d(clampi(_col, 0, 4))
				return
			FILEIRA_RIVAL_S:
				_confirmar_alvo_rival_magia3d()
				return
			_:
				_fala("Fase de campo: use os 20 slots do campo.")
		return


func _confirmar_meu_campo3d() -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
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
		_sel_atk = -1
		_fala("Não pode atacar: " + str(pode.get("erro", "")))
		_redesenhar(false)
		return
	_sel_atk = slot
	_fala("Atacante escolhido. Mire no campo rival.")
	_fileira = FILEIRA_RIVAL_M
	_posicionar_cursor()
	_redesenhar(false)


func _confirmar_alvo_rival3d(alvo_slot: int) -> void:
	if bool(_st.over) or int(_st.current_player) != 0:
		return
	if String(_st.phase) != "BATTLE":
		_fala("Ataque só na sua BATTLE.")
		return
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		return
	# Campo rival vazio -> menu de alvo oferece o LP (igual ao 2D).
	if not BattleSystem.has_monsters(_st, 1):
		_mostrar_popup_alvo()
		_fala("Rival sem monstros: mire no LP p/ ataque direto.")
		_redesenhar(false)
		return
	var zr: Array = (_st.players[1] as Dictionary)["monster"]
	var alvo := clampi(alvo_slot, 0, 4)
	if alvo < 0 or alvo >= zr.size() or zr[alvo] == null:
		_fala("Escolha um monstro rival (slot vazio).")
		return
	_atacar3d(alvo)


func _confirmar_alvo_rival_magia3d() -> void:
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
		_redesenhar(false)
		return
	_fala("Magia não é alvo: mire num monstro rival.")


func _confirmar_alvo_menu() -> void:
	if _popup_modo != "alvo":
		return
	if _pad_popup_idx == 1:
		_esconder_popup()
		_fala("Ataque direto cancelado. Mire de novo.")
		_redesenhar(false)
		return
	_esconder_popup()
	if _sel_atk < 0:
		_fala("Escolha seu atacante primeiro (seu campo).")
		_redesenhar(false)
		return
	if BattleSystem.has_monsters(_st, 1):
		_fala("Rival tem monstros: direto bloqueado.")
		_redesenhar(false)
		return
	_atacar3d(-1)


func _cancelar() -> void:
	if _st == null:
		return
	# Fusão animando: nenhum cancelar reescreve o fluxo (igual ao 2D).
	if _fusao_animando:
		_fala("Aguarde a fusão terminar.")
		return
	if _popup != null and _popup.visible:
		if _popup_modo == "alvo":
			_esconder_popup()
			_fala("Ataque direto cancelado. Mire de novo.")
			_redesenhar(false)
			return
		_esconder_popup()
		if _fase_jogador == FASE_MAO and _sub_mao == SUB_ESTRELA:
			_sub_mao = SUB_SLOT
			_fileira = FILEIRA_MEU_M
			_col = clampi(_slot_alvo, 0, 4)
			_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
			_redesenhar(false)
			return
		_fala("Invocação cancelada.")
		_redesenhar(false)
		return
	if _fase_jogador == FASE_MAO and int(_st.current_player) == 0:
		match _sub_mao:
			SUB_MAO_ESCOLHA:
				if not _levantadas.is_empty():
					var ultima := int(_levantadas.back())
					_levantadas.pop_back()
					print("[SOM] abaixar carta %d (cancelar)." % ultima)
					_fala("Abaixou a última. Restam %d levantadas." % _levantadas.size())
					_redesenhar(false)
					return
			SUB_ESTRELA:
				_sub_mao = SUB_SLOT
				_fileira = FILEIRA_MEU_M
				_col = clampi(_slot_alvo, 0, 4)
				_fala("Escolha 1 dos 5 slots (%s)." % _resumo_slots())
				_redesenhar(false)
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
					_fileira = FILEIRA_MAO
					_col = 0
					_fala("Fusão cancelada. Escolha de novo.")
					_redesenhar(false)
					return
				_sub_mao = SUB_FACE
				_fileira = FILEIRA_MAO
				_col = clampi(_mao_idx, 0, maxi(_larg_fileira(FILEIRA_MAO) - 1, 0))
				_fala("Face de novo: esq/dir.")
				_redesenhar(false)
				return
			SUB_FACE:
				_sub_mao = SUB_MAO_ESCOLHA
				_mao_idx = -1
				_sel_atk = -1
				_esconder_centro3d()
				_fileira = FILEIRA_MAO
				_fala("Escolha desfeita.")
				_redesenhar(false)
				return
	if _sel_atk >= 0:
		_sel_atk = -1
		_fala("Ataque desfeito.")
		_redesenhar(false)


func _alternar_posicao() -> void:
	if _st == null or bool(_st.over) or int(_st.current_player) != 0:
		return
	# Só no campo (fase de campo, carta própria), igual ao 2D.
	if _fase_jogador != FASE_CAMPO or _fileira != FILEIRA_MEU_M:
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
			var ops := _estrelas_da_carta(c)
			txt += "%s A%d/D%d estrela %s/%s" % [str(c.get("name", "?")), int(c.get("attack", 0)), int(c.get("defense", 0)), str(ops[0]), str(ops[1])]
	else:
		var lt := _lado_tipo_da_fileira(_fileira)
		if not lt.is_empty():
			txt += _texto_inst_slot(int(lt[0]), str(lt[1]), clampi(_col, 0, 4))
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
