class_name DuelManager
extends RefCounted

## DuelManager — monta o duelo a partir do duel_setup (DADO) e expõe o jogo.
## - embaralha cada deck com a seed do setup (determinístico);
## - mão inicial 5 p/ cada lado, SEM carta extra (FM fiel: draw up to five);
## - todo início de turno completa a mão até 5 (regra no TurnManager DRAW refill);
## - LP inicial do setup; ordem first_p1/first_p2/random.
## Expõe advance_phase(), estado (get_state) e vencedor (get_winner/is_over).
## R1/R2: este é o sistema real; TestHarness/Studio só preparam e observam.

const GameState := preload("res://duel/game_state.gd")
const TurnManager := preload("res://duel/turn_manager.gd")

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
	state = GameState.create(baralho1, baralho2, lp, primeiro)
	for i in range(5):
		for pi in [0, 1]:
			var dk: Array = (state.players[pi] as Dictionary)["deck"]
			if not dk.is_empty():
				((state.players[pi] as Dictionary)["hand"] as Array).append(dk.pop_front())
	# FM fiel: cada lado começa com 5, SEM carta extra. O refill até 5
	# acontece todo início de turno (TurnManager DRAW).


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
