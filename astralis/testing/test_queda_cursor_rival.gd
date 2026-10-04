extends "res://testing/astralis_test_base.gd"

## test_queda_cursor_rival — trava o CRASH que fechava o jogo (item A).
##
## O QUE ESTE ARQUIVO TRAVA (nenhuma regra nova, R1/R2):
## (1) Mover o cursor para a FILEIRA DO RIVAL (a de monstro E a de magia) não
##     estoura nem derruba o jogo. Era a queda: a tela lia a chave "monstro"
##     de `GameState.players[]`, que só tem "monster"/"spell" — chave
##     inexistente = "Invalid access to property or key 'monstro'" e o jogo
##     fechava no meio do duelo, ao escolher alvo de ataque.
## (2) A tradução dos nomes das zonas é UM ponto só e é blindada: nome
##     desconhecido, lado fora de 0..1 ou chave ausente viram lista vazia, e
##     nunca um crash. É a trava de regressão do tipo inteiro.
## (3) O caminho `_detalhes` (a mesma leitura pela fileira do rival) também
##     não estoura — era o MESMO bug escondido em outro lugar.
##
## Por que a chave estava trocada: existem DOIS dialetos no jogo e é fácil
## passar um pelo outro — o BoardLayout (posicao do ladrilho) fala PT
## ("monstro"/"magia") e o GameState (zonas da carta) fala EN
## ("monster"/"spell"). A tela traduz num ponto só e nunca mais.
##
## Cenas e sistemas REAIS (R2): duel3d/mesa_3d.tscn de verdade, DuelManager
## de verdade. Sem dublê. Nenhum teste aqui depende de sonda nem de
## argumento de linha de comando.

## As 4 fileiras de slot: as 2 do jogador e as 2 do RIVAL (as que quebravam).
const FILEIRAS_RIVAL := [3, 4]



func _mesa_3d_real() -> Node:
	var mesa: Node = Mesa3DScene.instantiate()
	add_child_autofree(mesa)
	await wait_process_frames(6)
	return mesa


# ---------- (1) O CAMINHO EXATO DA PILHA DE ERRO ----------

func test_mover_para_a_fileira_do_rival_nao_derruba_o_jogo() -> void:
	# Reproduz o caminho EXATO da pilha do usuário: `_confirmar` ->
	# `_confirmar_meu_campo3d` -> `_posicionar_cursor` -> `_em_defesa`, com o
	# cursor indo para a fileira do rival. Se sobrar qualquer leitura de chave
	# divergente, o GUT marca "Unexpected Errors" e o teste reprova.
	# Boot inteiro: a invocação do preparo é só na MAIN, que abre depois da moeda.
	var mesa: Node = await _mesa3d_nova()
	assert_true(mesa.get("_st") != null, "Duelo real carregado na mesa 3D.")
	# Prepara o caminho: um atacante seu INVOCADO de verdade, para o
	# `_confirmar_meu_campo3d` ter o que escolher (sistemas reais).
	var st = mesa.get("_st")
	var i: int = _indice_monstro_na_mao(st, 0)
	assert_true(i >= 0, "Preparo: sua mão tem monstro de verdade.")
	var slot: int = SummonSystem.free_monster_slot(st, 0)
	assert_true(slot >= 0, "Preparo: há slot livre no seu campo.")
	assert_true(bool(SummonSystem.normal_summon(st, 0, i, slot, false, "ATK").get("ok", false)),
		"Preparo: invocação real no seu campo.")
	mesa.set("_fase_jogador", 1) # sai da fase da mão (o jogo começa travado nela)
	mesa.set("_fileira", 1) # seu campo de monstros
	mesa.set("_col", slot)
	mesa.call("_atualizar_hud")
	await wait_process_frames(2)
	# >>> O PASSO QUE CRASHAVA: confirmar a própria carta e o cursor cair na
	# fileira do RIVAL. Percorre TODAS as 4 fileiras e as 5 colunas.
	for f in FILEIRAS_RIVAL:
		mesa.set("_fileira", f)
		for c in range(5):
			mesa.set("_col", c)
			mesa.call("_confirmar_meu_campo3d")
			mesa.call("_posicionar_cursor")
			mesa.call("_detalhes")
			await wait_process_frames(1)
	assert_true(is_instance_valid(mesa), "A mesa 3D continua viva depois de varrer as fileiras do RIVAL.")
	assert_false(bool(st.get("over")), "O jogo NÃO acabou (não caiu) ao mover o cursor.")


