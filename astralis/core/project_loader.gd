class_name ProjectLoader
extends RefCounted

## ProjectLoader — usa DataLoader e monta o estado inicial (só contagem, R5).
## Não inicia duelo, não aplica efeito/fusão. Só organiza os dicts carregados.

const DataLoaderScript := preload("res://core/data_loader.gd")

static func load_initial_state() -> Dictionary:
	var data: Dictionary = DataLoaderScript.load_starter_kit()
	var cards: Dictionary = data.get("cards", {})
	var duelists: Dictionary = data.get("duelists", {})
	var decks: Dictionary = data.get("decks", {})
	var counts := {
		"cartas": cards.size(),
		"duelistas": duelists.size(),
		"decks": decks.size(),
	}
	return {"data": data, "counts": counts}
