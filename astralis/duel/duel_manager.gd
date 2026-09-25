class_name DuelManager
extends RefCounted

## DuelManager — monta o duelo a partir do duel_setup (DADO) e expõe o jogo.
## - embaralha cada deck com a seed do setup (determinístico);
## - mão inicial 5 p/ cada lado, SEM carta extra (FM fiel: draw up to five);
## - todo início de turno completa a mão até 5 (regra no TurnManager DRAW refill);
## - LP inicial do setup; ordem first_p1/first_p2/random.
## - Campo de Testes: se o setup tem test_state (doc 04.6), mão + campo
##   iniciais vêm do dado (my_hand p/ p0 + 4 zonas p0/p1) e começa em first_p1;
##   sem test_state, tudo como acima.
## Expõe advance_phase(), estado (get_state) e vencedor (get_winner/is_over).
## R1/R2: este é o sistema real; TestHarness/Studio só preparam e observam.

const GameState := preload("res://duel/game_state.gd")
const TurnManager := preload("res://duel/turn_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")

var state
var cards_db: Dictionary = {}
var decks_db: Dictionary = {}
var duel_setup: Dictionary = {}
var rng := RandomNumberGenerator.new()


static func new_duel(setup: Dictionary, decks: Dictionary, cards: Dictionary):
	# load() em vez de DuelManager.new(): funciona mesmo com cache frio de class_name.
	var m = (load("res://duel/duel_manager.gd") as GDScript).new()
	m._montar(setup, decks, cards)
	return m


func _montar(setup: Dictionary, decks: Dictionary, cards: Dictionary) -> void:
	duel_setup = setup
	decks_db = decks
	cards_db = cards
	var lp: int = int(setup.get("starting_lp", 4000))
	if lp <= 0:
		lp = 4000
	var seed_val: int = int(setup.get("seed", 0))
	rng.seed = seed_val
	var d1: Dictionary = setup.get("duelist1", {})
	var d2: Dictionary = setup.get("duelist2", {})
	var baralho1: Array = _construir_baralho(_ids_do_deck(str(d1.get("deck_id", ""))))
	var baralho2: Array = _construir_baralho(_ids_do_deck(str(d2.get("deck_id", ""))))
	_embaralhar(baralho1)
	_embaralhar(baralho2)
	var primeiro := 0
	match str(setup.get("turn_order", "first_p1")):
		"first_p1":
			primeiro = 0
		"first_p2":
			primeiro = 1
		"random":
			primeiro = rng.randi_range(0, 1)
		_:
			primeiro = 0
	# Campo de Testes (contrato duel_setup.test_state, doc 04.6): é SÓ DADO
	# de inicialização (R3). Quando presente, o duelo sempre começa na fase
	# da mão de p0 (D24), então força o primeiro a 0 independente do sorteio.
	var teste: Dictionary = {}
	if setup.get("test_state", {}) is Dictionary:
		teste = setup.get("test_state", {})
	if not teste.is_empty():
		primeiro = 0
	state = GameState.create(baralho1, baralho2, lp, primeiro)
	if teste.is_empty():
		for i in range(5):
			for pi in [0, 1]:
				var dk: Array = (state.players[pi] as Dictionary)["deck"]
				if not dk.is_empty():
					((state.players[pi] as Dictionary)["hand"] as Array).append(dk.pop_front())
		# FM fiel: cada lado começa com 5, SEM carta extra. O refill até 5
		# acontece todo início de turno (TurnManager DRAW).
	else:
		_aplicar_test_state(teste)


