extends GutTest

## test_loader_validator — GUT real sobre os sistemas de verdade (R2: sem Fake).
## Conteúdo 100% FM original: 722 fm_* em schemas/examples/cards/,
## 39 duelistas + 39 decks fm_*, fusions.json com 25081 receitas,
## duel_setup = fm_duelist_01 (Simon Muran) vs fm_duelist_03 (Jono), 8000 LP.
## Customs card_* vivem só em schemas/starter_backup/. Bug vira teste permanente.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const RuntimeValidatorScript := preload("res://core/runtime_validator.gd")

var _data: Dictionary = {}
var _counts: Dictionary = {}
var _erros: Array = []


func before_all() -> void:
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	_data = state.get("data", {})
	_counts = state.get("counts", {})
	_erros = RuntimeValidatorScript.validate(_data)
	var load_errors: Array = _data.get("load_errors", [])
	for e in load_errors:
		_erros.append(str(e))


func test_conteudo_fm_722_cartas_39_duelistas_39_decks() -> void:
	# Conteúdo FM: 722 fm_* em examples/; customs card_* só no starter_backup.
	var cards: Dictionary = _data.get("cards", {})
	var n_fm := 0
	var n_custom := 0
	for cid in cards:
		if str(cid).begins_with("fm_"):
			n_fm += 1
		if str(cid).begins_with("card_"):
			n_custom += 1
	assert_eq(n_fm, 722, "Conteúdo FM: 722 cartas fm_* em examples/cards/ (achou %d)." % n_fm)
	assert_eq(n_custom, 0, "Customs card_* saíram de examples/ (vivem no starter_backup).")
	var duelists: Dictionary = _data.get("duelists", {})
	assert_eq(duelists.size(), 39, "39 duelistas FM (achou %d)." % duelists.size())
	assert_true(duelists.has("fm_duelist_01"), "Simon Muran (fm_duelist_01) existe.")
	assert_eq(str((duelists["fm_duelist_01"] as Dictionary).get("name", "")), "Simon Muran", "fm_duelist_01 é o Simon Muran.")
	assert_true(duelists.has("fm_duelist_03"), "Jono (fm_duelist_03) existe.")
	assert_eq(str((duelists["fm_duelist_03"] as Dictionary).get("name", "")), "Jono", "fm_duelist_03 é o Jono.")
	var decks: Dictionary = _data.get("decks", {})
	assert_eq(decks.size(), 39, "39 decks FM (achou %d)." % decks.size())
	assert_true(decks.has("fm_deck_01"), "Deck FM do Simon (fm_deck_01) existe.")
	assert_true(decks.has("fm_deck_03"), "Deck FM do Jono (fm_deck_03) existe.")
	assert_eq(((decks["fm_deck_01"] as Dictionary).get("cards", []) as Array).size(), 40, "fm_deck_01 tem 40 cartas.")
	# duel_setup FM: Simon vs Jono, 8000 LP, seed 42.
	var setup: Dictionary = _data.get("duel_setup", {})
	var d1: Dictionary = setup.get("duelist1", {})
	var d2: Dictionary = setup.get("duelist2", {})
	assert_eq(str(d1.get("duelist_id", "")), "fm_duelist_01", "Duelo: jogador é o Simon Muran.")
	assert_eq(str(d1.get("deck_id", "")), "fm_deck_01", "Duelo: deck do jogador é fm_deck_01.")
	assert_eq(str(d2.get("duelist_id", "")), "fm_duelist_03", "Duelo: rival é o Jono.")
	assert_eq(str(d2.get("deck_id", "")), "fm_deck_03", "Duelo: deck do rival é fm_deck_03.")
	assert_eq(int(setup.get("starting_lp", 0)), 8000, "Duelo FM usa 8000 LP.")


func test_fm_0001_blue_eyes_valores_e_schema() -> void:
	# Contrato card.schema.json: required schema_version/id/name/card_type
	# (+ monster_type/attribute/level/attack/defense p/ monstro).
	var cards: Dictionary = _data.get("cards", {})
	assert_true(cards.has("fm_0001"), "fm_0001 existe (primeira carta FM).")
	assert_true(cards.has("fm_0722"), "fm_0722 existe (última carta FM).")
	var be: Dictionary = cards.get("fm_0001", {})
	assert_eq(int(be.get("schema_version", -1)), 1, "fm_0001 schema_version 1.")
	assert_eq(str(be.get("card_type", "")), "monster", "Blue-eyes é monstro.")
	assert_eq(int(be.get("attack", -1)), 3000, "Blue-eyes ATK 3000.")
	assert_eq(int(be.get("defense", -1)), 2500, "Blue-eyes DEF 2500.")
	for campo in ["monster_type", "attribute", "level"]:
		assert_true(be.has(campo), "fm_0001 traz '%s' (schema de monstro)." % campo)


func test_customs_preservados_no_starter_backup() -> void:
	# Customs não foram apagados: vivem em schemas/starter_backup/.
	var res_dir: String = ProjectSettings.globalize_path("res://")
	var bak: String = res_dir.path_join("../schemas/starter_backup/cards/card_dragao_branco.json").simplify_path()
	assert_true(FileAccess.file_exists(bak), "Backup guarda o custom card_dragao_branco: " + bak)


func test_validacao_do_conteudo_fm_sem_erros() -> void:
	assert_eq(_erros.size(), 0, "Validação do conteúdo FM deve passar sem erros: %s" % str(_erros))


func test_fusao_fm_receita_explicita_tem_prioridade() -> void:
	# D08: receita explícita A+B=C tem prioridade; pack FM traz 25081
	# receitas e 0 regras (sem fallback genérico — só dado, sem regra nova).
	var fusions: Dictionary = _data.get("fusions", {})
	var cards: Dictionary = _data.get("cards", {})
	assert_eq(int(fusions.get("schema_version", -1)), 1, "fusions.json usa schema_version 1.")
	var recipes: Array = fusions.get("recipes", [])
	assert_eq(recipes.size(), 25081, "Pack FM tem 25081 receitas (achou %d)." % recipes.size())

	# 1. A 1ª receita existe com entrada e resultado explícitos.
	var primeira: Dictionary = {}
	for r in recipes:
		if r is Dictionary and str((r as Dictionary).get("id", "")) == "fm_fusion_00001":
			primeira = r
	assert_false(primeira.is_empty(), "Receita 'fm_fusion_00001' deve existir.")
	var inp: Dictionary = primeira.get("input", {})
	assert_eq(str(inp.get("card_a", "")), "fm_0002", "fm_fusion_00001 pede fm_0002 (Mystical Elf).")
	assert_eq(str(inp.get("card_b", "")), "fm_0008", "fm_fusion_00001 pede fm_0008 (Mushroom Man).")
	assert_eq(str(primeira.get("result", "")), "fm_0638", "fm_fusion_00001 cria fm_0638.")

	# 2. Pack FM não traz regra genérica: só receitas explícitas.
	var rules: Array = fusions.get("rules", [])
	assert_eq(rules.size(), 0, "Pack FM não traz regra genérica (só receitas explícitas).")

	# 3. Todas as cartas citadas existem de verdade.
	for cid in [str(inp.get("card_a", "")), str(inp.get("card_b", "")), str(primeira.get("result", ""))]:
		assert_true(cards.has(cid), "Carta da fusão FM deve existir: '%s'." % cid)
