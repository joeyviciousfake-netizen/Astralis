extends Node3D

## mesa_3d — CAMPO 3D OFICIAL do duelo (D23/D40, cena principal do projeto).
## Ref nova do usuário (céu azul estilo GX, SEM MESA): nada de tampo,
## moldura, emblema ou vazio estrelado — só DESENHA o estado real
## (DuelManager/GameState + sistemas reais Summon/Battle/Position/Turn/
## Fusion) flutuando no céu azul com painéis de vidro azul. Zero regra
## aqui (R1): cada jogada chama o sistema real e redesenha. A mesa 2D
## aposentada mora em duel_legacy2d/ (só emergência, nunca carrega).
## Controle 100% joypad (D19): só as 11 ações custom, sem mouse/teclado.
## Uso headless p/ validação: `-- --mesa3d-sair=5` sai sozinho após N segundos.
## Controle 100% joypad (D19): só as 11 ações custom, sem mouse/teclado.
## Uso headless p/ validação: `-- --mesa3d-sair=5` sai sozinho após N segundos.
##
## Arg oficial --cenario3d (boot, documentado aqui):
##   sem arg (ou valor diferente de 0) = abre SEMPRE esta mesa 3D;
##   `-- --cenario3d 0` (ou `--cenario3d=0`) = volta ao legado 2D
##   (duel_legacy2d/duel_table.tscn), só p/ emergência; se o legado não
##   existir mais, avisa em PT-BR e segue no 3D.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")
const PositionSystem := preload("res://duel/position_system.gd")
const FusionSystem := preload("res://duel/fusion_system.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")

## Conversão desenho 2D->3D (só desenho): campo 2D centrado em x=1158.
## Composição ref nova (céu azul GX, SEM MESA): câmera FIXA atrás/acima do
## seu campo olhando o rival longe (profundidade); céu azul com nuvens e
## pilares de vidro ao fundo; 20 painéis de VIDRO AZUL flutuantes (5+5 por
## lado); carta virada = marrom com espiral; monstro em pé face-up; fases
## DP/SP/MP1/BP/MP2/EP metálicas no meio; mão em arco embaixo; painel 2D
## fixo à esquerda estilo carta (fundo bege, nome/tipo verdes); HUD 2D no
## topo (placa azul do seu LP esq / TURN centro / placa vermelha do rival
## dir + etiquetas Single). Zero regra aqui (R1).
const DIV := 150.0
const CENTRO_X := 1158.0
const CENTRO_Y := 540.0
const TOPO := 0.35
## Câmera FIXA (sem órbita/balanço): atrás do jogador, tilt p/ dar a
## profundidade da ref (rival longe em cima, você grande embaixo).
const CAM_POS := Vector3(0, 7.4, 9.6)
const CAM_ALVO := Vector3(0, -0.3, -1.4)
const CAM_FOV := 50.0
## Fases estilo Tag Force no meio do campo (só desenho; o motor real só tem
## DRAW/MAIN/BATTLE/END — SP e MP2 ficam apagadas, ver _fase_tag_atual).
const FASES_TAG := ["DP", "SP", "MP1", "BP", "MP2", "EP"]

const LARG_CARTA := 1.0
## Proporção exata da carta real 59x86mm (0,6860). Tudo que é carta, slot
## ou pilha usa essa proporção — nenhuma carta fica de tamanho diferente.
const ALT_CARTA := 86.0 / 59.0
## Finura real de carta (0,3mm numa carta 59mm = 0,005 da largura).
const GROSS_CARTA := 0.005

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
## Espelha o fluxo oficial (FASE_MAO/SUB_*): carta ao centro -> face ->
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
var _cursor3d: Node3D = null
var _flash_tela: ColorRect = null
var _deck_pos := [Vector3(3.6, 0.6, 0.4), Vector3(-3.6, 0.6, -0.4)]

var _lbl_lp_rival: Label = null
var _lbl_mao_rival: Label = null
var _lbl_fase: Label = null
var _lbl_log: Label = null
var _lbl_lp_voce: Label = null
var _lbl_dica: Label = null
var _lbl_slot: Label = null
var _lbl_fila: Label = null
## HUD estilo Tag Force SEM MESA (só desenho): placas metálicas no topo
## (seu LP esq / TURN centro / rival+LP dir, nomes reais do dado) +
## retratos (foto real ou silhueta com a inicial) + painel esquerdo da
## carta focada (moldura laranja, arte real ou cor do atributo + dados).
var _lbl_turno: Label = null
var _lbl_turno_num: Label = null
var _retrato_rival_foto: TextureRect = null
var _retrato_rival_silhueta: Label = null
var _retrato_voce_foto: TextureRect = null
var _retrato_voce_silhueta: Label = null
var _lbl_retrato_rival_nome: Label = null
var _lbl_retrato_voce_nome: Label = null
var _painel_foco: PanelContainer = null
var _tex_foco_arte: TextureRect = null
var _cor_foco_arte: ColorRect = null
var _tex_foco_moldura: TextureRect = null
var _tex_foco_orbe: TextureRect = null
var _caixa_foco_estrelas: HBoxContainer = null
var _lbl_foco_nome_molde: Label = null
var _cache_tex: Dictionary = {}
var _lbl_foco_nome: Label = null
var _lbl_foco_estrelas: Label = null
var _lbl_foco_stats: Label = null
var _lbl_foco_attr: Label = null
var _cor_foco_attr: ColorRect = null
var _lbl_foco_tipo: Label = null
var _lbl_foco_desc: Label = null
## Identidade real do duelo (só leitura do dado): nomes + retratos dos
## duelistas vindos de duel_setup.duelist1/2 + duelists (nome/portrait).
## Sem foto no dado = silhueta com a inicial do nome (igual à ref).
var _nome_voce := "VOCÊ"
var _nome_rival := "RIVAL"
var _retrato_voce := ""
var _retrato_rival := ""
## Fases no meio (só desenho) + contadores de deck/cemitério.
var _no_fases: Node3D = null
var _fase_marcas: Dictionary = {}
var _lbl_conta_deck_rival: Label3D = null
var _lbl_conta_cem_rival: Label3D = null
var _lbl_conta_deck_voce: Label3D = null
var _lbl_conta_cem_voce: Label3D = null
var _lbl_conta_mao_rival: Label3D = null
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
var _foco := Vector3.ZERO
var _pulso := 0.0
var _foto_destino := ""
var _foto_frames := -1


func _ready() -> void:
	# Boot oficial (ver o topo: --cenario3d). Sem o arg fica no 3D; com
	# `--cenario3d 0` troca p/ o legado 2D e PARA aqui (nada do 3D monta).
	if _usar_legado_2d():
		return
	_construir_ambiente()
	_construir_campo()
	_construir_hud()
	_construir_menus()
	# Duelo REAL (motor de verdade): ProjectLoader + DuelManager.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	_base_dir = str(data.get("base_dir", ""))
	_carregar_identidade(data)
	_montar_retratos()
	_duel = DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))
	_st = _duel.get_state()
	_cartas = data.get("cards", {})
	# Arena REAL do projeto: desenho segue o layout, IDs intactos.
	var arena_id := str((data.get("duel_setup", {}) as Dictionary).get("arena_id", "arena_starter"))
	_arena_data = BoardLayoutScript.load_arena_data(BoardLayoutScript.project_arena_path(arena_id))
	_arena_layout = (_arena_data.get("slots", {}) as Dictionary)
	_avisar_arena()
	_fusions_data = _fusoes_do_data(data)
	_fala("Mesa 3D: duelo real carregado.")
	_duel.advance_phase() # DRAW inicial -> MAIN (mão 5/5 sem extra, D26).
	_fala("Duelo começou! Sua vez.")
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


