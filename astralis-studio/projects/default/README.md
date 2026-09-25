# projects/default/ — Projeto do editor (dono: Editor Engineer)

Boot VAZIO: o Studio abre sem nada carregado e só mostra o que você importar
(aba Exportar → Importar pack). `schemas/examples/` é o jogo embutido — o
editor nunca lê nem escreve lá.

Layout (o jogo lê tudo daqui via `--project "<esta pasta>"`):

- `cards/`, `duelists/`, `decks/`, `arenas/` — um `.json` por item
- `fusions.json` + `effects.json` — arquivos inteiros (vazios válidos aqui)
- `scenes/` — cenas simples do editor
- `assets/<cards|portraits|backgrounds>/` — PNGs arrastados nas telas

Jogar: a carta salva e abre `Godot --path astralis -- --project "<esta
pasta>"`; o duelo monta um setup temporário e soma `--setup <temp>` por cima
(o jogo lê o projeto + o setup por cima). O editor nunca calcula jogo (R1):
só prepara dado e chama o Astralis (R4).

Backups do Importar ficam em `backups/` (ignorado no git).
