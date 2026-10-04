extends "res://testing/astralis_test_base.gd"

## test_turno_quem_comeca — trava o BUG REPORTADO: quando o motor sorteia o
## RIVAL para começar, o duelo travava em "Aguarde o rival." para sempre.
##
## O QUE ESTE ARQUIVO TRAVA (nenhuma regra nova, R1/R2):
## (1) first_p2 (rival começa): a tela 3D conduz o turno do RIVAL de verdade
##     — pelo mesmo caminho real da IA (DuelManager/TurnManager +
##     SummonSystem/BattleSystem) —, o rival COMPRA (refill do TurnManager),
##     o rival JOGA, e no fim a vez volta para o jogador na MAIN.
## (2) first_p1 (você começa) NÃO regrediu: nada de turno do rival no start.
## (3) turn_order=random: a tela segue o QUE O MOTOR SORTEIOU, seja 0 ou 1.
## (4) TRAVA DE PROGRESSO: o turno do rival SEMPRE termina em
##     current_player == 0 + fase MAIN; e a trava de reentrada impede o turno
##     dele de rodar duas vezes em paralelo.
##
## POR QUE OS 3 SISTEMAS REAIS (R2): o duel_setup vem do DataLoader de
## verdade, o sorteio vem do DuelManager de verdade e a cena é a
## duel3d/mesa_3d.tscn de verdade. Nenhum dublê, nenhum motor falso: aqui só
## se monta o DADO (um duel_setup com outra ordem) e se OBSERVA a orquestração
## da tela. Quem decide fase/compra/turno/vencedor é o motor.
##
## R3: o primeiro jogador NUNCA é fixado aqui. O teste monta o duel_setup com
## `turn_order` e lê o que o motor devolveu em `current_player` — a tela só
## honra esse número.

const DuelManager := preload("res://duel/duel_manager.gd")


func _contar_zona(st, lado: int, zona_nome: String) -> int:
	var n := 0
	for m in ((st.players[lado] as Dictionary)[zona_nome] as Array):
		if m != null:
			n += 1
	return n


## Avança uma fase pelo DuelManager REAL da cena (não é dublê: é o mesmo
## objeto que o jogo usa).
func _avanca_fase(mesa: Node) -> void:
	(mesa.get("_duel") as Object).advance_phase()


## duel_setup REAL do projeto (FM), com a `turn_order` pedida e SEM
## test_state — sem test_state o DuelManager NÃO força o primeiro a p0, então
## o sorteio vale de verdade (é o mesmo caminho de um duelo de jogo normal).
func _setup_com_ordem(ordem: String) -> Dictionary:
	var base: Dictionary = ProjectLoaderScript.load_initial_state().get("data", {}).get("duel_setup", {})
	if base.is_empty():
		# Sem duel_setup na base: monta um com o contrato do schema.
		base = {
			"schema_version": 1, "duel_id": "teste_turno",
			"duelist1": {"duelist_id": "fm_duelist_01", "deck_id": "fm_deck_01"},
			"duelist2": {"duelist_id": "fm_duelist_03", "deck_id": "fm_deck_03"},
			"starting_lp": 8000, "turn_order": "first_p1", "seed": 42,
			"arena_id": "arena_starter",
			"win": {"on_lp_zero": true, "on_deckout": true},
		}
	var s := base.duplicate(true)
	s["turn_order"] = ordem
	s.erase("test_state")
	return s


## Duelo REAL do motor com a ordem pedida (DuelManager + dado FM do projeto).
func _duelo_com_ordem(ordem: String):
	var data: Dictionary = ProjectLoaderScript.load_initial_state().get("data", {})
	return DuelManager.new_duel(_setup_com_ordem(ordem), data.get("decks", {}), data.get("cards", {}))