## Boot: lê --cenario3d nas 2 formas (igual ao --project/--setup).
## "0" = legado 2D (emergência); sem arg ou outro valor = fica no 3D.
## Volta true quando trocou de cena (quem chamou PARA aqui).
func _usar_legado_2d() -> bool:
	var modo := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var s := str(args[i])
		if s == "--cenario3d" and i + 1 < args.size():
			modo = str(args[i + 1]).strip_edges()
		elif s.begins_with("--cenario3d="):
			modo = s.trim_prefix("--cenario3d=").strip_edges()
	if modo != "0":
		return false
	var legado := "res://duel_legacy2d/duel_table.tscn"
	if not FileAccess.file_exists(legado):
		print("[MESA3D] Aviso: --cenario3d 0 pediu o legado 2D, mas ele não existe mais — seguindo no 3D.")
		return false
	print("[MESA3D] --cenario3d 0: abrindo o legado 2D (emergência).")
	get_tree().call_deferred("change_scene_to_file", legado)
	return true


## Espelha o log da mesa antiga p/ o boot continuar legível ([MESA3D]
## no lugar de [TABLE]): arena carregada ou aviso + grade padrão.
func _avisar_arena() -> void:
	if _arena_layout.is_empty():
		print("[MESA3D] Aviso: arena não carregou, usando grade padrão.")
	else:
		var h0: Dictionary = BoardLayoutScript.get_hand(_arena_data, 0)
		var h1: Dictionary = BoardLayoutScript.get_hand(_arena_data, 1)
		print("[MESA3D] Arena carregada: %d slots + mão p0(%d,%d,%d) p1(%d,%d,%d)." % [_arena_layout.size(), int(h0["x"]), int(h0["y"]), int(h0["step"]), int(h1["x"]), int(h1["y"]), int(h1["step"])])


func _ver_autoquit() -> void:
	# Só p/ validação headless (`-- --mesa3d-sair=5`). Sem o argumento, nada muda.
	# Foto DEV (`-- --mesa3d-foto=<caminho>`): salva o viewport e sai.
	# Só p/ conferir visual sem abrir o editor (some no final).
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--mesa3d-foto="):
			_foto_destino = s.trim_prefix("--mesa3d-foto=").strip_edges()
			_foto_frames = 0
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
	# Ref nova = céu azul claro GX (SEM MESA, SEM vazio estrelado): céu
	# procedural azul + neblina azul-clara p/ profundidade + sol branco.
	var ceu := Sky.new()
	var mat_ceu := ProceduralSkyMaterial.new()
	mat_ceu.sky_top_color = Color(0.20, 0.48, 0.90)
	mat_ceu.sky_horizon_color = Color(0.55, 0.78, 0.98)
	mat_ceu.ground_bottom_color = Color(0.22, 0.40, 0.68)
	mat_ceu.ground_horizon_color = Color(0.52, 0.70, 0.92)
	mat_ceu.sun_angle_max = 30.0
	mat_ceu.energy_multiplier = 0.85
	ceu.sky_material = mat_ceu
	env.background_mode = Environment.BG_SKY
	env.sky = ceu
	# Luz PROFISSIONAL (ref tem volume, não clarão): ambient baixo e
	# neutro, sol modelando com sombra suave, Healing por zona.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.52, 0.58)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	we.environment = env
	add_child(we)
	_construir_cenario_ceu()
	# SEM LUZES (ordem do usuário): tudo é UNSHADED, luz não faz nada —
	# nem sol nem omnis. Só o flash de tela (overlay 2D, ver HUD).
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	# CÂMERA FIXA da ref: atrás/acima do seu campo, tilt p/ o rival longe.
	# Sem órbita/balanço (removido do _process): mesma imagem todo frame.
	_cam.position = CAM_POS
	_cam.fov = CAM_FOV
	_cam.current = true
	add_child(_cam)
	_cam.look_at(CAM_ALVO)
	print("[MESA3D] Ambiente: céu azul + neblina + pilares + Camera3D FIXA (sem luzes: tudo unshaded).")


## Cenário do céu da ref (só desenho): pilares altos de vidro azulado ao
## fundo + nuvens brancas suaves, sem textura externa. Sem mesa: o campo
## de vidro flutua aqui.
func _construir_cenario_ceu() -> void:
	var no := Node3D.new()
	no.name = "Ceu"
	add_child(no)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260707
	# Pilares de vidro ao longe (ref tem torres translúcidas no horizonte).
	var mat_vidro_fundo := StandardMaterial3D.new()
	mat_vidro_fundo.albedo_color = Color(0.35, 0.55, 0.85, 0.7)
	mat_vidro_fundo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_vidro_fundo.roughness = 0.15
	mat_vidro_fundo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(10):
		var mi := MeshInstance3D.new()
		mi.name = "Pilar%d" % i
		var malha := BoxMesh.new()
		malha.size = Vector3(1.2 + rng.randf() * 1.6, 9.0 + rng.randf() * 7.0, 1.2 + rng.randf() * 1.6)
		mi.mesh = malha
		var ang := -0.5 + float(i) * 0.35 + rng.randf() * 0.1
		mi.position = Vector3(sin(ang) * 22.0, 2.0, -14.0 - rng.randf() * 8.0)
		mi.material_override = mat_vidro_fundo
		no.add_child(mi)
	# Nuvens: discos brancos achatados e suaves no alto.
	var mat_nuvem := StandardMaterial3D.new()
	mat_nuvem.albedo_color = Color(1, 1, 1, 0.75)
	mat_nuvem.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_nuvem.roughness = 1.0
	mat_nuvem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(14):
		var mi := MeshInstance3D.new()
		mi.name = "Nuvem%d" % i
		var malha := SphereMesh.new()
		malha.radius = 1.6 + rng.randf() * 2.2
		malha.height = 0.9 + rng.randf() * 0.7
		mi.mesh = malha
		mi.position = Vector3(-20.0 + rng.randf() * 40.0, 9.0 + rng.randf() * 7.0, -10.0 - rng.randf() * 14.0)
		mi.material_override = mat_nuvem
		no.add_child(mi)


# ---- CAMPO (SEM MESA: 20 painéis escuros flutuantes + laterais + fases) ----

func _mat(cor: Color, emissao: float = 0.0, _metal: float = 0.0, alfa: float = 1.0) -> StandardMaterial3D:
	# Tudo UNSHADED (ordem do usuário: sem luz): cor pura estilo anime,
	# zero cálculo de luz — nada escurece, nada estoura.
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	if alfa < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	return m


