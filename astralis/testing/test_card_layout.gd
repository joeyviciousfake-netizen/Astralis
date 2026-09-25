extends "res://testing/astralis_test_base.gd"

## test_card_layout — GUT do molde da carta em DADO (D23/R3, V1 só monstro).
## Usa os SISTEMAS REAIS (CardLayout + CardView + DataLoader + ProjectLoader +
## dado FM + duel_table.tscn). Sem Fake (R2). Bug aqui vira teste permanente.
##
## O QUE ESTE ARQUIVO TRAVA (runtime, missão molde V1):
## (1) default EMBUTIDO idêntico ao JSON oficial peça por peça (se derivar,
##     este teste quebra de propósito);
## (2) conversão por-mil -> px (x/w na largura, y/h na altura, fonte na altura);
## (3) molde VÁLIDO em layouts/ do projeto MOVE a peça (no loader e na carta);
## (4) molde AUSENTE ou INVÁLIDO cai no default (jogo nunca quebra);
## (5) peça/campo ausente = default do scan (molde parcial vale);
## (6) visible_when: ATK/DEF (monster_only) some fora de monstro, inclusive
##     depois de virar/desvirar a carta;
## (7) a carta mostra o DADO real (nome, estrelas=level, ATK/DEF, id);
## (8) a mesa real renderiza com o molde sem erro;
## (9) COMPAT Rust x Jogo (trava anti-divergência, QA 2026-09-25): matriz
##     espelhada válido/inválido — tudo que o Rust (checar_card_layout em
##     main.rs) aceita o jogo (CardLayout.validar) aceita e renderiza, tudo
##     que os dois recusam cai no default. Casos: kinds, rect somas 0-1000,
##     enums (align/visible_when/layout_for), cores hex, versão 1, canvas
##     59x86, ids snake, peças 0-9 sem repetir;
## (10) MOLDE MOVIDO no formato do Studio (layouts/card_layout_monster_default.json
##     com as 9 peças explícitas, igual ao salvar_molde_para/layout normalizar):
##     o jogo de verdade (load_from_dir + CardView) lê e move a peça;
## (11) DIVERGÊNCIAS PINADAS (não corrigir produto aqui, dono corrige): extras,
##     null explícito, z float, versão float, id longo e name número — o teste
##     prova o comportamento REAL do jogo e cita o do Rust (main.rs) no texto.
##
## Helpers de duelo/mesa (_mesa_nova) vêm de astralis_test_base.gd.
## ProjectLoaderScript vem da base - R8: uma cópia só.

const CardLayoutScript := preload("res://core/card_layout.gd")
const CardViewScript := preload("res://ui/card_view.gd")
const DataLoaderScript := preload("res://core/data_loader.gd")

## Pasta temporária (user://, fora do repo inteiro, R8). Some no after_each.
var _proj := "user://qa_card_layout_tmp"


## ---------- FIXTURE (só dado, em user://; some no after_each) ----------

func _escrever_json(caminho: String, dados: Dictionary) -> bool:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dados, "  "))
	f.close()
	return true


func _escrever_texto(caminho: String, texto: String) -> bool:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(texto)
	f.close()
	return true


func _apagar_tudo(p: String) -> void:
	var abs := ProjectSettings.globalize_path(p)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for sub in DirAccess.get_directories_at(abs):
		_apagar_tudo(p.path_join(sub))
	for arq in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(arq))
	DirAccess.remove_absolute(abs)


func _layouts_abs() -> String:
	return ProjectSettings.globalize_path(_proj.path_join("layouts"))


func _montar_layouts() -> void:
	_apagar_tudo(_proj)
	DirAccess.make_dir_recursive_absolute(_layouts_abs())


func before_each() -> void:
	_montar_layouts()


func after_each() -> void:
	_apagar_tudo(_proj)


## Molde mínimo válido (1 peça; o resto vem do default do scan).
func _molde_min() -> Dictionary:
	return {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA",
		"pieces": [{"id": "name_bar", "kind": "name",
			"rect": {"x": 100, "y": 200, "w": 300, "h": 40}}]}


func _carta_monstro() -> Dictionary:
	return {"schema_version": 1, "id": "qa_m1", "name": "Dragão QA",
		"card_type": "monster", "monster_type": "dragon", "attribute": "fire",
		"level": 4, "attack": 1800, "defense": 1200, "description": "Sopro QA."}


func _carta_magia() -> Dictionary:
	return {"schema_version": 1, "id": "qa_s1", "name": "Magia QA",
		"card_type": "spell", "description": "Efeito QA."}


func _vista_nova() -> Control:
	var vista: Control = CardViewScript.new()
	add_child_autofree(vista)
	return vista


# ---------- (1) DEFAULT EMBUTIDO = JSON OFICIAL ----------