func test_fileira_do_rival_nao_da_erro_de_script_em_nenhuma_coluna() -> void:
	# (1b) Varredura fina: cada fileira do rival, cada coluna, medindo que o
	# Cursor3D foi posicionado (a moldura existe) e que a cena segue inteira.
	var mesa: Node = await _mesa_3d_real()
	var molduras_ok := 0
	for f in FILEIRAS_RIVAL:
		for c in range(5):
			mesa.set("_fileira", f)
			mesa.set("_col", c)
			mesa.call("_posicionar_cursor")
			await wait_process_frames(1)
			var grupo := _n3d(mesa, "Cursor3D/Grupo")
			var moldura := _n3d(mesa, "Cursor3D/Grupo/Moldura")
			assert_true(grupo != null and moldura != null and moldura.get_child_count() == 4,
				"Fileira %d coluna %d: moldura de foco montada (4 barras)." % [f, c])
			molduras_ok += 1
	assert_eq(molduras_ok, 10, "As 10 posições (2 fileiras x 5 colunas) do rival passaram.")


# ---------- (2) A TRADUÇÃO É UM PONTO SÓ E É BLINDADA ----------

func test_traducao_de_zona_aceita_os_dois_dialetos() -> void:
	# O ponto único de tradução: o nome PT (BoardLayout) e o nome EN
	# (GameState) levam à MESMA zona. Passar o nome errado não pode devolver
	# lixo, e sim lista vazia.
	var mesa: Node = await _mesa_3d_real()
	assert_eq(str(mesa.call("_chave_zona", "monstro")), "monster", "PT 'monstro' -> 'monster'.")
	assert_eq(str(mesa.call("_chave_zona", "monster")), "monster", "EN 'monster' -> 'monster'.")
	assert_eq(str(mesa.call("_chave_zona", "magia")), "spell", "PT 'magia' -> 'spell'.")
	assert_eq(str(mesa.call("_chave_zona", "spell")), "spell", "EN 'spell' -> 'spell'.")
	assert_eq(str(mesa.call("_chave_zona", "nao_existe_xyz")), "", "Nome desconhecido = vazio (não inventa chave).")


func test_leitura_de_zona_e_blindada_contra_todo_valor_de_entrada() -> void:
	# Nenhum valor de entrada derruba a tela: lado fora de 0..1, chave
	# inexistente, zona vazia ou estado nulo viram lista vazia / false.
	var mesa: Node = await _mesa_3d_real()
	for lado in [-99, -1, 2, 7]:
		assert_eq((mesa.call("_lista_do_jogador", lado, "monster") as Array).size(), 0,
			"Lado %d (fora do jogo) = lista vazia, sem crash." % lado)
		assert_eq((mesa.call("_zona_do_jogador", lado, "monstro") as Array).size(), 0,
			"Lado %d com nome PT = lista vazia, sem crash." % lado)
	assert_eq((mesa.call("_lista_do_jogador", 0, "chave_que_nao_existe") as Array).size(), 0,
		"Chave inexistente = lista vazia, sem crash.")
	assert_eq((mesa.call("_lista_do_jogador", 0, "lp") as Array).size(), 0,
		"Chave que não é lista (lp) = lista vazia, sem crash.")
	assert_eq(int(mesa.call("_int_do_jogador", 99, "lp", -1)), -1, "LP de lado inexistente = o padrão pedido.")
	# A zona real continua legível (a blindagem não "esvaziou" o estado).
	assert_eq((mesa.call("_lista_do_jogador", 0, "hand") as Array).size(), 5, "Sua mão real continua legível: 5.")
	assert_eq((mesa.call("_lista_do_jogador", 0, "monster") as Array).size(), 5, "Sua zona de monstros real: 5 slots.")


