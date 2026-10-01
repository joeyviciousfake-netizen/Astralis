extends RefCounted

## carta_3d — COMO UMA CARTA 3D E MONTADA. Um assunto so: o desenho da carta
## (corpo, moldura, arte, orbe, estrelas, nome, ATK/DEF e verso).
##
## Aqui nao ha um no fixo na cena como no painel, no cursor, no campo ou na
## vista: carta tem VARIAS (20 no campo, duas maos, as do combo), entao este
## arquivo e uma FABRICA — ele monta e devolve o no `Carta3D` que a mesa
## coloca dentro do guarda-chuva `Cartas`. Quem decide onde a carta fica e de
## que lado ela esta virada e a mesa (a mao, o ladrilho, o combo).
##
## Zero regra (R1): isto e desenho puro. Os numeros do DADO (nome, ATK, DEF,
## level, tipo, atributo) sao lidos e impressos; nada e calculado aqui.
##
## As texturas e as cores chegam por Callable da mesa porque o PAINEL 2D do
## HUD usa as MESMAS (e o dono delas continua sendo a mesa, um so lugar).

## Tamanho da carta em unidades de mundo (a medida e da mesa).
var larg_carta := 1.0
var alt_carta := 1.4576
var gross_carta := 0.05
## Retangulo da janela de arte dentro da moldura (fracao do JPG real).
var janela_art := Vector4(0.1190, 0.1827, 0.8918, 0.7099)
## Textura do projeto pelo caminho do dado (com cache de sessao).
var textura: Callable
## Moldura pelo DADO, cor do atributo, arte da carta, e o material UNSHADED.
var moldura_da_carta: Callable
var cor_de_atributo: Callable
var textura_arte: Callable
var mat: Callable


