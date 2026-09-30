extends "res://testing/astralis_test_base.gd"

## test_assets_embutidos — os assets da CARTA no jogo (`astralis/assets/`)
## são BYTE-IDÊNTICOS aos do Studio (`astralis-studio/static/`), e o jogo
## os acha SOZINHO, sem `--project` (doc 15 §15.2, D38: as molduras são do
## usuário e é PROIBIDO editar).
##
## O QUE ESTE ARQUIVO TRAVA:
## (1) os 17 pares (mesmo nome nos 2 lados) existem e batem byte a byte
##     (tamanho + SHA-256 + os bytes) — trocar UM dos lados quebra aqui;
## (2) a lista de 17 é a MESMA que o jogo procura (`ASSETS_EMBUTIDOS` em
##     duel3d/mesa_3d.gd) — asset novo em um lado só também quebra;
## (3) sem `--project` (é como o GUT roda) o jogo acha 17/17 e a carta 3D
##     sai com a MOLDURA REAL (832x1248), não com a cor de fallback;
## (4) a carta DEITADA no campo tem a mesma composição da carta da mão
##     (moldura + arte + orbe + estrelas + nome + ATK/DEF) e nome/ATK/DEF
##     são visíveis e vêm do DADO.
##
## Sem Fake (R2): a mesa real, os sistemas reais, os arquivos de verdade.

const Mesa3DScript := preload("res://duel3d/mesa_3d.gd")

## Os 17 pares, nome a nome. Tem que ser exatamente a lista que o jogo usa.
const PARES := [
	"frames/normal.jpg", "frames/effect.jpg", "frames/spell.jpg",
	"frames/trap.jpg", "frames/ritual.jpg", "frames/fusion.jpg",
	"attributes/earth.png", "attributes/water.png", "attributes/fire.png",
	"attributes/wind.png", "attributes/light.png", "attributes/dark.png",
	"attributes/divine.png", "attributes/spell.png", "attributes/trap.png",
	"estrelas/estrela.png", "backs/verso_padrao.png",
]
## Tamanho da moldura real do usuário (D38: 832x1248, byte-idêntica).
const TAM_MOLDURA := Vector2i(832, 1248)


func _studio() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../astralis-studio/static").simplify_path()


func _jogo() -> String:
	return ProjectSettings.globalize_path("res://").path_join("assets").simplify_path()


## (1) Byte a byte: se alguém trocar a moldura no Studio e não no jogo (ou
## o contrário), este teste FALHA.
func test_assets_do_jogo_batem_com_o_studio_byte_a_byte() -> void:
	assert_eq(PARES.size(), 17, "São 17 assets de carta (6 molduras + 9 orbes + estrela + verso).")
	for par in PARES:
		var no_studio := _studio().path_join(str(par))
		var no_jogo := _jogo().path_join(str(par))
		assert_true(FileAccess.file_exists(no_studio), "Studio tem o asset: " + str(par))
		assert_true(FileAccess.file_exists(no_jogo), "Jogo tem o asset: " + str(par))
		if not (FileAccess.file_exists(no_studio) and FileAccess.file_exists(no_jogo)):
			continue
		var bs_studio := FileAccess.get_file_as_bytes(no_studio)
		var bs_jogo := FileAccess.get_file_as_bytes(no_jogo)
		assert_eq(bs_jogo.size(), bs_studio.size(), "Mesmo tamanho nos 2 lados: " + str(par))
		assert_eq(bs_jogo, bs_studio, "Bytes IDÊNTICOS nos 2 lados: " + str(par))
		assert_eq(FileAccess.get_sha256(no_jogo), FileAccess.get_sha256(no_studio),
			"SHA-256 idêntico nos 2 lados: " + str(par))


