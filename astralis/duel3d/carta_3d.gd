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

## O corpo da carta em 3D: o canto arredondado de 2 mm e a espessura de verdade.
## E ARTEFATO, nao fonte — quem edita e a `.blend` em `assets/3d/fonte/`, e quem
## publica este `.glb` e `tools/blender/exportar_carta.py`, que roda o portao da
## R16 (n-gon proibido, malha fechada, face contada) ANTES de exportar.
const MODELO_CARTA := preload("res://assets/3d/carta_de_duelo.glb")

## Tamanho da carta em unidades de mundo (1 unidade = a largura, que e 59 mm).
## O DONO destes numeros e a mesa, que mede e passa. Aqui nao ha default de
## proposito: um valor escrito neste arquivo seria a segunda fonte da mesma
## medida, e foi assim que a espessura chegou a 0,05 num arquivo (10x) e a
## 0,005 arredondado no outro, sem ninguem ver. Sem valor a carta avisa em vez
## de nascer com tamanho errado.
var larg_carta: float
var alt_carta: float
var gross_carta: float
## Retangulo da janela de arte dentro da moldura (fracao do JPG real). DONO: a
## mesa, porque o painel esquerdo usa a MESMA janela. Sem default pelo mesmo
## motivo acima.
var janela_art: Vector4
## Raio do canto arredondado e segmentos por canto, em unidade de mundo. DONO:
## a mesa, como a espessura. A moldura e o verso sao geometria propria, com
## o mesmo canto do modelo 3D; sem estes numeros a face descolaria do corpo.
var raio_carta: float
var segmentos_arco: int
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
	assert(larg_carta > 0.0 and alt_carta > 0.0 and gross_carta > 0.0
			and janela_art.z > janela_art.x and janela_art.w > janela_art.y
			and raio_carta > 0.0 and segmentos_arco >= 2,
		"carta_3d: larg/alt/gross/janela_art/raio/segmentos chegam da mesa (ela e o "
		+ "dono da medida). Vazio aqui = carta com tamanho zero em silencio.")
	# Carta INTEIRA igual ao editor: moldura JPG por tipo + arte na janela +
	# orbe + estrelas + nome/ATK na placa. Sem nada no projeto = cai na cor.
	var no := Node3D.new()
	no.name = "Carta3D"
	var corpo := _corpo()
	no.add_child(corpo)
	var zf := gross_carta / 2.0
	var tex_moldura: Texture2D = textura.call(moldura_da_carta.call(dado))
	# Frente: moldura inteira (ou cor do atributo quando sem moldura).
	var frente := MeshInstance3D.new()
	frente.name = "Frente"
	frente.mesh = _face()
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
		# Orbe do atributo no canto da placa (imagem do pack do editor).
		var attr := str(dado.get("attribute", ""))
		var tex_orbe: Texture2D = textura.call("assets/attributes/%s.png" % attr.to_lower())
		if tex_orbe != null:
			no.add_child(_quad_textura("Orbe", 0.095, 0.0947, Vector3(0.3805, 0.6173, zf + 0.002), tex_orbe, true))
		# Estrelas = level (só monstro), imagem do pack do editor.
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
	# flutuando no meio da tela suja a visão. Quem liga de novo: o selo de fusão
	# na mão (`_redesenhar`).
	var tag_txt := "VIRADA" if face_down else ("DEF" if em_defesa else "ATK")
	var tag_cor := Color(0.7, 0.7, 0.8) if face_down else (Color(0.5, 0.8, 1.0) if em_defesa else Color(1.0, 0.75, 0.35))
	var tag := _rotulo3d(tag_txt, 40, tag_cor)
	tag.name = "TagPos"
	tag.position = Vector3(0, alt_carta / 2.0 + 0.14, 0)
	tag.visible = false
	no.add_child(tag)
	# Verso do pack do editor (card_back da carta ou verso padrão do pack).
	# Sem arquivo no pack = marrom com espiral.
	var verso := MeshInstance3D.new()
	verso.name = "Verso"
	verso.mesh = _face()
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


