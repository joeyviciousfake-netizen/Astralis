extends "res://testing/astralis_test_base.gd"

## test_perspectiva_campo — a CAMADA DE PERSPECTIVA do doc 16 / D46.
##
## A tela do duelo passa a ser a perspectiva de QUEM ESTA JOGANDO. NADA GIRA:
## nem a câmera (D41), nem o campo, nem o céu. O que muda é PARA ONDE cada
## carta é desenhada, e quem decide isso é UMA função só, `_vis`.
##
## ESTE ARQUIVO CRESCEU COM CADA ETAPA do doc 16 §16.6:
##   ETAPA 1 (esta) — a camada existe, todo o desenho passa por ela, e a
##                    perspectiva está TRAVADA no jogador 0: a tela fica
##                    EXATAMENTE igual à de antes. A foto de prova compara
##                    pixel a pixel (o original rodando 2x já difere 1129 px
##                    por causa do cursor que pulsa, então o "idêntico" é
##                    "idêntico dentro do ruído do próprio jogo").
##   ETAPA 2 — a perspectiva passa a seguir `current_player` (o teste da
##                    identidade abaixo é o que muda de propósito aqui).
##   ETAPA 3 — as mãos (a de baixo é a de quem joga, a de cima sempre virada).
##
## O QUE ESTA ETAPA TRAVA:
## (1) `_vis` é a identidade para os 20 lugares do campo (2 lados x 5 colunas);
## (2) a carta desenhada está EXATAMENTE onde `_vis` mandou, e o giro de 180°
##     segue o LADO VISUAL (D6), não o lado do dado;
## (3) o ESTADO NÃO SE MOVE: a mesma carta continua no mesmo índice do
##     `GameState` depois de redesenhar (a troca é só de desenho);
## (4) andar pela posição visível (direita = direita na tela) continua certo
##     nos DOIS lados, porque o vizinho passa pela mesma função que desenha;
## (5) a faixa do meio e as placas de nome NÃO espelham (D8).
##
## Sem Fake (R2): a cena 3D real + o GameState real do DuelManager. Nada
## aqui duplica regra — o teste só pergunta ao desenho da mesa.

const Mesa3DScene := preload("res://duel3d/mesa_3d.tscn")

## Onde as cartas desenhadas ficam (mesmo caminho que o jogo usa).
const CARTAS := "Camada3D/JanelaCampo/Viewport3D/Cartas"
## Colunas do campo (5 slots por fileira, D15/D17).
const COLUNAS := 5


func _mesa3d_nova() -> Node:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


## A carta desenhada de um slot do DADO (lado, i), pelo meta `slot_id` (que é
## o ID do DADO, nunca o da tela — a troca de perspectiva é só desenho).
func _carta_do_campo(mesa: Node, lado: int, tipo: String, i: int) -> Node3D:
	var cartas: Node = mesa.get_node(CARTAS)
	var letra := "m" if tipo == "monstro" else "s"
	var alvo := "p%d_%s%d" % [lado, letra, i]
	for f in cartas.get_children():
		if (f as Node).has_meta("slot_id") and str((f as Node).get_meta("slot_id")) == alvo:
			return f as Node3D
	return null


## Carta de DADO no campo, montada pelo CONSTRUTOR REAL
## (`SummonSystem.construir_instancia` — o único lugar do jogo que monta
## instância, R1) e colocada no slot pedido. Este arquivo não está testando
## regra de invocação (aí entram fase, mão e `normal_summon`), só o DESENHO:
## por isso usa o construtor direto, que é o mesmo caminho do jogo.
func _poe_no_campo(mesa: Node, st, lado: int, i: int) -> bool:
	var SummonSys := preload("res://duel/summon_system.gd")
	var cartas: Dictionary = mesa.get("_cartas")
	var cid := ""
	for k in cartas:
		if str((cartas[k] as Dictionary).get("card_type", "")) == "monster":
			cid = str(k)
			break
	if cid.is_empty():
		return false
	var real: Dictionary = cartas[cid] as Dictionary
	var inst: Dictionary = SummonSys.construir_instancia(real, false, "ATK", "", real, cid)
	(st.players[lado] as Dictionary)["monster"][i] = inst
	return true