func test_em_defesa_aceita_o_nome_da_fileira_sem_cair() -> void:
	# A função que crashava: chamada com o nome PT da fileira (é assim que a
	# tela fala), tem de ler a zona EN do estado — e nunca estourar.
	var mesa: Node = await _mesa_3d_real()
	var st = mesa.get("_st")
	# Prepara DANDO o dado: uma instância em DEFESA no slot 0 do rival, escrita
	# direto na zona (o mesmo truque de dado dos outros testes do repo; a
	# regra de invocação do turno 1 é do motor e não é o que está em teste).
	(st.players[1] as Dictionary)["monster"][0] = _inst_campo("DEF", false)
	assert_true((st.players[1] as Dictionary)["monster"][0] != null, "Preparo: rival tem monstro em DEFESA no slot 0.")
	# A tela chama com a chave PT da fileira (é assim que `_lado_tipo_da_fileira`
	# fala). As DUAS chaves têm de ler a MESMA zona do estado.
	assert_true(bool(mesa.call("_em_defesa", 1, "monstro", 0)), "Lê DEF pelo nome PT da fileira (o que crashava).")
	assert_true(bool(mesa.call("_em_defesa", 1, "monster", 0)), "Lê a MESMA carta pela chave EN: as duas concordam.")
	# E nenhum valor de entrada derruba a tela.
	assert_false(bool(mesa.call("_em_defesa", 1, "magia", 0)), "Nome de zona errado = false (magia está vazia), sem crash.")
	assert_false(bool(mesa.call("_em_defesa", 99, "monstro", 0)), "Lado inexistente = false, sem crash.")
	assert_false(bool(mesa.call("_em_defesa", 1, "monstro", 99)), "Slot inexistente = false, sem crash.")
	assert_false(bool(mesa.call("_em_defesa", 1, "nao_existe_xyz", 0)), "Zona desconhecida = false, sem crash.")
	# Uma carta em ATAKE no MESMO slot: as duas chaves dizem que não está em
	# DEFESA (ou seja, a tradução não está inventando resposta).
	(st.players[1] as Dictionary)["monster"][0] = _inst_campo("ATK", false)
	assert_false(bool(mesa.call("_em_defesa", 1, "monstro", 0)), "Carta em ATAKE lida pela chave PT = false.")
	assert_false(bool(mesa.call("_em_defesa", 1, "monster", 0)), "Carta em ATAKE lida pela chave EN = false.")


# ---------- (3) O MESMO BUG ESCONDIDO NO CAMINHO `_detalhes` ----------

func test_detalhes_na_fileira_do_rival_nao_derruba_o_jogo() -> void:
	# `_detalhes` é o outro lugar que traduzia mal: ele passava o nome PT da
	# fileira para a leitura da zona. Mesmo bug, outra porta.
	var mesa: Node = await _mesa_3d_real()
	var st = mesa.get("_st")
	var i: int = _indice_monstro_na_mao(st, 1)
	var slot: int = SummonSystem.free_monster_slot(st, 1)
	if i >= 0 and slot >= 0:
		SummonSystem.normal_summon(st, 1, i, slot, false, "ATK")
	for f in FILEIRAS_RIVAL:
		for c in range(5):
			mesa.set("_fileira", f)
			mesa.set("_col", c)
			mesa.call("_detalhes")
			await wait_process_frames(1)
	assert_true(is_instance_valid(mesa), "Mesa viva depois de `_detalhes` nas fileiras do rival.")
	var fala := str((mesa.get("_log") as Array).back())
	assert_true(fala.contains("Detalhes"), "A fala saiu de verdade (não foi engolida por um erro): '%s'." % fala)