## Vidro azul da ref (só desenho): painéis e cartas flutuam como vidro
## claro com brilho suave. Sem textura externa.
func _vidro(cor: Color, alfa: float = 0.45, brilho: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
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


func _construir_campo() -> void:
	var campo := Node3D.new()
	campo.name = "Campo"
	add_child(campo)
	_no_slots = Node3D.new()
	_no_slots.name = "Slots"
	campo.add_child(_no_slots)
	# 20 painéis chanfrados escuros flutuantes (5+5 por lado, espelho do 2D
	# via BoardLayout real). Vazio = painel escuro com brilho sutil na
	# borda; na perspectiva da câmera fixa viram os trapezoides da ref.
	for lado in [0, 1]:
		for i in range(5):
			_no_slots.add_child(_painel_slot(lado, "monstro", i))
			_no_slots.add_child(_painel_slot(lado, "magia", i))
	var laterais := Node3D.new()
	laterais.name = "Laterais"
	campo.add_child(laterais)
	# Pilhas nas laterais (ref nova): decks marrons flutuantes com o
	# número de cartas em cima, cemitérios mais escuros.
	laterais.add_child(_caixa("DeckRival", Vector3(1.0, 0.35, 1.46), Vector3(3.3, TOPO + 0.17, -2.2), _mat(Color(0.42, 0.24, 0.10))))
	laterais.add_child(_caixa("DeckVoce", Vector3(1.0, 0.35, 1.46), Vector3(3.3, TOPO + 0.17, 1.6), _mat(Color(0.45, 0.26, 0.11))))
	laterais.add_child(_caixa("CemRival", Vector3(1.0, 0.22, 1.43), Vector3(-3.3, TOPO + 0.11, -2.2), _mat(Color(0.30, 0.16, 0.20), 0.25)))
	laterais.add_child(_caixa("CemVoce", Vector3(1.0, 0.22, 1.43), Vector3(-3.3, TOPO + 0.11, 1.6), _mat(Color(0.16, 0.24, 0.30), 0.25)))
	_lbl_conta_deck_rival = _rotulo3d("0", 60, Color(0.9, 0.85, 1.0))
	_lbl_conta_deck_rival.name = "ContaDeckRival"
	_lbl_conta_deck_rival.position = Vector3(3.3, 1.15, -2.2)
	laterais.add_child(_lbl_conta_deck_rival)
	_lbl_conta_cem_rival = _rotulo3d("0", 60, Color(1.0, 0.75, 0.75))
	_lbl_conta_cem_rival.name = "ContaCemRival"
	_lbl_conta_cem_rival.position = Vector3(-3.3, 1.0, -2.2)
	laterais.add_child(_lbl_conta_cem_rival)
	_lbl_conta_deck_voce = _rotulo3d("0", 60, Color(1.0, 0.95, 0.7))
	_lbl_conta_deck_voce.name = "ContaDeckVoce"
	_lbl_conta_deck_voce.position = Vector3(3.3, 1.15, 1.6)
	laterais.add_child(_lbl_conta_deck_voce)
	_lbl_conta_cem_voce = _rotulo3d("0", 60, Color(0.75, 1.0, 1.0))
	_lbl_conta_cem_voce.name = "ContaCemVoce"
	_lbl_conta_cem_voce.position = Vector3(-3.3, 1.0, 1.6)
	laterais.add_child(_lbl_conta_cem_voce)
	# Número de cartas na mão do rival (a ref mostra o 6 ao lado da mão dele).
	_lbl_conta_mao_rival = _rotulo3d("0", 60, Color(0.8, 0.8, 0.9))
	_lbl_conta_mao_rival.name = "ContaMaoRival"
	_lbl_conta_mao_rival.position = Vector3(2.4, 1.9, -4.2)
	campo.add_child(_lbl_conta_mao_rival)
	_construir_fases(campo)
	_construir_tokens(campo)
	_no_cartas = Node3D.new()
	_no_cartas.name = "Cartas"
	add_child(_no_cartas)
	# Cursor = MOLDURA vazada branca (ref: borda de seleção, não tijolo).
	_cursor3d = Node3D.new()
	_cursor3d.name = "Cursor3D"
	_cursor3d.position = Vector3(0, TOPO, 4.15)
	add_child(_cursor3d)
	var mat_cur := _mat(Color(0.90, 0.95, 1.0), 1.0)
	var bw := 1.24
	var bh := 1.78
	var t := 0.09
	_cursor3d.add_child(_caixa("Aba", Vector3(bw, 0.06, t), Vector3(0, 0, bh / 2.0), mat_cur))
	_cursor3d.add_child(_caixa("Abaixo", Vector3(bw, 0.06, t), Vector3(0, 0, -bh / 2.0), mat_cur))
	_cursor3d.add_child(_caixa("Esq", Vector3(t, 0.06, bh), Vector3(-bw / 2.0, 0, 0), mat_cur))
	_cursor3d.add_child(_caixa("Dir", Vector3(t, 0.06, bh), Vector3(bw / 2.0, 0, 0), mat_cur))
	print("[MESA3D] Campo: 20 painéis de vidro + decks/cemitérios + 6 fases + tokens + Cursor3D.")


## Fileira de fases no MEIO do campo (só desenho, ref DP/SP/MP1/BP/MP2/EP).
## A fase atual acende (dourado); SP/MP2 nunca acendem (motor sem elas).
func _construir_fases(campo: Node3D) -> void:
	_no_fases = Node3D.new()
	_no_fases.name = "Fases"
	campo.add_child(_no_fases)
	_fase_marcas = {}
	for i in range(FASES_TAG.size()):
		var tag := String(FASES_TAG[i])
		var x := (float(i) - 2.5) * 1.05
		var base := _caixa("Fase_%s" % tag, Vector3(0.92, 0.05, 0.5), Vector3(x, 0.19, -0.3), _mat(Color(0.30, 0.42, 0.62), 0.5, 0.6))
		base.set_meta("fase_tag", tag)
		_no_fases.add_child(base)
		var rot := _rotulo3d(tag, 52, Color(0.85, 0.90, 1.0))
		rot.name = "FaseRot_%s" % tag
		rot.position = Vector3(x, 0.32, -0.3)
		_no_fases.add_child(rot)
		_fase_marcas[tag] = {"base": base, "rot": rot}


## Motor real -> tag da ref: DRAW=DP, MAIN=MP1, BATTLE=BP, END=EP.
func _fase_tag_atual() -> String:
	if _st == null:
		return ""
	match String(_st.phase):
		"DRAW":
			return "DP"
		"MAIN":
			return "MP1"
		"BATTLE":
			return "BP"
		"END":
			return "EP"
	return ""


func _atualizar_fases() -> void:
	if _fase_marcas.is_empty():
		return
	var atual := _fase_tag_atual()
	for tag in _fase_marcas.keys():
		var par: Dictionary = _fase_marcas[tag]
		var base := par["base"] as MeshInstance3D
		var rot := par["rot"] as Label3D
		if base == null:
			continue
		if str(tag) == atual:
			base.material_override = _mat(Color(1.0, 0.85, 0.20), 1.0)
			if rot != null:
				rot.modulate = Color(0.15, 0.10, 0.02)
		else:
			base.material_override = _mat(Color(0.30, 0.42, 0.62), 0.5, 0.6)
			if rot != null:
				rot.modulate = Color(0.85, 0.90, 1.0)


## Tokens decorativos da ref nova (só desenho, zero regra): círculo com
## X à esquerda do meio + bússola à direita do meio, discos azul-escuros
## flutuando com símbolo branco.
func _construir_tokens(campo: Node3D) -> void:
	var tokens := Node3D.new()
	tokens.name = "Tokens"
	campo.add_child(tokens)
	var anel := MeshInstance3D.new()
	anel.name = "TokenX"
	var toro_x := TorusMesh.new()
	toro_x.inner_radius = 0.14
	toro_x.outer_radius = 0.22
	anel.mesh = toro_x
	anel.position = Vector3(-3.2, 0.5, -0.3)
	anel.rotation_degrees = Vector3(90, 0, 0)
	anel.material_override = _mat(Color(0.12, 0.20, 0.38), 0.5, 0.4)
	tokens.add_child(anel)
	var xis := _rotulo3d("X", 72, Color(1, 1, 1))
	xis.name = "TokenXLetra"
	xis.position = Vector3(-3.2, 0.62, -0.3)
	tokens.add_child(xis)
	var bussola := MeshInstance3D.new()
	bussola.name = "TokenBussola"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.2
	disco.bottom_radius = 0.2
	disco.height = 0.06
	bussola.mesh = disco
	bussola.position = Vector3(3.2, 0.44, -0.3)
	bussola.material_override = _mat(Color(0.12, 0.22, 0.40), 0.5, 0.4)
	tokens.add_child(bussola)
	var norte := _rotulo3d("N", 72, Color(1, 1, 1))
	norte.name = "TokenBussolaLetra"
	norte.position = Vector3(3.2, 0.62, -0.3)
	tokens.add_child(norte)


## Painel de slot vazio (só desenho): VIDRO AZUL flutuante da ref nova
## (painel claro translúcido + borda brilhante). A carta desce no XZ.
func _painel_slot(lado: int, tipo: String, indice: int) -> Node3D:
	var p := _pos_slot(lado, tipo, indice)
	var no := Node3D.new()
	no.name = "Painel_p%d_%s%d" % [lado, ("m" if tipo == "monstro" else "s"), indice]
	no.position = Vector3(p.x, 0.0, p.z)
	var borda := _caixa("Borda", Vector3(1.16, 0.03, 1.69), Vector3(0, TOPO - 0.055, 0), _vidro(Color(0.55, 0.75, 1.0), 0.9, 0.5))
	no.add_child(borda)
	var base := _caixa("Base", Vector3(1.06, 0.05, 1.545), Vector3(0, TOPO - 0.03, 0), _vidro(Color(0.16, 0.38, 0.78), 0.78, 0.12))
	no.add_child(base)
	return no


func _pos_slot(lado: int, tipo: String, indice: int) -> Vector3:
	# Lê o XY oficial (BoardLayout real + layout da arena, com espelho do
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


## Textura do projeto com cache de sessão (moldura/orbe/estrela se
## repetem; lê do disco 1x). Sem nada no projeto = nulo (fallback de cor).
func _tex_cache(rel: String) -> Texture2D:
	var chave := rel.strip_edges().to_lower()
	if chave.is_empty():
		return null
	if _cache_tex.has(chave):
		return _cache_tex[chave] as Texture2D
	var tex := _textura_arquivo(chave)
	_cache_tex[chave] = tex
	return tex


func _textura_arquivo(rel: String) -> Texture2D:
	# Foto REAL do projeto (caminho do dado, relativo à base).
	# Inexistente (dívida conhecida: FM sem assets) = volta nulo.
	var arq := rel.strip_edges()
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
				return ImageTexture.create_from_image(img)
	return null


func _textura_arte(carta: Dictionary) -> Texture2D:
	# Tenta a arte REAL do projeto (caminho do dado, relativo à base).
	# Inexistente (dívida conhecida: FM sem assets) = volta nulo e usa cor.
	var tex := _textura_arquivo(str(carta.get("artwork", "")))
	if tex != null:
		_artes_ok += 1
	return tex


## Identidade real do duelo (só leitura do dado, sem regra): nomes e
## retratos vêm de duel_setup.duelist1/2 + duelists (name/portrait).
## Sem duelista no dado = "VOCÊ"/"RIVAL" + silhueta com a inicial.
func _carregar_identidade(data: Dictionary) -> void:
	_nome_voce = "VOCÊ"
	_nome_rival = "RIVAL"
	_retrato_voce = ""
	_retrato_rival = ""
	var setup: Dictionary = data.get("duel_setup", {})
	var duelists: Dictionary = data.get("duelists", {})
	for par in [[setup.get("duelist1", {}), 0], [setup.get("duelist2", {}), 1]]:
		var slot = par[0]
		var lado := int(par[1])
		if not (slot is Dictionary):
			continue
		var did := str((slot as Dictionary).get("duelist_id", ""))
		if did.is_empty() or not duelists.has(did):
			continue
		var duo := duelists[did] as Dictionary
		var nome := str(duo.get("name", "")).strip_edges()
		var retrato := str(duo.get("portrait", "")).strip_edges()
		if lado == 0:
			if not nome.is_empty():
				_nome_voce = nome
			_retrato_voce = retrato
		else:
			if not nome.is_empty():
				_nome_rival = nome
			_retrato_rival = retrato
	print("[MESA3D] Duelo: %s x %s." % [_nome_voce, _nome_rival])


## Preenche os 2 retratos do HUD: foto real do dado ou silhueta com a
## inicial do nome (moldura laranja, igual à ref). Só desenho.
func _montar_retratos() -> void:
	_montar_retrato(_retrato_voce_foto, _retrato_voce_silhueta, _retrato_voce, _nome_voce)
	_montar_retrato(_retrato_rival_foto, _retrato_rival_silhueta, _retrato_rival, _nome_rival)
	if _lbl_retrato_voce_nome != null:
		_lbl_retrato_voce_nome.text = _nome_voce
	if _lbl_retrato_rival_nome != null:
		_lbl_retrato_rival_nome.text = _nome_rival


func _montar_retrato(foto: TextureRect, silhueta: Label, caminho: String, nome: String) -> void:
	if foto == null or silhueta == null:
		return
	var tex := _textura_arquivo(caminho)
	if tex != null:
		foto.texture = tex
		foto.visible = true
		silhueta.visible = false
	else:
		foto.visible = false
		var inicial := "?"
		if not nome.strip_edges().is_empty():
			inicial = nome.strip_edges().substr(0, 1).to_upper()
		silhueta.text = inicial
		silhueta.visible = true


## Código curto do atributo p/ a faixa do painel (ícone = cor + sigla).
func _rotulo_attr_curto(attr: String) -> String:
	match attr:
		"light":
			return "LUZ"
		"dark":
			return "TREVAS"
		"fire":
			return "FOGO"
		"water":
			return "ÁGUA"
		"earth":
			return "TERRA"
		"wind":
			return "VENTO"
		"thunder":
			return "TROVÃO"
		"divine":
			return "DIVINO"
	if attr.strip_edges().is_empty():
		return "—"
	return attr.to_upper()


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


## Moldura pelo DADO (espelho do editor, só leitura): spell/equip →
## magia; trap → armadilha; ritual → ritual; fusão → fusão; com efeito
## → efeito; resto → normal. Caminho no PROJETO (o jogo lê, não copia).
func _moldura_da_carta(dado: Dictionary) -> String:
	var t := str(dado.get("card_type", "monster"))
	if t == "spell" or t == "equip":
		return "assets/frames/spell.jpg"
	if t == "trap":
		return "assets/frames/trap.jpg"
	if t == "ritual":
		return "assets/frames/ritual.jpg"
	var tags := ""
	for g in (dado.get("tags", []) as Array):
		tags += " " + str(g)
	if tags.match("*fusao*") or tags.match("*fusão*") or tags.match("*fusion*"):
		return "assets/frames/fusion.jpg"
	if not (dado.get("effects", []) as Array).is_empty():
		return "assets/frames/effect.jpg"
	return "assets/frames/normal.jpg"


## Quad com textura do projeto (só leitura). Sem textura = nulo.
func _quad_textura(nome: String, larg: float, alt: float, pos: Vector3, tex: Texture2D, com_alfa: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var q := QuadMesh.new()
	q.size = Vector2(larg, alt)
	mi.mesh = q
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	if com_alfa:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	return mi


func _fazer_carta(dado: Dictionary, face_down: bool, lado: int, em_defesa: bool) -> Node3D:
	# Carta INTEIRA igual ao editor (só leitura do projeto): moldura JPG
	# por tipo + arte na janela + orbe + estrelas + nome/ATK na placa.
	# Sem nada no projeto = cai na cor (comportamento antigo).
	var no := Node3D.new()
	no.name = "Carta3D"
	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	var malha := BoxMesh.new()
	malha.size = Vector3(LARG_CARTA, ALT_CARTA, GROSS_CARTA)
	corpo.mesh = malha
	corpo.material_override = _mat(Color(0.45, 0.30, 0.13))
	no.add_child(corpo)
	var zf := GROSS_CARTA / 2.0
	var tex_moldura := _textura_arquivo(_moldura_da_carta(dado))
	# Frente: moldura inteira (ou cor do atributo quando sem moldura).
	var frente := MeshInstance3D.new()
	frente.name = "Frente"
	var qf := QuadMesh.new()
	qf.size = Vector2(LARG_CARTA - 0.02, ALT_CARTA - 0.02)
	frente.mesh = qf
	frente.position = Vector3(0, 0, zf + 0.001)
	var mat_f := StandardMaterial3D.new()
	mat_f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_moldura != null:
		mat_f.albedo_texture = tex_moldura
	else:
		mat_f.albedo_color = _cor_atributo(str(dado.get("attribute", ""))).darkened(0.25)
	frente.material_override = mat_f
	no.add_child(frente)
	var eh_monstro := str(dado.get("card_type", "monster")) == "monster"
	if tex_moldura != null:
		# Arte na janela da moldura (medida a pixel na moldura real:
		# x 12,0%..88,9% e y 18,9%..70,9%).
		var tex := _textura_arte(dado)
		if tex != null:
			no.add_child(_quad_textura("Arte", 0.775, 0.758, Vector3(0.0015, 0.0743, zf + 0.002), tex))
		# Orbe do atributo no canto da placa.
		var attr := str(dado.get("attribute", ""))
		var tex_orbe := _textura_arquivo("assets/attributes/%s.png" % attr.to_lower())
		if tex_orbe != null:
			no.add_child(_quad_textura("Orbe", 0.095, 0.0947, Vector3(0.3805, 0.6173, zf + 0.002), tex_orbe, true))
		# Estrelas = level (só monstro), à direita como na moldura.
		if eh_monstro:
			var tex_est := _textura_arquivo("assets/estrelas/estrela.png")
			if tex_est != null:
				var n := clampi(int(dado.get("level", 0)), 0, 12)
				for s in range(n):
					var px := 0.42 - float(n - 1 - s) * (0.0457 + 0.008) - 0.0228
					no.add_child(_quad_textura("Estrela%d" % s, 0.0457, 0.0444, Vector3(px, 0.5174, zf + 0.002), tex_est, true))
	var nome := _rotulo3d(str(dado.get("name", "?")), 34, Color(0.12, 0.07, 0.03))
	nome.name = "Nome"
	nome.outline_size = 0
	nome.position = Vector3(-0.0645, 0.6523, zf + 0.003)
	nome.visible = false
	no.add_child(nome)
	var stats_txt := ""
	if eh_monstro:
		stats_txt = "ATK/%d DEF/%d" % [int(dado.get("attack", 0)), int(dado.get("defense", 0))]
	var stats := _rotulo3d(stats_txt, 32, Color(0.12, 0.07, 0.03))
	stats.name = "Stats"
	stats.outline_size = 0
	stats.position = Vector3(0.05, -0.5991, zf + 0.003)
	stats.visible = false
	no.add_child(stats)
	# Indicador ATK/DEF + face (só desenho, igual ao 2D que mostra a posição).
	var tag_txt := "VIRADA" if face_down else ("DEF" if em_defesa else "ATK")
	var tag_cor := Color(0.7, 0.7, 0.8) if face_down else (Color(0.5, 0.8, 1.0) if em_defesa else Color(1.0, 0.75, 0.35))
	var tag := _rotulo3d(tag_txt, 40, tag_cor)
	tag.name = "TagPos"
	tag.position = Vector3(0, ALT_CARTA / 2.0 + 0.14, 0)
	no.add_child(tag)
	# Verso: imagem do projeto (card_back da carta ou verso padrão).
	# Sem nada = marrom com espiral (comportamento antigo).
	var verso := MeshInstance3D.new()
	verso.name = "Verso"
	var qv := QuadMesh.new()
	qv.size = Vector2(LARG_CARTA - 0.02, ALT_CARTA - 0.02)
	verso.mesh = qv
	verso.position = Vector3(0, 0, -GROSS_CARTA / 2.0 - 0.001)
	verso.rotation_degrees = Vector3(0, 180, 0)
	var dorso := str(dado.get("card_back", "")).strip_edges()
	if dorso.is_empty():
		dorso = "assets/backs/verso_padrao.png"
	var tex_dorso := _textura_arquivo(dorso)
	var mat_v := StandardMaterial3D.new()
	mat_v.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_dorso != null:
		mat_v.albedo_texture = tex_dorso
	else:
		mat_v.albedo_color = Color(0.45, 0.28, 0.13)
	verso.material_override = mat_v
	no.add_child(verso)
	var espiral := Node3D.new()
	espiral.name = "Espiral"
	espiral.position = Vector3(0, 0, -GROSS_CARTA / 2.0 - 0.002)
	espiral.rotation_degrees = Vector3(0, 180, 0)
	espiral.visible = tex_dorso == null
	no.add_child(espiral)
	for r in [0.10, 0.19, 0.28]:
		var anel := MeshInstance3D.new()
		anel.name = "AnelEspiral"
		var toro := TorusMesh.new()
		toro.inner_radius = r - 0.018
		toro.outer_radius = r
		anel.mesh = toro
		anel.material_override = _mat(Color(0.92, 0.82, 0.62), 0.5)
		espiral.add_child(anel)
	# Posição: DEF deita NO PLANO (gira Z 90°, horizontal como na ref e
	# no 2D); virada mostra o verso (gira Y 180°).
	var giro_y := 0.0
	if face_down:
		giro_y += PI
	no.rotation.y = giro_y
	# Rival de cabeça p/ baixo (homenagem ao 2D) só no ATK aberto.
	if lado == 1 and not face_down and not em_defesa:
		no.rotation.z = PI
	elif em_defesa and not face_down:
		no.rotation.z = PI / 2.0
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
	# Mão em ARCO embaixo (você, grande/perto da câmera) e rival longe/cima
	# pequeno (ref): arco abre em leque, pontas sobem e avançam.
	var t := float(i) - float(maxi(n - 1, 0)) / 2.0
	if lado == 0:
		# TODAS idênticas à do meio (ordem do usuário): mesma altura,
		# giro e posição — só o x separa. Seleção aparece no cursor e
		# fusão no selo, sem mexer na carta.
		return Vector3(t * 1.12, -0.60, 4.15)
	return Vector3(t * 0.7, 1.5 + 0.08 * absf(t), -4.15 - 0.10 * absf(t))


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
	# TODAS paralelas e retas p/ a sua visão (ref): mesmo tilt calculado
	# da câmera p/ o meio da mão (look_at deixava cada uma p/ um lado).
	# tilt = atan2(cam.y - mao.y, cam.z - mao.z); frente +Z => gira X -tilt.
	var tilt_mao := 48.9
	if _cam != null:
		var d := _cam.global_position - Vector3(0, 1.15, 4.15)
		tilt_mao = rad_to_deg(atan2(d.y, d.z))
	var mao0: Array = (_st.players[0] as Dictionary)["hand"]
	for i in range(mao0.size()):
		var c := _fazer_carta(mao0[i] as Dictionary, false, 0, false)
		c.position = _pos_mao_arco(i, mao0.size(), 0)
		# Levantada p/ fusão: só o selo na etiqueta (posição não muda).
		var selo := _levantadas.find(i) + 1
		if selo > 0:
			(c.get_node("TagPos") as Label3D).text = "SELO %d" % selo
		c.set_meta("mao_idx", i)
		_no_cartas.add_child(c)
		c.rotation_degrees = Vector3(-tilt_mao, 0, 0)
		if com_efeito and not _sem_render():
			var alvo: Vector3 = c.position
			c.position = _deck_pos[0]
			var tw := c.create_tween().set_parallel(true)
			tw.tween_property(c, "position", alvo, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var mao1: Array = (_st.players[1] as Dictionary)["hand"]
	for j in range(mao1.size()):
		var v := _fazer_carta({}, true, 1, false)
		v.position = _pos_mao_arco(j, mao1.size(), 1)
		_no_cartas.add_child(v)
		v.rotation_degrees = Vector3(180.0 - tilt_mao, 0, 0)
	_atualizar_hud()
	_posicionar_cursor()


func _posicionar_cursor() -> void:
	if _cursor3d == null or _st == null:
		return
	var alvo := Vector3(0, TOPO, 4.15)
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


func _rotulo_placa(nome: String, texto: String, tam: int) -> Label:
	# Texto escuro gravado na placa metálica (sombra clara, D19: sem clique).
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.05, 0.05, 0.10))
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_placa(fundo: Color = Color(0.62, 0.64, 0.70), borda: Color = Color(0.18, 0.19, 0.24)) -> StyleBoxFlat:
	# Placa metálica do topo (ref nova): azul (você), azul-escuro (turno),
	# vermelha (rival). Texto claro gravado.
	var est := StyleBoxFlat.new()
	est.bg_color = fundo
	est.border_color = borda
	est.set_border_width_all(2)
	est.set_corner_radius_all(6)
	est.content_margin_left = 14
	est.content_margin_right = 14
	est.content_margin_top = 6
	est.content_margin_bottom = 6
	return est


func _rotulo_placa_clara(nome: String, texto: String, tam: int) -> Label:
	# Texto CLARO gravado na placa colorida (ref nova).
	var l := Label.new()
	l.name = nome
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _estilo_retrato() -> StyleBoxFlat:
	# Moldura clara do retrato (ref nova: aro claro fino).
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.03, 0.03, 0.07, 0.95)
	est.border_color = Color(0.85, 0.90, 1.0)
	est.set_border_width_all(3)
	est.set_corner_radius_all(6)
	est.content_margin_left = 4
	est.content_margin_right = 4
	est.content_margin_top = 4
	est.content_margin_bottom = 4
	return est


