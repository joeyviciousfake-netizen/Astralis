extends "res://testing/astralis_test_base.gd"

## test_assets_3d — o pipeline 3D (Blender -> .glb -> jogo), doc 17.
##
## O QUE ESTE ARQUIVO TRAVA, e por que cada trava existe:
##  1) O manifesto existe, e' a FONTE UNICA dos numeros do mesh. Um asset
##     listado sem os dois arquivos no disco e' erro, nao "asset opcional".
##  2) O .glb que o JOGO carrega bate com o que o manifesto promete: numero de
##     triangulos, de vertices, caixa (AABB) e nome do material. Esta e' a
##     mesma trava que `tools/blender/exportar_assets.py` faz do lado do
##     Blender, so que aqui do lado do Godot — dois medidores independentes do
##     MESMO artefato. E o que garante que a tela nao mude quando o mesh
##     muda: o D50 morreu de dois lugares da verdade, e nao de um so.
##  3) A CONVENCAO da base: o AABB comeca em y = 0 (o objeto pousa no chao
##     sem ajuste) e o no do .glb entra sem transform. Se someday vier
##     transform, o Godot mostraria o objeto deslocado e alguem iria
##     "consertar" no codigo da mesa — exatamente o defeito do APROXIMA_MAGIA
##     que o D49 apagou.
##  4) Asset que nao existe devolve NULO com aviso: nunca uma caixa no lugar
##     (R3/D50 — erro honesto, geometria inventada e' proibida).
##
## REGRA: o que este arquivo mede e' o ARTEFATO (o .glb) e o MANIFESTO. Nao
## ha regra de jogo aqui (R1) e o jogo nao e' mockado (R2): `core/asset_3d`
## e' o carregador real que a tela vai usar.

const Asset3D := preload("res://core/asset_3d.gd")


func _carregador() -> RefCounted:
	return Asset3D.new()


## Percorre as malhas de uma instancia e devolve {tris, verts, materiais, aabb}.
func _medir(no: Node3D) -> Dictionary:
	var tris := 0
	var verts := 0
	var materiais: Array = []
	var caixa := AABB()
	var primeira := true
	var achou := false
	for filho in no.get_children():
		var malha := filho as MeshInstance3D
		if malha == null or malha.mesh == null:
			continue
		achou = true
		for s in range(malha.mesh.get_surface_count()):
			var arrays: Array = malha.mesh.surface_get_arrays(s)
			var verts_surface: Array = arrays[Mesh.ARRAY_VERTEX]
			var ind: Array = arrays[Mesh.ARRAY_INDEX]
			verts += verts_surface.size()
			tris += (ind.size() / 3) if ind.size() > 0 else maxi(verts_surface.size() - 2, 0)
			var mat := malha.mesh.surface_get_material(s)
			if mat != null and str(mat.resource_name) not in materiais:
				materiais.append(str(mat.resource_name))
		var aabb := malha.mesh.get_aabb()
		caixa = aabb if primeira else caixa.merge(aabb)
		primeira = false
	return {"tris": tris, "verts": verts, "materiais": materiais, "caixa": caixa, "achou": achou}


func test_o_manifesto_existe_e_tem_a_versao_do_contrato() -> void:
	var c := _carregador()
	var m: Dictionary = c.manifesto()
	assert_false(m.is_empty(), "O manifesto 3D existe e le: %s" % Asset3D.MANIFESTO)
	assert_eq(int(m.get("schema_version", 0)), 1,
		"O manifesto 3D esta na versao 1 do contrato (mudou, o jogo recusa).")
	assert_true((m.get("assets", []) as Array).size() > 0, "O manifesto lista ao menos um asset 3D.")


