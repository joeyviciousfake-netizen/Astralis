class_name BoardLayout
extends RefCounted

## BoardLayout — lê a arena (só DESENHO, nunca regra — D24/R3).
## Slot tem ID fixo (lado+tipo+índice); a lógica só usa o índice,
## o desenho usa o XY do layout com fallback p/ grade padrão.
## Mover XY no JSON nunca muda para qual índice a carta vai.
## ESPELHO do rival (só DESENHO, IDs/lógica intactos): lado 1 tem X
## invertido (índice 0 à direita) e fileiras trocadas (monstro perto
## do centro, magia longe), espelhando o lado 0.

const SLOT := 165.0
const GAP := 24.0
const GRID_X := 780.0
## Fileiras em ESPELHO (só desenho): monstro sempre perto do centro,
## magia sempre longe. Rival/cima: monstro 317 (embaixo/perto),
## magia 128 (cima/longe). Você/baixo: monstro 600 (cima/perto),
## magia 789 (baixo/longe).
const Y_RIVAL_MONSTRO := 317.0
const Y_RIVAL_MAGIA := 128.0
const Y_VOCE_MONSTRO := 600.0
const Y_VOCE_MAGIA := 789.0

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
## tipo: "monstro"/"m" -> m, "magia"/"s" -> s. indice: 0..4.
## Volta "" se inválido.
static func slot_id(lado: int, tipo: String, indice: int) -> String:
	var prefixo := "p1" if lado == 1 else "p0"
	var t := tipo.strip_edges().to_lower()
	var letra := ""
	if t == "m" or t == "monstro":
		letra = "m"
	elif t == "s" or t == "magia":
		letra = "s"
	else:
		return ""
	if indice < 0 or indice > 4:
		return ""
	return "%s_%s%d" % [prefixo, letra, indice]


## Diz se o ID segue o contrato: p0/p1 + _ + m/s + 0-4.
static func eh_slot_valido(slot: String) -> bool:
	if slot.length() != 5:
		return false
	if slot[0] != "p":
		return false
	if slot[1] != "0" and slot[1] != "1":
		return false
	if slot[2] != "_":
		return false
	if slot[3] != "m" and slot[3] != "s":
		return false
	if slot[4] < "0" or slot[4] > "4":
		return false
	return true


## Grade padrão em ESPELHO (a mesma do duel_board.gd). Volta (-1,-1) se ID inválido.
## Lado 0 (você/baixo): X crescente 780→1536 (índice 0 à esquerda).
## Lado 1 (rival/cima): X ESPELHADO 1536→780 (índice 0 à direita) +
## fileiras trocadas (monstro 317 perto do centro, magia 128 longe).
## Só DESENHO: IDs/lógica continuam no índice.
static func default_pos(slot: String) -> Vector2:
	if not eh_slot_valido(slot):
		return Vector2(-1, -1)
	var indice := int(slot[4])
	var lado := slot[1]
	var letra := slot[3]
	var x := GRID_X + indice * (SLOT + GAP)
	if lado == "1":
		x = GRID_X + (4 - indice) * (SLOT + GAP)
	var y := Y_VOCE_MONSTRO
	if lado == "1" and letra == "m":
		y = Y_RIVAL_MONSTRO
	elif lado == "1" and letra == "s":
		y = Y_RIVAL_MAGIA
	elif lado == "0" and letra == "s":
		y = Y_VOCE_MAGIA
	return Vector2(x, y)


## Os 20 IDs esperados -> Vector2 padrão.
static func default_layout() -> Dictionary:
	var out: Dictionary = {}
	for lado in [0, 1]:
		for i in range(5):
			var id_m := slot_id(lado, "monstro", i)
			var id_s := slot_id(lado, "magia", i)
			out[id_m] = default_pos(id_m)
			out[id_s] = default_pos(id_s)
	return out


## Caminho do arena_starter no disco (pasta de trabalho schemas/examples/).
static func starter_arena_path() -> String:
	var res_dir: String = ProjectSettings.globalize_path("res://")
	return res_dir.path_join("../schemas/examples/arenas/arena_starter.json").simplify_path()


## Caminho da arena <arena_id>.json na pasta do --project (se válido)
## ou na embutida. Sem --project (ou pasta inválida), volta o starter
## de sempre. Nunca quebra: ausente cai na grade padrão em load_arena_data.
static func project_arena_path(arena_id: String = "arena_starter") -> String:
	var aid := arena_id.strip_edges()
	if aid.is_empty():
		aid = "arena_starter"
	var base: String = DataLoaderScript.project_base_dir()
	var cand: String = base.path_join("arenas").path_join(aid + ".json")
	if FileAccess.file_exists(cand):
		return cand
	if base != DataLoaderScript.starter_kit_dir():
		print("[ARENA] Arena '%s' não achada no --project, usando embutida." % aid)
	return starter_arena_path()


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