## Monta UMA carta. `dado` e a carta do DADO (só leitura), `face_down` diz se
## ela mostra o verso e `em_defesa` se é a carta virada de lado no ladrilho.
func montar(dado: Dictionary, face_down: bool, em_defesa: bool) -> Node3D:
	# Carta INTEIRA igual ao editor: moldura JPG por tipo + arte na janela +
	# orbe + estrelas + nome/ATK na placa. Sem nada no projeto = cai na cor.
	var no := Node3D.new()
	no.name = "Carta3D"
	var corpo := MeshInstance3D.new()
	corpo.name = "Corpo"
	var malha := BoxMesh.new()
	malha.size = Vector3(larg_carta, alt_carta, gross_carta)
	corpo.mesh = malha
	corpo.material_override = mat.call(Color(0.45, 0.30, 0.13))
	no.add_child(corpo)
	var zf := gross_carta / 2.0
	var tex_moldura: Texture2D = textura.call(moldura_da_carta.call(dado))
	# Frente: moldura inteira (ou cor do atributo quando sem moldura).
	var frente := MeshInstance3D.new()
	frente.name = "Frente"
	var qf := QuadMesh.new()
	qf.size = Vector2(larg_carta - 0.02, alt_carta - 0.02)
	frente.mesh = qf
	frente.position = Vector3(0, 0, zf + 0.001)
	var mat_f := StandardMaterial3D.new()
	mat_f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_moldura != null:
		mat_f.albedo_texture = tex_moldura
	else:
		mat_f.albedo_color = (cor_de_atributo.call(str(dado.get("attribute", ""))) as Color).darkened(0.25)
	frente.material_override = mat_f
	no.add_child(frente)
	var eh_monstro := str(dado.get("card_type", "monster")) == "monster"
	# A arte preenche a janela INTEIRA (medido no JPG real), então ela cobre o
	# quadro sem sobra nem faixa.
	var larg_art := (janela_art.z - janela_art.x) * (larg_carta - 0.02)
	var alt_art := (janela_art.w - janela_art.y) * (alt_carta - 0.02)
	var x_art := ((janela_art.x + janela_art.z) * 0.5 - 0.5) * (larg_carta - 0.02)
	var y_art := (0.5 - (janela_art.y + janela_art.w) * 0.5) * (alt_carta - 0.02)
	if tex_moldura != null:
		var tex: Texture2D = textura_arte.call(dado)
		if tex != null:
			no.add_child(_quad_textura("Arte", larg_art, alt_art, Vector3(x_art, y_art, zf + 0.002), tex))
		# Orbe do atributo no canto da placa.
		var attr := str(dado.get("attribute", ""))
		var tex_orbe: Texture2D = textura.call("assets/attributes/%s.png" % attr.to_lower())
		if tex_orbe != null:
			no.add_child(_quad_textura("Orbe", 0.095, 0.0947, Vector3(0.3805, 0.6173, zf + 0.002), tex_orbe, true))
		# Estrelas = level (só monstro), à direita como na moldura.
		if eh_monstro:
			var tex_est: Texture2D = textura.call("assets/estrelas/estrela.png")
			if tex_est != null:
				var n := clampi(int(dado.get("level", 0)), 0, 12)
				for s in range(n):
					var px := 0.42 - float(n - 1 - s) * (0.0457 + 0.008) - 0.0228
					no.add_child(_quad_textura("Estrela%d" % s, 0.0457, 0.0444, Vector3(px, 0.5174, zf + 0.002), tex_est, true))
	# NOME impresso na faixa da moldura (doc 15 §15.3: na referência o nome é
	# impresso na própria carta). Medidas em % da moldura real, iguais às do
	# painel 2D: faixa x 5,4%..67,4% e y 2,7%..7,8% (de cima p/ baixo).
	# `width` do Label3D é em PIXELS do texto (não em unidades de mundo):
	# 160 px = a largura da faixa (0,61 de mundo / 0,0038 de pixel_size).
	# Fonte do texto = DADO real; carta virada não mostra nada.
	var nome := _rotulo3d(str(dado.get("name", "?")), 11, Color(0.12, 0.07, 0.03))
	nome.name = "Nome"
	nome.outline_size = 0
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.width = 160.0
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nome.position = Vector3(-0.43, 0.6434, zf + 0.003)
	nome.visible = not face_down
	no.add_child(nome)
	# ATK/DEF impresso na caixa de baixo da moldura (só monstro, dado real).
	# Medida no JPG real: a caixa bege vai de y 75,3% a 91,4% -> o texto fica
	# no meio dela (abaixo da caixa ele caía em cima da borda).
	var stats_txt := ""
	if eh_monstro:
		stats_txt = "ATK/%d DEF/%d" % [int(dado.get("attack", 0)), int(dado.get("defense", 0))]
	var stats := _rotulo3d(stats_txt, 14, Color(0.12, 0.07, 0.03))
	stats.name = "Stats"
	stats.outline_size = 0
	stats.position = Vector3(0.0, -0.4800, zf + 0.003)
	stats.visible = not face_down
	no.add_child(stats)
	# Indicador ATK/DEF + face (só desenho, igual ao 2D que mostra a posição).
	# ESCONDIDO por padrão: o ATK/DEF já sai impresso na carta e uma etiqueta
	# flutuando no meio da tela era lixo visual (ordem do usuário 2026-09-28).
	# Quem liga de novo: o selo de fusão na mão (`_redesenhar`).
	var tag_txt := "VIRADA" if face_down else ("DEF" if em_defesa else "ATK")
	var tag_cor := Color(0.7, 0.7, 0.8) if face_down else (Color(0.5, 0.8, 1.0) if em_defesa else Color(1.0, 0.75, 0.35))
	var tag := _rotulo3d(tag_txt, 40, tag_cor)
	tag.name = "TagPos"
	tag.position = Vector3(0, alt_carta / 2.0 + 0.14, 0)
	tag.visible = false
	no.add_child(tag)
	# Verso: imagem do projeto (card_back da carta ou verso padrão).
	# Sem nada = marrom com espiral (comportamento antigo).
	var verso := MeshInstance3D.new()
	verso.name = "Verso"
	var qv := QuadMesh.new()
	qv.size = Vector2(larg_carta - 0.02, alt_carta - 0.02)
	verso.mesh = qv
	verso.position = Vector3(0, 0, -gross_carta / 2.0 - 0.001)
	verso.rotation_degrees = Vector3(0, 180, 0)
	var dorso := str(dado.get("card_back", "")).strip_edges()
	if dorso.is_empty():
		dorso = "assets/backs/verso_padrao.png"
	var tex_dorso: Texture2D = textura.call(dorso)
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
	espiral.position = Vector3(0, 0, -gross_carta / 2.0 - 0.002)
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
		anel.material_override = mat.call(Color(0.92, 0.82, 0.62), 0.5)
		espiral.add_child(anel)
	# Pose padrão: só a VIRADA (gira Y 180° = mostra o verso). A pose no
	# mundo (deitada no painel / de pé na mão) é de quem placementa a carta:
	# `_deitar_carta` no campo, `_redesenhar` na mão. Um dono só, sem rotação
	# se contradizendo em dois lugares.
	if face_down:
		no.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return no


## Rótulo 3D do texto da carta (nome, ATK/DEF, selo). `width` do Label3D é em
## pixels do texto, não em unidades de mundo.
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
	# Sem mouse_filter aqui de propósito: Label3D é 3D, não Control (D19 já
	# vale — nada nesta cena recebe clique).
	return l


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