extends Node3D

## campo_3d — O CAMPO DE VIDRO: os 24 painéis flutuantes que recebem as
## cartas (20 slots + 4 pilhas de baralho/cemitério), mais o guarda-chuva das
## laterais. Um assunto so: onde o vidro fica.
##
## O vidro é a peça ESCURA e translúcida (dá pra ver o fundo por baixo, como na
## ref) com um aro fininho de luz (na ref é um fio, não um wireframe). Na
## perspectiva da câmera fixa os 20 viram os trapezoides da ref.
##
## O painel sabe o TAMANHO do vidro (a medida `peca_prof_cartas` vem pronta, e
## ela é a MESMA que a mão e o cursor usam — número com um dono só) mas não
## sabe a POSIÇÃO: quem traduz o slot do DADO em XZ de mundo é a mesa
## (`pos_slot`), porque essa tradução é do DADO, não do vidro.
##
## Zero regra (R1): isto é desenho puro.

## Onde o painel vai, em XZ de mundo (a medida é da mesa, não daqui).
var pos_slot: Callable
## Fábrica de caixa e de vidro da mesa (as mesmas que montam o corpo das cartas).
var caixa: Callable
var vidro: Callable
## Medidas que a mesa passa: altura do chão, escala do campo, o lado do vidro
## e a largura/altura da carta (dono: a mesa, as mesmas da fábrica).
var topo := 0.0
var escala_campo := 1.0
var peca_prof_cartas := 1.58
var larg_carta := 1.0
var alt_carta := 1.0

var no_slots: Node3D = null
var no_laterais: Node3D = null


func _ready() -> void:
	name = "Campo"
	no_slots = Node3D.new()
	no_slots.name = "Slots"
	add_child(no_slots)
	# 24 painéis de vidro escuros flutuantes (5+5 por lado + 2 pilhas por lado,
	# espelho do 2D via BoardLayout real). Vazio = painel escuro com brilho
	# sutil na borda.
	for lado in [0, 1]:
		for i in range(5):
			no_slots.add_child(_painel_slot(lado, "monstro", i))
			no_slots.add_child(_painel_slot(lado, "magia", i))
		# As 2 PILHAS de cada lado (baralho a direita, cemiterio a esquerda):
		# o vidro tem o tamanho da carta EM ATAQUE (largura x altura, nunca
		# quadrado), porque carta de pilha nunca fica em defesa.
		no_slots.add_child(_painel_pilha(lado, "deck"))
		no_slots.add_child(_painel_pilha(lado, "cemiterio"))
	no_laterais = Node3D.new()
	no_laterais.name = "Laterais"
	add_child(no_laterais)
	# `Laterais` fica VAZIO de propósito (D44/D45): nada de desenho solto no
	# canto. É o guarda-chuva que o resto da cena já usava.


## Um painel de vidro = a PEÇA DE VIDRO da ref (doc 15 §15.3): vidro azul
## ESCURO translúcido (dá pra ver o fundo através), com aro fino mais
## claro em volta e ESPAÇO entre as peças (na ref são ladrilhos soltos, não
## um wireframe colado). O lado acompanha o campo, então a fresta entre as
## peças continua a mesma em qualquer escala.
##
## O vidro precisa ser maior que o lado LONGO da carta em DEFESA (a mesma
## carta girada um quarto de volta): 1,58 deixa ~0,12 de carta de folga dos
## dois lados. Abaixo disso a carta de DEF invade o vizinho. Só apresentação;
## a composição do dado não muda.
##
## NÃO passa pela perspectiva (doc 16) de propósito: as 24 peças são
## construídas UMA vez, com as DUAS fileiras e as pilhas, e a perspectiva só troca os
## lugares entre elas (lado 0 <-> lado 1). O conjunto de 24 peças é o
## mesmo antes e depois, então aqui não há nada a trocar. A CARTA dentro do
## ladrilho é que se move — e ela passa por `_vis` no `_redesenhar`.
func _painel_slot(lado: int, tipo: String, indice: int) -> Node3D:
	var p: Vector3 = pos_slot.call(lado, tipo, indice)
	var no := Node3D.new()
	no.name = "Painel_p%d_%s%d" % [lado, ("m" if tipo == "monstro" else "s"), indice]
	no.position = Vector3(p.x, 0.0, p.z)
	var mat_borda: Material = vidro.call(Color(0.40, 0.58, 0.88), 0.42, 0.05)
	var mat_base: Material = vidro.call(Color(0.035, 0.08, 0.20), 0.72, 0.05)
	var lado_pec: float = peca_prof_cartas * escala_campo
	no.add_child(caixa.call("Base", Vector3(lado_pec, 0.05, lado_pec), Vector3(0, topo - 0.03, 0), mat_base) as Node)
	# aro: um fio de luz nas 4 pontas, não um wireframe
	var t := 0.05 * escala_campo
	var meio := lado_pec / 2.0
	var y := topo + 0.005
	var fora := meio + t / 2.0
	no.add_child(caixa.call("Borda", Vector3(lado_pec + t, 0.02, t), Vector3(0, y, fora), mat_borda) as Node)
	no.add_child(caixa.call("Borda2", Vector3(lado_pec + t, 0.02, t), Vector3(0, y, -fora), mat_borda) as Node)
	no.add_child(caixa.call("Borda3", Vector3(t, 0.02, lado_pec + t), Vector3(-fora, y, 0), mat_borda) as Node)
	no.add_child(caixa.call("Borda4", Vector3(t, 0.02, lado_pec + t), Vector3(fora, y, 0), mat_borda) as Node)
	return no


## Um painel de PILHA (baralho/cemitério) = o mesmo vidro do slot, mas no
## formato da carta EM ATAQUE (largura x altura + a mesma folga do slot, sem
## virar quadrado). A posição vem do DADO (`pos_slot`), como nos slots.
func _painel_pilha(lado: int, pilha: String) -> Node3D:
	var letra := "d" if pilha == "deck" else "g"
	var p: Vector3 = pos_slot.call(lado, pilha, 0)
	var no := Node3D.new()
	no.name = "Painel_p%d_%s0" % [lado, letra]
	no.position = Vector3(p.x, 0.0, p.z)
	var mat_borda: Material = vidro.call(Color(0.40, 0.58, 0.88), 0.42, 0.05)
	var mat_base: Material = vidro.call(Color(0.035, 0.08, 0.20), 0.72, 0.05)
	var lx: float = (larg_carta + 0.12) * escala_campo
	var lz: float = (alt_carta + 0.12) * escala_campo
	no.add_child(caixa.call("Base", Vector3(lx, 0.05, lz), Vector3(0, topo - 0.03, 0), mat_base) as Node)
	var t := 0.05 * escala_campo
	var y := topo + 0.005
	no.add_child(caixa.call("Borda", Vector3(lx + t, 0.02, t), Vector3(0, y, lz / 2.0 + t / 2.0), mat_borda) as Node)
	no.add_child(caixa.call("Borda2", Vector3(lx + t, 0.02, t), Vector3(0, y, -lz / 2.0 - t / 2.0), mat_borda) as Node)
	no.add_child(caixa.call("Borda3", Vector3(t, 0.02, lz + t), Vector3(-lx / 2.0 - t / 2.0, y, 0), mat_borda) as Node)
	no.add_child(caixa.call("Borda4", Vector3(t, 0.02, lz + t), Vector3(lx / 2.0 + t / 2.0, y, 0), mat_borda) as Node)
	return no