func test_default_embitido_igual_ao_json_oficial() -> void:
	# O default embutido tem de ser idêntico ao JSON oficial peça por peça.
	# Se um número derivar, este teste quebra de propósito (trava D23).
	var caminho: String = DataLoaderScript.starter_kit_dir().path_join("layouts/card_layout_monster_default.json")
	assert_true(FileAccess.file_exists(caminho), "JSON oficial do molde existe: %s" % caminho)
	var res: Dictionary = DataLoaderScript.load_json_file(caminho)
	assert_true(bool(res.get("ok", false)), "JSON oficial abre: %s" % str(res.get("error", "")))
	var oficial: Dictionary = res.get("data", {})
	var padrao: Dictionary = CardLayoutScript.default_layout()
	assert_eq(int(padrao.get("schema_version", -1)), 1, "Default schema_version 1.")
	assert_eq(str(padrao.get("id", "")), "card_layout_monster_default", "Default tem o id oficial.")
	assert_eq(str(padrao.get("id", "")), str(oficial.get("id", "")), "Default id = oficial id.")
	assert_eq(str(padrao.get("layout_for", "")), "monster", "V1 só monstro.")
	var cv: Dictionary = padrao.get("canvas", {})
	assert_eq(float(cv.get("w", 0.0)), 59.0, "Canvas w 59.")
	assert_eq(float(cv.get("h", 0.0)), 86.0, "Canvas h 86.")
	assert_eq(str(cv.get("unit", "")), "per_mil", "Canvas em por-mil.")
	var po: Dictionary = CardLayoutScript.pecas_por_kind(padrao)
	assert_eq(po.size(), 9, "Default tem as 9 peças.")
	var oficiais: Array = oficial.get("pieces", []) as Array
	assert_eq(oficiais.size(), 9, "Oficial tem as 9 peças.")
	for o in oficiais:
		var kind := str((o as Dictionary).get("kind", ""))
		assert_true(po.has(kind), "Default tem a peça '%s'." % kind)
		var p: Dictionary = po[kind]
		var ro: Dictionary = (o as Dictionary).get("rect", {})
		var rp: Dictionary = p.get("rect", {})
		for c in ["x", "y", "w", "h"]:
			assert_eq(float(rp.get(c, -1.0)), float(ro.get(c, -2.0)), "Default '%s' rect.%s = oficial." % [kind, c])
		var so: Dictionary = (o as Dictionary).get("style", {})
		var sp: Dictionary = p.get("style", {})
		for k in so.keys():
			# JSON grava número como float (5.0); o embutido guarda int (5):
			# compara por valor, não por texto.
			if str(k) == "font_size":
				assert_eq(float(sp.get(k, -1.0)), float(so.get(k, -2.0)), "Default '%s' style.font_size = oficial." % kind)
			elif str(k) == "z":
				assert_eq(int(float(sp.get(k, -1.0))), int(float(so.get(k, -2.0))), "Default '%s' style.z = oficial." % kind)
			elif str(k) == "bold":
				assert_eq(bool(sp.get(k, false)), bool(so.get(k, true)), "Default '%s' style.bold = oficial." % kind)
			else:
				assert_eq(str(sp.get(k, "")), str(so.get(k, "")), "Default '%s' style.%s = oficial." % [kind, str(k)])
		assert_eq(str(p.get("visible_when", "")), str((o as Dictionary).get("visible_when", "")), "Default '%s' visible_when = oficial." % kind)
	assert_eq(str(po["atkdef_bar"].get("visible_when", "")), "monster_only", "ATK/DEF default só monstro.")


# ---------- (2) POR-MIL -> PX ----------

func test_por_mil_para_px() -> void:
	# x/w em ‰ da largura (130), y/h em ‰ da altura (186), fonte em ‰ da altura.
	var r: Rect2 = CardLayoutScript.rect_px({"x": 35.0, "y": 35.0, "w": 930.0, "h": 65.0}, Vector2(130, 186))
	assert_almost_eq(r.position.x, 4.55, 0.001, "Nome x 35‰ de 130.")
	assert_almost_eq(r.position.y, 6.51, 0.001, "Nome y 35‰ de 186.")
	assert_almost_eq(r.size.x, 120.9, 0.001, "Nome w 930‰ de 130.")
	assert_almost_eq(r.size.y, 12.09, 0.001, "Nome h 65‰ de 186.")
	var cheio: Rect2 = CardLayoutScript.rect_px({"x": 0.0, "y": 0.0, "w": 1000.0, "h": 1000.0}, Vector2(130, 186))
	assert_eq(cheio, Rect2(Vector2.ZERO, Vector2(130, 186)), "Frame 1000‰ = carta cheia.")
	assert_almost_eq(CardLayoutScript.fonte_px(37.0, 186.0, 14.0), 6.882, 0.001, "Fonte 37‰ de 186.")
	assert_eq(CardLayoutScript.fonte_px(null, 186.0, 14.0), 14.0, "Fonte ausente = padrão.")
	assert_eq(CardLayoutScript.fonte_px("grande", 186.0, 14.0), 14.0, "Fonte inválida = padrão.")


# ---------- (3) MOLDE VÁLIDO MOVE A PEÇA ----------