func _construir_hud() -> void:
	# TOPO estilo ref SEM MARCA: 3 placas metálicas flutuantes (seu LP à
	# esquerda, TURN ao centro, rival + LP à direita, tudo dado real) +
	# retratos (rival em cima à direita, você à esquerda do campo) +
	# painel esquerdo fixo com a carta focada GRANDE. Tudo IGNORE (D19).
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_construir_placas(hud)
	_construir_retratos(hud)
	# Textos inventados REMOVIDOS (ordem do usuário, ref não tem): MaoRival,
	# Fase, Log, InfoSlot, FilaFusao, Dica. Só ficam placas, retratos,
	# painel da carta, fases 3D, contadores e menus funcionais.
	_lbl_mao_rival = null
	_lbl_fase = null
	_lbl_log = null
	_lbl_slot = null
	_lbl_fila = null
	_lbl_dica = null
	var barra_start := PanelContainer.new()
	barra_start.name = "BarraStart"
	var est_start := StyleBoxFlat.new()
	est_start.bg_color = Color(0.02, 0.02, 0.05, 0.9)
	est_start.border_color = Color(0.30, 0.32, 0.40)
	est_start.set_border_width_all(2)
	est_start.set_corner_radius_all(6)
	barra_start.add_theme_stylebox_override("panel", est_start)
	barra_start.position = Vector2(1690, 1020)
	barra_start.custom_minimum_size = Vector2(214, 44)
	barra_start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl_start := _rotulo_hud("StartHelp", "START ? Help", Vector2.ZERO, 24, Color(1, 1, 1))
	lbl_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barra_start.add_child(lbl_start)
	hud.add_child(barra_start)
	_flash_tela = ColorRect.new()
	_flash_tela.name = "FlashTela"
	_flash_tela.color = Color(1, 1, 1)
	_flash_tela.modulate.a = 0.0
	_flash_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_flash_tela)
	_construir_painel_foco(hud)


