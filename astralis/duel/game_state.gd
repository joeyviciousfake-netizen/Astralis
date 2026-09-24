class_name DuelGameState
extends RefCounted

## GameState — dados puros do duelo (sem regras, sem cena).
## Zonas por jogador: deck, hand, monster[5], spell[5], graveyard, banished.
## + LP, turno/fase atual, vencedor. As regras ficam nos outros sistemas
## (TurnManager, SummonSystem, BattleSystem, DamageSystem, DuelManager).
## R3: só guarda DADO. Testável sem cena (RefCounted).
## D17: 5 slots monstro + 5 outros por lado, mão 5, decks 40, jogador (lado 0)
## não ataca no turno 1. Carta em campo tem face_down + battle_position
## (ATK vertical / DEF horizontal); virada p/ baixo entra em DEF.

const MONSTER_SLOTS := 5
const SPELL_SLOTS := 5
const INITIAL_HAND := 5
const MAX_HAND := 7
const PHASES := ["DRAW", "MAIN", "BATTLE", "END"]

var players: Array = []
var current_player: int = 0
var turn_number: int = 1
var phase: String = "DRAW"
var winner: int = -1 # -1 = sem vencedor, 0/1 = jogador, -2 = empate
var over: bool = false
var normal_summon_used: bool = false
var starting_lp: int = 4000


static func create(p0_deck: Array, p1_deck: Array, lp: int, first: int):
	# load() em vez de DuelGameState.new(): funciona mesmo com cache frio de class_name.
	var s = (load("res://duel/game_state.gd") as GDScript).new()
	s.starting_lp = lp
	s.players = [_make_player(p0_deck, lp), _make_player(p1_deck, lp)]
	s.current_player = clampi(first, 0, 1)
	s.turn_number = 1
	s.phase = "DRAW"
	s.winner = -1
	s.over = false
	s.normal_summon_used = false
	return s


static func _make_player(deck: Array, lp: int) -> Dictionary:
	return {
		"deck": deck,
		"hand": [],
		"monster": [null, null, null, null, null],
		"spell": [null, null, null, null, null],
		"graveyard": [],
		"banished": [],
		"lp": lp,
		"max_lp": lp,
	}


func get_player(idx: int) -> Dictionary:
	return players[idx] as Dictionary


func opponent_of(idx: int) -> int:
	return 1 - idx


func is_over() -> bool:
	return over


func get_winner() -> int:
	return winner
