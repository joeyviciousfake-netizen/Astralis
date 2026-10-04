class_name BoardLayout
extends RefCounted

## BoardLayout — lê a arena (só DESENHO, nunca regra — D24/R3).
## Slot tem ID fixo (lado+tipo+índice); a lógica só usa o índice,
## o desenho usa o XY do layout com fallback p/ grade padrão.
## D48: o fallback NÃO é uma segunda arena — é a MESMA arena oficial
## (arena_starter.json) escrita nos números abaixo. Uma arena só.
## Mover XY no JSON nunca muda para qual índice a carta vai.
## ESPELHO do rival (só DESENHO, IDs/lógica intactos): lado 1 tem X
## invertido (índice 0 à direita) e fileiras trocadas (monstro perto
## do centro, magia longe), espelhando o lado 0.

## D50: A MESA É O DADO, E HÁ SÓ UM DADO. Estas constantes saíram: a grade
## embutida que vivia aqui era a segunda cópia da arena (a terceira estava no
## `duel_legacy2d/duel_board.gd`), e era ela que fazia o jogo cair numa tela
## diferente da oficial sem ninguém ver. A posição de cada slot vem SO do
## arquivo `schemas/examples/arenas/arena_starter.json` (arena_oficial_path).
## Os números da mesa (632→1684 de 263 em 263; y 695/958 e 305/42, com o vão
## monstro->magia = 263 dos dois lados e a distância 390 entre as fileiras de
## monstro CONGELADA) vivem só naquele arquivo, e o D49 travou isso em teste.
const NULO := Vector2(-99999, -99999)

const DataLoaderScript := preload("res://core/data_loader.gd")

## Mão (só DESENHO, nunca regra). Centro X editável esq/dir no JSON,
## step = distância entre cartas, y = topo da carta em 1920x1080.
## Fallback quando a arena não tem "hand" (arena antiga continua válida).
const HAND_P0_X := 1240.0
const HAND_P0_Y := 980.0
const HAND_P0_STEP := 95.0
const HAND_P1_X := 1240.0
const HAND_P1_Y := 20.0
const HAND_P1_STEP := 60.0


## Mão padrão (fallback quando a arena não tem "hand").
## lado: 0 = p0/você-baixo, 1 = p1/rival-cima. Volta {x,y,step}.
static func default_hand(lado: int) -> Dictionary:
	if lado == 1:
		return {"x": HAND_P1_X, "y": HAND_P1_Y, "step": HAND_P1_STEP}
	return {"x": HAND_P0_X, "y": HAND_P0_Y, "step": HAND_P0_STEP}


static func _eh_num(v: Variant) -> bool:
	return v is float or v is int


## Valida um {x,y,step} da mão contra o contrato (x 0-1920, y 0-1080,
## step 40-200). Começa do fallback e troca só o campo válido,
## então JSON parcial nunca quebra o desenho.
static func _validar_hand_pos(d: Dictionary, fallback: Dictionary) -> Dictionary:
	var out := {"x": float(fallback["x"]), "y": float(fallback["y"]), "step": float(fallback["step"])}
	if d.has("x") and _eh_num(d["x"]):
		var vx := float(d["x"])
		if vx >= 0.0 and vx <= 1920.0:
			out["x"] = vx
	if d.has("y") and _eh_num(d["y"]):
		var vy := float(d["y"])
		if vy >= 0.0 and vy <= 1080.0:
			out["y"] = vy
	if d.has("step") and _eh_num(d["step"]):
		var vs := float(d["step"])
		if vs >= 40.0 and vs <= 200.0:
			out["step"] = vs
	return out


## Lê o "hand" opcional do JSON da arena -> {p0:{x,y,step}, p1:{...}}.
## Arena sem hand continua válida: volta o fallback (não quebra).
static func parse_hand(dados: Dictionary) -> Dictionary:
	var out := {"p0": default_hand(0), "p1": default_hand(1)}
	if not dados.has("hand") or not (dados["hand"] is Dictionary):
		return out
	var h: Dictionary = dados["hand"]
	for lado in [0, 1]:
		var chave := "p1" if lado == 1 else "p0"
		if h.has(chave) and (h[chave] is Dictionary):
			out[chave] = _validar_hand_pos(h[chave], default_hand(lado))
		else:
			out[chave] = default_hand(lado)
	return out