## (1) A camada de perspectiva: a tela ainda é a do JOGADOR 0, e para os 20
## lugares do campo `_vis` devolve o próprio (lado, coluna).
func test_vis_e_a_identidade_e_a_tela_continua_a_do_jogador_0() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	st.set("current_player", 0)
	assert_eq(int(mesa.call("_perspectiva")), 0, "Etapa 1: a perspectiva é a do jogador 0.")
	for lado in [0, 1]:
		for i in range(COLUNAS):
			var v: Vector2i = mesa.call("_vis", lado, i)
			assert_eq(v, Vector2i(lado, i),
				"Etapa 1: com o jogador 0 jogando, o lugar do dado (%d,%d) é ele mesmo." % [lado, i])
	# E o MESMO com o rival na vez: a perspectiva ainda está travada (é o que a
	# etapa 2 vai mudar de propósito). Sem isso, esta etapa já mexeu na tela.
	st.set("current_player", 1)
	for lado in [0, 1]:
		for i in range(COLUNAS):
			var v2: Vector2i = mesa.call("_vis", lado, i)
			assert_eq(v2, Vector2i(lado, i),
				"Etapa 1: a perspectiva segue TRAVADA no jogador 0 (lado %d, coluna %d)." % [lado, i])
	assert_eq(int(mesa.call("_perspectiva")), 0,
		"Etapa 1: com o rival jogando a tela NAO virou a perspectiva (a etapa 2 faz isso).")
	# Coluna fora de 0..4 não derruba nada (blindagem, como o resto da tela).
	assert_eq(mesa.call("_vis", 0, -3), Vector2i(0, 0), "Coluna -3 trava em 0 (nunca crash).")
	assert_eq(mesa.call("_vis", 1, 99), Vector2i(1, 4), "Coluna 99 trava em 4 (nunca crash).")


## (2) A carta desenhada está EXATAMENTE onde `_vis` mandou, e o giro de 180°
## da fileira de cima decide pelo LADO VISUAL (D6).
func test_carta_do_campo_vai_onde_a_perspectiva_mandou() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	# Coloca carta de verdade nos DOIS lados, em colunas DIFERENTES de
	# propósito (a 2), para uma coluna errada aparecer na prova.
	var ok0 := _poe_no_campo(mesa, st, 0, 2)
	var ok1 := _poe_no_campo(mesa, st, 1, 2)
	assert_true(ok0, "Preparo: o p0 tem carta no campo.")
	assert_true(ok1, "Preparo: o p1 tem carta no campo.")
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	for lado in [0, 1]:
		var carta: Node3D = _carta_do_campo(mesa, lado, "monstro", 2)
		assert_true(carta != null, "A carta do dado (p%d, m2) está desenhada." % lado)
		if carta == null:
			continue
		var v: Vector2i = mesa.call("_vis", lado, 2)
		var esperado: Vector3 = mesa.call("_pos_slot", v.x, "monstro", v.y) as Vector3
		assert_almost_eq(carta.position.x, esperado.x, 0.0001,
			"A carta do p%d m2 está no X que a perspectiva mandou." % lado)
		assert_almost_eq(carta.position.z, esperado.z, 0.0001,
			"A carta do p%d m2 está no Z que a perspectiva mandou." % lado)
		# O giro de 180° vem do LADO VISUAL, não do lado do dado.
		var virada := bool(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("face_down", false))
		var em_defesa := str(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("position", "ATK")) == "DEF"
		var rot: Vector3 = mesa.call("_rot_deitada", virada, v.x, em_defesa) as Vector3
		assert_almost_eq(carta.rotation_degrees.y, rot.y, 0.0001,
			"A carta do p%d m2 gira pelo LADO VISUAL (%.0f = %.0f graus)." % [lado, carta.rotation_degrees.y, rot.y])
		# E a carta desenhada é a do DADO daquele índice (nada trocou de lugar).
		assert_eq(str(carta.get_meta("card_id")),
			str(((st.players[lado] as Dictionary)["monster"][2] as Dictionary).get("card_id", "")),
			"A carta desenhada em m2 é a carta do DADO do índice 2 do p%d." % lado)


## (3) R1 na prática: redesenhar NÃO mexe no estado. A troca de perspectiva da
## etapa 2 vai ser só de desenho; o `GameState` tem que ficar igual.
func test_o_estado_nao_se_move_no_redesenho() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	assert_true(_poe_no_campo(mesa, st, 0, 0), "Preparo: o p0 tem carta no campo.")
	assert_true(_poe_no_campo(mesa, st, 1, 0), "Preparo: o p1 tem carta no campo.")
	var antes0: Array = ((st.players[0] as Dictionary)["monster"] as Array).duplicate(true)
	var antes1: Array = ((st.players[1] as Dictionary)["monster"] as Array).duplicate(true)
	mesa.call("_redesenhar", false)
	await wait_process_frames(2)
	assert_eq(((st.players[0] as Dictionary)["monster"] as Array), antes0,
		"O campo do p0 é o MESMO depois de redesenhar (nada entrou, nada saiu).")
	assert_eq(((st.players[1] as Dictionary)["monster"] as Array), antes1,
		"O campo do p1 é o MESMO depois de redesenhar.")
	# E a carta continua no MESMO índice, desenhada, dos dois lados.
	for lado in [0, 1]:
		var esperado: Dictionary = (st.players[lado] as Dictionary)["monster"][0] as Dictionary
		assert_false(esperado.is_empty(), "Preparo: o p%d tem carta no índice 0." % lado)
		var carta: Node3D = _carta_do_campo(mesa, lado, "monstro", 0)
		assert_true(carta != null, "A carta do p%d m0 está desenhada." % lado)
		if carta != null:
			assert_eq(str(carta.get_meta("card_id")), str(esperado.get("card_id", "")),
				"A carta desenhada no m0 do p%d é a do índice 0 (a troca é só desenho)." % lado)