func test_molde_valido_do_projeto_move_peca() -> void:
	# layouts/ do projeto com o nome deslocado: loader e carta obedecem.
	var molde := _molde_min()
	(molde["pieces"] as Array)[0]["rect"]["x"] = 500
	assert_true(_escrever_json(_layouts_abs().path_join("card_layout_monster_default.json"), molde), "Molde QA escrito.")
	var ativo := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path(_proj))
	assert_eq(str(ativo.get("id", "")), "qa_molde_ok", "Molde do projeto foi lido (não o default).")
	var pcs: Dictionary = CardLayoutScript.pecas_por_kind(ativo)
	assert_eq(float((pcs["name"] as Dictionary)["rect"]["x"]), 500.0, "Molde moveu o nome p/ x=500.")
	assert_eq(float((pcs["name"] as Dictionary)["rect"]["y"]), 200.0, "Resto do rect veio do molde.")
	assert_eq(float((pcs["art_window"] as Dictionary)["rect"]["x"]), 90.0, "Peça ausente = default do scan.")
	var vista := _vista_nova()
	vista.setup(_carta_monstro(), ativo)
	assert_eq(str(vista.get("_layout_id")), "qa_molde_ok", "Carta usou o molde do projeto.")
	var nome := ((vista.get("_pecas") as Dictionary)["name"] as Control)
	assert_almost_eq(nome.position.x, 65.0, 0.01, "Nome andou na carta (500‰ de 130).")
	assert_almost_eq(nome.position.y, 37.2, 0.01, "Nome y 200‰ de 186.")


# ---------- (4) AUSENTE OU INVÁLIDO = DEFAULT ----------

func test_molde_ausente_usa_default_embutido() -> void:
	# Sem layouts/ (projeto legado) ou base vazia: default, sem quebrar.
	var sem_nada := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path("user://qa_clayout_vazia_xyz"))
	assert_eq(sem_nada, CardLayoutScript.default_layout(), "Base inexistente = default embutido.")
	var sem_layouts := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path(_proj))
	assert_eq(sem_layouts, CardLayoutScript.default_layout(), "Projeto sem layouts/ = default embutido.")
	assert_eq(CardLayoutScript.load_from_dir(""), CardLayoutScript.default_layout(), "Base vazia = default embutido.")


func test_molde_invalido_cai_no_default() -> void:
	# Arquivo presente mas fora do contrato: aviso + default (nunca quebra).
	assert_false(CardLayoutScript.validar(_molde_min()).is_empty(), "Preparo: molde mínimo é válido.")
	var base_ok := _molde_min()
	var casos: Array = [
		["schema_version 2", func(m: Dictionary) -> void: m["schema_version"] = 2],
		["sem id", func(m: Dictionary) -> void: m.erase("id")],
		["sem name", func(m: Dictionary) -> void: m.erase("name")],
		["layout_for spell", func(m: Dictionary) -> void: m["layout_for"] = "spell"],
		["canvas errado", func(m: Dictionary) -> void: m["canvas"] = {"w": 60, "h": 86, "unit": "per_mil"}],
		["pieces não-array", func(m: Dictionary) -> void: m["pieces"] = {}],
		["kind aberto", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["kind"] = "enfeite"],
		["kind duplicado", func(m: Dictionary) -> void: (m["pieces"] as Array).append({"id": "outro_nome", "kind": "name"})],
		["10 peças", func(m: Dictionary) -> void:
			for k in ["attribute_orb", "level_stars", "art_window", "type_line", "text_box", "atkdef_bar", "footer", "frame", "name", "name"]:
				(m["pieces"] as Array).append({"id": "p_" + k, "kind": k})],
		["x+w>1000", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 900, "y": 0, "w": 200, "h": 10}],
		["y+h>1000", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 0, "y": 990, "w": 10, "h": 20}],
		["rect sem h", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 0, "y": 0, "w": 10}],
		["cor inválida", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"color": "vermelho"}],
		["align inválido", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"align": "diagonal"}],
		["z 99", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"z": 99}],
		["fonte -1", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"font_size": -1}],
		["visible_when inválido", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["visible_when"] = "sempre"],
		["id da peça inválido", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["id"] = "Nome Bar"],
	]
	for caso in casos:
		var titulo := str(caso[0])
		var mutar: Callable = caso[1]
		var m: Dictionary = (base_ok as Dictionary).duplicate(true)
		mutar.call(m)
		assert_true(CardLayoutScript.validar(m).is_empty(), "Inválido rejeitado: %s." % titulo)
	_montar_layouts()
	assert_true(_escrever_texto(_layouts_abs().path_join("card_layout_monster_default.json"), "{quebrado"), "JSON quebrado escrito.")
	var do_disco := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path(_proj))
	assert_eq(str(do_disco.get("id", "")), "card_layout_monster_default", "JSON quebrado no disco = default.")
	assert_true(CardLayoutScript.validar("texto").is_empty(), "Texto não é molde.")
	assert_true(CardLayoutScript.validar([]).is_empty(), "Array não é molde.")


# ---------- (5) PEÇA/CAMPO AUSENTE = DEFAULT ----------