## Pega a mão de um lado. Aceita 3 formatos (todos valem):
## 1. arena completa {slots, hand} (novo, de load_arena_data),
## 2. hand direto {p0, p1} (de parse_hand),
## 3. slots-only legado (de load_arena) ou vazio -> fallback.
## Nunca quebra: sem hand, volta p0(1240,980,95)/p1(1240,20,60).
static func get_hand(arena_ou_hand: Dictionary, lado: int) -> Dictionary:
	var chave := "p1" if lado == 1 else "p0"
	var fallback := default_hand(lado)
	if arena_ou_hand.is_empty():
		return fallback
	if arena_ou_hand.has("p0") or arena_ou_hand.has("p1"):
		if arena_ou_hand.has(chave) and (arena_ou_hand[chave] is Dictionary):
			return _validar_hand_pos(arena_ou_hand[chave], fallback)
		return fallback
	if arena_ou_hand.has("hand") and (arena_ou_hand["hand"] is Dictionary):
		var h: Dictionary = arena_ou_hand["hand"]
		if h.has(chave) and (h[chave] is Dictionary):
			return _validar_hand_pos(h[chave], fallback)
		return fallback
	return fallback


## ID fixo do slot. lado: 0 = p0/você-baixo, 1 = p1/rival-cima.
## tipo: "monstro"/"m" -> m, "magia"/"s" -> s (índice 0..4);
## "deck"/"d" -> d (pilha do baralho), "cemiterio"/"g" -> g (pilha do
## cemitério), sempre índice 0. Volta "" se inválido.
static func slot_id(lado: int, tipo: String, indice: int) -> String:
	var prefixo := "p1" if lado == 1 else "p0"
	var t := tipo.strip_edges().to_lower()
	var letra := ""
	if t == "m" or t == "monstro":
		letra = "m"
	elif t == "s" or t == "magia":
		letra = "s"
	elif t == "d" or t == "deck" or t == "baralho":
		letra = "d"
	elif t == "g" or t == "cemiterio" or t == "cemitério" or t == "graveyard":
		letra = "g"
	else:
		return ""
	if letra == "d" or letra == "g":
		if indice != 0:
			return ""
		return "%s_%s0" % [prefixo, letra]
	if indice < 0 or indice > 4:
		return ""
	return "%s_%s%d" % [prefixo, letra, indice]


## Diz se o ID segue o contrato: p0/p1 + _ + m/s + 0-4, ou d0/g0 de pilha.
static func eh_slot_valido(slot: String) -> bool:
	if slot.length() != 5:
		return false
	if slot[0] != "p":
		return false
	if slot[1] != "0" and slot[1] != "1":
		return false
	if slot[2] != "_":
		return false
	if slot[3] == "m" or slot[3] == "s":
		return slot[4] >= "0" and slot[4] <= "4"
	if slot[3] == "d" or slot[3] == "g":
		return slot[4] == "0"
	return false


## D50: NAO EXISTE MAIS GRADE NO CODIGO. Este arquivo era o segundo lugar (e o
## terceiro, no `duel_legacy2d/duel_board.gd`) onde os numeros da mesa
## estavam escritos, e era o que fazia o jogo cair numa tela diferente da
## arena oficial sem ninguem ver. AGORA O DADO E O UNICO DONO: a posicao de
## cada slot vem SO do arquivo `arena_oficial.json`, e nao existe nenhuma
## segunda fonte. `get_pos` le o layout; se o slot nao estiver no arquivo, o
## jogo avisa em voz alta (ver `valida_arena_oficial`) e NAO inventa posicao.
## D50: kept only as the "nao ha posicao" answer. NAO tem mais grade aqui.
## Quem chama precisa do layout (arena_oficial_path) - ver get_pos.
## O `slot` fica no prefixo `_` porque aqui NAO ha nada para consultar: o
## prefixo e' aviso de assinatura, nao uma regra escondida.
static func default_pos(_slot: String) -> Vector2:
	return NULO