## (4) Andar pela posição visível: a DIREITA é a direita que se VÊ, nos DOIS
## lados. O vizinho pergunta ao X de quem é DESENHADO (`_x_do_slot`, que já
## passa pela perspectiva), nunca ao índice — e o lado 1 é ESPELHADO no dado
## (D18: lá a coluna 0 é a da DIREITA). Se um dia alguém voltar a andar pelo
## índice, esta trava pega.
func test_direita_na_tela_e_direita_nos_dois_lados() -> void:
	var mesa: Node = await _mesa3d_nova()
	# O espelho do D18, que a perspectiva reaproveita: a coluna 4 é a da
	# direita no lado 0 e a coluna 0 é a da direita no lado 1.
	var x0_0: float = mesa.call("_x_do_slot", 0, "monstro", 0)
	var x4_0: float = mesa.call("_x_do_slot", 0, "monstro", 4)
	var x0_1: float = mesa.call("_x_do_slot", 1, "monstro", 0)
	var x4_1: float = mesa.call("_x_do_slot", 1, "monstro", 4)
	assert_true(x4_0 > x0_0, "Lado 0: a coluna 4 fica à direita da coluna 0 (%.3f > %.3f)." % [x4_0, x0_0])
	assert_true(x0_1 > x4_1, "Lado 1 (espelho D18): a coluna 0 fica à direita da coluna 4 (%.3f > %.3f)." % [x0_1, x4_1])
	# Andar para a DIREITA aumenta o X de tela; para a ESQUERDA, diminui.
	# Testado no MEIO da fileira, que não está na borda.
	for lado in [0, 1]:
		var meio: float = mesa.call("_x_do_slot", lado, "monstro", 2)
		var dir: int = mesa.call("_vizinho3d", lado, "monstro", 2, 1)
		var esq: int = mesa.call("_vizinho3d", lado, "monstro", 2, -1)
		assert_true(float(mesa.call("_x_do_slot", lado, "monstro", dir)) > meio,
			"No lado %d, andar para a DIREITA aumenta o X de tela (coluna %d)." % [lado, dir])
		assert_true(float(mesa.call("_x_do_slot", lado, "monstro", esq)) < meio,
			"No lado %d, andar para a ESQUERDA diminui o X de tela (coluna %d)." % [lado, esq])


## (5) D8: a faixa do meio e as placas de nome são SEMPRE o painel do jogador.
## A perspectiva troca as cartas de lugar, nunca o painel.
func test_a_faixa_do_meio_nao_espelha() -> void:
	var mesa: Node = await _mesa3d_nova()
	var st = mesa.get("_st")
	var hud: Node = mesa.get_node_or_null("HUD")
	assert_true(hud != null, "A mesa tem o HUD.")
	if hud == null:
		return
	st.set("current_player", 0)
	mesa.call("_construir_faixa_2d", hud)
	var faixa_a: Control = mesa.get("_faixa2d") as Control
	assert_true(faixa_a != null, "A faixa 2D existe no HUD.")
	if faixa_a == null:
		return
	var pos_a: Vector2 = faixa_a.position
	var tam_a: Vector2 = faixa_a.size
	# Vira o current_player e reconstrói: a faixa tem que ficar no MESMO lugar.
	# `free()` imediato (não `queue_free`): a fila só drena no fim do frame, e
	# o GUT conta órfão antes disso.
	hud.remove_child(faixa_a)
	faixa_a.free()
	mesa.set("_faixa2d", null)
	st.set("current_player", 1)
	mesa.call("_construir_faixa_2d", hud)
	var faixa_b: Control = mesa.get("_faixa2d") as Control
	assert_true(faixa_b != null, "A faixa 2D foi reconstruída na vez do rival.")
	if faixa_b == null:
		return
	assert_eq(faixa_b.position, pos_a,
		"D8: a faixa do meio fica no MESMO lugar com o rival na vez (não espelha).")
	assert_eq(faixa_b.size, tam_a,
		"D8: a faixa do meio tem o MESMO tamanho com o rival na vez.")
	hud.remove_child(faixa_b)
	faixa_b.free()
	mesa.set("_faixa2d", null)
