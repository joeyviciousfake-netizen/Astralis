extends "res://testing/astralis_test_base.gd"

## test_seed_sorteio — trava o CONTRATO DA SEMENTE do duel_setup (DADO, R3)
## em astralis/duel/duel_manager.gd.
##
## O BUG REPORTADO ("deixar aleatório sobre quem começa o jogo"): o rng era
## semeado com o valor do setup e o Studio mandava SEMPRE a mesma semente, e
## 0 também era uma semente válida e fixa. Resultado: `turn_order: "random"`
## dava sempre o mesmo primeiro jogador e o embaralhamento era sempre o
## mesmo — "aleatório" que não é aleatório.
##
## O CONTRATO (decisão do Lead, implementada no DuelManager):
## - seed != 0  = SEMENTE FIXA: mesmo número reproduz o mesmo duelo, carta
##   por carta (Test Lab doc 10, Campo de Testes, GUT — precisa repetir).
## - seed == 0 (ou ausente) = SEM SEMENTE: sorteio de verdade a cada partida.
## Retrocompatível: todo mundo que manda seed != 0 se comporta igual antes.
##
## O QUE ESTE ARQUIVO TRAVA:
## (1) seed != 0 (42): 3 duelos seguidos = MESMO primeiro jogador, MESMA mão
##     e MESMA ordem de baralho nos 2 lados (determinismo não regrediu — é o
##     que os outros testes e o Test Lab dependem);
## (2) seed == 0: vários duelos seguidos dão resultados DIFERENTES em pelo
##     menos uma observável (quem começa OU a ordem do baralho). Várias
##     tentativas de propósito, para não dar falso positivo por acaso;
## (3) turn_order "first_p1"/"first_p2" continuam DETERMINÍSTICOS mesmo com
##     seed 0: são fixos por contrato, não são sorteados;
## (4) seed AUSENTE vale como 0 (mesma semântica: sem semente).
##
## R2: motor real. O DuelManager real monta cada duelo, com o conteúdo FM de
## verdade do DataLoader; aqui só se monta o DADO (duel_setup com outra
## `turn_order`/`seed`) e se OBSERVA o estado que o motor devolveu. Nenhum
## sorteio, Fake ou dublê de engine. Quem embaralha e quem sorteia quem
## começa é o DuelManager (rng dele), nunca o teste.

## DADO FM (o duel_setup embutido): 8000 LP, first_p1, seed 42, 2 duelistas.
var _data: Dictionary = {}


func before_each() -> void:
	# O dado é carregado UMA vez por teste e reaproveitado: o DuelManager só
	# LÊ cards/decks (duplica as cartas ao montar), então o reuso não muda
	# nada do que é observado e evita 20 leituras de 722 cartas em disco.
	_data = ProjectLoaderScript.load_initial_state().get("data", {})


## duel_setup do projeto com a ordem e a semente pedidas (só dado, R3).
## `com_semente = false` monta o setup SEM o campo seed (contrato: ausente
## vale como 0). test_state é apagado de propósito: com ele o motor FORÇA
## o primeiro a p0 (doc 04.6) e o sorteio nem existe.
func _setup(ordem: String, semente: int, com_semente: bool = true) -> Dictionary:
	var base: Dictionary = _data.get("duel_setup", {}).duplicate(true)
	base["turn_order"] = ordem
	if com_semente:
		base["seed"] = semente
	else:
		base.erase("seed")
	base.erase("test_state")
	return base


## Duelo REAL do motor (DuelManager.new_duel) com o setup pedido.
func _duelo(ordem: String, semente: int, com_semente: bool = true):
	return DuelManagerScript.new_duel(
		_setup(ordem, semente, com_semente), _data.get("decks", {}), _data.get("cards", {}))


## Os ids das cartas de um lado, na ordem em que estão (mão ou baralho).
func _ids(cartas: Array) -> Array:
	var out: Array = []
	for c in cartas:
		out.append(str((c as Dictionary).get("id", "")))
	return out


