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

## Memo do --project: a base é resolvida/validada UMA vez por boot. O jogo
## chama project_base_dir() 2x (load_starter_kit e
## BoardLayout.project_arena_path); sem isto a validação da pasta e o print
## saíam duplicados no log. Só o --project é memoizado: o --setup é lido uma
## vez só, em load_starter_kit (linha ~200), e NÃO entra aqui.
static var _base_memo := ""
static var _base_memo_pronto := false


# ============================================================
# DEV-ONLY (SOME NO FINAL, ordem do usuário): preview no editor
# (F6/cena aberta sem --project) carrega o pack .apack que está
# sendo editado + sorteia 2 duelistas aleatórios, p/ visualizar o
# jogo real com o conteúdo atual. Gate: SÓ roda com
# OS.has_feature("editor") — no jogo exportado isso é sempre
# falso, então o final nem tem esse caminho. Não é regra (R1):
# só desempacota DADO e monta o setup inicial.
# ============================================================
const DEV_PACK_FIXO := "C:/Users/Max/Downloads/studio_pack_20260925_180627_COMPLETO.apack"


## Chave de teste do bloco DEV (teste descartável liga, usa e desliga).
static var _dev_forcar := false


static func _dev_dir() -> String:
	return ProjectSettings.globalize_path("user://").path_join("dev_pack")


static func _dev_pack_fonte() -> String:
	if FileAccess.file_exists(DEV_PACK_FIXO):
		return DEV_PACK_FIXO
	# Caiu o fixo? Pega o .apack mais novo de Downloads.
	var dl := "C:/Users/Max/Downloads"
	if not DirAccess.dir_exists_absolute(dl):
		return ""
	var melhor := ""
	var melhor_t := -1
	for f in DirAccess.get_files_at(dl):
		if not f.to_lower().ends_with(".apack"):
			continue
		var t: int = int(FileAccess.get_modified_time(dl.path_join(f)))
		if t > melhor_t:
			melhor_t = t
			melhor = dl.path_join(f)
	return melhor


static func _dev_setup_json(duelistas: Array) -> Dictionary:
	# Sorteia 2 duelistas DISTINTOS + deck de cada um (dado real do pack).
	randomize()
	var n := duelistas.size()
	var i1 := randi_range(0, maxi(n - 1, 0))
	var i2 := randi_range(0, maxi(n - 1, 0))
	var guarda := 0
	while n > 1 and i2 == i1 and guarda < 20:
		i2 = randi_range(0, n - 1)
		guarda += 1
	var d1: Dictionary = duelistas[i1] as Dictionary
	var d2: Dictionary = duelistas[i2] as Dictionary
	var ordens := ["first_p1", "first_p2", "random"]
	return {
		"schema_version": 1,
		"duel_id": "duel_dev_random",
		"duelist1": {"duelist_id": str(d1.get("id", "")), "deck_id": str(d1.get("deck_id", ""))},
		"duelist2": {"duelist_id": str(d2.get("id", "")), "deck_id": str(d2.get("deck_id", ""))},
		"starting_lp": 8000,
		"turn_order": ordens[randi_range(0, 2)],
		"seed": randi(),
		"arena_id": "arena_starter",
		"win": {"on_lp_zero": true, "on_deckout": true},
	}


static func _dev_gravar_json(caminho: String, dado: Variant) -> bool:
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dado))
	f.close()
	return true


