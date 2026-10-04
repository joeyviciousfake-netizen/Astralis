extends "res://testing/astralis_test_base.gd"

## test_mesa_6bugs - GUT permanente dos 6 bugs da mesa (so controle/desenho,
## sem regra nova). Roda na mesa 3D REAL, a oficial (D40).
## (2) popup da estrela ACIMA da carta central (menu por cima, carta visivel);
## (3) navegacao alcanca as 4 fileiras do campo (20 slots, magia inclusa);
## (5) cima no topo e baixo na base nao saem dos slots (nunca na mao);
## (6) rival vazio -> menu oferece o LP (dano ATK cheio via Battle real) e o
##     rival automATico ataca direto quando seu campo esta vazio.
## (1) "face p/ baixo desce escondida" e (4) "no rival, direita aumenta o X de
## tela" saíram daqui: a REGRA de descer virada esta em test_fluxo_fiel (face
## baixo) e o VERSO de uma carta no campo e test_verso_marrom_com_espiral
## (arquivo 3D); a ordem visivel das colunas de cada lado esta em
## test_volta_mesa/test_cada_jogador_ve_a_propria_fileira_na_ordem_normal.
## Sem Fake (R2). Sem gamepad fisico: Input.action_press so simula o botao;
## quem anda e o metodo real da mesa. Seed fixa 42.

const BattleSystem := preload("res://duel/battle_system.gd")
## FILEIRA_*/FASE_*/SUB_* da mesa 3D (mesmos valores do legado).
const FASE_MAO := 0
const FASE_CAMPO := 1
const SUB_FACE := 1
const SUB_SLOT := 2
const SUB_ESTRELA := 3
const FILEIRA_MAO := 0
const FILEIRA_MEU_M := 1
const FILEIRA_MEU_S := 2
const FILEIRA_RIVAL_M := 3
const FILEIRA_RIVAL_S := 4
## A ordem visual de cima para baixo do campo na mesa 3D (magia rival ->
## monstro rival -> meu monstro -> minha magia), na constante do runtime.
const ORDEM_CAMPO := [4, 3, 1, 2]