## A FOLGA da face: quantas vezes o depth buffer separa a imagem do corpo.
##
## A face tem de ser maior que ZERO para nao brigar com o corpo (z-fighting) e
## Por que nao e' um QuadMesh: o QuadMesh tem 4 vertices e canto reto, e a carta
## agora tem canto arredondado de verdade. Um quad reto do tamanho da carta
## passaria da silhueta nos 4 cantos; um quad reduzido (o que era antes) deixava
## a carta aparecendo em volta — 0,59 mm de lado, medido. O unico jeito de a
## imagem acompanhar o canto do corpo e' ter o MESMO raio e o MESMO numero de
## segmentos, e `_corpo` confere os dois contra o `.glb` antes de deixar passar.
func _face() -> ArrayMesh:
	var pontos := PackedVector2Array()
	var hx := larg_carta / 2.0
	var hy := alt_carta / 2.0
	var segs := maxi(2, segmentos_arco)
	# as 4 pontas do canto, em ordem anti-horaria, no plano XY
	var cantos: Array[Vector2] = [
		Vector2(hx - raio_carta, hy - raio_carta),
		Vector2(-hx + raio_carta, hy - raio_carta),
		Vector2(-hx + raio_carta, -hy + raio_carta),
		Vector2(hx - raio_carta, -hy + raio_carta)]
	var angulos: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	for c in 4:
		var centro: Vector2 = cantos[c]
		var inicio: float = angulos[c]
		for s in range(segs + 1):
			var ang: float = inicio + (PI * 0.5) * float(s) / float(segs)
			pontos.append(centro + Vector2(cos(ang), sin(ang)) * raio_carta)
	# a poligonal fecha: o ultimo ponto do canto e' o primeiro do seguinte
	if pontos.size() > 1 and pontos[0].is_equal_approx(pontos[pontos.size() - 1]):
		pontos.remove_at(pontos.size() - 1)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# leque a partir do centro: a face e' plana, entao triangulo e' o
	# preenchimento mais barato e sem sobra. O que importa aqui e' a BORDA, e ela
	# e' exatamente a poligonal de `pontos`.
	var n := pontos.size()
	for i in range(n):
		_uv_tri(st, Vector2.ZERO, pontos[i], pontos[(i + 1) % n], hx, hy)
	return st.commit()


## Um triangulo da face, com a UV pelo retangulo da carta: a imagem entra
## inteira, sem esticar nem encurtar.
##
## DOIS DETALHES que aqui estao medidos, nao presumidos:
##
## - **V cresce para BAIXO.** No jogo Y sobe, entao o topo da carta (y = +hy) e'
##   V = 0. Com V crescendo para cima a moldura sai de cabeca para baixo.
## - **Afrente do Godot e' no sentido HORARIO.** Emitindo (a, b, c) com a
##   poligonal anti-horaria, a face fica de costas e some (o corpo aparece no
##   lugar). Emitindo (a, c, b) ela aparece. Medido, nao lembrado.
func _uv_tri(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, hx: float, hy: float) -> void:
	st.set_uv(Vector2((a.x + hx) / (hx * 2.0), (hy - a.y) / (hy * 2.0)))
	st.add_vertex(Vector3(a.x, a.y, 0.0))
	st.set_uv(Vector2((c.x + hx) / (hx * 2.0), (hy - c.y) / (hy * 2.0)))
	st.add_vertex(Vector3(c.x, c.y, 0.0))
	st.set_uv(Vector2((b.x + hx) / (hx * 2.0), (hy - b.y) / (hy * 2.0)))
	st.add_vertex(Vector3(b.x, b.y, 0.0))


