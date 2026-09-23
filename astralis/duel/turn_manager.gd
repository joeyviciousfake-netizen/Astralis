class_name DuelTurnManager
extends RefCounted

## TurnManager — fases DRAW→MAIN→BATTLE→END (doc 13, LOGIC fixa, nesta ordem).
## - DRAW: compra 1 carta do topo; deck vazio na hora de comprar = derrota (deck out);
## - MAIN: 1 invocação normal (regra no SummonSystem);
## - BATTLE: 1 ataque por monstro (regra no BattleSystem);
## - END: descarta excesso da mão (limite 7, excedente vai ao cemitério)
##   + checa vitória por LP. Sair do END troca o jogador e compra do novo turno.

const DamageSystem := preload("res://duel/damage_system.gd")


static func draw_for_current(state) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou.", "phase": String(state.phase)}
	var cur: int = int(state.current_player)
	var p: Dictionary = state.players[cur] as Dictionary
	var deck: Array = p["deck"]
	if deck.is_empty():
		state.winner = 1 - cur
		state.over = true
		return {"ok": false, "erro": "Deck vazio: jogador %d perdeu por deck out." % cur, "deckout": true, "vencedor": int(state.winner)}
	var carta = deck.pop_front()
	(p["hand"] as Array).append(carta)
	return {"ok": true, "erro": "", "mao": (p["hand"] as Array).size()}


static func discard_excess(state, player_idx: int) -> int:
	var p: Dictionary = state.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var cem: Array = p["graveyard"]
	var n := 0
	while mao.size() > 7:
		var c = mao.pop_back()
		if c is Dictionary:
			cem.append(str((c as Dictionary).get("id", "")))
		else:
			cem.append(str(c))
		n += 1
	return n


static func reset_attacks(state) -> void:
	var zona: Array = (state.players[int(state.current_player)] as Dictionary)["monster"]
	for m in zona:
		if m is Dictionary:
			(m as Dictionary)["has_attacked"] = false


static func advance_phase(state) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou.", "phase": String(state.phase), "vencedor": int(state.winner)}
	match String(state.phase):
		"DRAW":
			state.phase = "MAIN"
			return {"ok": true, "erro": "", "phase": "MAIN"}
		"MAIN":
			state.phase = "BATTLE"
			reset_attacks(state)
			return {"ok": true, "erro": "", "phase": "BATTLE"}
		"BATTLE":
			state.phase = "END"
			var n: int = discard_excess(state, int(state.current_player))
			var v: int = DamageSystem.check_defeat(state)
			return {"ok": true, "erro": "", "phase": "END", "descartes": n, "vencedor": v, "acabou": bool(state.over)}
		"END":
			state.current_player = 1 - int(state.current_player)
			state.turn_number = int(state.turn_number) + 1
			state.normal_summon_used = false
			state.phase = "DRAW"
			var r: Dictionary = draw_for_current(state)
			r["phase"] = "DRAW"
			r["jogador"] = int(state.current_player)
			r["turno"] = int(state.turn_number)
			return r
		_:
			return {"ok": false, "erro": "Fase inválida: " + String(state.phase), "phase": String(state.phase)}
