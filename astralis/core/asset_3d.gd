extends RefCounted

## asset_3d — DONO DO CARREGAMENTO DOS ASSETS 3D DO JOGO (doc 17).
##
## O QUE ELE E: a ponte entre o arquivo exportado do Blender
## (`assets/3d/<id>.glb`, o artefato) e a tela. Ele nao tem regra nenhuma
## (R1): nao decide onde o objeto fica, nao escala, nao le o dado do duelo.
## Ele so responde "o asset `id` existe?" e "me da a cena dele", e mede o que
## o manifesto promete.
##
## A FONTE DOS NUMEROS E O MANIFESTO (`assets/3d/manifest.json`), e nao este
## arquivo. O mesmo numero nao pode estar em dois lugares — foi assim que a
## mesa teve DUAS arenas e o jogo caia numa tela diferente em silencio
## (D48/D50). O manifesto e verificado por dois lados independentes:
## `tools/blender/exportar_assets.py` (Blender, medindo o .glb gerado) e
## `testing/test_assets_3d.gd` (aqui, medindo o que o Godot carregou).
##
## A FONTE DO MESH E O `.blend` em `assets/3d/fonte/` (pasta com
## `.gdignore`, que o Godot nao escaneia). O jogo NUNCA carrega o `.blend`:
## carrega o `.glb`, que e o export deterministico do `.blend`.
##
## DONO DO 3D (D61): sao assets DO JOGO, como a arena oficial. Um projeto de
## usuario nao sobrescreve mesh de mesa — se um dia ele precisar, isso vira
## decisao de contrato (campo novo + espelho no Studio), nao um detalhe de
## caminho de arquivo.
##
## CONVENCOES (as mesmas do manifesto, e o manifesto e quem as crava):
##   - 1 unidade = 1 largura de carta (LARG_CARTA = 1.0 na mesa)
##   - Y para cima; a conversao de eixo e do exportador glTF, nao nossa
##   - origem na BASE e no CENTRO (y = 0 no chao), para o objeto pousar no
##     plano do campo sem nenhum ajuste
##   - um material por asset, `mat_<id>`

## Onde mora o manifesto e os artefatos exportados.
const DIR := "res://assets/3d"
const MANIFESTO := "res://assets/3d/manifest.json"
## Tolerancia da comparacao de caixa: o .glb grava em 4 casas decimais.
const TOL := 0.001

var _manifesto: Dictionary = {}
var _lido := false
var _cache: Dictionary = {}


## O manifesto inteiro ({} quando ausente ou ilegivel — e o jogo avisa em vez
## de inventar asset, R3).
func manifesto() -> Dictionary:
	if _lido:
		return _manifesto
	_lido = true
	if not FileAccess.file_exists(MANIFESTO):
		push_warning("[ASSET3D] Sem manifesto em %s: nenhum asset 3D pode ser usado." % MANIFESTO)
		return {}
	var txt := FileAccess.get_file_as_string(MANIFESTO)
	var dados = JSON.parse_string(txt)
	if not (dados is Dictionary):
		push_warning("[ASSET3D] Manifesto ilegivel em %s (JSON quebrado)." % MANIFESTO)
		return {}
	_manifesto = dados as Dictionary
	return _manifesto


## O registro de um asset pelo id ({} quando nao existe).
func registro(id: String) -> Dictionary:
	for a in (manifesto().get("assets", []) as Array):
		if str((a as Dictionary).get("id", "")) == id:
			return a as Dictionary
	return {}


## O asset existe no manifesto E o .glb esta no disco.
func existe(id: String) -> bool:
	var r := registro(id)
	if r.is_empty():
		return false
	return FileAccess.file_exists(caminho_glb(id))


func caminho_glb(id: String) -> String:
	return "%s/%s.glb" % [DIR, id]


func caminho_blend(id: String) -> String:
	return "%s/%s" % [DIR, str(registro(id).get("blend", ""))]


## A cena empacotada do asset (null quando nao existe). O `load()` e o caminho
## normal de um .glb no Godot: o arquivo importado vira PackedScene.
func cena(id: String) -> PackedScene:
	if _cache.has(id):
		return _cache[id] as PackedScene
	var r := registro(id)
	if r.is_empty():
		push_warning("[ASSET3D] Asset '%s' nao esta no manifesto." % id)
		return null
	if not FileAccess.file_exists(caminho_glb(id)):
		push_warning("[ASSET3D] Asset '%s' sem o .glb exportado (%s). Rode o exportador." % [
			id, caminho_glb(id)])
		return null
	var packed := load(caminho_glb(id))
	if not (packed is PackedScene):
		push_warning("[ASSET3D] '%s' carregou mas nao e PackedScene." % caminho_glb(id))
		return null
	_cache[id] = packed
	return packed as PackedScene


## Instancia o asset. Devolve null (e avisa) em vez de devolver uma caixa no
## lugar: asset faltando e erro honesto, nunca geometria inventada (R3/D50).
func instancia(id: String) -> Node3D:
	var packed := cena(id)
	if packed == null:
		return null
	return packed.instantiate() as Node3D


## O que o manifesto PROMETE, para o caller conferir com o que carregou.
func medido(id: String) -> Dictionary:
	var r := registro(id)
	if r.is_empty():
		return {}
	return {
		"triangulos": int(r.get("triangulos", -1)),
		"vertices": int(r.get("vertices", -1)),
		"caixa": r.get("caixa", {}),
		"materiais": r.get("materiais", []),
	}


## Soma dos triangulos de todos os assets do manifesto: o teto de poligonos do
## jogo em UM numero so, para ninguem descobrir no fim que a mesa ficou pesada.
func total_de_triangulos() -> int:
	var total := 0
	for a in (manifesto().get("assets", []) as Array):
		total += int((a as Dictionary).get("triangulos", 0))
	return total