## O CORPO da carta: a malha de `carta_de_duelo.glb`, com o canto arredondado
## de 2 mm e a espessura de verdade. A fonte e `astralis/assets/3d/fonte/`
## (`carta_de_duelo.blend`) e quem publica o artefato e
## `tools/blender/exportar_carta.py`; o `.glb` ja sai com a largura 1,0 e a
## mesma orientacao que o `BoxMesh` que ele substitui (largura em X, altura em Y,
## espessura em Z).
##
## O `assert` abaixo e a trava da D70 pelo lado do artefato: a medida e DA MESA,
## e o `.glb` nao pode trazer a dele. Sem a trava, uma fonte reescalada chegaria
## com a carta 17x menor e ninguem veria — foi o que a espessura fez quando
## chegou a 0,05 num arquivo e a 0,005 arredondado no outro.
func _corpo() -> MeshInstance3D:
	var raiz := MODELO_CARTA.instantiate()
	var corpo := _primeira_malha(raiz)
	assert(corpo != null and corpo.mesh != null,
		"carta_3d: o .glb de assets/3d tem de conter uma MeshInstance3D. "
		+ "Vazio aqui = artefato corrompido ou importacao quebrada.")
	if corpo == null or corpo.mesh == null:
		return MeshInstance3D.new()
	var caixa := corpo.mesh.get_aabb().size
	var medida := Vector3(larg_carta, alt_carta, gross_carta)
	assert(caixa.is_equal_approx(medida),
		("carta_3d: a medida do .glb nao bate com a da mesa. "
		+ "modelo=%s mesa=%s. O dono do numero e a mesa: regere o artefato com "
		+ "tools/blender/exportar_carta.py em vez de corrigir aqui.") % [caixa, medida])
	_conferir_o_canto(corpo)
	# O importador do Godot embrulha o `.glb` num Node3D de raiz em volta da
	# malha. A carta precisa do Corpo como no DIRETO de Carta3D (o mesmo lugar
	# onde o BoxMesh ficava, e o que os testes procuram), entao a malha sobe e
	# o embrulho vai junto — a transformacao do embrulho e composta nela para
	# nao perder pose.
	var embrulho := corpo.get_parent()
	corpo.transform = (embrulho as Node3D).transform * corpo.transform
	embrulho.remove_child(corpo)
	raiz.free()
	corpo.name = "Corpo"
	corpo.material_override = mat.call(Color(0.45, 0.30, 0.13))
	return corpo


## Confere o CANTO do `.glb` contra o da mesa. E o que garante que a moldura
## acompanhe o corpo em vez de-o chutar.
##
## O raio e' MEDIDO, nao lido: num canto arredondado, o vertice mais alto do
## arco esta a `LARG/2 - raio` do eixo. Os segmentos sao as POSICOES DISTINTAS
## estritamente dentro da caixa do canto — o importador do Godot quebra o vertice
## por face (normais por face), entao contar vertices contaria repetido.
##
## Por que os dois: com o raio certo e menos segmentos, a moldura entra para
## dentro da silhueta e aparece um fio de carta; com mais, ela passa para fora.
## So com os dois iguais os dois poligonos tracam a mesma linha.
func _conferir_o_canto(corpo: MeshInstance3D) -> void:
	var arrays: Array = corpo.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vs.is_empty():
		return
	var topo := -INF
	for v in vs:
		topo = maxf(topo, v.y)
	# a ponta do arco e' o vertice de maior |x| entre os que estao no topo: o
	# meio da borda reta tem |x| menor e nao serve
	var ponta := 0.0
	for v in vs:
		if absf(v.y - topo) < 1e-6:
			ponta = maxf(ponta, absf(v.x))
	var raio_medido: float = larg_carta / 2.0 - ponta

	var x0: float = larg_carta / 2.0 - raio_carta
	var y0: float = alt_carta / 2.0 - raio_carta
	var dentro := {}
	for v in vs:
		if v.x > x0 + 1e-6 and v.y > y0 + 1e-6:
			dentro["%.6f|%.6f" % [v.x, v.y]] = true
	var segs_medidos: int = dentro.size() + 1

	assert(absf(raio_medido - raio_carta) <= 0.0002,
		("carta_3d: o raio do canto do .glb e' %.6f e a mesa pede %.6f. A moldura e' "
		+ "uma geometria separada: com o raio errado ela passa da borda da carta "
		+ "ou deixa a carta aparecendo em volta. Regere o artefato com "
		+ "tools/blender/exportar_carta.py.") % [raio_medido, raio_carta])
	assert(segs_medidos == segmentos_arco,
		("carta_3d: o canto do .glb tem %d segmentos e a mesa pede %d. Com "
		+ "menos, a moldura entra para dentro da silhueta; com mais, passa para "
		+ "fora. Regere o artefato com tools/blender/exportar_carta.py.")
			% [segs_medidos, segmentos_arco])


## Acha a malha em qualquer profundidade. O `.glb` pode chegar com um no de
## raiz em volta, e o nome do no interno depende do exportador — o que nao pode
## mudar e a MEDIDA, e ela e conferida em `_corpo`.
func _primeira_malha(no: Node) -> MeshInstance3D:
	for c in no.get_children():
		if c is MeshInstance3D:
			return c as MeshInstance3D
		var achado := _primeira_malha(c)
		if achado != null:
			return achado
	return null


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