func test_bug2_popup_estrela_acima_da_carta_central() -> void:
	# (2) Menu da estrela sempre POR CIMA da carta segurada no centro-alto. O
	# menu é 2D (MenuLayer) e a carta é 3D, então a ordem é das camadas: o menu
	# fica por cima e a carta aparece inteira embaixo dele.
	var mesa = await _mesa3d_nova()
	assert_true(is_instance_valid(mesa), "Mesa real instanciada.")
	var st = mesa.get("_st")
	mesa.set("_fileira", FILEIRA_MAO)
	mesa.set("_col", _indice_monstro_na_mao(st, 0))
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), SUB_FACE, "Preparo: carta no centro.")
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), SUB_SLOT, "Preparo: escolhe o slot.")
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	mesa.set("_col", slot)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sub_mao")), SUB_ESTRELA, "Preparo: menu da estrela aberto.")
	var popup: Control = _menus(mesa).get("_popup") as Control
	var segurada: Node3D = mesa.get("_segurada") as Node3D
	assert_true(popup.visible, "Menu da estrela visivel.")
	assert_true(segurada != null and is_instance_valid(segurada) and segurada.visible, "Carta segurada existe no centro-alto.")
	assert_true(_menus(mesa).layer > -1, "Menu (camada %d) desenha por cima do 3D." % _menus(mesa).layer)
	assert_eq(int(mesa.get("_segurada_giros")) % 2, 1 if bool(mesa.get("_face_baixo")) else 0, "Giro conta a face que vale.")
	# O menu sobrevive a navegar dentro dele (nao some nem volta atras).
	Input.action_press("mover_baixo")
	mesa.call("_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_true(popup.visible, "Menu segue visivel apos navegar.")
	assert_true(is_instance_valid(segurada), "Segurada segue no centro apos navegar.")


func test_bug3_navegacao_alcanca_4_fileiras_20_slots() -> void:
	# (3) Fase de campo anda SO nos 20 slots: 2 de monstro + 2 de magia
	# (proprias + rival), na ordem VISUAL de cima para baixo.
	var mesa = await _mesa3d_nova()
	var fim: Dictionary = _fluxo3d_ate_campo(mesa, false, 0)
	assert_eq(int(mesa.get("_fase_jogador")), FASE_CAMPO, "Preparo: fase de campo.")
	assert_eq(ORDEM_CAMPO.size(), 4, "Campo tem 4 fileiras.")
	assert_eq(ORDEM_CAMPO, [4, 3, 1, 2], "Ordem visual: magia rival -> monstro rival -> meu monstro -> minha magia.")
	var total := 0
	for f in ORDEM_CAMPO:
		var larg: int = int(mesa.call("_larg_fileira", int(f)))
		assert_eq(larg, 5, "Fileira %d tem 5 slots." % int(f))
		total += larg
		var lt: Array = mesa.call("_lado_tipo_da_fileira", int(f))
		assert_eq(lt.size(), 2, "Fileira %d tem lado+tipo." % int(f))
	assert_eq(total, 20, "4 fileiras x 5 = 20 slots (magia inclusa).")
	assert_eq((mesa.call("_lado_tipo_da_fileira", 4) as Array), [1, "magia"], "Fileira 4: magia rival.")
	assert_eq((mesa.call("_lado_tipo_da_fileira", 3) as Array), [1, "monstro"], "Fileira 3: monstro rival.")
	assert_eq((mesa.call("_lado_tipo_da_fileira", 1) as Array), [0, "monstro"], "Fileira 1: meu monstro.")
	assert_eq((mesa.call("_lado_tipo_da_fileira", 2) as Array), [0, "magia"], "Fileira 2: minha magia.")
	assert_true(int(mesa.call("_larg_fileira", FILEIRA_MAO)) > 0, "A mao e uma fileira de verdade (0).")
	# A mao NAO e fileira de campo: e o que a fase de campo usa para nao sair
	# dela ao andar (o `_mover` volta pra FILEIRA_MEU_M se a fileira nao e do campo).
	assert_true((mesa.call("_lado_tipo_da_fileira", FILEIRA_MAO) as Array).is_empty(),
		"Fileira 0 (a mao) nao e de campo.")
	# Anda de cima a baixo e visita as 4 (botao so simulado, passo real).
	mesa.set("_fileira", int(ORDEM_CAMPO[0]))
	mesa.set("_col", 2)
	var visitadas: Array = [int(mesa.get("_fileira"))]
	for k in range(3):
		Input.action_press("mover_baixo")
		mesa.call("_mover", 0, 1)
		Input.action_release("mover_baixo")
		visitadas.append(int(mesa.get("_fileira")))
	assert_eq(visitadas, ORDEM_CAMPO, "Baixo visita as 4 fileiras em ordem.")
	for k in range(3):
		Input.action_press("mover_cima")
		mesa.call("_mover", 0, -1)
		Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_fileira")), int(ORDEM_CAMPO[0]), "Cima 3x volta ao topo (magia rival).")


func test_bug5_cima_no_topo_e_baixo_na_base_nao_saem_dos_slots() -> void:
	# (5) Na fase de campo, cima no topo e baixo na base nao saem do campo:
	# nunca fogem pra mao (0), que e a unica fileira de fora.
	var mesa = await _mesa3d_nova()
	_fluxo3d_ate_campo(mesa, false, 0)
	assert_eq(int(mesa.get("_fase_jogador")), FASE_CAMPO, "Preparo: fase de campo.")
	var topo: int = int(ORDEM_CAMPO[0])
	var base: int = int(ORDEM_CAMPO[ORDEM_CAMPO.size() - 1])
	# Cima no topo: nao sai do lugar.
	mesa.set("_fileira", topo)
	mesa.set("_col", 2)
	Input.action_press("mover_cima")
	mesa.call("_mover", 0, -1)
	Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_fileira")), topo, "Cima no topo nao sai do lugar.")
	assert_eq(int(mesa.get("_col")), 2, "Cima no topo nao muda a coluna.")
	for k in range(5):
		Input.action_press("mover_cima")
		mesa.call("_mover", 0, -1)
		Input.action_release("mover_cima")
	assert_eq(int(mesa.get("_fileira")), topo, "5x cima no topo: segue no topo.")
	# Baixo na base: nao sai do lugar.
	mesa.set("_fileira", base)
	mesa.set("_col", 2)
	Input.action_press("mover_baixo")
	mesa.call("_mover", 0, 1)
	Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_fileira")), base, "Baixo na base nao sai do lugar.")
	assert_eq(int(mesa.get("_col")), 2, "Baixo na base nao muda a coluna.")
	for k in range(5):
		Input.action_press("mover_baixo")
		mesa.call("_mover", 0, 1)
		Input.action_release("mover_baixo")
	assert_eq(int(mesa.get("_fileira")), base, "5x baixo na base: segue na base.")
	# Passeio completo nunca encosta na mao.
	for _k in range(6):
		Input.action_press("mover_cima")
		mesa.call("_mover", 0, -1)
		Input.action_release("mover_cima")
		assert_true((ORDEM_CAMPO as Array).has(int(mesa.get("_fileira"))), "Cima: segue num slot do campo.")
		assert_ne(int(mesa.get("_fileira")), FILEIRA_MAO, "Cima: nunca vai pra mao.")
	for _k2 in range(6):
		Input.action_press("mover_baixo")
		mesa.call("_mover", 0, 1)
		Input.action_release("mover_baixo")
		assert_true((ORDEM_CAMPO as Array).has(int(mesa.get("_fileira"))), "Baixo: segue num slot do campo.")
		assert_ne(int(mesa.get("_fileira")), FILEIRA_MAO, "Baixo: nunca vai pra mao.")


func test_bug6_rival_vazio_menu_LP_dano_ATK_cheio_e_IA_direta() -> void:
	# (6) Rival vazio: o menu oferece o LP (direto com o ATK cheio, pelo Battle
	# real) e o rival automatico ataca direto quando o seu campo esta vazio.
	# Parte A: menu na mesa real. Parte B: o rival joga o turno dele de verdade.
	var mesa = await _mesa3d_nova()
	var fim: Dictionary = _fluxo3d_ate_campo(mesa, false, 0)
	var st = mesa.get("_st")
	var slot_atk: int = int(fim["slot"])
	assert_eq(int(mesa.get("_fase_jogador")), FASE_CAMPO, "Preparo: fase de campo.")
	assert_eq(String(st.phase), "BATTLE", "Preparo: BATTLE da mesa.")
	# So organiza dado ANTES de escolher: rival sem monstros + turno liberado
	# p/ p0 atacar (turno 1 bloqueia, D43).
	for i in range(5):
		(st.players[1] as Dictionary)["monster"][i] = null
	assert_false(BattleSystem.has_monsters(st, 1), "Preparo: rival sem monstros.")
	st.set("turn_number", 3)
	# Escolhe o atacante (cursor real no proprio campo).
	mesa.set("_fileira", FILEIRA_MEU_M)
	mesa.set("_col", slot_atk)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_eq(int(mesa.get("_sel_atk")), slot_atk, "Atacante escolhido no proprio campo.")
	# Mira no campo rival vazio: abre o menu de alvo com o LP.
	mesa.set("_fileira", FILEIRA_RIVAL_M)
	mesa.set("_col", 0)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	var popup: Control = _menus(mesa).get("_popup") as Control
	assert_true(popup.visible, "Rival vazio: menu de alvo abriu.")
	assert_eq(str(mesa.call("_popup_modo")), "alvo", "Menu esta no modo alvo (LP).")
	var ops: Array = _menus(mesa).get("_popup_ops") as Array
	assert_true(ops.size() > 0, "O menu de alvo tem opcoes.")
	assert_true((_menus(mesa).get("_popup") as Control).get_child_count() > 0, "O menu de alvo desenha as opcoes.")
	# Cancelar fecha o menu de alvo.
	mesa.call("_set_pad_popup_idx", 1)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_false(popup.visible, "Cancelar fecha o menu de alvo.")
	# Magia rival vazia tambem oferece o direto (mesma regra, sem alvo em magia).
	mesa.set("_fileira", FILEIRA_RIVAL_S)
	mesa.set("_col", 0)
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_true(popup.visible, "Magia rival vazia tambem oferece o direto.")
	assert_eq(str(mesa.call("_popup_modo")), "alvo", "Magia: menu tambem e de alvo (LP).")
	mesa.call("_set_pad_popup_idx", 0)
	var inst_atk: Dictionary = (st.players[0] as Dictionary)["monster"][slot_atk] as Dictionary
	var atk_esperado: int = int(inst_atk.get("atk", 0))
	assert_true(atk_esperado > 0, "Preparo: atacante tem ATK %d." % atk_esperado)
	var lp_antes: int = int((st.players[1] as Dictionary)["lp"])
	Input.action_press("confirmar")
	mesa.call("_confirmar")
	Input.action_release("confirmar")
	assert_false(popup.visible, "Confirmar o LP fecha o menu.")
	var lp_depois: int = int((st.players[1] as Dictionary)["lp"])
	assert_eq(lp_antes - lp_depois, atk_esperado, "Direto via menu: dano ATK cheio (%d) no Battle real." % atk_esperado)
	# Parte B: o rival joga o turno dele de verdade e ataca direto no vazio.
	var mesa2 = await _mesa3d_nova()
	_fluxo3d_ate_campo(mesa2, false, 0)
	var st2 = mesa2.get("_st")
	_garantir_monstros_na_mao(st2, 1, 1)
	for i in range(5):
		(st2.players[0] as Dictionary)["monster"][i] = null
		(st2.players[1] as Dictionary)["monster"][i] = null
	assert_false(BattleSystem.has_monsters(st2, 0), "Preparo: seu campo vazio p/ o direto.")
	var lp_voce_antes: int = int((st2.players[0] as Dictionary)["lp"])
	Input.action_press("pausar")
	mesa2.call("_passar_turno")
	Input.action_release("pausar")
	assert_eq(int(st2.current_player), 1, "START passou o turno ao rival (ele joga).")
	await wait_seconds(5.0)
	assert_true(is_instance_valid(mesa2), "Mesa segue valida apos o turno do rival.")
	var lp_voce_depois: int = int((st2.players[0] as Dictionary)["lp"])
	assert_true(lp_voce_depois < lp_voce_antes, "Rival atacou direto: seu LP caiu (%d -> %d)." % [lp_voce_antes, lp_voce_depois])
	var atk_ia := 0
	for m in ((st2.players[1] as Dictionary)["monster"] as Array):
		if m is Dictionary and not (m as Dictionary).is_empty():
			atk_ia = maxi(atk_ia, int((m as Dictionary).get("atk", 0)))
	assert_true(atk_ia > 0, "Preparo: o rival tem atacante (ATK %d)." % atk_ia)
	assert_true(lp_voce_antes - lp_voce_depois >= atk_ia, "Direto: dano >= ATK cheio do rival (%d)." % atk_ia)
	assert_eq(int(st2.current_player), 0, "O rival devolveu sua vez.")