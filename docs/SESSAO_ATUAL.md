# SESSAO_ATUAL — CADERNO DE BORDO (mutável toda conversa)

> IA: atualize este arquivo NO FIM de toda resposta com mudança. Nunca deixe próximo_passo vazio.

```yaml
onde_estamos: "astralis/ Godot 4.7 rodando: loader+validador, GUT 3/3 verde, addons GUT+MCP instalados"
acabamos_de_fazer: "Runtime criou projeto + DataLoader + validador PT-BR + main (headless STP 10/2/2 erros=0); QA instalou GUT 9.7.1 e teste real 3/3 passou (13 asserts); lead instalou MCP addon (godot_ai+godot_omni) e corrigiu .gitignore (*.gd.uid)"
próximo_passo: "Duelo núcleo: TurnManager + invocação/batalha/dano + vitória/derrota (runtime) com teste GUT (qa)"
travas_e_dúvidas:
  - "V1: monster[3]+spell[3] fixos, mão 5/7 fixa, sem Extra Deck, sem standby/main2 (R5)"
  - "Código liberado pelo usuário em 2026-09-23 (dados primeiro, motor depois)"
  - "Rust/cargo AUSENTE — só quando começar o Studio"
  - "GUT 9.7.1 (era 9.6.1 no D16, subido p/ Godot 4.7); MCP addon instalado, plugins se ligam no editor"
  - "Godot 4.7.2 exe em Godot/ local, ignorado no git"
  - "Não reabrir D01-D16 sem permissão"
data_utc: "2026-09-23"
versão_docs: "1.5"
```

## Log curto (últimas 5)

- 2026-09-23: split monolito em docs/00-11 + melhorias v1.2 (flags-lite, battle win/lose, fusão regra, AI preset, templates, starter kit, preview unificado, test lab mínimo)
- 2026-09-23: criado 12 exportação protegida + cadeado por jogo + bundles por plataforma
- 2026-09-23: criado sistema anti-perda de contexto (AGENTS, SESSAO, DECISOES, MANIFEST)
- 2026-09-23: repo GitHub criado e push main (fcea17c) em https://github.com/joeyviciousfake-netizen/Astralis
- 2026-09-23: apagado Documentação.md legado (D14), fonte oficial = docs/00-12
- 2026-09-23: travado D15 (6 agentes) + limites de split em 11_ROADMAP_AGENTES
- 2026-09-23: criados .opencode/agents/lead+runtime+systems+campaign+editor+qa
- 2026-09-23: criado 13_TABULEIRO_DUELO.md V1 (zonas 3+3, DRAW/MAIN/BATTLE/END, mão 5/7, LP dado, win LP+deckout) via runtime+systems, bump docs v1.4
- 2026-09-23: criado projeto Godot astralis/ etapa 1 (loader+validador, STP 10/2/2 erros=0 no headless 4.7.2)
- 2026-09-23: GUT 9.7.1 instalado + teste real 3/3 verde (13 asserts) + MCP addon (godot_ai+godot_omni) + .gitignore *.gd.uid
