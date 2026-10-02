# ASTRALIS — ÍNDICE GERAL

STATUS: AUTHORITATIVE
AUDIENCE: IA
LANGUAGE: PT-BR

> IA: entrada oficial é `../AGENTS.md`. Ordem obrigatória: `AI_MANIFEST.json` →
> este índice → `SESSAO_ATUAL.md` → `DECISOES.md` → o doc do assunto. Não leia
> tudo de uma vez.
>
> **Antes de commitar o que toca `docs/`, rode `python tools/checar_docs.py`.**

Este índice é o **roteador**: diz o que existe e o que está dentro de cada doc.
O conteúdo de cada assunto mora no doc dele, e a razão de cada regra mora no
`DECISOES.md`. Aqui não se repete nenhum dos dois.

## O QUE VALE SEMPRE (leia uma vez)

| Regra | Onde está |
|---|---|
| DATA != LOGIC, sem motor falso, R1 a R14 | `../AGENTS.md` seção 2 |
| Decisões que não se reabrem, com o porquê de cada | `DECISOES.md` |
| Onde estamos e o que falta | `SESSAO_ATUAL.md` |
| Mapa máquina (owner, depends, read order, contrato) | `AI_MANIFEST.json` |

## OS DOCS POR ASSUNTO

```text
docs/
  AI_MANIFEST.json          mapa máquina: o que existe, de quem é, e o que depende de quê
  SESSAO_ATUAL.md           onde estamos, o que falta, o que está travado
  DECISOES.md               a regra travada e o motivo de cada uma (R7)
  00_INDICE_GERAL.md        <- você está aqui, o roteador
  01_VISAO_PRODUTO.md       identidade, o que o jogo não é, sucesso
  02_PRINCIPIOS_ARQUITETURAIS.md  DATA!=LOGIC, sem motor paralelo, política de conteúdo, regra das ferramentas
  03_STACK_DISTRIBUICAO.md  dev stack x product stack, os 4 modos (GAME/PREVIEW/TEST/DEBUG)
  04_CONTRATO_DADOS.md      os 8 schemas, versionamento, IDs, .apack, o molde
  05_RUNTIME_DUELO.md       os sistemas de duel/, a mesa 3D, a IA rival
  06_SISTEMA_FUSAO.md       receita + regra genérica, ordem de resolução
  07_SISTEMA_EFEITOS.md      o modelo do efeito e o que NÃO tem motor
  08_CAMPANHA.md            PLANO, 0% implementado
  09_STUDIO_EDITOR.md       as telas do editor e o que ele nunca faz
  10_PREVIEW_TESTE_DEBUG.md flags, --project/--setup, GUT, Campo de Testes
  11_ROADMAP.md             MVP, roadmap, donos por pasta, o fluxo de uma feature
  12_DISTRIBUICAO_EXPORTACAO.md  o .apack (existe) e a distribuição trancada (PLANO)
  13_TABULEIRO_DUELO.md     zonas, fases, mão, LP, vitória, a arena
  14_EXPERIENCIA_USUARIO.md Simples/Avançado, erro em PT-BR, o caminho de 5 minutos
  15_VISUAL_DUELO.md        o contrato visual da mesa e o dono de cada número
  16_PERSPECTIVA_CAMPO.md   a volta da mesa, o espelho do rival, as duas mãos
```

## O MAPA DO CÓDIGO (gerado, não escrito à mão)

- **Jogo** `astralis/` — `duel/` sistemas de regra · `duel3d/` a tela em 8
  arquivos · `ai/` a IA rival · `core/` carregador e layout · `ui/` a carta 2D ·
  `testing/` o GUT
- **Editor** `astralis-studio/` — `src-tauri/` Rust (validação, `.apack`,
  lançar o jogo) · `src/` Svelte (as telas)
- **Contrato** `schemas/` — 8 schemas + `examples/` (dado de teste)
- **Ferramentas** `tools/` — `fm_import.py` (o pack de referência),
  `apack.py` (o formato do pack), `checar_docs.py` (o portão de doc)
- **Dados do editor** `astralis-studio/projects/default/` — abre vazio, só por
  Importar (D29)

## REGRAS QUE NÃO SE REABREM (resumo; o texto está no `DECISOES.md`)

- Astralis = runtime, única verdade de gameplay. O Studio monta dado e lança o
  jogo; nunca calcula resultado.
- Proibido motor falso, inclusive em preview e teste.
- A arena é do jogo e tem um dono só, sem fallback.
- A lente da mesa nunca é deslocada.
- As cartas do campo não se mexem: quem gira é a câmera.
- Efeito não tem motor na mesa; o dado existe e é validado.
- Quem manda no projeto é o usuário.

## O QUE NÃO EXISTE (para não procurar)

- **Campanha** (D07): 0% implementado. Sem `CampaignManager`, sem schema, sem
  pasta no esqueleto do projeto. O editor de cenas grava um formato simples que o
  jogo não lê.
- **Motor de efeitos** (D30): o dado existe e é validado; a mesa não executa.
- **Distribuição trancada** (D03-D06): 0% implementado. Só existe `.apack`,
  que é aberto.
- **Test Lab** (D12): o que existe é o Campo de Testes (`test_state`).
- `SaveSystem`, `EventBus`, `AudioManager`, `StateInspector`, `TestHarness` e
  `EffectSystem`: **não existem**. O que existe é o GUT.
- `ai_preset` está no contrato e no Studio, e o **runtime não lê**.
