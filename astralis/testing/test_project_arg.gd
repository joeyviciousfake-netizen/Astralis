extends "res://testing/astralis_test_base.gd"

## test_project_arg — trava o --project (sistemas REAIS, sem Fake, sem regra nova).
## Bug aqui vira teste permanente.
##
## O QUE ESTE ARQUIVO TRAVA (runtime e9aafe9 + D29):
## (1) --project com pasta VÁLIDA -> o jogo lê cartas/duelistas/decks/fusões/
##     duel_setup/arenas de lá (e NÃO de schemas/examples/, que é só teste);
## (2) as duas formas de escrever o argumento: --project <pasta> e
##     --project=<pasta> dão o MESMO resultado;
## (3) caminho RELATIVO resolve a partir da raiz do REPO (_resolver_abs), e
##     relativo inválido avisa em PT-BR e cai na embutida;
## (4) --setup <arquivo> por cima do --project: o duel_setup do setup VENCE o
##     do projeto (a arena escolhida muda junto), sem trocar a base do resto;
## (5) --setup com caminho INVÁLIDO = aviso em PT-BR e segue com o do projeto;
## (6) REGRA NOVA: base de PROJETO + arena ausente lá -> project_arena_path()
##     devolve "" e o jogo usa a GRADE PADRÃO embutida (20 slots, espelho
##     correto, mão no fallback). D29: examples/ é SÓ TESTE, nunca é lido
##     quando a base é um projeto de verdade.
##
## COMO TESTA A LINHA DE COMANDO (leia antes de mexer):
## o GUT roda headless e NÃO recebe --project, e o Godot 4.7 NÃO deixa
## reescrever os args de usuário depois de iniciado (não existe
## OS.set_cmdline_user_args). Então a única forma honesta de exercitar a CLI
## é RODAR O JOGO DE VERDADE como processo filho, com os mesmos argumentos que
## o Studio passa, e ler o que ele imprimiu: `OS.execute` com o próprio
## executável, `--headless --quit-after`, e `--` antes dos args de usuário.
## Nada aqui é dublê: quem lê a pasta é o DataLoader real e quem monta a mesa
## é a duel_table.tscn real. O que este arquivo chama de função real
## (pasta_projeto_valida, _resolver_abs, load_arena_data, project_arena_path,
## default_pos, get_pos) é o mesmo código que o jogo usa.
##
## O QUE DÁ PARA CHAMAR DIRETO (sem processo filho): as funções que recebem o
## caminho como parâmetro — DataLoader.pasta_projeto_valida(p),
## DataLoader._resolver_abs(p) e BoardLayout.load_arena_data/
## load_arena/default_pos/get_pos. O que NÃO dá: project_base_dir(),
## load_starter_kit() e project_arena_path(), que leem sozinhas o
## override_path() vindo da linha de comando. Por isso o caminho feliz vai
## pelo processo filho.
##
## A pasta de teste fica em user:// (fora do repo inteiro, R8) e some no
## after_each. O conteúdo dela é mínimo e identificável (qa_carta_1,
## qa_duelist_1, qa_deck_1) para dar para provar que o jogo leu de lá.

const DataLoaderScript := preload("res://core/data_loader.gd")
const BoardLayoutScript := preload("res://core/board_layout.gd")
# ProjectLoaderScript vem da base (astralis_test_base.gd) - R8: uma cópia só.

## Pasta de projeto montada na hora (user://).
var _proj := "user://qa_project_arg_tmp"


## ---------- FIXTURE (só dado, em user://; some no after_each) ----------

func _escrever_json(caminho: String, dados: Dictionary) -> bool:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dados, "  "))
	f.close()
	return true


func _apagar_tudo(p: String) -> void:
	var abs := ProjectSettings.globalize_path(p)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for sub in ["cards", "duelists", "decks", "arenas"]:
		_apagar_tudo(p.path_join(sub))
	for arq in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(arq))
	DirAccess.remove_absolute(abs)


