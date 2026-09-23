class_name DuelBattleSystem
extends RefCounted

## BattleSystem — 1 ataque por monstro por BATTLE (doc 13, LOGIC fixa).
##
## REGRA DE DANO V1 (simplificada, vale para alvo em ATK ou em DEF):
## - compara ATK do atacante com ATK do alvo (alvo em ATK) ou DEF do alvo (alvo em DEF);
## - atacante maior: alvo vai ao cemitério + dano da diferença no LP do dono do alvo;
## - atacante menor: atacante vai ao cemitério + dano da diferença no próprio LP;
## - empate: os dois vão ao cemitério, sem dano a ninguém.
## - ataque direto (alvo = -1) só é permitido se o oponente não tiver monstros;
##   dano direto = ATK do atacante no LP do oponente.
## Invocação sempre coloca em ATK na V1; posição DEF existe no dado para futuro.

const DamageSystem := preload("res://duel/damage_system.gd")


static func has_monsters(state, player_idx: int) -> bool:
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	for m in zona:
		if m != null:
			return true
	return false


static func first_monster_slot(state, player_idx: int) -> int:
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	for i in range(zona.size()):
		if zona[i] != null:
			return i
	return -1


static func can_attack(state, attacker_player: int, attacker_slot: int) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou."}
	if String(state.phase) != "BATTLE":
		return {"ok": false, "erro": "Ataque só na fase BATTLE."}
	if int(state.current_player) != attacker_player:
		return {"ok": false, "erro": "Só o jogador da vez pode atacar."}
	var zona: Array = (state.players[attacker_player] as Dictionary)["monster"]
	if attacker_slot < 0 or attacker_slot >= zona.size() or zona[attacker_slot] == null:
		return {"ok": false, "erro": "Atacante inválido."}
	var atacante: Dictionary = zona[attacker_slot] as Dictionary
	if bool(atacante.get("has_attacked", false)):
		return {"ok": false, "erro": "Este monstro já atacou neste turno."}
	return {"ok": true, "erro": ""}


static func attack(state, attacker_player: int, attacker_slot: int, target_player: int, target_slot: int) -> Dictionary:
	var pode: Dictionary = can_attack(state, attacker_player, attacker_slot)
	if not bool(pode.get("ok", false)):
		return pode
	if target_player < 0 or target_player > 1 or target_player == attacker_player:
		return {"ok": false, "erro": "Alvo inválido."}
	var zona_a: Array = (state.players[attacker_player] as Dictionary)["monster"]
	var atacante: Dictionary = zona_a[attacker_slot] as Dictionary
	var atk_val: int = int(atacante.get("atk", 0))
	# Ataque direto: só sem monstros inimigos.
	if target_slot < 0:
		if has_monsters(state, target_player):
			return {"ok": false, "erro": "Ataque direto só sem monstros inimigos.", "dano": 0, "direto": false, "destruiu_atacante": false, "destruiu_alvo": false}
		atacante["has_attacked"] = true
		var rd: Dictionary = DamageSystem.apply_damage(state, target_player, atk_val)
		return {"ok": true, "erro": "", "direto": true, "dano": atk_val, "destruiu_atacante": false, "destruiu_alvo": false, "lp_alvo": int(rd.get("lp", 0))}
	var zona_d: Array = (state.players[target_player] as Dictionary)["monster"]
	if target_slot < 0 or target_slot >= zona_d.size() or zona_d[target_slot] == null:
		return {"ok": false, "erro": "Alvo inválido.", "dano": 0, "direto": false, "destruiu_atacante": false, "destruiu_alvo": false}
	var alvo: Dictionary = zona_d[target_slot] as Dictionary
	var pos: String = str(alvo.get("position", "ATK"))
	var alvo_val: int = int(alvo.get("atk", 0)) if pos == "ATK" else int(alvo.get("def", 0))
	atacante["has_attacked"] = true
	if atk_val > alvo_val:
		var diff: int = atk_val - alvo_val
		zona_d[target_slot] = null
		_para_cemiterio(state, target_player, alvo)
		var r: Dictionary = DamageSystem.apply_damage(state, target_player, diff)
		return {"ok": true, "erro": "", "direto": false, "dano": diff, "destruiu_atacante": false, "destruiu_alvo": true, "lp_alvo": int(r.get("lp", 0))}
	elif atk_val < alvo_val:
		var diff2: int = alvo_val - atk_val
		zona_a[attacker_slot] = null
		_para_cemiterio(state, attacker_player, atacante)
		var r2: Dictionary = DamageSystem.apply_damage(state, attacker_player, diff2)
		return {"ok": true, "erro": "", "direto": false, "dano": diff2, "destruiu_atacante": true, "destruiu_alvo": false, "lp_atacante": int(r2.get("lp", 0))}
	else:
		zona_a[attacker_slot] = null
		zona_d[target_slot] = null
		_para_cemiterio(state, attacker_player, atacante)
		_para_cemiterio(state, target_player, alvo)
		DamageSystem.check_defeat(state)
		return {"ok": true, "erro": "Empate: os dois monstros foram destruídos.", "direto": false, "dano": 0, "destruiu_atacante": true, "destruiu_alvo": true}


static func _para_cemiterio(state, player_idx: int, inst: Dictionary) -> void:
	var cem: Array = (state.players[player_idx] as Dictionary)["graveyard"]
	cem.append(str(inst.get("card_id", "")))