## Cena 3D REAL com um duelo REAL da ordem pedida. A cena já montou o duelo
## dela no _ready; aqui trocamos pelo duelo do teste e chamamos a MESMA
## entrada de orquestração que o _ready chama (`_iniciar_turno_do_duelo`),
## para o que ser testado ser o caminho de verdade da tela.
func _mesa_com_ordem(ordem: String) -> Array:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	var duelo = _duelo_com_ordem(ordem)
	# O boot abriu distribuicao (5+5 cartas voando) e esta esperando a ultima
	# assentar antes da moeda. O redesenho abaixo libera essas cartas no meio
	# do voo: o pouso delas nunca chega e o sinal nunca vem. Zera a contagem
	# para a abertura do teste nao esperar um sinal que nao existe mais. O
	# boot pendente fica esperando (morre com a mesa); quem abre o turno do
	# teste e a chamada de cada teste.
	mesa.set("_cartas_voando", 0)
	mesa.set("_distribuicao_ativa", false)
	mesa.set("_duel", duelo)
	mesa.set("_st", duelo.get_state())
	mesa.set("_aguardando_sorteio", mesa.call("_tem_sorteio_na_tela"))
	var faixa: Node = mesa.get("_faixa") as Node
	if faixa != null and is_instance_valid(faixa):
		faixa.call("esperar_sorteio", mesa.get("_aguardando_sorteio"))
	mesa.call("_redesenhar", false)
	return [mesa, duelo.get_state()]


## Espera o turno do rival acabar (a condução é async, com pausas de
## animação). Teto generoso; se não acabar, o próprio assert de
## current_player reprova.
func _espera_turno_do_rival(mesa: Node) -> void:
	for _i in range(240):
		await wait_process_frames(1)
		if not bool(mesa.get("_rival_rodando")):
			return


func _resumo(st) -> Dictionary:
	var p0: Dictionary = st.players[0] as Dictionary
	var p1: Dictionary = st.players[1] as Dictionary
	return {
		"cur": int(st.current_player), "fase": String(st.phase), "turno": int(st.turn_number),
		"over": bool(st.over),
		"mao0": (p0["hand"] as Array).size(), "mao1": (p1["hand"] as Array).size(),
		"deck0": (p0["deck"] as Array).size(), "deck1": (p1["deck"] as Array).size(),
		"campo1": _contar_zona(st, 1, "monster"), "lp0": int(p0["lp"]),
	}


# ---------- (1) first_p2: O RIVAL COMEÇA E O DUELO ANDA ----------

## A VISTA DO PRIMEIRO QUADRO: quem tem a vez é quem se vê. Com o rival
## começando, a mesa tem de NASCE na vista dele — não aparecer na sua e girar
## depois, porque durante essa volta a tela mostra a perspectiva de quem NÃO
## está jogando enquanto o rival já está comprando e jogando por baixo dela.
##
## POR QUE ESTE TESTE FORÇA O CAMINHO COM RENDER: sem render a volta antiga
## pulava direto para 180 (o `girar_para` tem atalho headless), então o bug
## seria invisível aqui e o teste passaria com a mesa errada. Forçando o render,
## a volta vira um tween de um segundo e a mesa errada fica em 0 por esse tempo
## todo — que é exatamente o que o jogador via. O `giro_campo` é lido no MESMO
## instante em que o boot devolve, sem esperar quadro nenhum: se a mesa tivesse
## de girar, ela ainda estaria em 0 aqui.
func test_rival_comecador_a_mesa_nasce_na_vista_dele() -> void:
	var par := await _mesa_com_ordem("first_p2")
	var mesa: Node = par[0]
	var vista: Node = mesa.get("_vista")
	# O motor sorteou o rival, então a tela tem de estar na vista DELE já no
	# primeiro quadro. 180 = visão do rival (o mesmo número da volta).
	assert_eq(int(par[1].current_player), 1,
		"Preparo: quem começa é o RIVAL (o motor sorteou, a tela não).")
	# Render ligado: agora a mesa errada (que gira) ficaria em 0.
	vista.set("sem_render", Callable(self, "_render_ligado"))
	vista.set("giro_campo", 0.0)
	vista.call("aplicar")
	mesa.call("_iniciar_turno_do_duelo")
	assert_eq(float(vista.get("giro_campo")), 180.0,
		"A mesa NASCE na vista do rival: quem tem a vez é quem se vê (sem girar antes).")
	assert_false(bool(vista.get("girando")),
		"Não há volta em curso no primeiro quadro (a mesa já nasceu na vista certa).")
	assert_eq((mesa.get_node("Camada3D/JanelaCampo/Viewport3D/PivoMesa") as Node3D).rotation_degrees.y, 180.0,
		"O pivô já está nos 180 do rival (a câmera girou junto, sem volta).")
	# E o número que manda no lugar de baixo é o dono do turno: com a mesa na
	# vista do rival, quem joga embaixo é o RIVAL (D52). Se isto devolvesse 0,
	# a sua mão estaria no lugar de quem está jogando.
	assert_eq(int(mesa.call("_dono_do_lugar_perto")), 1,
		"O lugar de BAIXO é o do rival (quem tem a vez), então a mão dele fica na frente.")
	# As DUAS mãos existem e as duas estão de pé de costas na vista do rival
	# (D52): o verso de uma carta não é o espelho da frente, então virar de
	# cabeça para baixo mostraria a arte do jogador.
	var cartas: Node3D = mesa.get_node("Camada3D/JanelaCampo/Viewport3D/Cartas")
	var p0 := 0
	var p1 := 0
	for f in cartas.get_children():
		if not (f as Node3D).has_meta("mao_dono"):
			continue
		if int((f as Node3D).get_meta("mao_dono")) == 0:
			p0 += 1
		else:
			p1 += 1
	assert_true(p0 > 0, "A sua mão continua desenhada na vista do rival (as duas mãos existem).")
	assert_true(p1 > 0, "A mão do rival continua desenhada na vista do rival (as duas mãos existem).")