func _setup_do_projeto(arena_id: String) -> Dictionary:
	# duel_setup no contrato de schemas/duel_setup.schema.json.
	return {
		"schema_version": 1,
		"duel_id": "qa_duelo_1",
		"duelist1": {"duelist_id": "qa_duelist_1", "deck_id": "qa_deck_1"},
		"duelist2": {"duelist_id": "qa_duelist_1", "deck_id": "qa_deck_1"},
		"starting_lp": 7777,
		"turn_order": "first_p1",
		"seed": 42,
		"arena_id": arena_id,
		"win": {"on_lp_zero": true, "on_deckout": true},
	}


func _montar_projeto(sem_arena: bool) -> void:
	# Refaz a pasta do zero. `sem_arena` = projeto SEM arenas/ (o caso do D29,
	# aberto pelo Editor, que recria o esqueleto vazio).
	_apagar_tudo(_proj)
	# Marcadores que o DataLoader reconhece: cards/ duelists/ decks/ arenas/.
	# FileAccess NÃO cria as pastas sozinho, então criamos antes de escrever.
	var subpastas := ["cards", "duelists", "decks"]
	if not sem_arena:
		subpastas.append("arenas")
	for sub in subpastas:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_proj.path_join(sub)))
	_escrever_json(_proj.path_join("cards/qa_carta_1.json"), {
		"schema_version": 1, "id": "qa_carta_1", "name": "Carta QA", "card_type": "monster",
		"monster_type": "dragon", "attribute": "fire", "level": 4, "attack": 1800, "defense": 1200,
	})
	_escrever_json(_proj.path_join("duelists/qa_duelist_1.json"), {
		"schema_version": 1, "id": "qa_duelist_1", "name": "Duelista QA", "starting_lp": 4000,
	})
	_escrever_json(_proj.path_join("decks/qa_deck_1.json"), {
		"schema_version": 1, "id": "qa_deck_1", "name": "Deck QA",
		"cards": [{"card_id": "qa_carta_1", "count": 40}],
	})
	_escrever_json(_proj.path_join("fusions.json"), {"schema_version": 1, "recipes": [], "rules": []})
	_escrever_json(_proj.path_join("effects.json"), {"schema_version": 1, "effects": []})
	_escrever_json(_proj.path_join("duel_setup.json"), _setup_do_projeto("arena_qa_1"))
	if not sem_arena:
		# Arena do projeto, com XY próprio (prova que a arena do projeto é lida).
		var slots: Array = []
		for lado in [0, 1]:
			for i in range(5):
				slots.append({"slot_id": BoardLayoutScript.slot_id(lado, "monstro", i), "x": 100 + lado * 10 + i, "y": 200 + i})
				slots.append({"slot_id": BoardLayoutScript.slot_id(lado, "magia", i), "x": 300 + lado * 10 + i, "y": 400 + i})
		_escrever_json(_proj.path_join("arenas/arena_qa_1.json"), {
			"schema_version": 1, "id": "arena_qa_1", "name": "Arena QA", "slots": slots,
		})


func before_each() -> void:
	# Recomeça limpo: se uma rodada anterior morreu, não sobra nada (R8).
	_montar_projeto(false)


func after_each() -> void:
	_apagar_tudo(_proj)
	_apagar_tudo("user://qa_project_arg_vazia")


## ---------- RODAR O JOGO DE VERDADE (única via da linha de comando) ----------

func _rodar_jogo(args_usuario: Array) -> String:
	# Lança o jogo real com os args de usuário e devolve tudo que ele imprimiu.
	# `saida` volta como Array de linhas (a última costuma vir sem \n).
	var cmd := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--quit-after", "60",
		"--",
	])
	cmd.append_array(PackedStringArray(args_usuario))
	var linhas: Array = []
	var codigo: int = OS.execute(OS.get_executable_path(), cmd, linhas, false)
	var texto := ""
	for linha in linhas:
		texto += str(linha) + "\n"
	if codigo != 0:
		return "FALHOU_O_EXEC codigo=" + str(codigo) + "\n" + texto
	return texto


func _contem(saida: String, agulha: String) -> bool:
	return saida.contains(agulha)


# ---------- CAMINHO NEGATIVO (o que já existia) ----------

func test_sem_arg_usa_embutida() -> void:
	# GUT não passa --project: override vazio e base = embutida.
	assert_eq(DataLoaderScript.project_override_path(), "", "Sem --project, override vazio.")
	assert_eq(DataLoaderScript.project_base_dir(), DataLoaderScript.starter_kit_dir(), "Sem --project, base é a embutida.")


