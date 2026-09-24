class_name DuelPositionSystem
extends RefCounted

## PositionSystem — troca Ataque (vertical) / Defesa (horizontal) na mesa.
## Regra FM fiel (LOGIC fixa, sem dado novo):
## - só na BATTLE, só o jogador da vez, só carta própria em campo;
## - trava pós-ataque: se has_attacked=true, não pode trocar;
## - face_down é preservada (virada continua virada, só deita/levanta).
## R1/R2: sistema real; a mesa só chama e mostra.

static func can_change_position(state, player_idx: int, slot_idx: int) -> Dictionary:
	if state.over:
		return {"ok": false, "erro": "Duelo já acabou."}
	if String(state.phase) != "BATTLE":
		return {"ok": false, "erro": "Posição só na sua BATTLE."}
	if int(state.current_player) != player_idx:
		return {"ok": false, "erro": "Só o jogador da vez troca posição."}
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	if slot_idx < 0 or slot_idx >= zona.size() or zona[slot_idx] == null:
		return {"ok": false, "erro": "Sem carta nesse slot."}
	var m: Dictionary = zona[slot_idx] as Dictionary
	if bool(m.get("has_attacked", false)):
		return {"ok": false, "erro": "Já atacou: posição travada neste turno."}
	var pos := str(m.get("position", "ATK"))
	if pos != "ATK" and pos != "DEF":
		return {"ok": false, "erro": "Posição inválida."}
	return {"ok": true, "erro": ""}


static func toggle_position(state, player_idx: int, slot_idx: int) -> Dictionary:
	var pode: Dictionary = can_change_position(state, player_idx, slot_idx)
	if not bool(pode.get("ok", false)):
		return pode
	var zona: Array = (state.players[player_idx] as Dictionary)["monster"]
	var m: Dictionary = zona[slot_idx] as Dictionary
	var atual := str(m.get("position", "ATK"))
	var nova := "DEF" if atual == "ATK" else "ATK"
	m["position"] = nova
	m["battle_position"] = nova
	return {"ok": true, "erro": "", "position": nova}