## 3 placas do topo (ref nova, só desenho): AZUL com seu LP + nome à
## esquerda, AZUL-ESCURA com TURN ao centro, VERMELHA com nome do rival +
## LP à direita + etiquetas laranja "Single" embaixo das duas. Sem logo.
func _construir_placas(hud: Control) -> void:
	var placa_voce := PanelContainer.new()
	placa_voce.name = "PlacaVoce"
	placa_voce.add_theme_stylebox_override("panel", _estilo_placa(Color(0.15, 0.35, 0.85), Color(0.05, 0.12, 0.35)))
	placa_voce.position = Vector2(16, 8)
	placa_voce.size = Vector2(420, 56)
	placa_voce.custom_minimum_size = Vector2(420, 56)
	placa_voce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_lp_voce = _rotulo_placa_clara("LpVoce", "LP 8000", 34)
	placa_voce.add_child(_lbl_lp_voce)
	hud.add_child(placa_voce)
	var tag_voce := _rotulo_hud("TagVoce", "Single", Vector2(436, 66), 20, Color(1.0, 0.65, 0.2))
	hud.add_child(tag_voce)
	var placa_turno := PanelContainer.new()
	placa_turno.name = "PlacaTurno"
	placa_turno.add_theme_stylebox_override("panel", _estilo_placa(Color(0.08, 0.12, 0.45), Color(0.02, 0.04, 0.20)))
	placa_turno.position = Vector2(860, 8)
	placa_turno.size = Vector2(200, 84)
	placa_turno.custom_minimum_size = Vector2(200, 84)
	placa_turno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa_turno := VBoxContainer.new()
	caixa_turno.name = "CaixaTurno"
	caixa_turno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_turno.add_theme_constant_override("separation", 0)
	placa_turno.add_child(caixa_turno)
	var titulo := _rotulo_placa_clara("TurnoTitulo", "TURN", 20)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa_turno.add_child(titulo)
	_lbl_turno = _rotulo_placa_clara("Turno", "1", 36)
	_lbl_turno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa_turno.add_child(_lbl_turno)
	_lbl_turno_num = _lbl_turno
	hud.add_child(placa_turno)
	var placa_rival := PanelContainer.new()
	placa_rival.name = "PlacaRival"
	placa_rival.add_theme_stylebox_override("panel", _estilo_placa(Color(0.80, 0.15, 0.20), Color(0.35, 0.05, 0.08)))
	placa_rival.position = Vector2(1324, 8)
	placa_rival.size = Vector2(580, 56)
	placa_rival.custom_minimum_size = Vector2(580, 56)
	placa_rival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_lp_rival = _rotulo_placa_clara("LpRival", "RIVAL LP 8000", 28)
	_lbl_lp_rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	placa_rival.add_child(_lbl_lp_rival)
	hud.add_child(placa_rival)
	var tag_rival := _rotulo_hud("TagRival", "Single", Vector2(1640, 66), 20, Color(1.0, 0.65, 0.2))
	tag_rival.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tag_rival.size = Vector2(100, 28)
	hud.add_child(tag_rival)