func test_peca_ausente_e_campo_ausente_viram_default() -> void:
	# Molde parcial vale: o que falta vem do scan, o que veio fica.
	var molde := _molde_min()
	(molde["pieces"] as Array)[0]["style"] = {"color": "#112233"}
	(molde["pieces"] as Array)[0]["rect"] = {"x": 100, "y": 200, "w": 300, "h": 40}
	var fundido := CardLayoutScript.validar(molde)
	assert_false(fundido.is_empty(), "Molde parcial é válido.")
	var pcs: Dictionary = CardLayoutScript.pecas_por_kind(fundido)
	assert_eq(pcs.size(), 9, "Fundido tem as 9 peças.")
	var nome: Dictionary = pcs["name"]
	assert_eq(float((nome["rect"] as Dictionary).get("x", 0.0)), 100.0, "Rect do molde fica.")
	assert_eq(str((nome["style"] as Dictionary).get("color", "")), "#112233", "Style do molde fica.")
	assert_eq(float((nome["style"] as Dictionary).get("font_size", 0.0)), 37.0, "Style ausente = default (fonte 37).")
	assert_eq(int((nome["style"] as Dictionary).get("z", 0)), 5, "Style ausente = default (z 5).")
	assert_eq(str(nome.get("visible_when", "")), "always", "visible_when ausente do nome = always.")
	assert_eq(str((pcs["atkdef_bar"] as Dictionary).get("visible_when", "")), "monster_only", "visible_when ausente do ATK = monster_only.")
	assert_eq(float(((pcs["art_window"] as Dictionary)["rect"] as Dictionary).get("x", 0.0)), 90.0, "Peça ausente = default (arte x 90).")


# ---------- (6) VISIBLE_WHEN ESCONDE ATK ----------

func test_visible_when_esconde_atk_onde_deve() -> void:
	# ATK/DEF (monster_only) só aparece em monstro; resto é always.
	var pcs: Dictionary = CardLayoutScript.pecas_por_kind(CardLayoutScript.default_layout())
	var atk: Dictionary = pcs["atkdef_bar"]
	var nome: Dictionary = pcs["name"]
	assert_true(CardLayoutScript.visivel(atk, _carta_monstro()), "ATK aparece no monstro.")
	assert_false(CardLayoutScript.visivel(atk, _carta_magia()), "ATK some na magia.")
	assert_false(CardLayoutScript.visivel(atk, {}), "ATK some sem tipo (mini do rival).")
	assert_true(CardLayoutScript.visivel(nome, {}), "Nome é always, aparece até vazio.")
	assert_true(CardLayoutScript.eh_monstro(_carta_monstro()), "Monstro detectado.")
	assert_false(CardLayoutScript.eh_monstro(_carta_magia()), "Magia não é monstro.")
	# E na carta de verdade, inclusive após virar/desvirar:
	var vista := _vista_nova()
	vista.setup(_carta_magia())
	var pecas_v: Dictionary = vista.get("_pecas")
	assert_false((pecas_v["atkdef_bar"] as Control).visible, "Magia nasce sem ATK.")
	assert_true((pecas_v["name"] as Control).visible, "Magia nasce com nome.")
	assert_eq(((pecas_v["type_line"] as Label).text), "spell", "Tipo da magia vem do dado.")
	vista.setup(_carta_monstro())
	pecas_v = vista.get("_pecas")
	assert_true((pecas_v["atkdef_bar"] as Control).visible, "Monstro nasce com ATK.")
	assert_eq(((pecas_v["type_line"] as Label).text), "dragon", "Tipo do monstro vem do dado.")
	vista.setup(_carta_magia())
	vista.set_facedown(true)
	for f in vista.get_children():
		assert_false((f as Control).visible, "Virada esconde tudo.")
	vista.set_facedown(false)
	pecas_v = vista.get("_pecas")
	assert_false((pecas_v["atkdef_bar"] as Control).visible, "Desvirada: ATK da magia SEGUE escondido.")
	assert_true((pecas_v["name"] as Control).visible, "Desvirada: nome volta.")


# ---------- (7) CARTA MOSTRA O DADO REAL ----------