func test_todo_asset_do_manifesto_tem_o_blend_e_o_glb_no_disco() -> void:
	var c := _carregador()
	for a in (c.manifesto().get("assets", []) as Array):
		var id := str((a as Dictionary).get("id", ""))
		assert_true(FileAccess.file_exists(str(c.caminho_glb(id))),
			"O .glb exportado do asset '%s' esta no disco (o jogo so carrega .glb)." % id)
		assert_true(FileAccess.file_exists(str(c.caminho_blend(id))),
			"O .blend FONTE do asset '%s' esta versionado em %s." % [id, c.caminho_blend(id)])
		assert_true(str(c.caminho_blend(id)).contains("/fonte/"),
			"O .blend de '%s' mora em assets/3d/fonte/ (pasta com .gdignore: o Godot nao escaneia)." % id)
		assert_true(FileAccess.file_exists("res://assets/3d/fonte/.gdignore"),
			"A pasta das fontes tem .gdignore, senao o Godot tenta importar o .blend como cena.")


func test_o_glb_que_o_jogo_carrega_bate_com_o_manifesto() -> void:
	# A TRAVA DE VERDADE: o manifesto promete, o .glb tem que entregar. Medido
	# no artefato que o Godot importou, sem passar pelo Blender.
	var c := _carregador()
	for a in (c.manifesto().get("assets", []) as Array):
		var id := str((a as Dictionary).get("id", ""))
		var no: Node3D = c.instancia(id)
		assert_true(no != null, "O asset '%s' instancia no jogo (o .glb carregou)." % id)
		if no == null:
			continue
		add_child_autofree(no)
		var med := _medir(no)
		assert_true(bool(med["achou"]), "O asset '%s' tem MeshInstance3D com malha." % id)
		assert_eq(int(med["tris"]), int((a as Dictionary).get("triangulos", -1)),
			"'%s': numero de triangulos igual ao manifesto (%d)." % [id, int(med["tris"])])
		assert_eq(int(med["verts"]), int((a as Dictionary).get("vertices", -1)),
			"'%s': numero de vertices igual ao manifesto (%d)." % [id, int(med["verts"])])
		assert_eq((med["materiais"] as Array).size(), ((a as Dictionary).get("materiais", []) as Array).size(),
			"'%s': um material, como o manifesto manda (%s)." % [id, str(med["materiais"])])
		for m in ((a as Dictionary).get("materiais", []) as Array):
			assert_true(str(m) in (med["materiais"] as Array),
				"'%s': o material '%s' do manifesto existe no .glb." % [id, str(m)])
		var caixa: AABB = med["caixa"]
		var esperado: Dictionary = (a as Dictionary).get("caixa", {}) as Dictionary
		assert_almost_eq(caixa.position.x, float((esperado.get("x", [0, 0]) as Array)[0]), Asset3D.TOL,
			"'%s': X minimo da caixa igual ao manifesto (%.4f)." % [id, caixa.position.x])
		assert_almost_eq(caixa.position.y, float((esperado.get("y", [0, 0]) as Array)[0]), Asset3D.TOL,
			"'%s': Y minimo da caixa igual ao manifesto (%.4f)." % [id, caixa.position.y])
		assert_almost_eq(caixa.size.x, float((esperado.get("x", [0, 0]) as Array)[1]) - float((esperado.get("x", [0, 0]) as Array)[0]), Asset3D.TOL,
			"'%s': largura da caixa igual ao manifesto (%.4f)." % [id, caixa.size.x])
		assert_almost_eq(caixa.size.y, float((esperado.get("y", [0, 0]) as Array)[1]) - float((esperado.get("y", [0, 0]) as Array)[0]), Asset3D.TOL,
			"'%s': altura da caixa igual ao manifesto (%.4f)." % [id, caixa.size.y])
		assert_almost_eq(caixa.size.z, float((esperado.get("z", [0, 0]) as Array)[1]) - float((esperado.get("z", [0, 0]) as Array)[0]), Asset3D.TOL,
			"'%s': profundidade da caixa igual ao manifesto (%.4f)." % [id, caixa.size.z])