## Retratos 2D (só desenho): rival no canto superior direito, você à
## esquerda do campo (igual à ref). Foto real ou silhueta com a inicial.
func _construir_retratos(hud: Control) -> void:
	var ret_rival := PanelContainer.new()
	ret_rival.name = "RetratoRival"
	ret_rival.add_theme_stylebox_override("panel", _estilo_retrato())
	ret_rival.position = Vector2(1768, 72)
	ret_rival.size = Vector2(136, 136)
	ret_rival.custom_minimum_size = Vector2(136, 136)
	ret_rival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_rival_foto = TextureRect.new()
	_retrato_rival_foto.name = "Foto"
	_retrato_rival_foto.custom_minimum_size = Vector2(120, 120)
	_retrato_rival_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_rival_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_retrato_rival_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_rival_foto.visible = false
	ret_rival.add_child(_retrato_rival_foto)
	_retrato_rival_silhueta = _rotulo_hud("Silhueta", "?", Vector2.ZERO, 72, Color(0.96, 0.56, 0.30))
	_retrato_rival_silhueta.custom_minimum_size = Vector2(120, 120)
	_retrato_rival_silhueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retrato_rival_silhueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ret_rival.add_child(_retrato_rival_silhueta)
	hud.add_child(ret_rival)
	_lbl_retrato_rival_nome = null
	var ret_voce := PanelContainer.new()
	ret_voce.name = "RetratoVoce"
	ret_voce.add_theme_stylebox_override("panel", _estilo_retrato())
	ret_voce.position = Vector2(384, 540)
	ret_voce.size = Vector2(136, 136)
	ret_voce.custom_minimum_size = Vector2(136, 136)
	ret_voce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_voce_foto = TextureRect.new()
	_retrato_voce_foto.name = "Foto"
	_retrato_voce_foto.custom_minimum_size = Vector2(120, 120)
	_retrato_voce_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato_voce_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_retrato_voce_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_voce_foto.visible = false
	ret_voce.add_child(_retrato_voce_foto)
	_retrato_voce_silhueta = _rotulo_hud("Silhueta", "?", Vector2.ZERO, 72, Color(0.55, 0.85, 1.0))
	_retrato_voce_silhueta.custom_minimum_size = Vector2(120, 120)
	_retrato_voce_silhueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_retrato_voce_silhueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ret_voce.add_child(_retrato_voce_silhueta)
	hud.add_child(ret_voce)
	_lbl_retrato_voce_nome = null