func test_cardview_mostra_dado_real_fm() -> void:
	# Blue-eyes de verdade (dado FM, sem Fake): nome, 8 estrelas, ATK/DEF, id.
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var cards: Dictionary = (state.get("data", {}) as Dictionary).get("cards", {})
	assert_true((cards as Dictionary).has("fm_0001"), "Preparo: FM tem fm_0001.")
	var vista := _vista_nova()
	vista.setup((cards as Dictionary)["fm_0001"])
	var pecas_v: Dictionary = vista.get("_pecas")
	assert_eq(pecas_v.size(), 8, "Carta tem as 8 peças (frame vai no _draw).")
	assert_eq(((pecas_v["name"] as Label).text), "Blue-eyes White Dragon", "Nome vem do dado.")
	assert_eq(((pecas_v["level_stars"] as Label).text).length(), 8, "Estrelas = level (8).")
	var atk_txt := ((pecas_v["atkdef_bar"] as Label).text)
	assert_true(atk_txt.contains("3000"), "ATK 3000 na barra (texto '%s')." % atk_txt)
	assert_true(atk_txt.contains("2500"), "DEF 2500 na barra (texto '%s')." % atk_txt)
	assert_true(((pecas_v["footer"] as Label).text).contains("fm_0001"), "Rodapé traz o id.")
	assert_eq((pecas_v["attribute_orb"] as ColorRect).color, CardViewScript.cor_atributo("light"), "Orbe na cor do atributo (light).")
	assert_eq(str(vista.get("_layout_id")), "card_layout_monster_default", "Sem molde no teste, vale o default.")
	for f in vista.get_children():
		assert_eq((f as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Peça sem clique (D19).")
	assert_false(vista.has_signal("clicada"), "Sem sinal de clique (100% controle).")
	assert_eq(str((vista.get("_carta") as Dictionary).get("id", "")), "fm_0001", "Carta guardada p/ a mesa ler.")


# ---------- CARTA NUNCA QUEBRA ----------

func test_cardview_nunca_quebra() -> void:
	# Dit vazio, molde inválido, virar, selecionar, remontar: sem erro, sem lixo.
	var vista := _vista_nova()
	vista.setup({})
	var pecas_v: Dictionary = vista.get("_pecas")
	assert_eq(pecas_v.size(), 8, "Vazia monta as 8 peças.")
	assert_eq(((pecas_v["name"] as Label).text), "?", "Vazia mostra '?' (como antes).")
	assert_false((pecas_v["atkdef_bar"] as Control).visible, "Vazia não é monstro: sem ATK.")
	vista.setup(_carta_monstro(), {"invalido": true})
	assert_eq(str(vista.get("_layout_id")), "card_layout_monster_default", "Molde inválido injetado = default.")
	vista.set_facedown(true)
	assert_true(bool(vista.get("_face_down")), "Virada marca.")
	vista.set_facedown(false)
	assert_true((vista.get("_pecas") as Dictionary)["name"] != null, "Desvirada mantém peças.")
	vista.set_selected(true)
	vista.set_selected(false)
	vista.setup(_carta_magia())
	assert_eq(vista.get_child_count(), 8, "Remontar não acumula filhos.")
	assert_eq(((vista.get("_pecas") as Dictionary)["type_line"] as Label).text, "spell", "Remontada mostra o dado novo.")


# ---------- (8) MESA REAL RENDERIZA COM O MOLDE ----------

func test_mesa_real_renderiza_com_molde() -> void:
	# duel_table.tscn de verdade: a mão desenha cartas pelo molde, sem erro.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var camada: Node = mesa.get("_camada_mao")
	assert_true(camada.get_child_count() > 0, "Mesa desenha a mão (cartas reais).")
	var vistas := 0
	for v in camada.get_children():
		if v is CardViewScript:
			vistas += 1
			assert_eq(((v.get("_pecas") as Dictionary).size()), 8, "Carta da mesa tem as 8 peças.")
			assert_eq(str(v.get("_layout_id")), "card_layout_monster_default", "Carta da mesa usa o molde default.")
			var nome := ((v.get("_pecas") as Dictionary)["name"] as Control)
			assert_almost_eq(nome.position.x, 4.55, 0.01, "Nome da mesa no x do molde (35‰ de 130).")
	assert_true(vistas > 0, "Mão tem CardViews de verdade (%d)." % vistas)


# ---------- (9) COMPAT: RUST ACEITA = JOGO ACEITA E RENDERIZA ----------

func test_compat_rust_aceita_jogo_aceita_e_renderiza() -> void:
	# Espelho do checar_card_layout (main.rs:1833): estes moldes passam no Rust
	# (gate do salvar_molde_para) e TÊM de passar no jogo (validar) e renderizar.
	# Seed fixa: sem aleatório, mesmos números sempre.
	var casos_validos: Array = [
		["mínimo 1 peça", _molde_min()],
		["sem pieces (tudo default)", {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA"}],
		["default embutido completo", CardLayoutScript.default_layout()],
		["canvas ausente vale", {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA",
			"pieces": [{"id": "name_bar", "kind": "name"}]}],
		["layout_for ausente vale (default monster)", {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA",
			"pieces": [{"id": "arte", "kind": "art_window",
				"rect": {"x": 90, "y": 165, "w": 820, "h": 563}}]}],
		["style só cor (resto default)", {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA",
			"pieces": [{"id": "name_bar", "kind": "name",
				"rect": {"x": 35, "y": 35, "w": 930, "h": 65},
				"style": {"color": "#112233"}}]}],
		["borda x+w=1000 e y+h=1000", {"schema_version": 1, "id": "qa_molde_ok", "name": "Molde QA",
			"pieces": [{"id": "name_bar", "kind": "name",
				"rect": {"x": 0, "y": 0, "w": 1000, "h": 1000}}]}],
		["9 peças distintas", CardLayoutScript.default_layout()],
	]
	for caso in casos_validos:
		var titulo := str(caso[0])
		var fundido: Dictionary = CardLayoutScript.validar((caso[1] as Dictionary).duplicate(true))
		assert_false(fundido.is_empty(), "Rust aceita = jogo aceita: %s." % titulo)
		assert_eq((fundido.get("pieces", []) as Array).size(), 9, "Fundido tem 9 peças: %s." % titulo)
	# O JSON oficial passa nos dois lados (Rust tem teste molde_default_oficial_passa).
	var caminho: String = DataLoaderScript.starter_kit_dir().path_join("layouts/card_layout_monster_default.json")
	var res: Dictionary = DataLoaderScript.load_json_file(caminho)
	assert_true(bool(res.get("ok", false)), "Oficial abre no jogo.")
	var fund_oficial: Dictionary = CardLayoutScript.validar((res.get("data", {}) as Dictionary).duplicate(true))
	assert_false(fund_oficial.is_empty(), "Oficial válido no jogo (como no Rust).")
	# E renderiza de verdade (CardView real, sem Fake R2).
	var vista := _vista_nova()
	vista.setup(_carta_monstro(), _molde_min())
	assert_eq(str(vista.get("_layout_id")), "qa_molde_ok", "Carta renderizou o molde válido.")
	var nome := ((vista.get("_pecas") as Dictionary)["name"] as Control)
	assert_almost_eq(nome.position.x, 13.0, 0.01, "Nome renderizou no x do molde (100‰ de 130).")


# ---------- (9b) COMPAT: RUST RECUSA = JOGO RECUSA (cai no default) ----------

func test_compat_rust_recusa_jogo_recusa() -> void:
	# Espelho inverso: estes moldes o Rust BARRA (checar_card_layout dá erro e o
	# salvar_molde_para não grava) e o jogo TEM de recusar (validar vazio = cai
	# no default embutido, nunca quebra). Mesma lista do fm_import --check.
	var base := _molde_min()
	var casos: Array = [
		["versão 2", func(m: Dictionary) -> void: m["schema_version"] = 2],
		["versão texto abc", func(m: Dictionary) -> void: m["schema_version"] = "abc"],
		["sem id", func(m: Dictionary) -> void: m.erase("id")],
		["id maiúscula", func(m: Dictionary) -> void: m["id"] = "Molde_QA"],
		["id com espaço", func(m: Dictionary) -> void: m["id"] = "qa molde"],
		["sem name", func(m: Dictionary) -> void: m.erase("name")],
		["name vazio", func(m: Dictionary) -> void: m["name"] = ""],
		["name só espaço", func(m: Dictionary) -> void: m["name"] = "   "],
		["layout_for spell", func(m: Dictionary) -> void: m["layout_for"] = "spell"],
		["canvas w 60", func(m: Dictionary) -> void: m["canvas"] = {"w": 60, "h": 86, "unit": "per_mil"}],
		["canvas unit px", func(m: Dictionary) -> void: m["canvas"] = {"w": 59, "h": 86, "unit": "px"}],
		["pieces não-array", func(m: Dictionary) -> void: m["pieces"] = {}],
		["kind fora do enum", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["kind"] = "sombra"],
		["kind duplicado", func(m: Dictionary) -> void: (m["pieces"] as Array).append({"id": "outro_nome", "kind": "name"})],
		["10 peças", func(m: Dictionary) -> void:
			for k in ["attribute_orb", "level_stars", "art_window", "type_line", "text_box", "atkdef_bar", "footer", "frame", "name", "name"]:
				(m["pieces"] as Array).append({"id": "p_" + k, "kind": k})],
		["x+w>1000", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 900, "y": 0, "w": 200, "h": 10}],
		["y+h>1000", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 0, "y": 990, "w": 10, "h": 20}],
		["rect x -1", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": -1, "y": 0, "w": 10, "h": 10}],
		["rect w 1001", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 0, "y": 0, "w": 1001, "h": 10}],
		["rect sem h", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": 0, "y": 0, "w": 10}],
		["rect texto", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["rect"] = {"x": "esq", "y": 0, "w": 10, "h": 10}],
		["cor sem #", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"color": "2a1c08"}],
		["cor curta #fff", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"color": "#fff"}],
		["cor nome", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"color": "marrom"}],
		["align diagonal", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"align": "diagonal"}],
		["z 99", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"z": 99}],
		["z -1", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"z": -1}],
		["z texto", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"z": "alto"}],
		["fonte -1", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"font_size": -1}],
		["fonte 1001", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"font_size": 1001}],
		["bold texto", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["style"] = {"bold": "sim"}],
		["visible_when sempre", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["visible_when"] = "sempre"],
		["peça id com espaço", func(m: Dictionary) -> void: (m["pieces"] as Array)[0]["id"] = "Nome Bar"],
		["peça sem kind", func(m: Dictionary) -> void: (m["pieces"] as Array)[0].erase("kind")],
		["peça sem id", func(m: Dictionary) -> void: (m["pieces"] as Array)[0].erase("id")],
	]
	for caso in casos:
		var titulo := str(caso[0])
		var mutar: Callable = caso[1]
		var m: Dictionary = (base as Dictionary).duplicate(true)
		mutar.call(m)
		assert_true(CardLayoutScript.validar(m).is_empty(), "Rust recusa = jogo recusa: %s." % titulo)
	# E no disco o inválido cai no default (jogo nunca quebra).
	_montar_layouts()
	var ruim := (base as Dictionary).duplicate(true)
	(ruim["pieces"] as Array)[0]["kind"] = "sombra"
	assert_true(_escrever_json(_layouts_abs().path_join("card_layout_monster_default.json"), ruim), "Molde ruim escrito.")
	var do_disco := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path(_proj))
	assert_eq(str(do_disco.get("id", "")), "card_layout_monster_default", "Disco inválido = default embutido.")