## Pega a posição: primeiro o layout, senão a grade padrão, senão o fallback.
static func get_pos(layout: Dictionary, slot: String, fallback: Vector2 = Vector2(-1, -1)) -> Vector2:
	if layout.has(slot):
		var c := para_vec(layout[slot])
		if c != NULO:
			return c
	var d := default_pos(slot)
	if d.x >= 0.0 and d.y >= 0.0:
		return d
	return fallback


## Lê a arena do disco -> {slots, hand} (novo formato completo).
## slots: Dict slot_id -> Vector2 (só desenho). hand: {p0,p1} com x/y/step.
## hand é OPCIONAL: arena sem hand continua válida, volta fallback
## p0(1240,980,95)/p1(1240,20,60). Nunca quebra: arquivo ruim volta
## slots vazio + hand fallback + aviso PT-BR.
static func load_arena_data(path: String) -> Dictionary:
	var vazio := {"slots": {}, "hand": {"p0": default_hand(0), "p1": default_hand(1)}}
	if path.is_empty() or not FileAccess.file_exists(path):
		push_warning("[ARENA] Arquivo não encontrado: %s. Usando grade padrão." % path)
		print("[ARENA] Arquivo não encontrado, usando grade padrão: " + path)
		return vazio
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[ARENA] Não foi possível abrir: %s. Usando grade padrão." % path)
		print("[ARENA] Não foi possível abrir, usando grade padrão: " + path)
		return vazio
	var texto: String = f.get_as_text()
	var json := JSON.new()
	if json.parse(texto) != OK:
		push_warning("[ARENA] JSON inválido em %s: %s. Usando grade padrão." % [path, json.get_error_message()])
		print("[ARENA] JSON inválido, usando grade padrão: " + path)
		return vazio
	if not (json.data is Dictionary):
		push_warning("[ARENA] Formato inesperado em %s (esperava objeto). Usando grade padrão." % path)
		return vazio
	var dados: Dictionary = json.data
	if not dados.has("slots") or not (dados["slots"] is Array):
		push_warning("[ARENA] Arena sem lista 'slots' em %s. Usando grade padrão." % path)
		return vazio
	var layout: Dictionary = {}
	var lista: Array = dados["slots"]
	if lista.size() != 20:
		push_warning("[ARENA] Arena precisa de 20 slots, achou %d em %s. Faltando usa grade padrão." % [lista.size(), path])
		print("[ARENA] Esperava 20 slots, achou %d. Completando com grade padrão." % lista.size())
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
			push_warning("[ARENA] Slot com ID inválido '%s' ignorado (esperava p0/p1 + m/s + 0-4)." % sid)
			continue
		if layout.has(sid):
			push_warning("[ARENA] Slot duplicado '%s' ignorado (vale o primeiro)." % sid)
			continue
		if not d.has("x") or not d.has("y"):
			push_warning("[ARENA] Slot '%s' sem x/y, ignorado (usa grade padrão)." % sid)
			continue
		var vx = d["x"]
		var vy = d["y"]
		if not (vx is float or vx is int) or not (vy is float or vy is int):
			push_warning("[ARENA] Slot '%s' sem x/y válidos, ignorado (usa grade padrão)." % sid)
			continue
		layout[sid] = Vector2(float(vx), float(vy))
	var faltando: Array = []
	for esperado in default_layout().keys():
		if not layout.has(esperado):
			faltando.append(esperado)
	if not faltando.is_empty():
		push_warning("[ARENA] Faltando slots %s, usando grade padrão para eles." % str(faltando))
		print("[ARENA] Faltando %d slots, completando com grade padrão." % faltando.size())
	var hand := parse_hand(dados)
	if not dados.has("hand"):
		print("[ARENA] Sem 'hand' no JSON, usando fallback p0(1240,980,95)/p1(1240,20,60).")
	return {"slots": layout, "hand": hand}


## Lê a arena do disco -> Dict slot_id -> Vector2 (legado, mantido p/ compat).
## É só o ["slots"] de load_arena_data. Quem precisa da mão usa
## load_arena_data + get_hand. Nunca quebra: volta vazio + aviso,
## e quem desenha completa com a grade padrão.
static func load_arena(path: String) -> Dictionary:
	return (load_arena_data(path).get("slots", {}) as Dictionary)
