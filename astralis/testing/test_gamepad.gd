extends "res://testing/astralis_test_base.gd"

## test_gamepad — GUT do controle 100% gamepad na mesa (D26, R2: sem Fake).
## Usa o InputMap real (project.godot) + a cena real da mesa OFICIAL
## (duel3d/mesa_3d.tscn). Sem gamepad físico: simula com
## Input.action_press/action_release + chama o passo real do cursor
## (_mover/_cancelar). START reservado (pausar sem ação).
## Trava D26 parcial: 11 ações só-joypad (zero teclado/mouse) + mesa
## sem controle clicável (sinal clicada removido de verdade).
## Bug aqui vira teste permanente.

# Os helpers de mesa (_mesa3d_nova) vêm da base (astralis_test_base.gd) - R8.

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
	# Mesa 3D real. Simula o direcional sem gamepad físico e anda 1 passo
	# p/ direita + volta p/ esquerda, pelo mesmo código que o jogo usa.
	var mesa: Node = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var fileira_ini: int = int(mesa.get("_fileira"))
	var col_ini: int = int(mesa.get("_col"))
	var larg: int = int(mesa.call("_larg_fileira", fileira_ini))
	assert_true(larg > 1, "Preparo: a fileira tem %d casas, dá p/ andar esq/dir." % larg)
	# Segura o direcional (simula o controle) e dá 1 passo real.
	Input.action_press("mover_dir")
	assert_true(Input.is_action_pressed("mover_dir"), "Direcional simulado fica pressionado.")
	mesa.call("_mover", 1, 0)
	Input.action_release("mover_dir")
	assert_false(Input.is_action_pressed("mover_dir"), "Direcional simulado solta após o passo.")
	var col_meio: int = int(mesa.get("_col"))
	assert_eq(col_meio, posmod(col_ini + 1, larg), "1 passo p/ direita anda 1 casa.")
	assert_ne(col_meio, col_ini, "Cursor saiu da posição inicial.")
	# Volta 1 passo p/ esquerda e cai na posição inicial.
	Input.action_press("mover_esq")
	mesa.call("_mover", -1, 0)
	Input.action_release("mover_esq")
	assert_eq(int(mesa.get("_col")), col_ini, "1 passo p/ esquerda volta à posição inicial.")
	assert_eq(int(mesa.get("_fileira")), fileira_ini, "Fileira não mudou no passo lateral.")


func test_cancelar_desfaz_escolha_real() -> void:
	# Cancelar na mesa 3D real: desce uma carta levantada (volta ao neutro).
	var mesa: Node = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada p/ cancelar.")
	mesa.set("_levantadas", [0, 2])
	mesa.set("_sub_mao", 0)
	mesa.call("_cancelar")
	assert_eq((mesa.get("_levantadas") as Array).size(), 1, "cancelar abaixa a última levantada.")
	assert_eq((mesa.get("_levantadas") as Array).back(), 0, "Fica a que foi levantada antes.")


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


## A varredura "mesa sem controle clicavel" (nenhum Button, nenhum Control com
## clique) saiu daqui: ela vivia no duel_table.tscn e ja e feita na mesa
## OFICIAL por test_mesa_3d_oficial/test_mesa_3d_so_joypad_sem_clique.