# ---------- (10) MOLDE MOVIDO NO FORMATO DO STUDIO, LIDO PELO JOGO ----------

func test_molde_movido_formato_studio_lido_pelo_jogo() -> void:
	# O Studio salva layouts/card_layout_monster_default.json com as 9 peças
	# explícitas (LayoutStudio normalizar + salvar_molde_para). Este teste grava
	# NESSE formato (nome movido 35->70, w 930 mantido: 70+930=1000 cabe) e o
	# JOGO DE VERDADE lê (load_from_dir) e desenha (CardView). Sem Fake (R2).
	var oficial: Dictionary = CardLayoutScript.default_layout()
	var molde := (oficial as Dictionary).duplicate(true)
	molde["id"] = "card_layout_monster_default"
	molde["name"] = "Molde padrão de monstro (scan Blue-Eyes)"
	for p in (molde["pieces"] as Array):
		if str((p as Dictionary).get("kind", "")) == "name":
			((p as Dictionary)["rect"] as Dictionary)["x"] = 70
	assert_eq((molde["pieces"] as Array).size(), 9, "Formato Studio tem as 9 peças explícitas.")
	assert_false(CardLayoutScript.validar((molde as Dictionary).duplicate(true)).is_empty(), "Molde movido é válido nos dois lados.")
	assert_true(_escrever_json(_layouts_abs().path_join("card_layout_monster_default.json"), molde), "Molde Studio gravado no layouts/ do projeto.")
	var lido := CardLayoutScript.load_from_dir(ProjectSettings.globalize_path(_proj))
	assert_eq(str(lido.get("id", "")), "card_layout_monster_default", "Jogo leu o arquivo do Studio (não o default).")
	var pcs: Dictionary = CardLayoutScript.pecas_por_kind(lido)
	assert_eq(float(((pcs["name"] as Dictionary)["rect"] as Dictionary).get("x", 0.0)), 70.0, "Jogo moveu o nome p/ x=70.")
	assert_eq(float(((pcs["art_window"] as Dictionary)["rect"] as Dictionary).get("x", 0.0)), 90.0, "Resto ficou no oficial (arte x 90).")
	# Roundtrip pelo disco: o que volta é igual ao que o Studio salvou.
	var f := FileAccess.open(_proj.path_join("layouts/card_layout_monster_default.json"), FileAccess.READ)
	assert_true(f != null, "Arquivo do Studio existe no disco.")
	var json := JSON.new()
	assert_eq(json.parse(f.get_as_text()), OK, "Arquivo do Studio é JSON válido.")
	f.close()
	var de_volta: Dictionary = json.data
	assert_eq(float((((de_volta["pieces"] as Array)[0] as Dictionary)["rect"] as Dictionary).get("x", 0.0)), 70.0, "Disco guardou o movido.")
	# E a carta desenha no lugar novo (130px de largura: 70‰ = 9.1px).
	var vista := _vista_nova()
	vista.setup(_carta_monstro(), lido)
	assert_eq(str(vista.get("_layout_id")), "card_layout_monster_default", "Carta usou o molde do Studio.")
	var nome := ((vista.get("_pecas") as Dictionary)["name"] as Control)
	assert_almost_eq(nome.position.x, 9.1, 0.01, "Nome andou na carta (70‰ de 130).")


