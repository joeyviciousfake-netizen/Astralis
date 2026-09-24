extends GutTest

## test_gamepad — GUT do controle 100% gamepad na mesa (D26, R2: sem Fake).
## Usa o InputMap real (project.godot) + o script real da mesa
## (duel_table.gd) via cena real. Sem gamepad físico: simula com
## Input.action_press/action_release + chama o passo do cursor
## (_pad_mover/_pad_cancelar). START reservado (pausar sem ação).
## Trava D26 parcial: 11 ações só-joypad (zero teclado/mouse) + mesa
## sem controle clicável (sinal clicada removido de verdade).
## Bug aqui vira teste permanente.

const TableScript := preload("res://ui/duel_table.gd")
const CardViewScript := preload("res://ui/card_view.gd")
const MesaScene := preload("res://ui/duel_table.tscn")

const ACOES_CONTROLE := [
	"mover_cima", "mover_baixo", "mover_esq", "mover_dir",
	"confirmar", "cancelar",
	"posicao_l1", "posicao_r1", "detalhes", "sair_duelo", "pausar",
]
const ACOES_MOVER := ["mover_cima", "mover_baixo", "mover_esq", "mover_dir"]


func _assinatura(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		return "btn:%d" % int((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		return "eixo:%d:%+.1f" % [int((ev as InputEventJoypadMotion).axis), float((ev as InputEventJoypadMotion).axis_value)]
	return "outro:%s" % ev.get_class()


func test_11_acoes_de_controle_existem() -> void:
	assert_eq(ACOES_CONTROLE.size(), 11, "Controle D26 tem 11 ações.")
	for acao in ACOES_CONTROLE:
		assert_true(InputMap.has_action(str(acao)), "Ação '%s' existe no InputMap." % str(acao))
	assert_false(InputMap.has_action("passar_turno"), "passar_turno não existe (START reservado, D26).")


func test_confirmar_e_cancelar_sao_botoes_diferentes() -> void:
	var ev_conf: Array = InputMap.action_get_events("confirmar")
	var ev_canc: Array = InputMap.action_get_events("cancelar")
	assert_true(ev_conf.size() > 0, "confirmar tem ao menos 1 botão.")
	assert_true(ev_canc.size() > 0, "cancelar tem ao menos 1 botão.")
	var sig_conf := {}
	for ev in ev_conf:
		sig_conf[_assinatura(ev)] = true
	var sobreposicao: Array = []
	for ev in ev_canc:
		var s := _assinatura(ev)
		if sig_conf.has(s):
			sobreposicao.append(s)
	assert_true(sobreposicao.is_empty(), "confirmar e cancelar não dividem botão (sobreposição: %s)." % str(sobreposicao))


func test_mover_so_tem_evento_de_joypad() -> void:
	for acao in ACOES_MOVER:
		var eventos: Array = InputMap.action_get_events(str(acao))
		assert_true(eventos.size() > 0, "'%s' tem ao menos 1 evento." % str(acao))
		for ev in eventos:
			assert_true(ev is InputEventJoypadButton or ev is InputEventJoypadMotion, "'%s' só usa joypad (achou %s)." % [str(acao), ev.get_class()])
			assert_false(ev is InputEventKey, "'%s' não tem tecla de teclado." % str(acao))
			assert_false(ev is InputEventMouseButton, "'%s' não tem botão de mouse." % str(acao))


func test_cursor_anda_e_volta_passo_real() -> void:
	# Cena real (mesa jogável de verdade). Simula o direcional sem
	# gamepad físico e anda 1 passo p/ direita + volta p/ esquerda.
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var fileira_ini: int = int(mesa.get("_pad_fileira"))
	assert_eq(fileira_ini, TableScript.FILEIRA_MAO, "Cursor começa na fileira da mão.")
	var col_ini: int = int(mesa.get("_pad_col"))
	var larg: int = int(mesa.call("_pad_largura_fileira", fileira_ini))
	assert_true(larg > 1, "Preparo: mão tem %d cartas, dá p/ andar esq/dir." % larg)
	# Segura o direcional (simula o controle) e dá 1 passo real.
	Input.action_press("mover_dir")
	assert_true(Input.is_action_pressed("mover_dir"), "Direcional simulado fica pressionado.")
	mesa.call("_pad_mover", 1, 0)
	Input.action_release("mover_dir")
	assert_false(Input.is_action_pressed("mover_dir"), "Direcional simulado solta após o passo.")
	var col_meio: int = int(mesa.get("_pad_col"))
	assert_eq(col_meio, posmod(col_ini + 1, larg), "1 passo p/ direita anda 1 casa.")
	assert_ne(col_meio, col_ini, "Cursor saiu da posição inicial.")
	# Volta 1 passo p/ esquerda e cai na posição inicial.
	Input.action_press("mover_esq")
	mesa.call("_pad_mover", -1, 0)
	Input.action_release("mover_esq")
	var col_volta: int = int(mesa.get("_pad_col"))
	assert_eq(col_volta, col_ini, "1 passo p/ esquerda volta à posição inicial.")
	assert_eq(int(mesa.get("_pad_fileira")), fileira_ini, "Fileira não mudou no passo lateral.")


func test_cancelar_desfaz_escolha_real() -> void:
	# Cancelar da mesa real: limpa a carta escolhida (volta ao neutro).
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	assert_true(is_instance_valid(mesa), "Mesa real instanciada p/ cancelar.")
	mesa.set("_sel_mao", 0)
	mesa.call("_pad_cancelar")
	assert_eq(int(mesa.get("_sel_mao")), -1, "cancelar limpa a carta escolhida.")
	assert_eq(int(mesa.get("_sel_atk")), -1, "cancelar deixa sem atacante escolhido.")


func test_todas_11_acoes_so_joypad_zero_teclado_mouse() -> void:
	# D26 parcial (100% controle): TODAS as 11 ações só usam joypad
	# (botão/eixo). Zero tecla de teclado, zero evento de mouse.
	# Se o runtime recolocar um atalho de teclado/mouse, este teste quebra.
	assert_eq(ACOES_CONTROLE.size(), 11, "Controle D26 tem 11 ações.")
	for acao in ACOES_CONTROLE:
		var eventos: Array = InputMap.action_get_events(str(acao))
		assert_true(eventos.size() > 0, "'%s' tem ao menos 1 evento." % str(acao))
		var n_teclado := 0
		var n_mouse := 0
		for ev in eventos:
			if ev is InputEventKey:
				n_teclado += 1
			if ev is InputEventMouseButton or ev is InputEventMouseMotion:
				n_mouse += 1
			assert_true(ev is InputEventJoypadButton or ev is InputEventJoypadMotion, "'%s' só usa joypad (achou %s)." % [str(acao), ev.get_class()])
		assert_eq(n_teclado, 0, "'%s' tem zero tecla de teclado." % str(acao))
		assert_eq(n_mouse, 0, "'%s' tem zero evento de mouse." % str(acao))


func _coletar_arvore(n: Node, out: Array) -> void:
	out.append(n)
	for f in n.get_children():
		_coletar_arvore(f, out)


func test_mesa_sem_controle_clicavel() -> void:
	# D26 parcial (100% controle): a mesa não tem controle clicável.
	# (a) Texto da cena: nenhum Button/TextureButton declarado.
	var caminho := "res://ui/duel_table.tscn"
	assert_true(FileAccess.file_exists(caminho), "duel_table.tscn existe.")
	var arq := FileAccess.open(caminho, FileAccess.READ)
	if arq == null:
		assert_true(false, "duel_table.tscn abre p/ leitura.")
		return
	var texto := arq.get_as_text()
	assert_false(texto.contains("Button"), "duel_table.tscn sem Button/TextureButton (só controle).")
	# (b) Cena real: nenhum BaseButton + textos sem clique (o que a mesa expõe).
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	assert_true(is_instance_valid(mesa), "Mesa real instanciada p/ varredura.")
	assert_eq((mesa as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "Raiz da mesa não recebe clique.")
	var todos: Array = []
	_coletar_arvore(mesa, todos)
	var n_botao := 0
	var n_texto_clicavel := 0
	var n_carta_clicavel := 0
	for n in todos:
		if n is BaseButton:
			n_botao += 1
		if n is Label and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			n_texto_clicavel += 1
		if n is CardViewScript:
			assert_false((n as Node).has_signal("clicada"), "Carta sem sinal clicada (100% controle).")
			if (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				n_carta_clicavel += 1
	assert_eq(n_botao, 0, "Mesa real tem zero botão clicável.")
	assert_eq(n_texto_clicavel, 0, "Todo texto da mesa está sem clique.")
	assert_eq(n_carta_clicavel, 0, "Toda carta da mesa está sem clique.")
