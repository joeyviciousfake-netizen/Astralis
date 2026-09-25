class_name AstralisTestBase
extends GutTest

## astralis_test_base — a BASE ÚNICA de todos os testes GUT do Astralis.
##
## COMO SE ESTENDE (leia antes de criar arquivo de teste): use o CAMINHO,
## não o nome global:
##     extends "res://testing/astralis_test_base.gd"
## Motivo: rodar `godot --headless -s gut_cmdln.gd` NÃO reconstrói o cache de
## classes globais (`.godot/global_script_class_cache.cfg`), então
## `extends AstralisTestBase` quebra em CI/clone novo com
## "Could not find base class". O `class_name` acima é só pro editor abrir
## bonito; quem roda a suíte é o caminho.
##
## O que este arquivo trava: NENHUMA regra. Ele só reúne, numa cópia só, os
## helpers que antes estavam duplicados em 7 dos 11 arquivos de teste
## (~200 linhas repetidas). Cada `test_*.gd` agora faz
## `extends AstralisTestBase` e usa daqui.
##
## REGRA R2 (a mais importante deste arquivo): helper só ORGANIZA DADO
## (monta duelo, enche a mão, ocupa slot, limpa campo) ou OBSERVA o estado.
## Quem decide a regra é SEMPRE o sistema real do Astralis (DuelManager,
## Summon, Battle, Damage, Turn, Fusion, DataLoader, BoardLayout e a cena
## duel_table.tscn). Proibido Fake/Mock/Stub de gameplay (R2) e proibido
## "adaptar" um teste que falhou: teste vermelho = bug do runtime, reportar.
##
## Os preloads abaixo são os SISTEMAS REAIS. Nenhum é cópia, nenhum é dublê.
##
## CUIDADO ao adicionar helper aqui: 1) nome novo só se o comportamento for
## realmente diferente (as cópias antigas de `_inst` e `_inst_campo` NÃO são
## iguais — por isso as duas existem com nomes diferentes); 2) helper não
## pode virar regra nova, senão o teste deixa de testar o motor real.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const DuelManagerScript := preload("res://duel/duel_manager.gd")
const SummonSystem := preload("res://duel/summon_system.gd")
const TableScript := preload("res://ui/duel_table.gd")
const MesaScene := preload("res://ui/duel_table.tscn")


# ---------- DUELO (motor, sem cena) ----------

# Monta um duelo novo de verdade: conteúdo FM + duel_setup (seed 42).
func _novo_duelo():
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	return DuelManagerScript.new_duel(data.get("duel_setup", {}), data.get("decks", {}), data.get("cards", {}))


# Índice da 1ª carta de tipo monstro na mão de um lado (-1 se não tem).
func _indice_monstro_na_mao(st, player_idx: int) -> int:
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for i in range(mao.size()):
		var c = mao[i]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			return i
	return -1


# Quantas cartas de tipo monstro tem na mão de um lado.
func _contar_monstros_na_mao(st, player_idx: int) -> int:
	var n := 0
	var mao: Array = (st.players[player_idx] as Dictionary)["hand"]
	for c in mao:
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			n += 1
	return n


# Prepara: garante N monstros na mão puxando do topo do próprio deck.
# Só organiza dado; a regra testada continua sendo a do motor real.
func _garantir_monstros_na_mao(st, player_idx: int, quantos: int) -> void:
	var p: Dictionary = st.players[player_idx] as Dictionary
	var mao: Array = p["hand"]
	var deck: Array = p["deck"]
	var k := 0
	while _contar_monstros_na_mao(st, player_idx) < quantos and k < deck.size():
		var c = deck[k]
		if c is Dictionary and str((c as Dictionary).get("card_type", "")) == "monster":
			mao.append(c)
			deck.remove_at(k)
		else:
			k += 1


# ---------- MESA REAL (duel_table.tscn) ----------