# ---------- (11) DIVERGÊNCIAS PINADAS RUST x JOGO (prova, sem corrigir) ----------

func test_compat_divergencias_rust_x_jogo_pinadas() -> void:
	# Cada caso abaixo PROVA uma divergência REAL entre os dois validadores:
	# o Rust (checar_card_layout, main.rs) barra e o jogo (CardLayout.validar)
	# aceita — ou o inverso. O assert trava o comportamento REAL do jogo; o
	# texto cita a linha do Rust. NÃO corrigir produto aqui: o dono corrige
	# (Sistemas no Rust ou Runtime no GDScript). QA só trava e reporta.
	# D1: campo extra no topo — Rust barra (main.rs:1869-1879), jogo ignora.
	var d1 := _molde_min()
	d1["extra"] = 1
	assert_false(CardLayoutScript.validar(d1).is_empty(), "D1 prova: jogo ACEITA topo extra; Rust RECUSA.")
	# D2: campo extra na peça — Rust barra (main.rs:1936-1943), jogo ignora.
	var d2 := _molde_min()
	(d2["pieces"] as Array)[0]["brilho"] = 5
	assert_false(CardLayoutScript.validar(d2).is_empty(), "D2 prova: jogo ACEITA peça extra; Rust RECUSA.")
	# D3: campo extra no style — Rust barra (main.rs:1999-2007), jogo ignora.
	var d3 := _molde_min()
	(d3["pieces"] as Array)[0]["style"] = {"color": "#112233", "sombra": 1}
	assert_false(CardLayoutScript.validar(d3).is_empty(), "D3 prova: jogo ACEITA style extra; Rust RECUSA.")
	# D4: canvas com chave extra — Rust barra (len==3, main.rs:1891), jogo ignora (_canvas_ok).
	var d4 := _molde_min()
	d4["canvas"] = {"w": 59, "h": 86, "unit": "per_mil", "extra": 1}
	assert_false(CardLayoutScript.validar(d4).is_empty(), "D4 prova: jogo ACEITA canvas extra; Rust RECUSA.")
	# D5: rect com chave extra — Rust barra (len==4, main.rs:1976), jogo ignora.
	var d5 := _molde_min()
	(d5["pieces"] as Array)[0]["rect"] = {"x": 35, "y": 35, "w": 930, "h": 65, "extra": 1}
	assert_false(CardLayoutScript.validar(d5).is_empty(), "D5 prova: jogo ACEITA rect extra; Rust RECUSA.")
	# D6a: rect null explícito — Rust barra (Some(Null) não tem x/y/w/h), jogo usa default.
	var d6a := _molde_min()
	(d6a["pieces"] as Array)[0]["rect"] = null
	assert_false(CardLayoutScript.validar(d6a).is_empty(), "D6a prova: jogo ACEITA rect null (default); Rust RECUSA.")
	# D6b: style null explícito — Rust barra (as_object None, main.rs:1993), jogo usa default.
	var d6b := _molde_min()
	(d6b["pieces"] as Array)[0]["style"] = null
	assert_false(CardLayoutScript.validar(d6b).is_empty(), "D6b prova: jogo ACEITA style null (default); Rust RECUSA.")
	# D6c: visible_when null explícito — Rust barra (main.rs:2063), jogo usa default.
	var d6c := _molde_min()
	(d6c["pieces"] as Array)[0]["visible_when"] = null
	assert_false(CardLayoutScript.validar(d6c).is_empty(), "D6c prova: jogo ACEITA visible_when null (default); Rust RECUSA.")
	# D7: z float 5.0 — Rust barra (as_i64, main.rs:2050), jogo aceita (int 5).
	var d7 := _molde_min()
	(d7["pieces"] as Array)[0]["style"] = {"z": 5.0}
	var f7: Dictionary = CardLayoutScript.validar(d7)
	assert_false(f7.is_empty(), "D7 prova: jogo ACEITA z 5.0; Rust RECUSA (schema pede int).")
	assert_eq(int(((CardLayoutScript.pecas_por_kind(f7)["name"] as Dictionary)["style"] as Dictionary).get("z", -1)), 5, "z 5.0 virou 5 no jogo.")
	# D8: schema_version 1.0 float — Rust barra (as_i64, main.rs:1845), jogo aceita (int 1).
	var d8 := _molde_min()
	d8["schema_version"] = 1.0
	assert_false(CardLayoutScript.validar(d8).is_empty(), "D8 prova: jogo ACEITA versão 1.0; Rust RECUSA (schema pede int).")
	# D8b: schema_version texto "1" — Rust barra (as_i64 None), jogo aceita (int("1")==1).
	var d8b := _molde_min()
	d8b["schema_version"] = "1"
	assert_false(CardLayoutScript.validar(d8b).is_empty(), "D8b prova: jogo ACEITA versão '1'; Rust RECUSA.")
	# D9: id longo 71 chars — Rust ACEITA (eh_id_snake sem teto, main.rs:103), jogo RECUSA (_eh_id máx 64).
	var d9 := _molde_min()
	d9["id"] = "a" + "x".repeat(70)
	assert_true(CardLayoutScript.validar(d9).is_empty(), "D9 prova: jogo RECUSA id 71 chars; Rust ACEITA. Direção perigosa: Studio salva, jogo ignora.")
	# D9b: peça id longa — mesma regra nos dois validadores de id.
	var d9b := _molde_min()
	(d9b["pieces"] as Array)[0]["id"] = "p" + "y".repeat(70)
	assert_true(CardLayoutScript.validar(d9b).is_empty(), "D9b prova: jogo RECUSA peça id longa; Rust ACEITA.")
	# D10: name número — Rust barra (as_str, main.rs:1861), jogo aceita (str() coage).
	var d10 := _molde_min()
	d10["name"] = 123
	assert_false(CardLayoutScript.validar(d10).is_empty(), "D10 prova: jogo ACEITA name 123; Rust RECUSA.")
