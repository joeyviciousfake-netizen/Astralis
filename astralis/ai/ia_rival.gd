extends RefCounted

## ia_rival — AS DECISÕES DO RIVAL. Um assunto só: qual carta ele joga.
##
## A IA **não conduz o turno**. Ela escolhe e devolve a escolha; quem executa é
## a mesa (`_rival_auto`), pelo MESMO caminho que executa as jogadas do
## jogador. Por isso este arquivo não sabe nada de tela, de animação, de fase
## nem de tempo — e a mesa não sabe nada de estratégia.
##
## REGRA ZERO (R1): esta função não decide regra nenhuma. Onde a carta vai
## (`SummonSystem.free_monster_slot`), se o ataque é legal
## (`BattleSystem.attack`) e quem ganhou (`DamageSystem`) é o MOTOR. A IA só
## diz QUAL carta e QUAL alvo; o motor diz se pode.
##
## ## D55 (TRAVADA): a IA do rival é TEMPORÁRIA e a escolha fina não foi
## portada — ela morava no 2D, que saiu no D54/D58. O que está aqui é a
## escolha de hoje, sem firmware: o primeiro monstro da mão e o primeiro
## monstro em campo. **Isto é organização, não ganho de inteligência**: quando
## a D55 for destravada, é este arquivo que ganha a escolha de verdade, e a
## mesa não muda.

## O que a IA quer fazer na invocação. É a ESCOLHA, não a jogada: o índice da
## carta na mão e nada mais (o slot é do `SummonSystem`, é regra).
## Vazio = não tem o que invocar. `motivo` diz o porquê, e é só para a tela
## falar o que aconteceu (nada de regra).
func escolher_invocacao(state, lado: int) -> Dictionary:
	var p: Dictionary = state.players[lado] as Dictionary
	var mao: Array = p["hand"] as Array
	if mao.is_empty():
		return {"ok": false, "idx": -1, "motivo": "mao_vazia"}
	for i in range(mao.size()):
		if str((mao[i] as Dictionary).get("card_type", "")) == "monster":
			return {"ok": true, "idx": i, "motivo": ""}
	return {"ok": false, "idx": -1, "motivo": "sem_monstro"}


## O que a IA quer atacar com o monstro que está em `slot_atacante`. É a
## ESCOLHA, não a jogada: o índice do alvo, e nada mais (se o ataque é legal é
## `BattleSystem.attack` que diz).
##
## ## `-1` É UMA ESCOLHA, NÃO "NADA": no motor, alvo menor que zero é o ATAQUE
## DIRETO no jogador, e ele só é legal com o campo do outro lado vazio. É o
## que a IA escolhe quando não há monstro para atacar. Tratar o -1 como
## "sem alvo" (e pular o ataque) foi um bug meu que o
## `test_mesa_6bugs.gd` pegou: o rival deixava de dar dano direto.
##
## `ok: false` aqui é SÓ para "este slot não pode atacar" (vazio ou fora da
## zona). Nunca para "não achei alvo".
func escolher_ataque(state, lado_atacante: int, slot_atacante: int, lado_defensor: int) -> Dictionary:
	var zona: Array = (state.players[lado_atacante] as Dictionary)["monster"] as Array
	if slot_atacante < 0 or slot_atacante >= zona.size():
		return {"ok": false, "slot_atacante": slot_atacante, "alvo": -1}
	if zona[slot_atacante] == null:
		return {"ok": false, "slot_atacante": slot_atacante, "alvo": -1}
	var adv: Array = (state.players[lado_defensor] as Dictionary)["monster"] as Array
	# Sem monstro em campo do outro lado: o alvo é o DIRETO (-1 no motor).
	var alvo := -1
	for i in range(adv.size()):
		if adv[i] != null:
			alvo = i
			break
	return {"ok": true, "slot_atacante": slot_atacante, "alvo": alvo, "direto": alvo < 0}