## Diz à vista que HÁ RENDER, para o teste acima medir a mesa no instante em que
## o boot devolve — que é onde a volta errada ainda estaria no meio do caminho.
func _render_ligado() -> bool:
	return false


func test_first_p2_rival_comeca_compra_joga_e_devolve_a_vez() -> void:
	# (1) O BUG. first_p2 = o motor diz que o RIVAL começa. Antes a tela
	# assumia que o primeiro era você, entrava no fluxo da fase da mão e
	# todas as travas caíam em "current_player != 0": ninguém conduzia o
	# turno do rival e o duelo ficava em "Aguarde o rival." para sempre.
	var par := await _mesa_com_ordem("first_p2")
	var mesa: Node = par[0]
	var st = par[1]
	# O motor sorteou o rival (R3: quem diz quem começa é ele, não a tela).
	assert_eq(int(st.current_player), 1, "Preparo: o MOTOR sorteou o rival como primeiro.")
	assert_eq(String(st.phase), "DRAW", "Preparo: o duelo abre na DRAW do rival.")
	var mao_rival_antes: int = ((st.players[1] as Dictionary)["hand"] as Array).size()
	var campo_rival_antes: int = _contar_zona(st, 1, "monster")
	var lp0_antes: int = int((st.players[0] as Dictionary)["lp"])
	mesa.call("_iniciar_turno_do_duelo")
	await _espera_turno_do_rival(mesa)
	var fim := _resumo(st)
	# O duelo ANDA: a vez voltou para o jogador, na MAIN, com o turno do
	# motor já incrementado. Este é o assert que pegava a regressão.
	assert_false(bool(fim["over"]), "O duel NÃO acabou no primeiro turno do rival.")
	assert_eq(int(fim["cur"]), 0, "A vez VOLTOU para o jogador (current_player == 0).")
	assert_eq(String(fim["fase"]), "MAIN", "O jogador recebeu o turno na MAIN (dá para jogar).")
	assert_eq(int(fim["turno"]), 2, "Turno do motor avançou para 2.")
	# A tela really entrou no fluxo do jogador (D24): fase da mão, cursor
	# na mão, e nada de menu aberto.
	assert_eq(int(mesa.get("_fase_jogador")), int(mesa.get("FASE_MAO")), "Tela no fluxo da FASE DA MÃO.")
	assert_eq(int(mesa.get("_fileira")), int(mesa.get("FILEIRA_MAO")), "Cursor na sua mão.")
	assert_eq(int(mesa.get("_sub_mao")), int(mesa.get("SUB_MAO_ESCOLHA")), "Sub-fase = escolher carta.")
	# O RIVAL AGIU de verdade (era a reclamação do usuário: "não bota carta
	# nenhuma e nem faz nada"). Ou ele invocou, ou ele atacou.
	assert_true(int(fim["campo1"]) > campo_rival_antes or int(fim["lp0"]) < lp0_antes,
		"O rival JOGOU: invocou (%d -> %d em campo) ou atacou (LP %d -> %d)." % [
			campo_rival_antes, int(fim["campo1"]), lp0_antes, int(fim["lp0"])])
	# A COMPRA do turno do rival (D26, refill até 5 do TurnManager): a mão
	# dele não pode ficar com menos de 5 no começo do turno seguinte, e o
	# baralho dele só encolhe quando ele realmente comprou.
	assert_true(int(fim["mao1"]) <= 5, "Mão do rival não estourou o limite de 5: %d." % int(fim["mao1"]))
	assert_eq(int(fim["mao0"]), 5, "Sua mão foi completada até 5 na sua DRAW (refill do motor): %d." % int(fim["mao0"]))
	assert_true(mao_rival_antes >= 5, "Preparo: o rival começou com a mão de abertura do motor (%d)." % mao_rival_antes)
	# D44 (item 6): a barra de fases SAIU da tela por ordem do usuário, e o
	# turno agora é lido na FAIXA DO MEIO (que em D45 virou 2D, na camada de
	# trás), com o valor real do motor.
	#
	# D80: este duelo e `first_p1`, sem moeda na tela, entao a faixa ja esta
	# Mostrando o numero do motor desde o primeiro quadro. Este teste mede a
	# ORDEM do turno e nao o desenho da espera — o `?` tem como dono
	# `test_moeda.gd`.
	var txt := str((mesa.get_node("CamadaFaixa/Faixa2D/Celulas/Turno/Caixa/Numero") as Label).text)
	assert_eq(txt, str(int(fim["turno"])), "Faixa do meio com o turno real do motor (%s)." % txt)
	assert_true(mesa.get_node_or_null(NodePath("HUD/BarraFases")) == null, "Sem barra de fases na tela (D44).")


