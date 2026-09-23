extends Node

## Cena inicial — carrega o Starter Kit, valida e imprime no console.
## R5: só carregar+validar. Sem duelo/efeito/fusão aqui.

const ProjectLoaderScript := preload("res://core/project_loader.gd")
const RuntimeValidatorScript := preload("res://core/runtime_validator.gd")

func _ready() -> void:
	print("[Astralis] Iniciando Starter Kit...")
	var state: Dictionary = ProjectLoaderScript.load_initial_state()
	var data: Dictionary = state.get("data", {})
	var counts: Dictionary = state.get("counts", {})
	var n_cartas: int = int(counts.get("cartas", 0))
	var n_duelistas: int = int(counts.get("duelistas", 0))
	var n_decks: int = int(counts.get("decks", 0))
	var erros: Array = RuntimeValidatorScript.validate(data)
	var load_errors: Array = data.get("load_errors", [])
	for e in load_errors:
		erros.append(str(e))
	print("[Astralis] STP: %d cartas, %d duelistas, %d decks, erros=%d" % [n_cartas, n_duelistas, n_decks, erros.size()])
	if erros.is_empty():
		print("[Astralis] OK: Starter Kit válido, sem erros.")
	else:
		for e in erros:
			print("[Astralis] ERRO: " + str(e))