## O que dá para OBSERVAR de um duelo montado (nada é calculado aqui: é
## só o estado devolvido pelo motor). "assinatura" junta as observáveis
## para comparar dois duelos com um `==` só.
func _observaveis(st) -> Dictionary:
	var p0: Dictionary = st.players[0] as Dictionary
	var p1: Dictionary = st.players[1] as Dictionary
	var mao0 := _ids(p0["hand"] as Array)
	var mao1 := _ids(p1["hand"] as Array)
	var deck0 := _ids(p0["deck"] as Array)
	var deck1 := _ids(p1["deck"] as Array)
	return {
		"primeiro": int(st.current_player),
		"fase": String(st.phase),
		"mao0": mao0, "mao1": mao1,
		"deck0": deck0, "deck1": deck1,
		"assinatura": "%d|%s|%s|%s|%s" % [int(st.current_player), str(mao0), str(mao1), str(deck0), str(deck1)],
	}


# ---------- (1) SEED FIXA: DETERMINISMO PRESERVADO (o que já existia) ----------

func test_seed_fixa_reproduz_o_duelo_inteiro() -> void:
	# (1) Este é o teste que NÃO pode quebrar: Test Lab (doc 10), Campo de
	# Testes, test_duel_core, test_campo_testes e test_board_layout dependem
	# da semente fixa repetir o duelo. Três montagens com seed 42 (a do
	# duel_setup FM) têm de dar exatamente o mesmo primeiro jogador, a mesma
	# mão e a mesma ordem de baralho nos 2 lados.
	var a := _observaveis(_duelo("random", 42).get_state())
	var b := _observaveis(_duelo("random", 42).get_state())
	var c := _observaveis(_duelo("random", 42).get_state())
	assert_eq(a["primeiro"], b["primeiro"], "Seed fixa: mesmo primeiro jogador (2a montagem).")
	assert_eq(a["primeiro"], c["primeiro"], "Seed fixa: mesmo primeiro jogador (3a montagem).")
	assert_eq(a["mao0"], b["mao0"], "Seed fixa: sua mão igual na 2a montagem.")
	assert_eq(a["mao0"], c["mao0"], "Seed fixa: sua mão igual na 3a montagem.")
	assert_eq(a["mao1"], b["mao1"], "Seed fixa: mão do rival igual na 2a montagem.")
	assert_eq(a["mao1"], c["mao1"], "Seed fixa: mão do rival igual na 3a montagem.")
	assert_eq(a["deck0"], b["deck0"], "Seed fixa: MESMA ordem do baralho p0 (2a montagem).")
	assert_eq(a["deck1"], b["deck1"], "Seed fixa: MESMA ordem do baralho p1 (2a montagem).")
	assert_eq(a["assinatura"], c["assinatura"], "Seed fixa: duelo inteiro idêntico nas 3 montagens.")
	# E a semente é o que decide, e não o acaso: outra semente fixa (7777)
	# embaralha em outra ordem e é fixa como a 42.
	var d1 := _observaveis(_duelo("random", 7777).get_state())
	var d2 := _observaveis(_duelo("random", 7777).get_state())
	assert_eq(d1["assinatura"], d2["assinatura"], "Seed fixa 7777 também é determinística.")
	assert_ne(d1["deck0"], a["deck0"], "A semente 7777 embaralha diferente da 42 (é a semente que decide a ordem).")
	assert_ne(d1["deck1"], a["deck1"], "A semente 7777 embaralha o rival diferente da 42.")


# ---------- (2) SEED 0 = SORTEIO DE VERDADE (o bug corrigido) ----------