func test_pasta_invalida_reprovada() -> void:
	assert_false(DataLoaderScript.pasta_projeto_valida(""), "Vazio não é projeto válido.")
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	assert_false(DataLoaderScript.pasta_projeto_valida(repo.path_join("pasta_que_nao_existe_xyz")), "Pasta inexistente não é projeto válido.")
	assert_true(DataLoaderScript.pasta_projeto_valida(DataLoaderScript.starter_kit_dir()), "A embutida tem cara de projeto válido.")


func test_pasta_valida_reconhece_os_marcadores() -> void:
	# Pasta de projeto = tem ao menos UM marcador (cards/ duelists/ decks/
	# arenas/ ou duel_setup.json/fusions.json/effects.json). Sem marcador
	# nenhuma = inválida, mesmo que a pasta exista.
	var abs := ProjectSettings.globalize_path(_proj)
	assert_true(DataLoaderScript.pasta_projeto_valida(_proj), "Projeto de teste (com cards/) é válido.")
	for sub in ["cards", "duelists", "decks", "arenas"]:
		assert_true(DirAccess.dir_exists_absolute(abs.path_join(sub)), "Marcador %s/ existe na pasta de teste." % sub)
	# Pasta que existe mas não tem nenhum marcador = inválida.
	var vazia := "user://qa_project_arg_vazia"
	_apagar_tudo(vazia)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(vazia))
	assert_true(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(vazia)), "Pasta vazia existe...")
	assert_false(DataLoaderScript.pasta_projeto_valida(vazia), "...mas não é projeto válido (nenhum marcador).")
	_apagar_tudo(vazia)


func test_load_traz_arenas_e_base() -> void:
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	assert_true(data.has("arenas"), "load_starter_kit traz 'arenas' (só dado, sem regra).")
	assert_true((data.get("arenas", {}) as Dictionary).has("arena_starter"), "arena_starter vem junto.")
	assert_eq(str(data.get("base_dir", "")), DataLoaderScript.starter_kit_dir(), "Sem --project, base_dir é a embutida.")
	assert_eq(BoardLayoutScript.project_arena_path("arena_starter"), BoardLayoutScript.starter_arena_path(), "Sem --project, arena sai da embutida.")
	assert_eq(BoardLayoutScript.project_arena_path("arena_que_nao_existe"), BoardLayoutScript.starter_arena_path(), "Arena ausente cai na embutida.")


# ---------- (3) CAMINHO RELATIVO (função real chamada direto) ----------

func test_caminho_relativo_resolve_na_raiz_do_repo() -> void:
	# (3) _resolver_abs: relativo = raiz do REPO (res:// ..), não o CWD e
	# não res://. Essa é a função REAL que o --project usa por baixo.
	assert_eq(DataLoaderScript._resolver_abs(""), "", "Caminho vazio não resolve.")
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	assert_eq(DataLoaderScript._resolver_abs("schemas/examples"), repo.path_join("schemas/examples").simplify_path(), "Relativo resolve a partir da raiz do repo.")
	assert_ne(DataLoaderScript._resolver_abs("schemas/examples"), ProjectSettings.globalize_path("res://").path_join("schemas/examples"), "Não resolve a partir de res:// (pasta do projeto), e sim da raiz do repo.")
	assert_true(DirAccess.dir_exists_absolute(DataLoaderScript._resolver_abs("schemas/examples")), "A pasta resolvida existe de verdade no disco.")
	assert_eq(DataLoaderScript._resolver_abs("res://core"), ProjectSettings.globalize_path("res://core").simplify_path(), "res:// vira caminho de disco.")
	# Relativo válido aceito como projeto:
	assert_true(DataLoaderScript.pasta_projeto_valida("schemas/examples"), "Relativo aceito como pasta de projeto (tem os marcadores).")
	# Relativo inválido reprovado (o jogo avisa e usa a embutida, testado no
	# processo filho mais abaixo):
	assert_false(DataLoaderScript.pasta_projeto_valida("schemas/pasta_que_nao_existe_xyz"), "Relativo inexistente não é projeto válido.")