## Os 24 IDs esperados -> Vector2 do DADO (a arena oficial). Sem layout, tudo
## NULO: e assim que o jogo percebe que o arquivo nao veio, em vez de desenhar
## uma grade imaginaria.
static func default_layout() -> Dictionary:
	var out: Dictionary = {}
	for lado in [0, 1]:
		for i in range(5):
			var id_m := slot_id(lado, "monstro", i)
			var id_s := slot_id(lado, "magia", i)
			out[id_m] = NULO
			out[id_s] = NULO
		out[slot_id(lado, "deck", 0)] = NULO
		out[slot_id(lado, "cemiterio", 0)] = NULO
	return out


## Caminho do ARQUIVO DA ARENA OFICIAL (a mesa do jogo, D50: uma só).
static func starter_arena_path() -> String:
	var res_dir: String = ProjectSettings.globalize_path("res://")
	return res_dir.path_join("../schemas/examples/arenas/arena_starter.json").simplify_path()



## `schemas/examples/arenas/arena_starter.json` e a MESMA mesa que o jogo
## desenha (24 slots + mao p0/p1). NAO existe mais nenhuma outra arena:
## nem no codigo (as grades do `board_layout.gd` e do `duel_legacy2d/
## duel_board.gd` foram apagadas) nem por projeto (o projeto nao tem mais
## pasta `arenas/`; o D50 tirou o override por projeto).
static func arena_oficial_path() -> String:
	return starter_arena_path()


## D50: o override por projeto foi REMOVIDO de proposito. Existia só para
## deixar um projeto trocar a mesa por outra, e é exatamente a "segunda arena"
## que o usuario mandou tirar. O jogo tem UMA mesa; o `arena_id` do
## `duel_setup` continua no contrato (o dado FM traz `arena_starter`) e o
## runtime o ignora de propósito, avisando no log.
static func project_arena_path(arena_id: String = "arena_starter") -> String:
	var aid := arena_id.strip_edges()
	if aid != "" and aid != "arena_starter":
		print("[ARENA] arena_id '%s' IGNORADO: o jogo tem UMA arena só (D50), a arena oficial." % aid)
	return arena_oficial_path()