func test_seed_zero_da_resultados_diferentes() -> void:
	# (2) O BUG. Com seed 0 (sem semente) o motor tem de VARIAR. Várias
	# tentativas de propósito: uma repetição sorteada seria falso positivo
	# e não provaria nada. O que trava aqui é: os duelos com seed 0 não
	# podem ser todos idênticos.
	var assinaturas := {}
	var baralhos := {}
	var primeiros := {}
	for _i in range(12):
		var o := _observaveis(_duelo("random", 0).get_state())
		assinaturas[o["assinatura"]] = true
		baralhos[str(o["deck0"]) + "|" + str(o["deck1"])] = true
		primeiros[o["primeiro"]] = true
	assert_gt(assinaturas.size(), 1,
		"Seed 0 = sem semente: 12 duelos deram %d duelo(s) diferente(s) — o sorteio tem de variar." % assinaturas.size())
	assert_gt(baralhos.size(), 1,
		"Seed 0: a ordem do baralho também variou (%d ordens diferentes em 12 duelos)." % baralhos.size())
	assert_eq(primeiros.size(), 2,
		"Seed 0 com turn_order=random: os DOIS primeiros jogadores saíram em 12 duelos (sorteados: %s)." % str(primeiros.keys()))


func test_seed_ausente_e_o_mesmo_que_seed_zero() -> void:
	# (4) Contrato: seed 0 OU AUSENTE = sem semente. Um setup sem o campo
	# seed não pode virar uma semente fixa disfarçada (era o que acontecia
	# com o get("seed", 0) semeando 0).
	var assinaturas := {}
	for _i in range(12):
		assinaturas[_observaveis(_duelo("random", 0, false).get_state())["assinatura"]] = true
	assert_gt(assinaturas.size(), 1,
		"Setup SEM o campo seed = sem semente: %d duelo(s) diferente(s) em 12 montagens." % assinaturas.size())


# ---------- (3) ORDEM FIXA = FIXA, COMO seed 0 ou COMO seed 42 ----------

func test_first_p1_e_first_p2_sao_deterministas_mesmo_com_seed_zero() -> void:
	# (3) first_p1/first_p2 NÃO são sorteados: são fixos por contrato. Com
	# seed 0 (nem com seed 42) o motor pode devolver outra coisa. Aqui a
	# mesa vira as duas ordens 6x cada uma e a resposta tem de ser sempre a
	# mesma, e diferente entre elas.
	for _i in range(6):
		var p1 := _observaveis(_duelo("first_p1", 0).get_state())
		assert_eq(int(p1["primeiro"]), 0, "first_p1 com seed 0: você começa (sempre).")
		var p2 := _observaveis(_duelo("first_p2", 0).get_state())
		assert_eq(int(p2["primeiro"]), 1, "first_p2 com seed 0: o rival começa (sempre).")
	for _i in range(6):
		assert_eq(int(_observaveis(_duelo("first_p1", 42).get_state())["primeiro"]), 0, "first_p1 com seed 42: você começa (sempre).")
		assert_eq(int(_observaveis(_duelo("first_p2", 42).get_state())["primeiro"]), 1, "first_p2 com seed 42: o rival começa (sempre).")


# ---------- (4) O DADO FM (seed 42) SEGUE VALENDO ----------

func test_duel_setup_do_projeto_continua_deterministico() -> void:
	# (4) O duelo_setup embutido (schemas/examples/duel_setup.json) tem
	# seed 42 e turn_order first_p1: o jogo continua abrindo exatamente
	# igual em toda máquina, como antes desta mudança (ninguém que manda
	# seed ≠ 0 pode ter o resultado alterado).
	var setup: Dictionary = (_data.get("duel_setup", {}) as Dictionary).duplicate(true)
	setup.erase("test_state")
	assert_eq(int(setup.get("seed", -1)), 42, "Preparo: o duel_setup FM tem seed fixa 42 (≠ 0).")
	var a := _observaveis(DuelManagerScript.new_duel(setup.duplicate(true), _data.get("decks", {}), _data.get("cards", {})).get_state())
	var b := _observaveis(DuelManagerScript.new_duel(setup.duplicate(true), _data.get("decks", {}), _data.get("cards", {})).get_state())
	assert_eq(a["primeiro"], 0, "FM abre com você (turn_order first_p1 do dado).")
	assert_eq(a["assinatura"], b["assinatura"], "FM: duas partidas com o dado de fábrica são idênticas (seed 42).")
