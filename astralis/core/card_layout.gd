class_name CardLayout
extends RefCounted

## CardLayout — molde da carta em DADO (D23/R3, schemas/card_layout.schema.json V1).
## Só DESENHO, nunca regra (R1): lê layouts/card_layout_monster_default.json da
## base do --project (via DataLoader, mesma base de cartas/duelos/arenas),
## valida o essencial do contrato e completa peça ausente com o default do scan.
## Sem molde ou molde inválido = default EMBUTIDO (números idênticos ao JSON
## oficial schemas/examples/layouts/card_layout_monster_default.json) — o jogo
## nunca quebra. V1 = só molde de monstro; override por carta fica p/ V2, por
## isso nada aqui lê card.schema.json (não criar campo novo).
## Conversão por-mil -> px: x/w em ‰ da LARGURA, y/h em ‰ da ALTURA, font_size
## em ‰ da ALTURA (ver schema). Peça ausente = default do scan; rect ausente
## numa peça presente = default daquela peça; style mescla por campo.

const MOLDE_ARQUIVO := "card_layout_monster_default.json"
const MOLDE_ID := "card_layout_monster_default"

## Tipos FECHADOS (R5, mesmos do schema). Máx 1 peça por kind no molde.
const KINDS := ["name", "attribute_orb", "level_stars", "art_window", "type_line", "text_box", "atkdef_bar", "footer", "frame"]

const DataLoaderScript := preload("res://core/data_loader.gd")

## Memo do molde ativo (mesmo padrão do DataLoader): a base é resolvida uma
## vez por boot; a mesa cria dezenas de CardViews por _atualizar e cada
## setup() pede o ativo — sem isto o JSON seria relido a cada carta.
static var _memo_base := ""
static var _memo_layout := {}
static var _memo_ok := false


## Limpa o memo (só p/ teste descartável; o jogo nunca chama).
static func limpar_cache() -> void:
	_memo_base = ""
	_memo_layout = {}
	_memo_ok = false


## Peça default do scan (números idênticos ao JSON oficial, peça por peça).
## Devolve dict NOVO a cada chamada (sem estado compartilhado).
static func peca_padrao(kind: String) -> Dictionary:
	match kind:
		"name":
			return {"id": "name_bar", "kind": "name",
				"rect": {"x": 35.0, "y": 35.0, "w": 930.0, "h": 65.0},
				"style": {"font_size": 37.0, "bold": true, "color": "#2a1c08", "align": "left", "z": 5},
				"visible_when": "always"}
		"attribute_orb":
			return {"id": "attribute_orb", "kind": "attribute_orb",
				"rect": {"x": 865.0, "y": 30.0, "w": 90.0, "h": 62.0},
				"style": {"z": 6},
				"visible_when": "always"}
		"level_stars":
			return {"id": "level_stars", "kind": "level_stars",
				"rect": {"x": 35.0, "y": 115.0, "w": 885.0, "h": 45.0},
				"style": {"font_size": 45.0, "bold": false, "color": "#ff9d0a", "align": "right", "z": 5},
				"visible_when": "always"}
		"art_window":
			return {"id": "art_window", "kind": "art_window",
				"rect": {"x": 90.0, "y": 165.0, "w": 820.0, "h": 563.0},
				"style": {"z": 4},
				"visible_when": "always"}
		"type_line":
			return {"id": "type_line", "kind": "type_line",
				"rect": {"x": 95.0, "y": 752.0, "w": 810.0, "h": 30.0},
				"style": {"font_size": 22.0, "bold": true, "color": "#2a1c08", "align": "left", "z": 5},
				"visible_when": "always"}
		"text_box":
			return {"id": "text_box", "kind": "text_box",
				"rect": {"x": 60.0, "y": 740.0, "w": 880.0, "h": 210.0},
				"style": {"font_size": 20.0, "bold": false, "color": "#2a1c08", "align": "left", "z": 3},
				"visible_when": "always"}
		"atkdef_bar":
			return {"id": "atkdef_bar", "kind": "atkdef_bar",
				"rect": {"x": 95.0, "y": 905.0, "w": 810.0, "h": 32.0},
				"style": {"font_size": 26.0, "bold": true, "color": "#2a1c08", "align": "right", "z": 5},
				"visible_when": "monster_only"}
		"footer":
			return {"id": "footer", "kind": "footer",
				"rect": {"x": 35.0, "y": 960.0, "w": 930.0, "h": 25.0},
				"style": {"font_size": 13.0, "bold": false, "color": "#ffffff", "align": "left", "z": 5},
				"visible_when": "always"}
		"frame":
			return {"id": "frame", "kind": "frame",
				"rect": {"x": 0.0, "y": 0.0, "w": 1000.0, "h": 1000.0},
				"style": {"z": 0},
				"visible_when": "always"}
	return {}