## (2) O jogo procura exatamente estes 17 (nada de asset órfão num lado só).
func test_lista_do_jogo_e_a_mesma_pinada() -> void:
	var do_jogo: Array = Mesa3DScript.ASSETS_EMBUTIDOS
	assert_eq(do_jogo.size(), PARES.size(), "ASSETS_EMBUTIDOS tem os 17 (nada a mais/nada a menos).")
	for par in PARES:
		assert_true(("assets/" + str(par)) in do_jogo, "O jogo procura: assets/" + str(par))


## (3) Sem `--project` (assim que o GUT roda) o jogo acha os 17 e a carta
## sai com a MOLDURA REAL, não com a cor de fallback.
func test_jogo_acha_o_vertido_e_a_moldura_sem_project() -> void:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	assert_true(mesa.get("_base_dir") != null, "Preparo: base de dados carregada.")
	assert_eq(int(mesa.call("_conta_assets_embutidos")), 17,
		"17/17 assets embutidos achados SEM --project (o jogo mostra a carta real sozinho).")
	# A carta 3D da sua mão tem que estar com a moldura de verdade.
	var carta: Node3D = null
	for f in (mesa.get_node("Camada3D/JanelaCampo/Viewport3D/Cartas") as Node3D).get_children():
		# D52: as DUAS mãos têm `mao_idx` e `mao_dono`, e elas trocam de lugar
		# na volta — quem diz de quem é a carta é o DONO (0 = a sua mão).
		if (f as Node).has_meta("mao_dono") and int((f as Node).get_meta("mao_dono")) == 0 and int((f as Node).get_meta("mao_idx")) == 0:
			carta = f as Node3D
	assert_true(carta != null, "A 1a carta da sua mão está desenhada.")
	if carta == null:
		return
	var mat := (carta.get_node("Frente") as MeshInstance3D).material_override as StandardMaterial3D
	assert_true(mat.albedo_texture != null, "Frente com TEXTURA (não caiu na cor de fallback).")
	if mat.albedo_texture != null:
		assert_eq(mat.albedo_texture.get_size(), Vector2(TAM_MOLDURA), "Textura = a moldura real do usuário (832x1248).")
	# A arte (assets/fm/...) é DADO do pack: entra quando o arquivo existe
	# (com --project; dívida conhecida: o pack embutido de examples aponta
	# pra arte que não está no repo). O que este arquivo trava é o EMBUTIDO
	# do jogo: moldura, orbe, estrela e verso, que é o que faltava.
	assert_true(carta.get_node_or_null(NodePath("Orbe")) != null, "Carta tem o orbe do atributo.")
	assert_true(carta.get_node_or_null(NodePath("Estrela0")) != null, "Carta tem a estrela do nível.")
	assert_true(carta.get_node_or_null(NodePath("Verso")) != null, "Carta tem o verso.")