static func _dev_preparar() -> String:
	# Retorna a pasta DEV pronta ou "". Nunca quebra o boot: qualquer
	# falha cai no examples/ embutido (comportamento de antes).
	# Gate duplo: no jogo exportado has_feature é falso; no headless
	# (GUT/CI/MCP) o DisplayServer é "headless" — DEV só vale no editor
	# ABERTO (F6/preview com tela), nunca em teste nem no final.
	if not _dev_forcar and (DisplayServer.get_name() == "headless" or not OS.has_feature("editor")):
		return ""
	var pack := _dev_pack_fonte()
	if pack.is_empty():
		return ""
	var dev := _dev_dir()
	var tam := 0
	var probe := FileAccess.open(pack, FileAccess.READ)
	if probe != null:
		tam = int(probe.get_length())
		probe.close()
	var stamp: String = "v4:%d:%d" % [int(FileAccess.get_modified_time(pack)), tam]
	var carimbo := dev.path_join(".stamp")
	var pronto := false
	if FileAccess.file_exists(carimbo):
		var l := FileAccess.open(carimbo, FileAccess.READ)
		if l != null and l.get_as_text().strip_edges() == stamp:
			pronto = DirAccess.dir_exists_absolute(dev.path_join("cards")) and FileAccess.file_exists(dev.path_join("arenas/arena_starter.json"))
		if l != null:
			l.close()
	var dados_pack: Dictionary = {}
	if pronto:
		# Pack igual ao da última vez: só o setup é re-sorteado.
		var z0 := ZIPReader.new()
		if z0.open(pack) == OK:
			var raw := z0.read_file("data/pack.json")
			z0.close()
			var js := JSON.new()
			if js.parse(raw.get_string_from_utf8()) == OK and js.data is Dictionary:
				dados_pack = js.data as Dictionary
	if dados_pack.is_empty():
		var z := ZIPReader.new()
		if z.open(pack) != OK:
			return ""
		var nomes := z.get_files()
		var txt := ""
		for n in nomes:
			if str(n) == "data/pack.json":
				txt = z.read_file(str(n)).get_string_from_utf8()
		if txt.is_empty():
			z.close()
			return ""
		var js2 := JSON.new()
		if js2.parse(txt) != OK or not (js2.data is Dictionary):
			z.close()
			return ""
		dados_pack = js2.data as Dictionary
		for sub in ["cards", "duelists", "decks", "assets/fm"]:
			DirAccess.make_dir_recursive_absolute(dev.path_join(sub))
		for c in (dados_pack.get("cartas", []) as Array):
			if c is Dictionary and not str((c as Dictionary).get("id", "")).is_empty():
				_dev_gravar_json(dev.path_join("cards/%s.json" % str((c as Dictionary).get("id", ""))), c)
		for d in (dados_pack.get("duelistas", []) as Array):
			if d is Dictionary and not str((d as Dictionary).get("id", "")).is_empty():
				_dev_gravar_json(dev.path_join("duelists/%s.json" % str((d as Dictionary).get("id", ""))), d)
		for k in (dados_pack.get("decks", []) as Array):
			if k is Dictionary and not str((k as Dictionary).get("id", "")).is_empty():
				_dev_gravar_json(dev.path_join("decks/%s.json" % str((k as Dictionary).get("id", ""))), k)
		_dev_gravar_json(dev.path_join("fusions.json"), dados_pack.get("fusoes", {"schema_version": 1, "recipes": [], "rules": []}))
		_dev_gravar_json(dev.path_join("effects.json"), {"schema_version": 1, "effects": []})
		# Arena padrão junto (o pack não traz arenas/): igual ao examples/.
		var arena_src := starter_kit_dir().path_join("arenas/arena_starter.json")
		if FileAccess.file_exists(arena_src):
			DirAccess.make_dir_recursive_absolute(dev.path_join("arenas"))
			var al := FileAccess.open(arena_src, FileAccess.READ)
			if al != null:
				var w0 := FileAccess.open(dev.path_join("arenas/arena_starter.json"), FileAccess.WRITE)
				if w0 != null:
					w0.store_string(al.get_as_text())
					w0.close()
				al.close()
		for n in nomes:
			var s := str(n)
			if s.begins_with("assets/"):
				var dest := dev.path_join(s)
				DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
				var w := FileAccess.open(dest, FileAccess.WRITE)
				if w != null:
					w.store_buffer(z.read_file(s))
					w.close()
		z.close()
		var s2 := FileAccess.open(carimbo, FileAccess.WRITE)
		if s2 != null:
			s2.store_string(stamp)
			s2.close()
	var lista_duel: Array = dados_pack.get("duelistas", []) as Array
	if lista_duel.size() >= 2:
		_dev_gravar_json(dev.path_join("duel_setup.json"), _dev_setup_json(lista_duel))
	else:
		return ""
	if not pasta_projeto_valida(dev):
		return ""
	print("[DataLoader] DEV editor: pack do Downloads + duelistas sorteados.")
	return dev


static func setup_override_path() -> String:
	# Lê --setup <caminho> (ou --setup=<caminho>) dos args de usuário.
	# Retorna "" se não foi passado. Só leitura de CLI, sem regra nova.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a := String(args[i])
		if a == "--setup" and i + 1 < args.size():
			return _limpar_caminho(String(args[i + 1]))
		if a.begins_with("--setup="):
			return _limpar_caminho(a.trim_prefix("--setup="))
	return ""


static func project_override_path() -> String:
	# Lê --project <pasta> (ou --project=<pasta>) dos args de usuário.
	# Retorna "" se não foi passado. Só leitura de CLI, sem regra nova.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var a := String(args[i])
		if a == "--project" and i + 1 < args.size():
			return _limpar_caminho(String(args[i + 1]))
		if a.begins_with("--project="):
			return _limpar_caminho(a.trim_prefix("--project="))
	return ""


static func _resolver_abs(p: String) -> String:
	# Vira caminho absoluto do SO. Relativo = relativo à raiz do repo
	# (de onde o Godot é chamado). res:// e user:// viram disco.
	var r := _limpar_caminho(p)
	if r.is_empty():
		return ""
	if r.begins_with("res://") or r.begins_with("user://"):
		return ProjectSettings.globalize_path(r).simplify_path()
	if r.is_absolute_path():
		return r.simplify_path()
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	return repo.path_join(r).simplify_path()