## Painel esquerdo 2D fixo estilo CARTA (ref nova): fundo bege como a
## moldura da carta + carta GRANDE (arte real de assets/fm/ via --project
## quando existir, senão cor do atributo; fileira de estrelas; faixa
## ATK/DEF) + NOME verde + [TIPO] verde + DESCRIÇÃO branca + barra
## vermelha decorativa à direita. Só leitura, sem regra.
func _construir_painel_foco(hud: Control) -> void:
	_painel_foco = PanelContainer.new()
	_painel_foco.name = "PainelCarta"
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.72, 0.58, 0.38, 0.97)
	est.border_color = Color(0.45, 0.28, 0.12)
	est.set_border_width_all(4)
	est.set_corner_radius_all(8)
	est.content_margin_left = 12
	est.content_margin_right = 12
	est.content_margin_top = 10
	est.content_margin_bottom = 10
	_painel_foco.add_theme_stylebox_override("panel", est)
	_painel_foco.position = Vector2(8, 72)
	_painel_foco.size = Vector2(356, 830)
	_painel_foco.custom_minimum_size = Vector2(356, 830)
	_painel_foco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_painel_foco)
	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 8)
	_painel_foco.add_child(linha)
	var caixa := VBoxContainer.new()
	caixa.name = "Caixa"
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 6)
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(caixa)
	# Carta inteira como na ref: moldura JPG do projeto + arte + nome +
	# orbe + estrelas posicionados na moldura (igual ao editor).
	var molde := Control.new()
	molde.name = "CartaMolde"
	molde.custom_minimum_size = Vector2(300, 434)
	molde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(molde)
	_tex_foco_moldura = TextureRect.new()
	_tex_foco_moldura.name = "Moldura"
	_tex_foco_moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_foco_moldura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_foco_moldura.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_foco_moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_tex_foco_moldura)
	# Posições em % da moldura real (iguais às do 3D e do editor).
	_tex_foco_arte = TextureRect.new()
	_tex_foco_arte.name = "FocoArte"
	_tex_foco_arte.position = Vector2(300 * 0.117, 434 * 0.186)
	_tex_foco_arte.size = Vector2(300 * 0.775, 434 * 0.521)
	_tex_foco_arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_foco_arte.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_foco_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_tex_foco_arte)
	_cor_foco_arte = ColorRect.new()
	_cor_foco_arte.name = "FocoCor"
	_cor_foco_arte.position = Vector2(300 * 0.117, 434 * 0.186)
	_cor_foco_arte.size = Vector2(300 * 0.775, 434 * 0.521)
	_cor_foco_arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_cor_foco_arte)
	_lbl_foco_nome_molde = _rotulo_hud("FocoNomeMolde", "", Vector2.ZERO, 15, Color(0.12, 0.07, 0.03))
	_lbl_foco_nome_molde.position = Vector2(300 * 0.054, 434 * 0.027)
	_lbl_foco_nome_molde.size = Vector2(300 * 0.62, 434 * 0.051)
	_lbl_foco_nome_molde.clip_text = true
	molde.add_child(_lbl_foco_nome_molde)
	_tex_foco_orbe = TextureRect.new()
	_tex_foco_orbe.name = "FocoOrbe"
	_tex_foco_orbe.position = Vector2(300 * 0.833, 434 * 0.044)
	_tex_foco_orbe.size = Vector2(300 * 0.095, 434 * 0.065)
	_tex_foco_orbe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_foco_orbe.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_foco_orbe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	molde.add_child(_tex_foco_orbe)
	_caixa_foco_estrelas = HBoxContainer.new()
	_caixa_foco_estrelas.name = "FocoEstrelasBox"
	_caixa_foco_estrelas.position = Vector2(300 * 0.40, 434 * 0.118)
	_caixa_foco_estrelas.size = Vector2(300 * 0.52, 434 * 0.054)
	_caixa_foco_estrelas.alignment = BoxContainer.ALIGNMENT_END
	_caixa_foco_estrelas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa_foco_estrelas.add_theme_constant_override("separation", 1)
	molde.add_child(_caixa_foco_estrelas)
	# Bloco de descrição SEPARADO da imagem (ref): tamanho FIXO — texto
	# longo nunca muda o tamanho do bloco (corta com clip).
	var bloco := PanelContainer.new()
	bloco.name = "BlocoDesc"
	var est_b := StyleBoxFlat.new()
	est_b.bg_color = Color(0.62, 0.48, 0.30, 0.97)
	est_b.border_color = Color(0.40, 0.24, 0.10)
	est_b.set_border_width_all(2)
	est_b.set_corner_radius_all(6)
	est_b.content_margin_left = 10
	est_b.content_margin_right = 10
	est_b.content_margin_top = 8
	est_b.content_margin_bottom = 8
	bloco.add_theme_stylebox_override("panel", est_b)
	bloco.custom_minimum_size = Vector2(300, 330)
	bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(bloco)
	var coluna := VBoxContainer.new()
	coluna.name = "Bloco"
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation", 4)
	bloco.add_child(coluna)
	var faixa := HBoxContainer.new()
	faixa.name = "FocoFaixa"
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_theme_constant_override("separation", 8)
	coluna.add_child(faixa)
	_cor_foco_attr = ColorRect.new()
	_cor_foco_attr.name = "FocoAttrIcon"
	_cor_foco_attr.custom_minimum_size = Vector2(28, 28)
	_cor_foco_attr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(_cor_foco_attr)
	_lbl_foco_attr = _rotulo_hud("FocoAttr", "", Vector2.ZERO, 22, Color(0.12, 0.12, 0.18))
	faixa.add_child(_lbl_foco_attr)
	_lbl_foco_stats = _rotulo_hud("FocoStats", "", Vector2.ZERO, 24, Color(0.10, 0.10, 0.14))
	faixa.add_child(_lbl_foco_stats)
	_lbl_foco_nome = _rotulo_hud("FocoNome", "—", Vector2.ZERO, 24, Color(0.10, 0.35, 0.12))
	_lbl_foco_nome.clip_text = true
	coluna.add_child(_lbl_foco_nome)
	_lbl_foco_tipo = _rotulo_hud("FocoTipo", "", Vector2.ZERO, 20, Color(0.10, 0.38, 0.12))
	_lbl_foco_tipo.clip_text = true
	coluna.add_child(_lbl_foco_tipo)
	_lbl_foco_desc = _rotulo_hud("FocoDesc", "", Vector2.ZERO, 19, Color(0.12, 0.12, 0.16))
	_lbl_foco_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_foco_desc.custom_minimum_size = Vector2(280, 170)
	_lbl_foco_desc.clip_text = true
	_lbl_foco_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	coluna.add_child(_lbl_foco_desc)
	var barra := ColorRect.new()
	barra.name = "BarraVermelha"
	barra.color = Color(0.75, 0.10, 0.15)
	barra.custom_minimum_size = Vector2(10, 0)
	barra.size_flags_vertical = Control.SIZE_EXPAND_FILL
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(barra)


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
	# Placas do topo com o DADO real: seu LP, turno, nome do rival + LP.
	_lbl_lp_rival.text = "%s LP %d" % [_nome_rival.to_upper(), int((_st.players[1] as Dictionary)["lp"])]
	_lbl_lp_voce.text = "LP %d %s" % [int((_st.players[0] as Dictionary)["lp"]), _nome_voce.to_upper()]
	if _lbl_turno != null:
		if bool(_st.over):
			_lbl_turno.text = "VITÓRIA!" if int(_st.winner) == 0 else "DERROTA"
		else:
			_lbl_turno.text = "%d" % int(_st.turn_number)
	_atualizar_painel_foco()
	_atualizar_fases()
	_atualizar_contadores()


## Contadores dos 2 lados (só leitura do estado real): número no deck,
## no cemitério e na mão do rival (a ref mostra 33/32/6 sobre as pilhas).
func _atualizar_contadores() -> void:
	if _st == null:
		return
	var d0 := 0
	var c0 := 0
	var d1 := 0
	var c1 := 0
	if (_st.players[0] as Dictionary).has("deck"):
		d0 = ((_st.players[0] as Dictionary)["deck"] as Array).size()
	if (_st.players[0] as Dictionary).has("graveyard"):
		c0 = ((_st.players[0] as Dictionary)["graveyard"] as Array).size()
	if (_st.players[1] as Dictionary).has("deck"):
		d1 = ((_st.players[1] as Dictionary)["deck"] as Array).size()
	if (_st.players[1] as Dictionary).has("graveyard"):
		c1 = ((_st.players[1] as Dictionary)["graveyard"] as Array).size()
	if _lbl_conta_deck_voce != null:
		_lbl_conta_deck_voce.text = "%d" % d0
	if _lbl_conta_cem_voce != null:
		_lbl_conta_cem_voce.text = "%d" % c0
	if _lbl_conta_deck_rival != null:
		_lbl_conta_deck_rival.text = "%d" % d1
	if _lbl_conta_cem_rival != null:
		_lbl_conta_cem_rival.text = "%d" % c1
	if _lbl_conta_mao_rival != null:
		_lbl_conta_mao_rival.text = "%d" % ((_st.players[1] as Dictionary)["hand"] as Array).size()