func test_a_convencao_da_base_e_o_no_sem_transform() -> void:
	# Se o .glb viesse com transform no no, o Godot mostraria o objeto
	# deslocado/escalado e o conserto seria feito no codigo da mesa — que e o
	# que o D49 Eliminou. Entao a convencao e TRAVADA aqui.
	var c := _carregador()
	for a in (c.manifesto().get("assets", []) as Array):
		var id := str((a as Dictionary).get("id", ""))
		var no: Node3D = c.instancia(id)
		if no == null:
			continue
		add_child_autofree(no)
		assert_almost_eq(no.position.length(), 0.0, Asset3D.TOL,
			"'%s': o no raiz entra na posicao zero (quem posiciona e a tela, nao o asset)." % id)
		assert_almost_eq(no.rotation.length(), 0.0, Asset3D.TOL,
			"'%s': o no raiz entra sem rotacao." % id)
		assert_almost_eq(no.scale.length() - sqrt(3.0), 0.0, Asset3D.TOL,
			"'%s': o no raiz entra na escala 1 (padrao da unidade = largura da carta)." % id)
		var caixa: AABB = _medir(no)["caixa"]
		assert_almost_eq(caixa.position.y, 0.0, Asset3D.TOL,
			"'%s': a base do asset esta em y=0 (pousa no chao sem ajuste nenhum)." % id)


func test_asset_que_nao_existe_devolve_nulo_e_nao_inventa_geometria() -> void:
	# R3/D50: dado faltando e' erro honesto. Um asset inexistente nao pode
	# virar "um cubo qualquer no lugar", senao a tela volta a mentir em silencio.
	var c := _carregador()
	assert_true((c.registro("nao_existe_esse") as Dictionary).is_empty(),
		"Registro inexistente devolve dicionario vazio.")
	assert_false(c.existe("nao_existe_esse"), "Asset fora do manifesto nao existe.")
	assert_eq(c.cena("nao_existe_esse"), null, "Cena de asset inexistente devolve nulo.")
	assert_eq(c.instancia("nao_existe_esse"), null,
		"Instancia de asset inexistente devolve nulo (nunca geometria inventada).")


func test_o_manifesto_e_a_fonte_e_o_jogo_nao_tem_numero_de_asset() -> void:
	# O espelho do D50: o manifesto tem que ser a SO fonte dos numeros do
	# mesh. O total de triangulos vem de uma funcao que SOMA o manifesto (o
	# numero unico do peso do 3D na mesa), e nao de uma constante solta.
	var c := _carregador()
	var total: int = c.total_de_triangulos()
	var soma := 0
	for a in (c.manifesto().get("assets", []) as Array):
		soma += int((a as Dictionary).get("triangulos", 0))
	assert_eq(total, soma, "O total de triangulos do 3D e a soma do manifesto (%d)." % total)
	# A topologia tambem e do manifesto, e e ela que trava o portão de malha do
	# doc 17. Este arquivo NAO repete nenhum numero do manifesto: foi repetir
	# (os 36 triangulos estavam escritos aqui a mao) que fez o teste divergir do
	# dado sozinho quando a estrela passou de n-gon para quads.
	var reg := c.registro("estrela_teste") as Dictionary
	var topo := reg.get("topologia", {}) as Dictionary
	assert_false(topo.is_empty(), "O manifesto declara a topologia da malha do asset.")
	assert_eq(int(topo.get("ngons", -1)), 0,
		"Nenhuma face de mais de 4 lados: em contorno con cavo a diagonal e escolhida "
		+ "na hora da exportacao, entao a mesma .blend daria geometrias diferentes "
		+ "em ferramentas diferentes.")
	assert_true(int(topo.get("quads", 0)) > 0,
		"A malha tem face de 4 lados (a topologia de verdade esta no .blend).")
	assert_eq(int(topo.get("tris_fonte", -1)), 0,
		"Nenhuma face de 3 lados na fonte: o .glb tem triangulos porque o glTF so "
		+ "tem triangulos, mas o .blend nao precisa deles.")
	assert_true(bool(topo.get("fechada", false)),
		"A malha e fechada e manifold (toda aresta em exatamente 2 faces).")
	assert_eq(int(topo.get("faces", 0)) * 2, int(reg.get("triangulos", -1)),
		"Um quad da fonte vira exatamente 2 triangulos no .glb: 20 faces -> 40 tris.")
