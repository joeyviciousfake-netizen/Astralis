extends GutTest

## test_project_arg — trava o --project (sistemas reais, sem Fake, sem regra nova).
## Sem o argumento, tudo sai da pasta examples/ embutida; pasta inexistente/
## inválida = avisa e usa a embutida. Bug aqui vira teste permanente.

const DataLoaderScript := preload("res://core/data_loader.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")
const ProjectLoaderScript := preload("res://core/project_loader.gd")


func test_sem_arg_usa_embutida() -> void:
	# GUT não passa --project: override vazio e base = embutida.
	assert_eq(DataLoaderScript.project_override_path(), "", "Sem --project, override vazio.")
	assert_eq(DataLoaderScript.project_base_dir(), DataLoaderScript.starter_kit_dir(), "Sem --project, base é a embutida.")


func test_pasta_invalida_reprovada() -> void:
	assert_false(DataLoaderScript.pasta_projeto_valida(""), "Vazio não é projeto válido.")
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	assert_false(DataLoaderScript.pasta_projeto_valida(repo.path_join("pasta_que_nao_existe_xyz")), "Pasta inexistente não é projeto válido.")
	assert_true(DataLoaderScript.pasta_projeto_valida(DataLoaderScript.starter_kit_dir()), "A embutida tem cara de projeto válido.")


func test_load_traz_arenas_e_base() -> void:
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	assert_true(data.has("arenas"), "load_starter_kit traz 'arenas' (só dado, sem regra).")
	assert_true((data.get("arenas", {}) as Dictionary).has("arena_starter"), "arena_starter vem junto.")
	assert_eq(str(data.get("base_dir", "")), DataLoaderScript.starter_kit_dir(), "Sem --project, base_dir é a embutida.")
	assert_eq(BoardLayoutScript.project_arena_path("arena_starter"), BoardLayoutScript.starter_arena_path(), "Sem --project, arena sai da embutida.")
	assert_eq(BoardLayoutScript.project_arena_path("arena_que_nao_existe"), BoardLayoutScript.starter_arena_path(), "Arena ausente cai na embutida.")
