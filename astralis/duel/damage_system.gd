class_name DuelDamageSystem
extends RefCounted

## DamageSystem — aplica dano/cura e decide derrota por LP.
## Regras V1 (doc 13.4/13.5, LOGIC fixa):
## - dano subtrai do LP; cura soma sem nunca passar do inicial (max_lp);
## - LP<=0 = derrota (checada após cada dano e no END pelo TurnManager).
## R3: valores de ATK/DEF e LP inicial vêm dos dados; a fórmula é fixa.

static func apply_damage(state, player_idx: int, amount: int) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou.", "lp": -1, "dano": 0}
	if player_idx < 0 or player_idx > 1:
		return {"ok": false, "erro": "Jogador inválido.", "lp": -1, "dano": 0}
	var dmg: int = maxi(0, amount)
	var p: Dictionary = state.players[player_idx] as Dictionary
	p["lp"] = int(p["lp"]) - dmg
	if int(p["lp"]) < 0:
		p["lp"] = 0
	check_defeat(state)
	return {"ok": true, "erro": "", "lp": int(p["lp"]), "dano": dmg}


static func apply_heal(state, player_idx: int, amount: int) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou.", "lp": -1, "cura": 0}
	if player_idx < 0 or player_idx > 1:
		return {"ok": false, "erro": "Jogador inválido.", "lp": -1, "cura": 0}
	var cura: int = maxi(0, amount)
	var p: Dictionary = state.players[player_idx] as Dictionary
	var teto: int = int(p.get("max_lp", state.starting_lp))
	p["lp"] = mini(teto, int(p["lp"]) + cura)
	return {"ok": true, "erro": "", "lp": int(p["lp"]), "cura": cura}


## Retorna -1 (sem vencedor), 0/1 (jogador) ou -2 (empate, ambos zerados).
static func check_defeat(state) -> int:
	if state.over:
		return int(state.winner)
	var lp0: int = int((state.players[0] as Dictionary)["lp"])
	var lp1: int = int((state.players[1] as Dictionary)["lp"])
	if lp0 <= 0 and lp1 <= 0:
		state.winner = -2
		state.over = true
	elif lp0 <= 0:
		state.winner = 1
		state.over = true
	elif lp1 <= 0:
		state.winner = 0
		state.over = true
	return int(state.winner)
