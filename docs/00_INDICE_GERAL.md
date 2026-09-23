# ASTRALIS — ÍNDICE GERAL

VERSION: 1.3
STATUS: AUTHORITATIVE (split de `Documentação.md` v1.1 + decisões v1.2/v1.3)
AUDIENCE: AI AGENTS
LANGUAGE: PT-BR

Este índice substitui o documento único. Cada arquivo abaixo é autoritativo no seu domínio. Em caso de conflito, vale este índice + `02_PRINCIPIOS_ARQUITETURAIS.md`.

> IA: entrada oficial é `../AGENTS.md`. Ordem obrigatória: `AI_MANIFEST.json` → este índice → `SESSAO_ATUAL.md` → `DECISOES.md` → doc de domínio. SPEC (00-12) é estável; OPS (SESSAO/DECISOES) muda toda conversa.

## Mapa estratégico

```text
docs/
  00_INDICE_GERAL.md          <- você está aqui, Lead Architect
  01_VISAO_PRODUTO.md         <- identidade, modelo, experiência, sucesso
  02_PRINCIPIOS_ARQUITETURAIS.md <- DATA!=LOGIC, sem motor paralelo, fontes da verdade
  03_STACK_DISTRIBUICAO.md     <- dev stack vs product stack, modos GAME/PREVIEW/TEST/DEBUG
  04_CONTRATO_DADOS.md         <- project data, schemas, versionamento, IDs
  05_RUNTIME_DUELO.md          <- duel, duelist + AI presets [NOVO], deck, card
  06_SISTEMA_FUSAO.md          <- receitas + regras com prioridade [NOVO]
  07_SISTEMA_EFEITOS.md        <- triggers/conditions/targets/actions/flow + templates [NOVO]
  08_CAMPANHA.md               <- grafo, scene, timeline, battle win/lose [NOVO], flags-lite [NOVO]
  09_STUDIO_EDITOR.md          <- editores, UX, starter kit [NOVO], wizard
  10_PREVIEW_TESTE_DEBUG.md    <- preview unificado [NOVO], test lab mínimo [NOVO], GUT, determinismo
  11_ROADMAP_AGENTES.md        <- MVP, roadmap, agentes, workflow
  12_DISTRIBUICAO_EXPORTACAO.md <- fita .astralis + cadeado + bundles win/linux/android [NOVO v1.3]
  AI_MANIFEST.json          <- mapa máquina (owner, depends, read_order)
  SESSAO_ATUAL.md           <- OPS mutável: onde paramos + próximo passo (ler sempre)
  DECISOES.md               <- OPS append-only: travas D01-D13, não reabrir
```

## O que mudou na v1.2 (suas sugestões aplicadas)

1. **Flags-lite V1** (`08_CAMPANHA.md`): `flags booleanas + counters` setadas em vitória/derrota/escolha. Sem linguagem geral. Permite finais múltiplos, revanche, desbloqueio.
2. **Battle Node com `on_win / on_lose / retry`** (`08_CAMPANHA.md`): obrigatório na V1. Sem isso campanha trava.
3. **Fusão receita + regra** (`06_SISTEMA_FUSAO.md`): receita explícita `A+B=C` tem prioridade; regra genérica `tipo+atributo->resultado` como fallback. Continua data-driven, reduz 90% do cadastro.
4. **AI por preset** (`05_RUNTIME_DUELO.md`): mesma base de IA, parâmetros por duelista: `agressividade, uso_fusao, protecao_lp, dificuldade`. Sem custom scripting na V1.
5. **Effect Templates** (`07_SISTEMA_EFEITOS.md`): Modo Simples (modelos prontos) + Modo Avançado (blocos). Mesmo motor, mesma validação.
6. **Starter Kit jogável** (`09_STUDIO_EDITOR.md`): 10 cartas, 2 duelistas, 1 duelo, 1 cena. Duplicar e editar.
7. **Preview unificado "Jogar a partir daqui"** (`10_PREVIEW_TESTE_DEBUG.md`): um único mecanismo `launch Astralis with context {project, scene_id?, duel_setup?, seed?}`. Scene/Duel/Effect/Fusion Preview viram contextos, não 4 features separadas.
8. **Test Lab mínimo junto do Effect Builder** (`10_PREVIEW_TESTE_DEBUG.md`): botão `Testar agora` com setup auto-sugerido + expected vs actual. UI completa depois.
9. **Escopo V1 enxuto**: adiados `State Diff completo, Trace rico, Breakpoints, Recording, Debug Console completo`. V1 mantém: `Play Project + Validação humana + State Inspector simples`.
10. **Exportação protegida v1.3** (`12_DISTRIBUICAO_EXPORTACAO.md`): pasta JSON de trabalho vs `.astralis` binário de distribuição; cadeado por jogo gerado no Exportar com chave embutida no player; bundles `exe + .astralis` (win/linux) e `apk + .astralis` com importação (android V1, fundido só V2); versionamento vai junto e acaba mismatch.

## Regras que NÃO mudaram

- Astralis = runtime, única fonte da verdade de gameplay.
- Astralis Studio = editor, nunca implementa gameplay, nunca calcula resultado.
- Preview e Test Lab usam o mesmo código do Astralis. Proibido `FakeDuelEngine`.
- `Documentação.md` v1.1 original mantida como legado. Se divergir, valem os `docs/`.
