extends "res://testing/astralis_test_base.gd"

## A IA do rival é o arquivo real `ai/ia_rival.gd` — sem dublê, sem mock.
## Este teste pega a IA de verdade, dá um estado de duelo de verdade e prova
## que a ESCOLHA é dela. A mesa continua sendo quem EXECUTA (R1): a IA devolve
## o índice da carta, e quem diz onde ela entra é o `SummonSystem`.
##
## ## D55 (TRAVADA): a escolha fina NÃO existe — ela morava no 2D, que saiu no
## D54/D58. Estes testes cravam o comportamento de HOJE (primeiro monstro da
## mão, primeiro monstro em campo), não o de um dia. Quando a D55 for destravada,
## é aqui que o esperado muda, e a mesa não muda junto.

var IaRival := preload("res://ai/ia_rival.gd")

var _ia: RefCounted = null
var _st = null


func before_each() -> void:
	_ia = IaRival.new()
	_st = (_novo_duelo() as RefCounted).get_state()


## ---------- a IA e o arquivo real, e ela NÃO executa ----------

func test_a_ia_e_o_arquivo_real_e_nao_um_duble() -> void:
	assert_true(_ia != null, "A IA do rival instanciou do arquivo real.")
	assert_true(_ia.has_method("escolher_invocacao"),
		"A IA decide a invocação (a mesa só executa).")
	assert_true(_ia.has_method("escolher_ataque"), "A IA decide o alvo do ataque.")
	# Se a IA tivesse metodo de execucao, a regra estaria morando nela e a R1
	# estaria quebrada: onde a carta entra e se o ataque vale é do MOTOR.
	for proibido in ["invocar", "atacar", "advance_phase", "normal_summon", "attack",
			"free_monster_slot", "check_defeat"]:
		assert_false(_ia.has_method(proibido),
			"A IA NÃO executa: '%s' é do motor/da mesa, não dela." % proibido)


## ---------- a escolha da invocação ----------

func test_a_ia_escolhe_o_primeiro_monstro_da_mao() -> void:
	_garantir_monstros_na_mao(_st, 1, 1)
	var esperado := _indice_monstro_na_mao(_st, 1)
	var r: Dictionary = _ia.escolher_invocacao(_st, 1)
	assert_true(esperado >= 0, "O teste precisa de um monstro na mão do rival para haver escolha.")
	assert_true(bool(r.get("ok", false)), "Com monstro na mão, a IA tem o que invocar.")
	assert_eq(int(r.get("idx", -1)), esperado,
		"A IA escolhe o PRIMEIRO monstro da mão (D55: escolha fina não existe).")
	assert_eq(str(r.get("motivo", "x")), "",
		"Com escolha, o motivo é vazio (o motivo é só o que a tela fala).")


func test_a_ia_diz_mao_vazia_quando_nao_tem_nada() -> void:
	var mao: Array = (_st.players[1] as Dictionary)["hand"] as Array
	while mao.size() > 0:
		mao.pop_back()
	var r: Dictionary = _ia.escolher_invocacao(_st, 1)
	assert_false(bool(r.get("ok", false)), "Mão vazia: a IA não tem o que invocar.")
	assert_eq(str(r.get("motivo", "")), "mao_vazia",
		"O motivo é 'mao_vazia' — é o que a tela fala, não é regra.")
	assert_eq(int(r.get("idx", -1)), -1, "Sem carta, o índice sai -1 (nada é inventado).")


func test_a_ia_diz_sem_monstro_quando_a_mao_so_tem_magia() -> void:
	var mao: Array = (_st.players[1] as Dictionary)["hand"] as Array
	while mao.size() > 0:
		mao.pop_back()
	mao.append({"card_id": "spell_teste", "card_type": "spell", "name": "Magia"})
	var r: Dictionary = _ia.escolher_invocacao(_st, 1)
	assert_false(bool(r.get("ok", false)),
		"Só magia na mão: a IA não tem monstro para escolher.")
	assert_eq(str(r.get("motivo", "")), "sem_monstro",
		"O motivo é 'sem_monstro' — distinto de 'mao_vazia'.")


## ---------- a escolha do alvo ----------

func test_a_ia_mira_o_primeiro_monstro_em_campo_e_nao_o_mais_forte() -> void:
	_limpar_campo(_st)
	var seu: Array = (_st.players[0] as Dictionary)["monster"] as Array
	seu[0] = _inst(100, "ATK", false, 100)
	seu[2] = _inst(9000, "ATK", false, 9000)
	var rival: Array = (_st.players[1] as Dictionary)["monster"] as Array
	rival[1] = _inst(10, "ATK", false, 10)
	var r: Dictionary = _ia.escolher_ataque(_st, 1, 1, 0)
	assert_true(bool(r.get("ok", false)), "Com monstro dos dois lados, a IA tem alvo.")
	assert_eq(int(r.get("alvo", -1)), 0,
		"A IA mira o PRIMEIRO monstro em campo — o de 100 ATK, não o de 9000 (D55).")
	assert_eq(int(r.get("slot_atacante", -1)), 1, "A IA devolve o slot que atacou.")