## Converte valor do layout em Vector2. Aceita Vector2, Array [x,y] ou Dict {x,y}.
static func para_vec(v: Variant) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		var a: Array = v
		if (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			return Vector2(float(a[0]), float(a[1]))
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("x") and d.has("y"):
			var dx = d["x"]
			var dy = d["y"]
			if (dx is float or dx is int) and (dy is float or dy is int):
				return Vector2(float(dx), float(dy))
	return NULO


## Pega a posição de UM slot: SÓ do layout (o arquivo da arena oficial).
## D50: não existe mais "grade padrão" aqui — se o slot não estiver no
## arquivo, o jogo tem um problema de verdade e o fallback do chamador é usado
## (a mesa avisa antes, em `valida_arena_oficial`).
static func get_pos(layout: Dictionary, slot: String, fallback: Vector2 = NULO) -> Vector2:
	if layout.has(slot):
		var c := para_vec(layout[slot])
		if c != NULO:
			return c
	return fallback


## Confere que a arena oficial tem os 24 slots. D50: como não existe mais
## grade no código, um arquivo faltando ou quebrado é um ERRO DE VERDADE —
## devolve a lista do que falta e a mesa não inventa posição nenhuma.
static func valida_arena_oficial(slots: Dictionary) -> Array:
	var faltando: Array = []
	for lado in [0, 1]:
		for i in range(5):
			for tipo in ["monstro", "magia"]:
				var sid := slot_id(lado, tipo, i)
				var p := get_pos(slots, sid)
				if p == NULO:
					faltando.append(sid)
		for pilha in ["deck", "cemiterio"]:
			var pid := slot_id(lado, pilha, 0)
			if get_pos(slots, pid) == NULO:
				faltando.append(pid)
	if faltando.is_empty():
		print("[ARENA] Arena oficial OK: 24 slots, uma mesa só (D50).")
	else:
		push_warning("[ARENA] A arena oficial está com %d slot(s) faltando: %s. "
			% [faltando.size(), str(faltando)]
			+ "O jogo NÃO inventa posição (D50): sem o arquivo schemas/examples/arenas/"
			+ "arena_starter.json completo, o campo não pode ser desenhado.")
	return faltando


## Lê a arena do disco -> {slots, hand}.
## slots: Dict slot_id -> Vector2 (só desenho). hand: {p0,p1} com x/y/step.
## D50: `path` é sempre a arena OFICIAL do jogo (arena_oficial_path) — não
## existe override por projeto. Arquivo faltando/quebrado = erro honesto
## (slots vazio + aviso PT-BR), e a mesa NÃO desenha o campo, porque não há
## mais nenhuma grade no código para cair.
static func load_arena_data(path: String) -> Dictionary:
	var sem_hand := {"p0": default_hand(0), "p1": default_hand(1)}
	var vazio := {"slots": {}, "hand": sem_hand}
	if path.is_empty():
		push_warning("[ARENA] Caminho da arena oficial vazio: o campo não pode ser desenhado (D50).")
		return vazio
	if not FileAccess.file_exists(path):
		push_warning("[ARENA] Arena oficial não encontrada: %s. O campo não pode ser desenhado (D50)." % path)
		return vazio
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[ARENA] Não foi possível abrir a arena oficial: %s." % path)
		return vazio
	var texto: String = f.get_as_text()
	var json := JSON.new()
	if json.parse(texto) != OK:
		push_warning("[ARENA] JSON inválido na arena oficial %s: %s" % [path, json.get_error_message()])
		return vazio
	if not (json.data is Dictionary):
		push_warning("[ARENA] Formato inesperado na arena oficial %s (esperava objeto)." % path)
		return vazio
	var dados: Dictionary = json.data
	if not dados.has("slots") or not (dados["slots"] is Array):
		push_warning("[ARENA] Arena oficial sem lista 'slots' em %s." % path)
		return vazio
	var layout: Dictionary = {}
	var lista: Array = dados["slots"]
	if lista.size() != 24:
		push_warning("[ARENA] Arena oficial precisa de 24 slots, achou %d em %s." % [lista.size(), path])
	for item in lista:
		if not (item is Dictionary):
			push_warning("[ARENA] Slot inválido ignorado (esperava objeto com slot_id/x/y).")
			continue
		var d: Dictionary = item
		if not d.has("slot_id"):
			push_warning("[ARENA] Slot sem 'slot_id' ignorado.")
			continue
		var sid := str(d.get("slot_id", ""))
		if not eh_slot_valido(sid):
			push_warning("[ARENA] Slot com ID inválido '%s' ignorado (esperava p0/p1 + m/s + 0-4 ou d0/g0)." % sid)
			continue
		if layout.has(sid):
			push_warning("[ARENA] Slot duplicado '%s' ignorado (vale o primeiro)." % sid)
			continue
		if not d.has("x") or not d.has("y"):
			push_warning("[ARENA] Slot '%s' sem x/y, ignorado (D50: sem grade no código, fica sem posição)." % sid)
			continue
		var vx = d["x"]
		var vy = d["y"]
		if not (vx is float or vx is int) or not (vy is float or vy is int):
			push_warning("[ARENA] Slot '%s' sem x/y válidos, ignorado (D50: sem grade no código, fica sem posição)." % sid)
			continue
		layout[sid] = Vector2(float(vx), float(vy))
	valida_arena_oficial(layout)
	var hand := parse_hand(dados)
	if not dados.has("hand"):
		push_warning("[ARENA] A arena oficial não tem 'hand': a mão cai no padrão do contrato.")
	return {"slots": layout, "hand": hand}


## Lê a arena do disco -> Dict slot_id -> Vector2 (legado, mantido p/ compat).
## É só o ["slots"] de load_arena_data. Quem precisa da mão usa
## load_arena_data + get_hand. Sem arena, volta vazio + aviso.
static func load_arena(path: String) -> Dictionary:
	return (load_arena_data(path).get("slots", {}) as Dictionary)
