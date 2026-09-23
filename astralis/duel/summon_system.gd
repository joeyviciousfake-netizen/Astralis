class_name DuelSummonSystem
extends RefCounted

## SummonSystem — 1 invocação normal por MAIN, só em slot livre, ATK/DEF da carta.
## Regras V1 (doc 13, LOGIC fixa):
## - só na fase MAIN, só o jogador da vez, 1 uso por turno;
## - slot de monstro 0..2 precisa estar livre;
## - a carta precisa ser monster; entra em campo em ATK com ATK/DEF da carta.
## R3: ATK/DEF vêm do dado; a permissão é fixa.

static func free_monster_slot(state, player_idx: int) -> int:
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	for i in range(zona.size()):
		if zona[i] == null:
			return i
	return -1


static func can_normal_summon(state, player_idx: int, hand_index: int, slot_index: int) -> Dictionary:
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
	if slot_index < 0 or slot_index > 2:
		return {"ok": false, "erro": "Slot de monstro inválido (0 a 2)."}
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	if zona[slot_index] != null:
		return {"ok": false, "erro": "Slot de monstro ocupado."}
	var carta = mao[hand_index]
	if not (carta is Dictionary) or str((carta as Dictionary).get("card_type", "")) != "monster":
		return {"ok": false, "erro": "Só monstro pode ser invocado."}
	return {"ok": true, "erro": ""}


static func normal_summon(state, player_idx: int, hand_index: int, slot_index: int) -> Dictionary:
	var pode: Dictionary = can_normal_summon(state, player_idx, hand_index, slot_index)
	if not bool(pode.get("ok", false)):
		return pode
	var p: Dictionary = state.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var zona: Array = p["monster"]
	var carta: Dictionary = mao[hand_index] as Dictionary
	var inst := {
		"card_id": str(carta.get("id", "")),
		"nome": str(carta.get("name", "")),
		"atk": int(carta.get("attack", 0)),
		"def": int(carta.get("defense", 0)),
		"position": "ATK",
		"has_attacked": false,
	}
	mao.remove_at(hand_index)
	zona[slot_index] = inst
	state.normal_summon_used = true
	return {"ok": true, "erro": "", "carta": str(carta.get("id", "")), "slot": slot_index}