# ---------- (2) first_p1: VOCÊ COMEÇA (não regrediu) ----------

func test_first_p1_voce_comeca_e_o_rival_NAO_roda_sozinho() -> void:
	# (2) Sem regressão: quando a vez é sua, a tela abre o fluxo da fase da
	# mão e NÃO conduz turno de ninguém. O rival só joga quando VOCÊ passar
	# o turno (START), nunca sozinho.
	var par := await _mesa_com_ordem("first_p1")
	var mesa: Node = par[0]
	var st = par[1]
	assert_eq(int(st.current_player), 0, "Preparo: o MOTOR sorteou você como primeiro.")
	var campo_rival_antes: int = _contar_zona(st, 1, "monster")
	var lp0_antes: int = int((st.players[0] as Dictionary)["lp"])
	mesa.call("_iniciar_turno_do_duelo")
	await wait_process_frames(10)
	var inicio := _resumo(st)
	assert_eq(int(inicio["cur"]), 0, "Continua sua vez logo no começo.")
	assert_eq(String(inicio["fase"]), "MAIN", "Sua MAIN aberta pelo motor (não ficou na DRAW).")
	assert_eq(int(mesa.get("_fase_jogador")), int(mesa.get("FASE_MAO")), "Tela no fluxo da FASE DA MÃO.")
	assert_false(bool(mesa.get("_rival_rodando")), "A tela NÃO conduz turno do rival no começo (o START é seu).")
	assert_eq(int(inicio["campo1"]), campo_rival_antes, "O rival não invocou nada sozinho.")
	assert_eq(int(inicio["lp0"]), lp0_antes, "O rival não te atacou sozinho.")


# ---------- (3) random: SEGUE O QUE O MOTOR SORTEIOU ----------

func test_random_a_tela_segue_o_sorteio_do_motor() -> void:
	# (3) R3: a tela NÃO sorteia. Com turn_order=random quem decide é o
	# DuelManager; a tela tem de abrir o fluxo correspondente ao número que
	# ele devolveu. Este teste roda as DUASidian saídas possíveis do sorteio
	# e, em cada uma, confere que a tela fez o que o motor mandou.
	for tentativa in range(8):
		var par := await _mesa_com_ordem("random")
		var mesa: Node = par[0]
		var st = par[1]
		var primeiro := int(st.current_player)
		assert_true(primeiro == 0 or primeiro == 1, "Sorteio do motor é 0 ou 1 (tentativa %d): %d." % [tentativa, primeiro])
		mesa.call("_iniciar_turno_do_duelo")
		await _espera_turno_do_rival(mesa)
		var fim := _resumo(st)
		if primeiro == 0:
			# Motor disse "você": a tela abre o fluxo e NÃO mexe em turno.
			assert_eq(int(fim["cur"]), 0, "random=seu: continua sua vez (tentativa %d)." % tentativa)
			assert_eq(String(fim["fase"]), "MAIN", "random=seu: MAIN aberta (tentativa %d)." % tentativa)
			assert_eq(int(fim["turno"]), 1, "random=seu: turno do motor não andou (tentativa %d)." % tentativa)
		else:
			# Motor disse "rival": a tela conduziu o turno dele até o fim.
			assert_eq(int(fim["cur"]), 0, "random=rival: a vez voltou pra você (tentativa %d)." % tentativa)
			assert_eq(String(fim["fase"]), "MAIN", "random=rival: você recebeu na MAIN (tentativa %d)." % tentativa)
			assert_eq(int(fim["turno"]), 2, "random=rival: turno do motor avançou (tentativa %d)." % tentativa)
		assert_false(bool(fim["over"]), "random: o duelo não travou nem acabou (tentativa %d)." % tentativa)
		# O START é seu: a trava de não agir fora de hora vale nos dois casos.
		assert_false(bool(mesa.get("_rival_rodando")), "random: a condução do rival terminou (tentativa %d)." % tentativa)


