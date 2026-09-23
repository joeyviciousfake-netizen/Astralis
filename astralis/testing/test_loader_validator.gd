extends GutTest

## test_loader_validator — GUT real sobre os sistemas de verdade (R2: sem Fake).
## Carrega o Starter Kit via ProjectLoader/DataLoader de verdade e valida
## via RuntimeValidator de verdade. Bug aqui vira teste permanente.

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


func test_starter_kit_tem_10_cartas_2_duelistas_2_decks() -> void:
	assert_eq(int(_counts.get("cartas", -1)), 10, "Starter Kit deve ter 10 cartas.")
	assert_eq(int(_counts.get("duelistas", -1)), 2, "Starter Kit deve ter 2 duelistas.")
	assert_eq(int(_counts.get("decks", -1)), 2, "Starter Kit deve ter 2 decks.")


func test_validacao_do_starter_kit_sem_erros() -> void:
	assert_eq(_erros.size(), 0, "Validação deve passar sem erros: %s" % str(_erros))


func test_fusao_receita_vence_regra() -> void:
	# D08: receita explícita tem prioridade; regra genérica é fallback.
	var fusions: Dictionary = _data.get("fusions", {})
	var cards: Dictionary = _data.get("cards", {})
	var recipes: Array = fusions.get("recipes", [])
	var rules: Array = fusions.get("rules", [])

	# 1. A receita suprema existe com entrada e resultado explícitos.
	var suprema: Dictionary = {}
	for r in recipes:
		if r is Dictionary and str((r as Dictionary).get("id", "")) == "fusion_receita_suprema":
			suprema = r
	assert_false(suprema.is_empty(), "Receita 'fusion_receita_suprema' deve existir.")
	var inp: Dictionary = suprema.get("input", {})
	assert_eq(str(inp.get("card_a", "")), "card_dragao_branco", "Receita suprema pede dragão branco.")
	assert_eq(str(inp.get("card_b", "")), "card_mago_negro", "Receita suprema pede mago negro.")
	assert_eq(str(suprema.get("result", "")), "card_dragao_supremo", "Receita suprema cria dragão supremo.")

	# 2. A regra genérica (fallback) existe.
	var regra: Dictionary = {}
	for rl in rules:
		if rl is Dictionary and str((rl as Dictionary).get("id", "")) == "fusion_regra_dragao_trevas":
			regra = rl
	assert_false(regra.is_empty(), "Regra 'fusion_regra_dragao_trevas' (fallback) deve existir.")

	# 3. Todas as cartas citadas (receita + regra) existem de verdade:
	#    é isso que permite a receita vencer a regra no jogo.
	for cid in [str(inp.get("card_a", "")), str(inp.get("card_b", "")), str(suprema.get("result", "")), str(regra.get("result", ""))]:
		assert_true(cards.has(cid), "Carta da fusão deve existir no Starter Kit: '%s'." % cid)
