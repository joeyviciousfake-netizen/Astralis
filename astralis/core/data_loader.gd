class_name DataLoader
extends RefCounted

## DataLoader — carrega JSONs de TRABALHO em schemas/examples/ (Starter Kit).
## R3: só lê DADO, nunca executa lógica. R5: só carregar+validar (sem duelo/efeito/fusão).
## Retorna dicts puros. Erros de leitura voltam em "load_errors" (PT-BR simples).

static func starter_kit_dir() -> String:
	var res_dir: String = ProjectSettings.globalize_path("res://")
	# astralis/../schemas/examples -> <repo>/schemas/examples (simplify resolve o "..").
	return res_dir.path_join("../schemas/examples").simplify_path()

static func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "Arquivo não encontrado: " + path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "data": {}, "error": "Não foi possível abrir: " + path}
	var text: String = f.get_as_text()
	var json := JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		return {"ok": false, "data": {}, "error": "JSON inválido em " + path + ": " + json.get_error_message()}
	return {"ok": true, "data": json.data, "error": ""}

static func _load_folder(folder: String) -> Dictionary:
	var out: Dictionary = {}
	var erros: Array = []
	if not DirAccess.dir_exists_absolute(folder):
		erros.append("Pasta não encontrada: " + folder)
		return {"items": out, "erros": erros}
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	for fname in files:
		if not fname.to_lower().ends_with(".json"):
			continue
		var full: String = folder.path_join(fname)
		var res: Dictionary = load_json_file(full)
		if not bool(res.get("ok", false)):
			erros.append(String(res.get("error", "Erro desconhecido ao ler " + full)))
			continue
		var data: Variant = res.get("data", {})
		if data is Dictionary:
			var d: Dictionary = data
			var key: String = String(d.get("id", fname.get_basename()))
			out[key] = d
		else:
			erros.append("Formato inesperado em " + full + " (esperava objeto).")
	return {"items": out, "erros": erros}

static func load_starter_kit() -> Dictionary:
	var base: String = starter_kit_dir()
	var cards: Dictionary = {}
	var duelists: Dictionary = {}
	var decks: Dictionary = {}
	var fusions: Dictionary = {}
	var effects: Dictionary = {}
	var duel_setup: Dictionary = {}
	var load_errors: Array = []

	var rc: Dictionary = _load_folder(base.path_join("cards"))
	cards = rc.get("items", {})
	load_errors.append_array(rc.get("erros", []))

	var rd: Dictionary = _load_folder(base.path_join("duelists"))
	duelists = rd.get("items", {})
	load_errors.append_array(rd.get("erros", []))

	var rk: Dictionary = _load_folder(base.path_join("decks"))
	decks = rk.get("items", {})
	load_errors.append_array(rk.get("erros", []))

	var rf: Dictionary = load_json_file(base.path_join("fusions.json"))
	if bool(rf.get("ok", false)):
		var fdata: Variant = rf.get("data", {})
		if fdata is Dictionary:
			fusions = fdata
		else:
			load_errors.append("Formato inesperado em fusions.json (esperava objeto).")
	else:
		load_errors.append(String(rf.get("error", "")))

	var re: Dictionary = load_json_file(base.path_join("effects.json"))
	if bool(re.get("ok", false)):
		var edata: Variant = re.get("data", {})
		if edata is Dictionary:
			effects = edata
		else:
			load_errors.append("Formato inesperado em effects.json (esperava objeto).")
	else:
		load_errors.append(String(re.get("error", "")))

	var rs: Dictionary = load_json_file(base.path_join("duel_setup.json"))
	if bool(rs.get("ok", false)):
		var sdata: Variant = rs.get("data", {})
		if sdata is Dictionary:
			duel_setup = sdata
		else:
			load_errors.append("Formato inesperado em duel_setup.json (esperava objeto).")
	else:
		load_errors.append(String(rs.get("error", "")))

	return {
		"cards": cards,
		"duelists": duelists,
		"decks": decks,
		"fusions": fusions,
		"effects": effects,
		"duel_setup": duel_setup,
		"load_errors": load_errors,
		"base_dir": base,
	}
