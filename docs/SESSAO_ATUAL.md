# SESSAO_ATUAL — CADERNO DE BORDO (mutável toda conversa)

> IA: atualize este arquivo NO FIM de toda resposta com mudança. Nunca deixe próximo_passo vazio.

```yaml
onde_estamos: "docs v1.5 + pastas + ferramentas prontos; usuário perguntou se pode começar — plano de largada proposto"
acabamos_de_fazer: "Proposto início em 3 tempos: 1) commit da organização 2) schemas/ V1 + starter kit (systems, sem Godot) 3) projeto Godot astralis/ + GUT + MCP (runtime+qa)"
próximo_passo: "Aguardando ok do usuário para commit; depois schemas/ V1 via systems"
travas_e_dúvidas:
  - "V1: monster[3]+spell[3] fixos, mão 5/7 fixa, sem Extra Deck, sem standby/main2 (R5)"
  - "Nada de código até docs prontos (pedido usuário 2026-09-23)"
  - "Rust/cargo AUSENTE — instalar só quando começar o Studio (rustup.rs)"
  - "MCP: Godot MCP asset 5470 + GUT 1709 travados em D16; instalar só quando começar astralis/; Python 3.14 local já atende (3.11-3.14)"
  - "Godot 4.7.2 exe em Godot/ local, ignorado no git"
  - "Não reabrir D01-D15 sem permissão"
travas_e_dúvidas:
  - "V1: monster[3]+spell[3] fixos, mão 5/7 fixa, sem Extra Deck, sem standby/main2 (R5)"
  - "Nada de código até docs prontos (pedido usuário 2026-09-23)"
  - "Godot 4.7.2 exe em Godot/ local, ignorado no git"
  - "Não reabrir D01-D15 sem permissão; v1.5 é compatível, não quebra travas"
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
