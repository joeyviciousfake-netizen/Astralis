extends "res://testing/astralis_test_base.gd"

## test_ia_ataque — GUT permanente da escolha de ataque da IA (rival).
## Trava a regra nova do runtime (duel_table.gd: FindKiller + FindBestAttack)
## SEM mudar regra, com IA/mesa/sistemas REAIS (duel_table.tscn + Battle
## real). Sem Fake (R2). Seed fixa 42 (duel_setup).
## (1) campo vazio -> direto com o mais forte;
## (2) kill usa o mais fraco que vence (não o mais forte);
## (3) só DEF forte -> rival não ataca (passa);
## (4) empate ATK vs ATK -> ataca e os dois caem (dano 0);
## (5) _ia_bonus_guardia retorna 0 (guardiã adiada).
## Bug aqui vira teste permanente.
## Helpers (_mesa_nova/_limpar_campo/_inst) vêm de astralis_test_base.gd.

const BattleSystem := preload("res://duel/battle_system.gd")


func test_campo_vazio_direto_com_mais_forte() -> void:
	# (1) Seu campo vazio -> direto com o ATK não-usado mais forte.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[1] as Dictionary)["monster"][0] = _inst(1500)
	(st.players[1] as Dictionary)["monster"][2] = _inst(2200)
	assert_false(BattleSystem.has_monsters(st, 0), "Preparo: seu campo vazio.")
	var escolha: Array = mesa.call("_ia_escolher_ataque")
	assert_eq(escolha, [2, -1], "Campo vazio: direto com o mais forte (slot 2, 2200).")


func test_kill_usa_mais_fraco_que_vence() -> void:
	# (2) FindKiller: vence com o mais FRACO (diferença > 0), não o mais forte.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[0] as Dictionary)["monster"][1] = _inst(1500)
	(st.players[1] as Dictionary)["monster"][0] = _inst(1600)
	(st.players[1] as Dictionary)["monster"][1] = _inst(2500)
	var escolha: Array = mesa.call("_ia_escolher_ataque")
	assert_eq(escolha, [0, 1], "Kill usa o mais fraco que vence (1600 no alvo 1).")
	assert_ne(escolha, [1, 1], "Kill NÃO usa o mais forte (2500).")
	var zona_r: Array = (st.players[1] as Dictionary)["monster"]
	assert_eq(int((zona_r[int(escolha[0])] as Dictionary).get("atk", -1)), 1600, "Atacante escolhido tem 1600.")


func test_so_def_forte_rival_nao_ataca() -> void:
	# (3) Só DEF forte -> sem kill (1500-2500<0) e best ignora DEF -> passa.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[0] as Dictionary)["monster"][0] = _inst(500, "DEF", false, 2500)
	(st.players[1] as Dictionary)["monster"][0] = _inst(1500)
	assert_true(BattleSystem.has_monsters(st, 0), "Preparo: você tem monstro (em DEF).")
	var escolha: Array = mesa.call("_ia_escolher_ataque")
	assert_true(escolha.is_empty(), "Só DEF forte: rival não ataca (passa).")


func test_empate_atk_vs_atk_ataca_e_os_dois_caem() -> void:
	# (4) Empate ATK vs ATK: best-margin 0 ataca; o Battle real derruba os dois.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	_limpar_campo(st)
	(st.players[0] as Dictionary)["monster"][0] = _inst(1500)
	(st.players[1] as Dictionary)["monster"][0] = _inst(1500)
	var escolha: Array = mesa.call("_ia_escolher_ataque")
	assert_eq(escolha, [0, 0], "Empate 1500x1500: margem 0 ataca (slot 0 no 0).")
	# Ataque de verdade no BattleSystem (sem Fake): os dois caem, dano 0.
	st.set("turn_number", 2)
	st.set("current_player", 1)
	st.set("phase", "BATTLE")
	var lp0_antes: int = int((st.players[0] as Dictionary)["lp"])
	var lp1_antes: int = int((st.players[1] as Dictionary)["lp"])
	var r: Dictionary = BattleSystem.attack(st, 1, 0, 0, 0)
	assert_true(bool(r.get("ok", false)), "Ataque do empate resolve no motor real.")
	assert_true(bool(r.get("destruiu_atacante", false)), "Empate: atacante caiu.")
	assert_true(bool(r.get("destruiu_alvo", false)), "Empate: alvo caiu.")
	assert_eq(int(r.get("dano", -1)), 0, "Empate: dano 0.")
	assert_true((st.players[0] as Dictionary)["monster"][0] == null, "Alvo saiu do campo.")
	assert_true((st.players[1] as Dictionary)["monster"][0] == null, "Atacante saiu do campo.")
	assert_eq(int((st.players[0] as Dictionary)["lp"]), lp0_antes, "Seu LP não muda no empate.")
	assert_eq(int((st.players[1] as Dictionary)["lp"]), lp1_antes, "LP do rival não muda no empate.")


func test_ia_bonus_guardia_retorna_0() -> void:
	# (5) Guardiã adiada: o hook retorna 0 p/ qualquer par de estrelas.
	var mesa = await _mesa_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	for par in [["Sol", "Lua"], ["Lua", "Sol"], ["Sol", "Sol"], ["", ""], ["Marte", "Júpiter"]]:
		var b: int = int(mesa.call("_ia_bonus_guardia", str(par[0]), str(par[1])))
		assert_eq(b, 0, "Guardiã adiada: bônus %s x %s = 0." % [str(par[0]), str(par[1])])