## Carta focada pelo cursor (só leitura): mão, campo próprio ou rival.
## Rival de costas / virada = dado oculto (mostra "?" sem vazar).
func _carta_focada() -> Dictionary:
	if _st == null:
		return {}
	if _fase_jogador == FASE_MAO and _sub_mao != SUB_MAO_ESCOLHA and _mao_idx >= 0:
		var mao_c: Array = (_st.players[0] as Dictionary)["hand"]
		if _mao_idx >= 0 and _mao_idx < mao_c.size():
			return {"dado": mao_c[_mao_idx] as Dictionary, "aberta": true, "lado": 0}
	if _fileira == FILEIRA_MAO:
		var mao: Array = (_st.players[0] as Dictionary)["hand"]
		var i := clampi(_col, 0, maxi(int(mao.size()) - 1, 0))
		if i >= 0 and i < mao.size():
			return {"dado": mao[i] as Dictionary, "aberta": true, "lado": 0}
	var lt := _lado_tipo_da_fileira(_fileira)
	if lt.is_empty():
		return {}
	var lado := int(lt[0])
	# _lado_tipo_da_fileira fala PT ("monstro"/"magia"); o estado real usa EN.
	var zona_nome := "monster" if str(lt[1]) == "monstro" else "spell"
	var zona: Array = (_st.players[lado] as Dictionary)[zona_nome]
	var slot := clampi(_col, 0, 4)
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return {}
	var inst := zona[slot] as Dictionary
	var aberta := not bool(inst.get("face_down", false))
	if lado == 1 and not aberta:
		return {"dado": {}, "aberta": false, "lado": lado}
	return {"dado": _fantasia(inst), "aberta": aberta, "lado": lado, "inst": inst}


## Preenche o painel esquerdo com o DADO real (nome/level/ATK/DEF/tipo/
## descrição) + arte real quando existir, senão cor do atributo.
func _atualizar_painel_foco() -> void:
	if _painel_foco == null:
		return
	var foco := _carta_focada()
	var dado: Dictionary = foco.get("dado", {}) as Dictionary
	if dado.is_empty():
		_lbl_foco_nome.text = "—"
		if _lbl_foco_estrelas != null:
			_lbl_foco_estrelas.text = ""
		_lbl_foco_stats.text = ""
		_lbl_foco_attr.text = ""
		_cor_foco_attr.color = Color(0.2, 0.2, 0.25)
		_lbl_foco_tipo.text = ""
		_lbl_foco_desc.text = "Mire numa carta."
		_tex_foco_arte.visible = false
		_cor_foco_arte.color = Color(0.08, 0.08, 0.12)
		_tex_foco_moldura.texture = null
		_tex_foco_orbe.texture = null
		_lbl_foco_nome_molde.text = ""
		for f in _caixa_foco_estrelas.get_children():
			(f as Node).queue_free()
		return
	# Completa pelo DADO real quando a instância só tem o básico.
	var cid := str(dado.get("id", dado.get("card_id", "")))
	var real: Dictionary = dado
	if not cid.is_empty() and _cartas.has(cid):
		real = _cartas[cid] as Dictionary
	var nome := str(real.get("name", dado.get("name", "?")))
	_lbl_foco_nome.text = nome
	var nivel := int(real.get("level", dado.get("level", 0)))
	if _lbl_foco_estrelas != null:
		_lbl_foco_estrelas.text = ""
	# Carta inteira na moldura (igual ao editor): moldura + arte + nome +
	# orbe + fileira de estrelas-imagem, tudo do projeto (com cache).
	_tex_foco_moldura.texture = _tex_cache(_moldura_da_carta(real))
	_lbl_foco_nome_molde.text = nome.to_upper()
	var attr_cedo := str(real.get("attribute", dado.get("attribute", "")))
	var tex_o := _tex_cache("assets/attributes/%s.png" % attr_cedo.to_lower())
	_tex_foco_orbe.texture = tex_o
	for f in _caixa_foco_estrelas.get_children():
		(f as Node).queue_free()
	var tex_e := _tex_cache("assets/estrelas/estrela.png")
	if tex_e != null and str(real.get("card_type", dado.get("card_type", "monster"))) == "monster":
		for s in range(clampi(nivel, 0, 12)):
			var im := TextureRect.new()
			im.custom_minimum_size = Vector2(20, 20)
			im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			im.stretch_mode = TextureRect.STRETCH_SCALE
			im.texture = tex_e
			im.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_caixa_foco_estrelas.add_child(im)
	_lbl_foco_stats.text = "ATK/%d DEF/%d" % [int(real.get("attack", dado.get("attack", 0))), int(real.get("defense", dado.get("defense", 0)))]
	var tipo := str(real.get("monster_type", dado.get("monster_type", "")))
	var attr := str(real.get("attribute", dado.get("attribute", "")))
	_lbl_foco_attr.text = _rotulo_attr_curto(attr)
	if _lbl_foco_attr.text.strip_edges() == "—":
		_lbl_foco_attr.text = ""
	_cor_foco_attr.color = _cor_atributo(attr)
	var ctipo := str(real.get("card_type", dado.get("card_type", "monster")))
	if ctipo == "monster":
		_lbl_foco_tipo.text = "[%s]" % tipo.to_upper() if not tipo.is_empty() else "[MONSTRO]"
	else:
		_lbl_foco_tipo.text = "[%s]" % ctipo.to_upper()
	var desc := str(real.get("description", dado.get("description", "")))
	if desc.strip_edges().is_empty():
		var ops := _estrelas_da_carta(dado)
		desc = "Guardiãs %s/%s." % [str(ops[0]), str(ops[1])] if not dado.is_empty() else ""
		if not attr.is_empty():
			desc += (" Atributo %s." % attr) if not desc.is_empty() else ("Atributo %s." % attr)
	_lbl_foco_desc.text = desc
	var tex := _textura_arte(real)
	if tex != null:
		_tex_foco_arte.texture = tex
		_tex_foco_arte.visible = true
		_cor_foco_arte.visible = false
	else:
		_tex_foco_arte.visible = false
		_cor_foco_arte.visible = true
		_cor_foco_arte.color = _cor_atributo(attr)


func _texto_inst_slot(lado: int, zona_nome: String, slot: int) -> String:
	var zona: Array = (_st.players[lado] as Dictionary)[zona_nome]
	var sid := "p%d_%s%d" % [lado, ("m" if zona_nome == "monster" else "s"), slot]
	if slot < 0 or slot >= zona.size() or zona[slot] == null:
		return "Slot %s: vazio." % sid
	var m := zona[slot] as Dictionary
	var face := "virada" if bool(m.get("face_down", false)) else "aberta"
	var pos := str(m.get("position", "ATK"))
	return "Slot %s: %s em %s %s." % [sid, _nome_no_slot_lado(lado, zona_nome, slot), pos, face]


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
	if _sem_render() or _flash_tela == null:
		return
	_flash_tela.modulate.a = 0.85
	var tw := _flash_tela.create_tween()
	tw.tween_property(_flash_tela, "modulate:a", 0.0, 0.4)


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
	# CÂMERA FIXA (ref): nunca mexe — só o cursor pulsa. Sem órbita/balanço.
	_pulso += delta * 4.0
	if not _foto_destino.is_empty():
		_foto_frames += 1
		if _foto_frames >= 90:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_foto_destino)
			print("[MESA3D] Foto salva: " + _foto_destino)
			get_tree().quit()
	if _cam != null:
		if _cam.position != CAM_POS:
			_cam.position = CAM_POS
		# look_at todo frame é barato e garante o tilt fixo da ref.
		_cam.look_at(CAM_ALVO)
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