## Campo de Testes: monta mão + campo iniciais vindos do duel_setup.test_state
## (DADO do Studio, doc 04.6). Só inicialização, sem regra nova (R3):
## - my_hand[0-5] vira a mão inicial de p0 (cartas abertas, do cards_db);
##   o resto completa até 5 pela REGRA REAL (TurnManager DRAW refill, com
##   deck out D26 — o mesmo motor do turno, sem duplicar lógica);
## - p0_monster/p0_spell/p1_monster/p1_spell (5 slots cada) vão p/ os
##   players[0]/[1] via SummonSystem.construir_instancia (construtor ÚNICO,
##   R1): face_down = !face_up, position ATK/DEF, ATK/DEF da base (o clamp
##   0-9999 de leitura já mora no construtor), estrela = guardian_star_1
##   do dado (igual à fusão), null = vazio;
## - tudo ausente/desconhecido = completa pelo padrão (mão compra do deck,
##   slot fica vazio, card_id fora do catálogo é ignorado com aviso).
## Sem test_state este caminho nunca roda (comportamento 100% igual).
func _aplicar_test_state(teste: Dictionary) -> void:
	# Rival (p1): mão inicial normal, igual ao duelo sem teste (5 do deck).
	for i in range(5):
		var dk1: Array = (state.players[1] as Dictionary)["deck"]
		if not dk1.is_empty():
			((state.players[1] as Dictionary)["hand"] as Array).append(dk1.pop_front())
	# Minha mão (p0): os ids pedidos primeiro, depois o refill real até 5.
	var mao0: Array = (state.players[0] as Dictionary)["hand"]
	var pedidas: Array = []
	if teste.get("my_hand", []) is Array:
		pedidas = teste.get("my_hand", [])
	for i in range(mini(5, pedidas.size())):
		var cid := str(pedidas[i])
		if not cards_db.has(cid):
			print("[Duel] Aviso: test_state ignorou card_id desconhecido na mão: " + cid)
			continue
		mao0.append((cards_db[cid] as Dictionary).duplicate(true))
	# current_player já é 0 (forçado acima): completa até 5 pela regra fixa.
	TurnManager.draw_for_current(state)
	_aplicar_zona_teste(0, "monster", teste.get("p0_monster", []))
	_aplicar_zona_teste(0, "spell", teste.get("p0_spell", []))
	_aplicar_zona_teste(1, "monster", teste.get("p1_monster", []))
	_aplicar_zona_teste(1, "spell", teste.get("p1_spell", []))
	print("[Duel] Campo de Testes: mão p0=%d p1=%d, campo p0_m=%d p0_s=%d p1_m=%d p1_s=%d." % [
		((state.players[0] as Dictionary)["hand"] as Array).size(),
		((state.players[1] as Dictionary)["hand"] as Array).size(),
		_contar_campo(0, "monster"), _contar_campo(0, "spell"),
		_contar_campo(1, "monster"), _contar_campo(1, "spell"),
	])


func _aplicar_zona_teste(pi: int, nome_zona: String, lista) -> void:
	if not (lista is Array):
		return
	var zona: Array = (state.players[pi] as Dictionary)[nome_zona]
	for i in range(mini(5, mini(lista.size(), zona.size()))):
		var slot = lista[i]
		if slot == null:
			continue # null = vazio (já vem null do GameState).
		if not (slot is Dictionary):
			continue
		var cid := str((slot as Dictionary).get("card_id", ""))
		if not cards_db.has(cid):
			print("[Duel] Aviso: test_state ignorou card_id desconhecido no campo: " + cid)
			continue
		var base: Dictionary = cards_db[cid] as Dictionary
		var face_up := bool((slot as Dictionary).get("face_up", true))
		var em_ataque := bool((slot as Dictionary).get("attack_position", true))
		var estrela := str(base.get("guardian_star_1", ""))
		zona[i] = SummonSystem.construir_instancia(base, not face_up, "ATK" if em_ataque else "DEF", estrela)


func _contar_campo(pi: int, nome_zona: String) -> int:
	var n := 0
	for m in ((state.players[pi] as Dictionary)[nome_zona] as Array):
		if m != null:
			n += 1
	return n


func _ids_do_deck(deck_id: String) -> Array:
	if not decks_db.has(deck_id):
		return []
	var d: Dictionary = decks_db[deck_id] as Dictionary
	return Array(d.get("cards", [])).duplicate()


func _construir_baralho(ids: Array) -> Array:
	var out: Array = []
	for cid in ids:
		var key: String = str(cid)
		if cards_db.has(key):
			out.append((cards_db[key] as Dictionary).duplicate(true))
	return out


func _embaralhar(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func advance_phase() -> Dictionary:
	return TurnManager.advance_phase(state)


func get_state():
	return state


func get_winner() -> int:
	return int(state.winner)


func is_over() -> bool:
	return bool(state.over)