# ---------- (4) TRAVA DE PROGRESSO: NINGUÉM PATH TRAVA ----------

func test_turno_do_rival_sempre_termina_na_vez_do_jogador() -> void:
	# (4) A trava de progresso. Seja qual for o estado em que o turno do
	# rival começa (DRAW dele, MAIN dele, o que for), a condução tem SEMPRE
	# de terminar com a vez do jogador na MAIN. Aqui o turno do rival é
	# montado com os SISTEMAS REAIS (não por truque de teste) e a entrega de
	# vez é medida depois de cada turno completo.
	var par := await _mesa_com_ordem("first_p2")
	var mesa: Node = par[0]
	var st = par[1]
	# Ciclo de 3 turnos DO RIVAL: cada volta tem de terminar com
	# current_player == 0 e fase MAIN, sem travar em nenhum passo.
	for volta in range(3):
		# Deixa a máquina REAL de fases no começo do turno do rival (DRAW dele,
		# com a compra do TurnManager já feita por ela).
		var g := 0
		while not bool(st.over) and g < 20:
			if int(st.current_player) == 1 and String(st.phase) == "DRAW":
				break
			_avanca_fase(mesa)
			g += 1
		assert_eq(int(st.current_player), 1, "Volta %d: o turno a ser conduzido é o do RIVAL." % volta)
		assert_eq(String(st.phase), "DRAW", "Volta %d: o turno do rival começa na DRAW (fase do motor)." % volta)
		var turno_antes: int = int(st.turn_number)
		mesa.call("_rival_auto")
		await _espera_turno_do_rival(mesa)
		var fim := _resumo(st)
		assert_false(bool(fim["over"]), "Volta %d: o duelo não acabou." % volta)
		assert_eq(int(fim["cur"]), 0, "Volta %d: a vez voltou para o jogador (trava de progresso)." % volta)
		assert_eq(String(fim["fase"]), "MAIN", "Volta %d: o jogador recebeu na MAIN (dá para jogar)." % volta)
		assert_eq(int(fim["turno"]), turno_antes + 1, "Volta %d: o motor contou exatamente 1 turno." % volta)
		assert_eq(int(mesa.get("_fase_jogador")), int(mesa.get("FASE_MAO")), "Volta %d: fluxo da fase da mão aberto." % volta)


## Reentrada: o turno do rival não pode rodar duas vezes em paralelo (o que
## faria o motor pular turno). Chamar duas vezes seguidas tem de rodar uma só.
func test_turno_do_rival_nao_roda_em_paralelo() -> void:
	var par := await _mesa_com_ordem("first_p2")
	var mesa: Node = par[0]
	var st = par[1]
	var turno_inicial: int = int(st.turn_number)
	mesa.call("_rival_auto")
	mesa.call("_rival_auto") # segunda chamada: tem de ser ignorada
	assert_true(bool(mesa.get("_rival_rodando")), "A trava de reentrada ligou na primeira chamada.")
	await _espera_turno_do_rival(mesa)
	assert_eq(int(st.turn_number), turno_inicial + 1, "O turno do rival rodou UMA vez só (+1 no motor, não +2).")
	assert_eq(int(st.current_player), 0, "A vez voltou para o jogador.")
	assert_eq(String(st.phase), "MAIN", "O jogador recebeu na MAIN.")
