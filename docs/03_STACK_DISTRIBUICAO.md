# 03 — STACK DEV vs PRODUTO

ORIGEM: spec v1.1 seções 0, 3, 72, 73, 74, 75-79

## 3.1 Terminologia oficial

- ASTRALIS: runtime oficial.
- ASTRALIS STUDIO: editor oficial.
- GODOT: engine usada para desenvolver Astralis.
- GODOT MCP: ferramenta de IA para operar Godot durante desenvolvimento.
- GUT: framework de testes durante desenvolvimento.
- OPENCODE: ambiente de dev assistido por IA.

Godot, Godot MCP, GUT, OpenCode NÃO são produtos que o usuário instala.

## 3.2 Dev stack (equipe/IA)

OpenCode, Godot, Godot MCP, GUT, Rust, Tauri, Svelte.

- Godot: só para construir Astralis. Build exportada é o produto. Usuário nunca instala/abre/configura Godot.
- Godot MCP: criar/modificar recursos, debug, automação. Não faz parte do Astralis/Studio, não é requisito do usuário.
- GUT: unit/integration/regression do Astralis. Não é gameplay, não vai no produto final, não tem lógica alternativa.

## 3.3 Product stack (usuário)

Astralis Studio + Astralis + Project Data + Assets. Na distribuição: player por plataforma + `.astralis` (ver `12_DISTRIBUICAO_EXPORTACAO.md`). Equipe exporta players 1 vez via Godot no CI; Studio só copia o player certo, sem Godot no usuário.

## 3.4 Preview architecture

```text
STUDIO -> save project -> Project Data -> launch ASTRALIS -> load project -> run
```

Studio não conhece Godot interno. Conhece: executável Astralis + formato do projeto + protocolo/args de preview.

Comunicação V1 simples: args de inicialização, diretório compartilhado, arquivos temporários de status/resultado. Sem IPC complexo prematuro. Primeiro definir: project contract + command contract + result contract.

## 3.5 Modos do Astralis

Mesmos sistemas de gameplay, muda inicialização/observabilidade/controle:

- GAME: jogar normal, sem ferramentas de teste.
- PREVIEW: autoria, iniciar projeto/cena/duelo/conteúdo selecionado, inspecionar quando suportado.
- TEST: setup + actions + assertions + trace + snapshots + resultado estruturado.
- DEBUG: logs, state, events, timing, AI, diagnostics (dev do Astralis).

[MELHORIA V1.2]: PREVIEW/TEST/DEBUG compartilham o mesmo `launch with context`. Não são 3 binários/motores, são flags do mesmo runtime.