# Mesa nova de verdade: instancia a cena, espera 4 quadros (a mesa monta o
# duelo e desenha sozinha) e devolve o nó. O GUT libera no fim do teste.
func _mesa_nova():
	var mesa: Node = MesaScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(4)
	return mesa


# Roda o fluxo fiel completo na mesa real via confirmar de verdade:
# carta -> centro (face) -> slot -> estrela -> campo. Devolve o slot usado
# e a estrela esperada. O botão é só simulado (Input.action_press);
# quem anda é o método real da mesa.
func _fluxo_completo_ate_campo(mesa: Node, face_baixo: bool, estrela_idx: int) -> Dictionary:
	var st = mesa.get("_st")
	var mao_antes: int = ((st.players[0] as Dictionary)["hand"] as Array).size()
	var idx: int = _indice_monstro_na_mao(st, 0)
	assert_true(idx >= 0, "Preparo: mão tem monstro p/ o fluxo fiel.")
	mesa.set("_pad_fileira", TableScript.FILEIRA_MAO)
	mesa.set("_pad_col", idx)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_FACE, "Carta foi ao centro (trava a face).")
	if face_baixo:
		Input.action_press("mover_dir")
		mesa.call("_pad_mover", 1, 0)
		Input.action_release("mover_dir")
	assert_eq(bool(mesa.get("_face_baixo")), face_baixo, "Face escolhida: p/ baixo = %s." % str(face_baixo))
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_SLOT, "Face travada, escolhe 1 dos 5 slots.")
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(slot >= 0, "Preparo: há slot livre no próprio campo.")
	mesa.set("_pad_col", slot)
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), TableScript.SUB_ESTRELA, "Slot escolhido, abre o menu da estrela.")
	assert_true((mesa.get("_popup") as Control).visible, "Menu da estrela abriu no centro.")
	var ops: Array = mesa.get("_estrela_ops")
	assert_eq(ops.size(), 2, "Menu traz as 2 guardian stars do dado.")
	if estrela_idx == 1:
		Input.action_press("mover_baixo")
		mesa.call("_pad_mover", 0, 1)
		Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_pad_popup_idx")), estrela_idx, "Cursor do menu na estrela %d." % (estrela_idx + 1))
	var esperada := str(ops[estrela_idx])
	Input.action_press("confirmar")
	mesa.call("_pad_confirmar")
	Input.action_release("confirmar")
	return {"slot": slot, "estrela": esperada, "mao_antes": mao_antes}


# ---------- CAMPO (instâncias) ----------
# As duas funções de instância NÃO podem virar uma: são diferentes de propósito.
# `_inst` trava a ESCOLHA DE ATAQUE da IA (ATK/DEF varym, guardiã vazia).
# `_inst_campo` trava o DESENHO da mesa (ATK/DEF fixos, guardiã "Sol").
# Unificar as duas mudaria o número esperado dos testes.

# Zera os 5 slots de monstro dos 2 lados (só organiza dado).
func _limpar_campo(st) -> void:
	for i in range(5):
		(st.players[0] as Dictionary)["monster"][i] = null
		(st.players[1] as Dictionary)["monster"][i] = null


# Instância p/ travar a IA de ataque: ATK/DEF são parâmetros, guardiã vazia.
func _inst(atk: int, pos: String = "ATK", face_down: bool = false, def: int = 1000) -> Dictionary:
	return {
		"card_id": "trava",
		"nome": "Trava",
		"atk": atk,
		"def": def,
		"position": pos,
		"battle_position": pos,
		"face_down": face_down,
		"has_attacked": false,
		"guardian_star": "",
	}


# Instância p/ travar o desenho da mesa: ATK 1500/DEF 1200 e guardiã "Sol".
func _inst_campo(pos: String, face_down: bool) -> Dictionary:
	return {
		"card_id": "",
		"nome": "Trava",
		"atk": 1500,
		"def": 1200,
		"position": pos,
		"battle_position": pos,
		"face_down": face_down,
		"has_attacked": false,
		"guardian_star": "Sol",
	}