func test_a_ia_escolhe_o_ataque_direto_quando_o_campo_do_outro_esta_vazio() -> void:
	# `-1` NO MOTOR É ATAQUE DIRETO, e a IA escolhe ele. Isto não é detalhe: foi
	# um bug meu tratar -1 como "sem alvo" e pular o ataque, e o
	# `test_mesa_6bugs.gd` pegou (o rival parou de dar dano direto).
	_limpar_campo(_st)
	var rival: Array = (_st.players[1] as Dictionary)["monster"] as Array
	var seu: Array = (_st.players[0] as Dictionary)["monster"] as Array
	rival[0] = _inst(700, "ATK", false, 100)
	# Seu campo VAZIO de propósito: é o que torna o direto legal.
	for i in range(seu.size()):
		seu[i] = null
	var r: Dictionary = _ia.escolher_ataque(_st, 1, 0, 0)
	assert_true(bool(r.get("ok", false)), "Campo vazio NÃO é 'sem alvo': o direto é escolha válida.")
	assert_eq(int(r.get("alvo", 0)), -1, "A IA escolhe o direto: alvo -1 (a convenção do motor).")
	assert_true(bool(r.get("direto", false)), "A IA marca que é direto, para a tela poder falar.")


func test_a_ia_nao_ataca_slot_vazio() -> void:
	_limpar_campo(_st)
	var rival: Array = (_st.players[1] as Dictionary)["monster"] as Array
	var seu: Array = (_st.players[0] as Dictionary)["monster"] as Array
	seu[0] = _inst(100, "ATK", false, 100)
	# Slot 0 do rival está vazio: não há o que atacar com.
	var r: Dictionary = _ia.escolher_ataque(_st, 1, 0, 0)
	assert_false(bool(r.get("ok", false)), "Slot do atacante vazio: a IA não escolhe ataque.")
	# Slot fora da zona também não é alvo de ninguém (a IA não inventa índice).
	var fora: Dictionary = _ia.escolher_ataque(_st, 1, 99, 0)
	assert_false(bool(fora.get("ok", false)), "Slot fora da zona: a IA não escolhe ataque.")


func test_a_ia_sabe_o_motivo_cada_escolha() -> void:
	# O `motivo` é o que a TELA fala, e nada mais: a IA não tem regra, só
	# escolhe e diz por quê escolheu (ou por que não há o que escolher).
	_limpar_campo(_st)
	var rival: Array = (_st.players[1] as Dictionary)["monster"] as Array
	var seu: Array = (_st.players[0] as Dictionary)["monster"] as Array
	rival[0] = _inst(700, "ATK", false, 100)
	for i in range(seu.size()):
		seu[i] = null
	var direto: Dictionary = _ia.escolher_ataque(_st, 1, 0, 0)
	assert_true(bool(direto.get("ok", false)) and int(direto.get("alvo", 0)) == -1,
		"Campo de defesa vazio: a IA escolhe o ataque direto (não 'sem alvo').")
	seu[0] = _inst(10, "DEF", false, 999)
	var em_campo: Dictionary = _ia.escolher_ataque(_st, 1, 0, 0)
	assert_eq(int(em_campo.get("alvo", -1)), 0,
		"Com monstro em campo, a IA mira ele — e o direto vira ilegal sozinho (o motor barra).")
	# Slot do atacante vazio: aqui sim é 'não pode atacar'.
	var sem_atacante: Dictionary = _ia.escolher_ataque(_st, 1, 3, 0)
	assert_false(bool(sem_atacante.get("ok", false)),
		"Slot do atacante vazio: a IA não escolhe ataque (não tem o que ataca com).")


## ---------- a separação R1: a IA decide, a mesa executa ----------

func test_a_mesa_e_quem_executa_a_escolha_da_ia() -> void:
	# A prova da ponte R1: a IA devolve um índice, o motor decide se a jogada
	# vale. E o motor é quem recusa — com o duelo em DRAW a invocação é
	# ILEGAL, e quem barra é ele, não a IA (que nem sabe o que fase é).
	var duelo = _novo_duelo()
	var st = duelo.get_state()
	_limpar_campo(st)
	_garantir_monstros_na_mao(st, 1, 1)
	var r: Dictionary = _ia.escolher_invocacao(st, 1)
	var idx := int(r.get("idx", -1))
	var slot := SummonSystem.free_monster_slot(st, 1)
	assert_true(idx >= 0, "A IA escolheu uma carta (ela não olha fase: escolher não é jogar).")
	assert_true(slot >= 0, "O SummonSystem (e não a IA) diz onde a carta entra.")

	# Em DRAW o motor recusa: a REGRA é dele, e a IA não tem nada a ver nisso.
	var cedo: Dictionary = SummonSystem.normal_summon(st, 1, idx, slot, false, "ATK")
	assert_false(bool(cedo.get("ok", false)),
		"Em DRAW o motor recusa a invocação: a fase é regra do motor (R1), e a IA não decide fase.")

	# Na MAIN, pelo MESMO caminho, a carta que a IA escolheu entra no slot que
	# o motor deu. Nada aqui é dublê: é o SummonSystem real. E o duelo precisa
	# estar COM a vez do rival, porque "só o jogador da vez pode invocar" é
	# REGRA do motor — e é o motor que recusa, nunca a IA.
	st.current_player = 1
	duelo.advance_phase() # DRAW -> MAIN do rival
	assert_eq(int(st.current_player), 1, "A vez é do rival (quem vai invocar).")
	assert_eq(String(st.phase), "MAIN", "O duelo está na MAIN (fase real do motor).")
	var res: Dictionary = SummonSystem.normal_summon(st, 1, idx, slot, false, "ATK")
	assert_true(bool(res.get("ok", false)),
		"Na MAIN o motor aceitou a escolha da IA (ok=%s, erro=%s)." % [
			str(res.get("ok", false)), str(res.get("erro", ""))])
	assert_true((st.players[1] as Dictionary)["monster"][slot] != null,
		"A carta que a IA escolheu entrou no campo, no slot que o motor deu.")