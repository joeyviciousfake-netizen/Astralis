# SESSAO_ATUAL — CADERNO DE BORDO (mutável toda conversa)

> IA: atualize este arquivo NO FIM de toda resposta com mudança. Nunca deixe próximo_passo vazio.

```yaml
onde_estamos: "schemas/ V1 + Starter Kit criados, validados pelo lead e commitados; docs v1.5 prontos"
acabamos_de_fazer: "Systems criou 6 schemas + examples/ (10 cards, 2 duelists, 2 decks 20 cartas, fusions 2+1, effects 2, duel_setup 4000LP); lead verificou refs/LP/sem-código/schema_version (0 erros); corrigido travas duplicadas; commit"
próximo_passo: "Projeto Godot astralis/ + GUT + MCP addon (runtime+qa)"
travas_e_dúvidas:
  - "V1: monster[3]+spell[3] fixos, mão 5/7 fixa, sem Extra Deck, sem standby/main2 (R5)"
  - "Código liberado pelo usuário em 2026-09-23 (fase dados primeiro: schemas antes do motor)"
  - "Rust/cargo AUSENTE — instalar só quando começar o Studio (rustup.rs)"
  - "MCP: Godot MCP asset 5470 + GUT 1709 travados em D16; instalar ao criar astralis/; Python 3.14 já atende"
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
