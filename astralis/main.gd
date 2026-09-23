extends Node

## Cena inicial — valida o Starter Kit e simula um duelo automático curto
## com os sistemas reais (DuelManager). Só prepara/observa (R2).
## R5: sem efeito/fusão/IA/UI aqui — só invoca + ataca com o núcleo do duelo.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const RuntimeValidatorScript := preload("res://core/runtime_validator.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const BattleSystem := preload("res://duel/battle_system.gd")

func _ready() -> void:
	print("[Astralis] Iniciando Starter Kit...")
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	var counts: Dictionary = state.get("counts", {})
	var n_cartas: int = int(counts.get("cartas", 0))
	var n_duelistas: int = int(counts.get("duelistas", 0))
	var n_decks: int = int(counts.get("decks", 0))
	var erros: Array = RuntimeValidatorScript.validate(data)
	var load_errors: Array = data.get("load_errors", [])
	for e in load_errors:
		erros.append(str(e))
	print("[Astralis] STP: %d cartas, %d duelistas, %d decks, erros=%d" % [n_cartas, n_duelistas, n_decks, erros.size()])
	if erros.is_empty():
		print("[Astralis] OK: Starter Kit válido, sem erros.")
	else:
		for e in erros:
			print("[Astralis] ERRO: " + str(e))
	_simular_duelo(data)


func _simular_duelo(data: Dictionary) -> void:
	var duel_setup: Dictionary = data.get("duel_setup", {})
	var decks: Dictionary = data.get("decks", {})
	var cards: Dictionary = data.get("cards", {})
	if duel_setup.is_empty() or decks.is_empty() or cards.is_empty():
		print("[Astralis] DUELO: sem dados para simular.")
		return
	var duel = DuelManagerScript.new_duel(duel_setup, decks, cards)
	var st = duel.get_state()
	var passos := 0
	while not duel.is_over() and int(st.turn_number) <= 20 and passos < 200:
		passos += 1
		match String(st.phase):
			"DRAW":
				duel.advance_phase()
			"MAIN":
				_auto_invocar(st)
				duel.advance_phase()
			"BATTLE":
				_auto_atacar(st)
				duel.advance_phase()
			"END":
				duel.advance_phase()
			_:
				break
	var lp0: int = int((st.players[0] as Dictionary)["lp"])
	var lp1: int = int((st.players[1] as Dictionary)["lp"])
	var v: int = int(st.winner)
	var nome_v := "ninguém (limite de 20 turnos)"
	if v == 0 or v == 1:
		nome_v = "jogador %d" % v
	elif v == -2:
		nome_v = "empate"
	print("[Astralis] DUELO: turnos=%d, LP=(%d x %d), vencedor=%s" % [int(st.turn_number), lp0, lp1, nome_v])


func _auto_invocar(st) -> void:
	var cur: int = int(st.current_player)
	if bool(st.normal_summon_used):
		return
	var mao: Array = (st.players[cur] as Dictionary)["hand"]
	var idx_mao := -1
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			idx_mao = i
			break
	if idx_mao < 0:
		return
	var slot: int = SummonSystem.free_monster_slot(st, cur)
	if slot < 0:
		return
	SummonSystem.normal_summon(st, cur, idx_mao, slot)


func _auto_atacar(st) -> void:
	var cur: int = int(st.current_player)
	var foe: int = 1 - cur
	var zona: Array = (st.players[cur] as Dictionary)["monster"]
	for slot in range(zona.size()):
		if bool(st.over):
			return
		if zona[slot] == null:
			continue
		var m: Dictionary = zona[slot] as Dictionary
		if bool(m.get("has_attacked", false)):
			continue
		var alvo: int = BattleSystem.first_monster_slot(st, foe)
		BattleSystem.attack(st, cur, slot, foe, alvo)
