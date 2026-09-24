class_name DuelSummonSystem
extends RefCounted

## SummonSystem — 1 invocação normal por MAIN, só em slot livre.
## Regras V1 + D17 (LOGIC fixa):
## - só na fase MAIN, só o jogador da vez, 1 uso por turno;
## - slot de monstro livre (0..4, 5 slots por lado);
## - a carta precisa ser monster;
## - face_down=false + position ATK/DEF (p/ cima, vertical ou horizontal);
## - face_down=true entra sempre em DEF (virada p/ baixo, horizontal).
## R3: ATK/DEF vêm do dado; a permissão é fixa.

static func free_monster_slot(state, player_idx: int) -> int:
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	for i in range(zona.size()):
		if zona[i] == null:
			return i
	return -1


static func can_normal_summon(state, player_idx: int, hand_index: int, slot_index: int, face_down: bool = false, position: String = "ATK") -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou."}
	if String(state.phase) != "MAIN":
		return {"ok": false, "erro": "Invocação só na fase MAIN."}
	if int(state.current_player) != player_idx:
		return {"ok": false, "erro": "Só o jogador da vez pode invocar."}
	if bool(state.normal_summon_used):
		return {"ok": false, "erro": "Só 1 invocação normal por turno."}
	var mao: Array = (state.players[player_idx] as Dictionary)["hand"]
	if hand_index < 0 or hand_index >= mao.size():
		return {"ok": false, "erro": "Carta inválida na mão."}
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	if slot_index < 0 or slot_index >= zona.size():
		return {"ok": false, "erro": "Slot de monstro inválido (0 a %d)." % (zona.size() - 1)}
	if zona[slot_index] != null:
		return {"ok": false, "erro": "Slot de monstro ocupado."}
	var carta = mao[hand_index]
	if not (carta is Dictionary) or str((carta as Dictionary).get("card_type", "")) != "monster":
		return {"ok": false, "erro": "Só monstro pode ser invocado."}
	var pos: String = position.to_upper()
	if pos != "ATK" and pos != "DEF":
		return {"ok": false, "erro": "Posição inválida (use Ataque ou Defesa)."}
	# Virada p/ baixo entra sempre em DEF (D17).
	if face_down and pos != "DEF":
		return {"ok": false, "erro": "Carta virada entra em Defesa."}
	return {"ok": true, "erro": ""}


static func normal_summon(state, player_idx: int, hand_index: int, slot_index: int, face_down: bool = false, position: String = "ATK") -> Dictionary:
	var pode: Dictionary = can_normal_summon(state, player_idx, hand_index, slot_index, face_down, position)
	if not bool(pode.get("ok", false)):
		return pode
	var p: Dictionary = state.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	var carta: Dictionary = mao[hand_index] as Dictionary
	var pos_final: String = "DEF" if face_down else position.to_upper()
	var inst := {
		"card_id": str(carta.get("id", "")),
		"nome": str(carta.get("name", "")),
		"atk": clampi(int(carta.get("attack", 0)), 0, 9999),
		"def": clampi(int(carta.get("defense", 0)), 0, 9999),
		"position": pos_final,
		"battle_position": pos_final,
		"face_down": face_down,
		"has_attacked": false,
	}
	mao.remove_at(hand_index)
	zona[slot_index] = inst
	state.normal_summon_used = true
	return {"ok": true, "erro": "", "carta": str(carta.get("id", "")), "slot": slot_index, "face_down": face_down, "position": pos_final}