func test_project_relativo_no_jogo_resolve_na_raiz_do_repo() -> void:
	# (3b) O mesmo relativo, agora no jogo de verdade. A pasta pedida
	# ("schemas/examples") NÃO existe dentro de res:// (a pasta do projeto
	# Godot), então se o runtime resolvesse por ali ele cairia no aviso +
	# embutida. Só sai daqui sem aviso se resolveu pela raiz do repo.
	var esperado: String = DataLoaderScript.starter_kit_dir()
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://").path_join("schemas")), "res:// não tem schemas/ (o relativo só existe na raiz do repo).")
	var saida := _rodar_jogo(["--project", "schemas/examples"])
	assert_true(_contem(saida, "[DataLoader] --project usando: " + esperado), "Relativo resolveu na raiz do repo: %s" % saida)
	assert_false(_contem(saida, "[DataLoader] Aviso: --project ignorado"), "Relativo válido não gera aviso.")


func test_project_relativo_invalido_avisa_e_usa_embutida() -> void:
	# (3c) Relativo que não existe = aviso PT-BR e o jogo segue na embutida.
	var saida := _rodar_jogo(["--project", "schemas/pasta_que_nao_existe_xyz"])
	assert_true(_contem(saida, "[DataLoader] Aviso: --project ignorado"), "Avisa que ignorou o --project inválido: %s" % saida)
	assert_true(_contem(saida, "usando embutida"), "Aviso diz que usa a embutida.")
	assert_true(_contem(saida, "[TABLE] Arena carregada: 20 slots"), "Jogo seguiu na embutida (arena do starter).")
	assert_true(_contem(saida, "[TABLE] Duelo come"), "Duelo começou com o conteúdo FM da embutida.")


# ---------- (1) e (2) CAMINHO FELIZ: --project VÁLIDO ----------

func test_project_valido_jogo_le_tudo_da_pasta() -> void:
	# (1) --project com pasta que TEM os marcadores. O jogo tem de ler de lá:
	# o conteúdo FM tem 25081 receitas de fusão, então "0 receitas + 0
	# regras" só pode ter vindo do fusions.json da pasta de teste.
	var abs := ProjectSettings.globalize_path(_proj)
	assert_true(DataLoaderScript.pasta_projeto_valida(_proj), "Preparo: a pasta montada é projeto válido.")
	var saida := _rodar_jogo(["--project", abs])
	assert_true(_contem(saida, "[DataLoader] --project usando: " + abs), "Base do jogo = a pasta do projeto: %s" % saida)
	assert_false(_contem(saida, "[DataLoader] Aviso: --project ignorado"), "Pasta válida não gera aviso.")
	assert_true(_contem(saida, "receitas + 0 regras"), "fusions.json veio da pasta do projeto (o FM tem 25081).")
	assert_true(_contem(saida, "[TABLE] Arena carregada: 20 slots"), "Arena veio da pasta do projeto.")
	assert_true(_contem(saida, "[TABLE] Duelo come"), "Duelo montou com cartas/duelistas/decks do projeto.")


func test_project_igual_mesmo_resultado_que_espaco() -> void:
	# (2) --project=<pasta> é a MESMA coisa que --project <pasta>.
	var abs := ProjectSettings.globalize_path(_proj)
	var com_espaco := _rodar_jogo(["--project", abs])
	var com_igual := _rodar_jogo(["--project=" + abs])
	assert_true(_contem(com_espaco, "[DataLoader] --project usando: " + abs), "Forma com espaço: base = a pasta. %s" % com_espaco)
	assert_true(_contem(com_igual, "[DataLoader] --project usando: " + abs), "Forma com '=': base = a mesma pasta. %s" % com_igual)
	assert_false(_contem(com_igual, "[DataLoader] Aviso: --project ignorado"), "Forma com '=' não gera aviso.")
	for marca in ["receitas + 0 regras", "[TABLE] Arena carregada: 20 slots", "[TABLE] Duelo come"]:
		assert_true(_contem(com_espaco, marca), "Controle '%s' presente na forma com espaço." % marca)
		assert_true(_contem(com_igual, marca), "Controle '%s' presente na forma com '='." % marca)