## Molde default completo (idêntico ao JSON oficial). Dict NOVO por chamada.
static func default_layout() -> Dictionary:
	var pecas: Array = []
	for kind in KINDS:
		pecas.append(peca_padrao(String(kind)))
	return {
		"schema_version": 1,
		"id": MOLDE_ID,
		"name": "Molde padrão de monstro (scan Blue-Eyes)",
		"layout_for": "monster",
		"canvas": {"w": 59.0, "h": 86.0, "unit": "per_mil"},
		"pieces": pecas,
	}


static func layouts_dir(base: String) -> String:
	return base.path_join("layouts")


static func molde_path(base: String) -> String:
	return layouts_dir(base).path_join(MOLDE_ARQUIVO)


## Molde ATIVO: layouts/ da base do --project (ou da embutida sem --project).
## Sem arquivo = default em SILÊNCIO (projeto legado não tem layouts/, é o
## caso comum); arquivo presente mas quebrado = aviso PT-BR + default.
## Memoizado por base (a mesa monta dezenas de cartas por quadro).
static func load_active() -> Dictionary:
	var base: String = DataLoaderScript.project_base_dir()
	if _memo_ok and _memo_base == base and not _memo_layout.is_empty():
		return (_memo_layout as Dictionary).duplicate(true)
	var molde := load_from_dir(base)
	_memo_base = base
	_memo_layout = molde.duplicate(true)
	_memo_ok = true
	return molde


## Lê o molde de uma base explícita (produção passa a base do --project; teste
## passa pasta temporária — sem gambiarra de CLI). Sempre devolve 9 peças
## fundidas; qualquer falha devolve o default (jogo nunca quebra).
static func load_from_dir(base: String) -> Dictionary:
	if base.strip_edges().is_empty():
		return default_layout()
	var caminho := molde_path(base)
	if not FileAccess.file_exists(caminho):
		return default_layout()
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		print("[CardLayout] Aviso: não foi possível abrir o molde, usando padrão: " + caminho)
		return default_layout()
	var texto: String = f.get_as_text()
	var json := JSON.new()
	if json.parse(texto) != OK:
		print("[CardLayout] Aviso: molde com JSON inválido, usando padrão: " + caminho)
		return default_layout()
	var fundido := validar(json.data)
	if fundido.is_empty():
		print("[CardLayout] Aviso: molde fora do contrato (V1 só monstro, 9 kinds, x+w<=1000 e y+h<=1000), usando padrão: " + caminho)
		return default_layout()
	return fundido


## Valida o dict do molde e funde com os defaults (peça ausente = default do
## scan, rect/style ausentes = default da peça). Volta {} se INVÁLIDO (o
## chamador cai no default). Rígido no que o schema trava (versão, kinds
## fechados, kind único, limites 0-1000, somas, hex, enums); ignora chave
## desconhecida (compat futura, sem quebrar V1).
static func validar(molde: Variant) -> Dictionary:
	if not (molde is Dictionary):
		return {}
	var d: Dictionary = molde
	if int(d.get("schema_version", -1)) != 1:
		return {}
	if not _eh_id(d.get("id", "")):
		return {}
	if str(d.get("name", "")).strip_edges().is_empty():
		return {}
	if str(d.get("layout_for", "monster")) != "monster":
		return {}
	if d.has("canvas") and not _canvas_ok(d["canvas"]):
		return {}
	var brutas: Array = []
	if d.has("pieces"):
		if not (d["pieces"] is Array):
			return {}
		brutas = d["pieces"]
		if brutas.size() > 9:
			return {}
	var fundidas := {}
	for b in brutas:
		if not (b is Dictionary):
			return {}
		var p: Dictionary = b
		var kind := str(p.get("kind", ""))
		if not KINDS.has(kind) or fundidas.has(kind):
			return {}
		if not _eh_id(p.get("id", "")):
			return {}
		var rect = _rect_fundido(kind, p.get("rect", null))
		if rect == null:
			return {}
		var style = _style_fundido(kind, p.get("style", null))
		if style == null:
			return {}
		var vw = _vw_fundido(kind, p.get("visible_when", null))
		if vw == null:
			return {}
		fundidas[kind] = {"id": str(p.get("id", "")), "kind": kind, "rect": rect, "style": style, "visible_when": vw}
	var pecas: Array = []
	for kind in KINDS:
		var k := String(kind)
		if fundidas.has(k):
			pecas.append(fundidas[k])
		else:
			pecas.append(peca_padrao(k))
	return {
		"schema_version": 1,
		"id": str(d.get("id", "")),
		"name": str(d.get("name", "")),
		"layout_for": "monster",
		"canvas": {"w": 59.0, "h": 86.0, "unit": "per_mil"},
		"pieces": pecas,
	}


## Layout (validado ou default) -> {kind: peça fundida}. Começa dos defaults e
## aplica por cima, então dict parcial nunca quebra quem desenha.
static func pecas_por_kind(layout: Dictionary) -> Dictionary:
	var out := {}
	for kind in KINDS:
		out[String(kind)] = peca_padrao(String(kind))
	var lista: Array = layout.get("pieces", []) as Array
	for p in lista:
		if p is Dictionary and KINDS.has(str((p as Dictionary).get("kind", ""))):
			out[str((p as Dictionary).get("kind", ""))] = p
	return out