## (4) A carta DEITADA no campo é a mesma carta da mão (moldura + arte +
## orbe + estrelas + nome + ATK/DEF impressos, tudo do DADO real).
func test_carta_deitada_no_campo_igual_a_da_mao_com_nome_e_atkdef() -> void:
	var SummonSys := preload("res://duel/summon_system.gd")
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	var st = mesa.get("_st")
	# Prepara: o sistema REAL invoca a 1a carta da mão no p0_m0.
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão p0 tem monstro.")
	var slot: int = SummonSys.free_monster_slot(st, 0)
	var r: Dictionary = SummonSys.normal_summon(st, 0, idx, slot, false, "ATK", "")
	assert_true(bool(r.get("ok", false)), "Sistema real invocou.")
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	var cartas: Node3D = mesa.get_node("Camada3D/JanelaCampo/Viewport3D/Cartas")
	var da_mao: Node3D = null
	var do_campo: Node3D = null
	for f in cartas.get_children():
		if (f as Node).has_meta("slot_id"):
			do_campo = f as Node3D
		elif (f as Node).has_meta("mao_dono") and int((f as Node).get_meta("mao_dono")) == 0 and int((f as Node).get_meta("mao_idx")) == 0:
			da_mao = f as Node3D
	assert_true(do_campo != null, "Carta invocada desenhada no campo.")
	assert_true(da_mao != null, "Carta da mão desenhada.")
	if do_campo == null or da_mao == null:
		return
	# Mesma composição nos dois (a do campo NÃO pode ser mais pobre que a mão).
	var pecas_do_campo: Array = []
	for f in do_campo.get_children():
		pecas_do_campo.append(str((f as Node).name))
	var pecas_da_mao: Array = []
	for f in da_mao.get_children():
		pecas_da_mao.append(str((f as Node).name))
	for peca in ["Frente", "Orbe", "Estrela0", "Nome", "Stats", "Verso"]:
		assert_true(do_campo.get_node_or_null(NodePath(peca)) != null, "Campo tem a peça: " + peca)
		assert_true(da_mao.get_node_or_null(NodePath(peca)) != null, "Mão tem a peça: " + peca)
	# A arte entra junto nos dois quando o dado tem o arquivo (dívida
	# conhecida: o pack embutido de examples aponta pra arte que não existe).
	var tem_arte := do_campo.get_node_or_null(NodePath("Arte")) != null
	assert_eq(tem_arte, da_mao.get_node_or_null(NodePath("Arte")) != null, "Arte nos dois ou em nenhum (mesma regra).")
	assert_eq(pecas_do_campo, pecas_da_mao, "Carta do campo = carta da mão (mesmas peças, mesmo desenho).")
	# Nome e ATK/DEF IMPRESSOS e visíveis, com o texto do DADO real.
	var nome := do_campo.get_node("Nome") as Label3D
	var stats := do_campo.get_node("Stats") as Label3D
	assert_true(nome.visible, "Nome visível na carta do campo.")
	assert_true(stats.visible, "ATK/DEF visível na carta do campo.")
	var cid := str(do_campo.get_meta("card_id"))
	var cartas_dado: Dictionary = mesa.get("_cartas")
	assert_true(cartas_dado.has(cid), "Preparo: a carta invocada tem dado no pack (id %s)." % cid)
	var carta_real: Dictionary = cartas_dado[cid] as Dictionary
	assert_eq(nome.text, str(carta_real.get("name", "")), "Nome impresso = nome do dado real.")
	assert_eq(stats.text, "ATK/%d DEF/%d" % [int(carta_real.get("attack", 0)), int(carta_real.get("defense", 0))],
		"ATK/DEF impresso = números do dado real.")
	# Deitada no painel: a carta gira deitada e fica sobre a peça de vidro.
	assert_almost_eq(do_campo.rotation_degrees.x, -90.0, 0.01, "Carta deitada (não em pé) no painel.")
	var painel := (mesa.get_node("Camada3D/JanelaCampo/Viewport3D/Campo/Slots") as Node3D).get_node("Painel_p0_m%d" % slot) as Node3D
	assert_almost_eq(do_campo.position.x, painel.position.x, 0.001, "Carta no X do painel.")
	assert_almost_eq(do_campo.position.z, painel.position.z, 0.001, "Carta no Z do painel.")
	assert_true(do_campo.position.y < 0.5, "Carta apoiada no vidro (não flutuando em pé).")
	# A etiqueta de posição (ATK/DEF) NÃO fica flutuando no vazio.
	var tag := do_campo.get_node("TagPos") as Label3D
	assert_eq(tag.visible, false, "Sem etiqueta ATK flutuando: o ATK/DEF sai impresso na carta.")
	# A peça de vidro: translúcida e com fresta (doc 15 §15.3, "mesa de vidro").
	var base := (painel.get_node("Base") as MeshInstance3D).material_override as StandardMaterial3D
	assert_eq(base.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Vidro do campo é translúcido.")
	assert_true(base.albedo_color.a < 1.0, "Vidro do campo tem transparência (< 1).")
	assert_true(base.albedo_color.r < 0.2 and base.albedo_color.b < 0.35, "Vidro do campo é AZUL ESCURO.")