static func pasta_projeto_valida(p: String) -> bool:
	# Pasta de projeto válida = existe e tem cara de projeto Astralis
	# (ao menos 1 marcador: cards/, duelists/, decks/, arenas/ ou
	# duel_setup.json/fusions.json/effects.json). Sem mudar regra/schema.
	var abs := _resolver_abs(p)
	if abs.is_empty() or not DirAccess.dir_exists_absolute(abs):
		return false
	for sub in ["cards", "duelists", "decks", "arenas"]:
		if DirAccess.dir_exists_absolute(abs.path_join(sub)):
			return true
	for arq in ["duel_setup.json", "fusions.json", "effects.json"]:
		if FileAccess.file_exists(abs.path_join(arq)):
			return true
	return false


static func project_base_dir() -> String:
	# Com --project válido, TUDO (cartas, duelistas, decks, fusões,
	# arenas, duel_setup, efeitos) é lido de lá; sem o argumento,
	# tudo como hoje (pasta examples/ embutida). Pasta inexistente
	# ou inválida = avisa em PT-BR e usa a embutida. Sem regra/schema.
	# MEMOIZADO: resolvido/validado/avisado só na 1ª chamada (o jogo
	# chama 2x por boot); da 2ª em diante devolve o MESMO resultado,
	# sem refazer pasta nem repetir a mensagem no log.
	if _base_memo_pronto:
		return _base_memo
	var pedido := project_override_path()
	if pedido.is_empty():
		var dev := _dev_preparar()
		if not dev.is_empty():
			_base_memo = dev
			_base_memo_pronto = true
			return _base_memo
		_base_memo = starter_kit_dir()
		_base_memo_pronto = true
		return _base_memo
	var abs := _resolver_abs(pedido)
	if pasta_projeto_valida(pedido):
		print("[DataLoader] --project usando: " + abs)
		_base_memo = abs
	else:
		print("[DataLoader] Aviso: --project ignorado (pasta inexistente ou inválida): " + pedido + " — usando embutida.")
		_base_memo = starter_kit_dir()
	_base_memo_pronto = true
	return _base_memo


static func _limpar_caminho(p: String) -> String:
	var r := p.strip_edges()
	if r.length() >= 2 and r.begins_with('"') and r.ends_with('"'):
		r = r.substr(1, r.length() - 2)
	return r.strip_edges()


static func load_starter_kit() -> Dictionary:
	# Base = pasta do --project (se válido) ou examples/ embutida.
	# O --setup continua valendo por cima (só troca o duel_setup).
	var base: String = project_base_dir()
	var cards: Dictionary = {}
	var duelists: Dictionary = {}
	var decks: Dictionary = {}
	var fusions: Dictionary = {}
	var effects: Dictionary = {}
	var arenas: Dictionary = {}
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

	# Arenas (só DADO p/ o desenho, nunca regra — D24/R3).
	# Pasta arenas/ ausente = silêncio (a mesa usa a grade padrão);
	# só arquivo quebrado vira erro. Sem mudar regra/schema.
	# ATENÇÃO: hoje o dict "arenas" (abaixo) NÃO é consumido por ninguém —
	# a mesa lê a arena por CAMINHO (BoardLayout.project_arena_path), não
	# pelo dict. Fica carregado p/ o contrato e p/ o QA olhar; não é
	# duplicata de leitura, é só um campo não usado ainda.
	var ra: Dictionary = _load_folder(base.path_join("arenas"))
	arenas = ra.get("items", {})
	for e in ra.get("erros", []):
		if not String(e).begins_with("Pasta não encontrada"):
			load_errors.append(String(e))

	# Override via CLI p/ o Studio lançar duelos sem sobrescrever o starter.
	# Se --setup foi passado e o arquivo existe e é um objeto válido, usa-o;
	# senão, mantém o comportamento atual (starter). Sem mudar regra/schema/ID.
	# O caminho passa pelo MESMO _resolver_abs do --project: assim res://,
	# user:// e caminho relativo (raiz do repo) funcionam igual aqui — sem
	# isso o mesmo caminho aceito no --project caía no aviso de "ignorado".
	var override_path: String = setup_override_path()
	if override_path != "":
		var override_abs: String = _resolver_abs(override_path)
		var ro: Dictionary = load_json_file(override_abs)
		if bool(ro.get("ok", false)) and ro.get("data", {}) is Dictionary and not (ro.get("data", {}) as Dictionary).is_empty():
			duel_setup = ro.get("data", {})
			print("[DataLoader] --setup usando: " + override_abs)
		else:
			print("[DataLoader] Aviso: --setup ignorado (ausente ou inválido): " + override_path + " — usando starter.")

	return {
		"cards": cards,
		"duelists": duelists,
		"decks": decks,
		"fusions": fusions,
		"effects": effects,
		"arenas": arenas,
		"duel_setup": duel_setup,
		"load_errors": load_errors,
		"base_dir": base,
	}