# ---------- (4) e (5) --setup POR CIMA DO --project ----------

func test_setup_por_cima_do_project_vence_o_duel_setup() -> void:
	# (4) O duel_setup do --setup VENCE o do projeto. Prova observável: a
	# arena vem de duel_setup.arena_id, então um arena_id que NÃO existe só
	# acontece se o setup ganhou. O controle (mesmo projeto sem --setup)
	# carrega a arena, então a diferença é do --setup mesmo.
	var abs := ProjectSettings.globalize_path(_proj)
	var controle := _rodar_jogo(["--project", abs])
	assert_true(_contem(controle, "[TABLE] Arena carregada: 20 slots"), "Controle: sem setup, vale a arena do projeto: %s" % controle)
	var caminho_setup := _proj.path_join("qa_setup_override.json")
	_escrever_json(caminho_setup, _setup_do_projeto("arena_que_nao_existe_xyz"))
	var saida := _rodar_jogo(["--project", abs, "--setup", ProjectSettings.globalize_path(caminho_setup)])
	assert_true(_contem(saida, "[DataLoader] --project usando: " + abs), "--project continua valendo: %s" % saida)
	assert_true(_contem(saida, "[DataLoader] --setup usando: " + ProjectSettings.globalize_path(caminho_setup)), "--setup foi lido por cima.")
	assert_true(_contem(saida, "[TABLE] Aviso: arena "), "duel_setup do setup venceu: ele pediu uma arena que não existe.")
	assert_false(_contem(saida, "[TABLE] Arena carregada"), "A arena do projeto NÃO foi usada (o setup mandou).")
	assert_true(_contem(saida, "[TABLE] Duelo come"), "O jogo continua jogável com o setup por cima.")


func test_setup_invalido_avisa_e_segue_com_o_do_projeto() -> void:
	# (5) --setup apontando para arquivo inexistente = aviso PT-BR e o jogo
	# continua com o duel_setup do PROJETO (a arena do projeto carrega).
	var abs := ProjectSettings.globalize_path(_proj)
	var quebrado := ProjectSettings.globalize_path(_proj.path_join("nao_existe_xyz.json"))
	var saida := _rodar_jogo(["--project", abs, "--setup", quebrado])
	assert_true(_contem(saida, "[DataLoader] Aviso: --setup ignorado"), "Avisa que ignorou o --setup inválido: %s" % saida)
	assert_true(_contem(saida, "usando starter"), "Aviso diz que segue o starter (o do projeto).")
	assert_false(_contem(saida, "[DataLoader] --setup usando:"), "Não tentou usar o setup quebrado.")
	assert_true(_contem(saida, "[TABLE] Arena carregada: 20 slots"), "Seguiu com o duel_setup do projeto (arena dele carregou).")
	assert_true(_contem(saida, "[TABLE] Duelo come"), "Jogo continua rodando de verdade.")


# ---------- (6) ARENA AUSENTE NO PROJETO = GRADE PADRÃO (D29) ----------

