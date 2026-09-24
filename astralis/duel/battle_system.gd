class_name DuelBattleSystem
extends RefCounted

## BattleSystem — 1 ataque por monstro por BATTLE (doc 13 + D17/D22, LOGIC fixa).
##
## REGRA DE DANO D17/D22 (nossa, vale até o lote FM):
## - alvo em ATK: compara ATK x ATK (maior destrói o outro + dano da
##   diferença no LP do dono do destruído; empate = os dois caem, sem dano).
## - alvo em DEF: compara ATK do atacante x DEF do alvo, mesma conta:
##   ATK maior destrói o alvo + dano da diferença no LP do dono do alvo;
##   ATK menor destrói o ATACANTE + dano da diferença no próprio LP;
##   empate (F1): nada acontece, sem dano e sem destruição.
## - ataque direto (alvo = -1) só é permitido se o oponente não tiver monstros;
##   dano direto = ATK do atacante no LP do oponente.
## D17 (restaurada, D28 revertido):
## - jogador (lado 0) não ataca no 1º turno; inimigo pode atacar no turno dele;
## - carta tem face_down (bool) + battle_position (ATK vertical / DEF horizontal);
## - virada p/ baixo entra em DEF e o inimigo não vê ATK/DEF (a tela esconde);
## - ao ser atacada, a carta virada vira p/ cima ANTES do cálculo;
## - só ataca monstro virado p/ cima em ATK.

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
	if bool(atacante.get("face_down", false)) or str(atacante.get("position", "ATK")) != "ATK":
		return {"ok": false, "erro": "Só monstro virado em Ataque pode atacar."}
	if bool(atacante.get("has_attacked", false)):
		return {"ok": false, "erro": "Este monstro já atacou neste turno."}
	# D17/D22: jogador (lado 0) não ataca no 1º turno; inimigo pode no dele.
	if attacker_player == 0 and int(state.turn_number) <= 1:
		return {"ok": false, "erro": "Sem ataque no 1º turno."}
	return {"ok": true, "erro": ""}


static func attack(state, attacker_player: int, attacker_slot: int, target_player: int, target_slot: int) -> Dictionary:
	var pode: Dictionary = can_attack(state, attacker_player, attacker_slot)
	if not bool(pode.get("ok", false)):
		return pode
	if target_player < 0 or target_player > 1 or target_player == attacker_player:
		return {"ok": false, "erro": "Alvo inválido."}
	var zona_a: Array = (state.players[attacker_player] as Dictionary)["monster"]
	var atacante: Dictionary = zona_a[attacker_slot] as Dictionary
	var atk_val: int = clampi(int(atacante.get("atk", 0)), 0, 9999)
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
	# D17: a virada vira p/ cima ANTES do cálculo (entra em DEF).
	alvo["face_down"] = false
	var pos: String = str(alvo.get("position", "ATK"))
	var alvo_val: int = clampi(int(alvo.get("atk", 0)) if pos == "ATK" else int(alvo.get("def", 0)), 0, 9999)
	atacante["has_attacked"] = true
	if atk_val > alvo_val:
		# D17/D22: maior vence, destrói o alvo + dano da diferença no LP do
		# dono do alvo (vale contra ATK e contra DEF fraca).
		var diff: int = atk_val - alvo_val
		zona_d[target_slot] = null
		_para_cemiterio(state, target_player, alvo)
		var r: Dictionary = DamageSystem.apply_damage(state, target_player, diff)
		return {"ok": true, "erro": "", "direto": false, "dano": diff, "destruiu_atacante": false, "destruiu_alvo": true, "lp_alvo": int(r.get("lp", 0))}
	elif atk_val < alvo_val:
		# D17/D22: menor perde, destrói o ATACANTE + dano da diferença no
		# próprio LP (vale contra ATK e contra DEF forte).
		var diff2: int = alvo_val - atk_val
		zona_a[attacker_slot] = null
		_para_cemiterio(state, attacker_player, atacante)
		var r2: Dictionary = DamageSystem.apply_damage(state, attacker_player, diff2)
		return {"ok": true, "erro": "", "direto": false, "dano": diff2, "destruiu_atacante": true, "destruiu_alvo": false, "lp_atacante": int(r2.get("lp", 0))}
	else:
		# F1 (FM): empate ATK vs DEF = nada acontece; empate ATK vs ATK = os dois caem.
		if pos != "ATK":
			return {"ok": true, "erro": "Empate contra Defesa: nada acontece.", "direto": false, "dano": 0, "destruiu_atacante": false, "destruiu_alvo": false}
		zona_a[attacker_slot] = null
		zona_d[target_slot] = null
		_para_cemiterio(state, attacker_player, atacante)
		_para_cemiterio(state, target_player, alvo)
		DamageSystem.check_defeat(state)
		return {"ok": true, "erro": "Empate: os dois monstros foram destruídos.", "direto": false, "dano": 0, "destruiu_atacante": true, "destruiu_alvo": true}


static func _para_cemiterio(state, player_idx: int, inst: Dictionary) -> void:
	var cem: Array = (state.players[player_idx] as Dictionary)["graveyard"]
	cem.append(str(inst.get("card_id", "")))