## rect por-mil -> px no tamanho da carta (x/w na largura, y/h na altura).
static func rect_px(rect: Dictionary, tamanho: Vector2) -> Rect2:
	var x := float(rect.get("x", 0.0)) / 1000.0 * tamanho.x
	var y := float(rect.get("y", 0.0)) / 1000.0 * tamanho.y
	var w := float(rect.get("w", 0.0)) / 1000.0 * tamanho.x
	var h := float(rect.get("h", 0.0)) / 1000.0 * tamanho.y
	return Rect2(x, y, w, h)


## font_size por-mil -> px na altura da carta (ausente = padrao).
static func fonte_px(fs: Variant, altura: float, padrao: float) -> float:
	if (fs is float or fs is int) and not (fs is bool) and float(fs) >= 0.0:
		return float(fs) / 1000.0 * altura
	return padrao


## monster_only = só quando a carta é monstro (card_type do contrato).
static func eh_monstro(carta: Dictionary) -> bool:
	return str(carta.get("card_type", "")).strip_edges().to_lower() == "monster"


## Quando desenhar a peça (visible_when do molde + tipo da carta).
static func visivel(peca: Dictionary, carta: Dictionary) -> bool:
	if str(peca.get("visible_when", "always")) == "monster_only":
		return eh_monstro(carta)
	return true


static func _eh_num(v: Variant) -> bool:
	return (v is float or v is int) and not (v is bool)


static func _eh_id(v: Variant) -> bool:
	if not (v is String):
		return false
	var s := str(v)
	if s.length() < 1 or s.length() > 64:
		return false
	var primeira := s.substr(0, 1)
	if primeira < "a" or primeira > "z":
		return false
	for i in range(1, s.length()):
		var c := s.substr(i, 1)
		var ok := (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"
		if not ok:
			return false
	return true


static func _eh_cor(v: Variant) -> bool:
	if not (v is String):
		return false
	var s := str(v)
	if s.length() != 7 or not s.begins_with("#"):
		return false
	for i in range(1, 7):
		var c := s.substr(i, 1).to_lower()
		var ok := (c >= "0" and c <= "9") or (c >= "a" and c <= "f")
		if not ok:
			return false
	return true


## Canvas V1 é fixo (molde proporcional: o desenho escala). Ausente = default.
static func _canvas_ok(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	var c: Dictionary = v
	return _eh_num(c.get("w", null)) and float(c.get("w", 0.0)) == 59.0 \
		and _eh_num(c.get("h", null)) and float(c.get("h", 0.0)) == 86.0 \
		and str(c.get("unit", "")) == "per_mil"


## Funde o rect com o default da peça (ausente = default). null = inválido.
static func _rect_fundido(kind: String, v: Variant) -> Variant:
	if v == null:
		return (peca_padrao(kind)["rect"] as Dictionary).duplicate(true)
	if not (v is Dictionary):
		return null
	var r: Dictionary = v
	for chave in ["x", "y", "w", "h"]:
		if not r.has(chave) or not _eh_num(r[chave]):
			return null
		var n := float(r[chave])
		if n < 0.0 or n > 1000.0:
			return null
	if float(r["x"]) + float(r["w"]) > 1000.0:
		return null
	if float(r["y"]) + float(r["h"]) > 1000.0:
		return null
	return {"x": float(r["x"]), "y": float(r["y"]), "w": float(r["w"]), "h": float(r["h"])}


## Funde o style com o default da peça (ausente = default, por campo).
## null = campo conhecido com valor inválido.
static func _style_fundido(kind: String, v: Variant) -> Variant:
	var base: Dictionary = (peca_padrao(kind)["style"] as Dictionary).duplicate(true)
	if v == null:
		return base
	if not (v is Dictionary):
		return null
	var s: Dictionary = v
	if s.has("font_size"):
		if not _eh_num(s["font_size"]) or float(s["font_size"]) < 0.0 or float(s["font_size"]) > 1000.0:
			return null
		base["font_size"] = float(s["font_size"])
	if s.has("bold"):
		if not (s["bold"] is bool):
			return null
		base["bold"] = bool(s["bold"])
	if s.has("color"):
		if not _eh_cor(s["color"]):
			return null
		base["color"] = str(s["color"])
	if s.has("align"):
		if not (str(s["align"]) in ["left", "center", "right"]):
			return null
		base["align"] = str(s["align"])
	if s.has("z"):
		if not _eh_num(s["z"]) or float(s["z"]) < 0.0 or float(s["z"]) > 10.0:
			return null
		base["z"] = int(float(s["z"]))
	return base


## visible_when ausente = default da peça (atkdef só monstro). null = inválido.
static func _vw_fundido(kind: String, v: Variant) -> Variant:
	if v == null:
		return str(peca_padrao(kind)["visible_when"])
	if not (str(v) in ["always", "monster_only"]):
		return null
	return str(v)