func test_arena_ausente_no_projeto_usa_grade_padrao_com_espelho() -> void:
	# (6) REGRA NOVA: base de PROJETO (não embutida) + arena ausente lá =>
	# project_arena_path() devolve "" e o jogo usa a grade padrão embutida.
	_montar_projeto(true) # projeto SEM arenas/
	var abs := ProjectSettings.globalize_path(_proj)
	assert_ne(abs, DataLoaderScript.starter_kit_dir(), "Preparo: a base é um PROJETO, não a embutida.")
	assert_false(DirAccess.dir_exists_absolute(abs.path_join("arenas")), "Preparo: o projeto não tem arenas/.")
	# (6a) No jogo de verdade: o BoardLayout avisa que a arena não existe no
	# projeto e devolve "", a mesa cai na grade padrão e o duelo continua.
	var saida := _rodar_jogo(["--project", abs])
	assert_true(_contem(saida, "[DataLoader] --project usando: " + abs), "Base = a pasta do projeto: %s" % saida)
	assert_true(_contem(saida, "[ARENA] Arena 'arena_qa_1' "), "Arena pedida não existe no projeto (D29: não lê examples/).")
	assert_true(_contem(saida, "[ARENA] Sem arena no projeto"), "BoardLayout devolveu caminho vazio e avisou.")
	assert_true(_contem(saida, "[TABLE] Aviso: arena "), "Mesa cai na grade padrão embutida.")
	assert_false(_contem(saida, "[TABLE] Arena carregada"), "Nenhuma arena foi carregada (nem a de examples/).")
	assert_true(_contem(saida, "[TABLE] Duelo come"), "Jogo segue jogável sem arena no projeto.")
	# (6b) A grade padrão embutida: 20 slots, IDs válidos, espelho correto e
	# mão no fallback. Este é o mesmo caminho que load_arena_data("") devolve.
	var arena: Dictionary = BoardLayoutScript.load_arena_data("")
	assert_true((arena.get("slots", {}) as Dictionary).is_empty(), "Sem caminho de arena, load_arena_data volta sem slots (usa a grade padrão).")
	var total := 0
	for lado in [0, 1]:
		for i in range(5):
			for tipo in ["monstro", "magia"]:
				var sid: String = BoardLayoutScript.slot_id(lado, tipo, i)
				assert_true(BoardLayoutScript.eh_slot_valido(sid), "Slot '%s' segue o contrato p0/p1+m/s+0-4." % sid)
				assert_eq(BoardLayoutScript.get_pos({}, sid), BoardLayoutScript.default_pos(sid), "Slot '%s' cai na grade padrão embutida." % sid)
				total += 1
	assert_eq(total, 20, "Grade padrão tem 20 slots (5 monstro + 5 magia em cada lado).")
	# Espelho correto: rival com X invertido (índice 0 à direita) e fileiras
	# trocadas (monstro perto do centro, magia longe).
	assert_true(BoardLayoutScript.default_pos("p1_m0").x > BoardLayoutScript.default_pos("p1_m4").x, "Espelho: p1_m0 à direita de p1_m4.")
	assert_eq(BoardLayoutScript.default_pos("p1_m0").x, BoardLayoutScript.default_pos("p0_m4").x, "Espelho horizontal: p1_m0.x == p0_m4.x.")
	assert_eq(BoardLayoutScript.default_pos("p1_s0").x, BoardLayoutScript.default_pos("p1_m0").x, "Magia do rival na mesma coluna do monstro.")
	assert_eq(BoardLayoutScript.default_pos("p1_s4").x, BoardLayoutScript.default_pos("p1_m4").x, "Magia do rival espelha a coluna do monstro.")
	assert_eq(BoardLayoutScript.default_pos("p1_m2").x, BoardLayoutScript.default_pos("p0_m2").x, "Meio espelha no mesmo X.")
	assert_eq(BoardLayoutScript.default_pos("p1_m0").y, 317.0, "Monstro do rival perto do centro (y=317).")
	assert_eq(BoardLayoutScript.default_pos("p1_s0").y, 128.0, "Magia do rival longe (y=128).")
	assert_eq(BoardLayoutScript.default_pos("p0_m0").y, 600.0, "Seu monstro perto (y=600).")
	assert_eq(BoardLayoutScript.default_pos("p0_s0").y, 789.0, "Sua magia longe (y=789).")
	# A mão também cai no fallback embutido (nada quebra sem arena).
	assert_eq(BoardLayoutScript.get_hand(arena, 0), BoardLayoutScript.default_hand(0), "Mão p0 no fallback embutido (1240/980/95).")
	assert_eq(BoardLayoutScript.get_hand(arena, 1), BoardLayoutScript.default_hand(1), "Mão p1 no fallback embutido (1240/20/60).")
	# E a grade padrão tem OS MESMOS números do arena_starter: trocar a base
	# para um projeto sem arena não muda uma única coordenada do desenho.
	var starter_slots: Dictionary = BoardLayoutScript.load_arena(BoardLayoutScript.starter_arena_path())
	assert_eq(starter_slots.size(), 20, "arena_starter (pasta de teste) também tem 20 slots.")
	for sid in starter_slots.keys():
		assert_eq(BoardLayoutScript.default_pos(str(sid)), starter_slots[sid] as Vector2, "Grade padrão bate com arena_starter em '%s' (D29)." % str(sid))
