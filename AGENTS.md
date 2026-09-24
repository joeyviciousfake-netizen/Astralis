# AGENTS.md — PROTOCOLO OBRIGATÓRIO PARA IA

> Este arquivo é a única entrada. Humano não programa. Só IA lê e implementa.
> Siga exatamente. Não improvise processo.

## 1. BOOTSTRAP (toda nova conversa, nesta ordem)

1. Leia `docs/AI_MANIFEST.json` (mapa máquina, 1 min).
2. Leia `docs/00_INDICE_GERAL.md` (visão + changelog).
3. Leia `docs/SESSAO_ATUAL.md` (onde paramos + próximo passo).
4. Leia `docs/DECISOES.md` (o que é travado, não reabra sem permissão).
5. Só então leia o doc de domínio necessário (05, 06, 07...). Não leia tudo de uma vez.

Se o usuário disser só "continue", retome de `SESSAO_ATUAL.próximo_passo`.

## 2. REGRAS DURAS (nunca violar)

- R1: Astralis = runtime, única verdade de gameplay. Studio nunca calcula resultado.
- R2: Proibido `FakeDuelEngine/Effect/Fusion/Campaign`. Preview/Test usam Astralis real.
- R3: DATA != LOGIC. Novo conteúdo = dado, não código. Sem script por carta.
- R4: Studio só expõe o que Astralis sabe executar. Feature nova: contrato → Astralis → Studio → testes → docs.
- R5: Não ampliar escopo, não genericizar engine, não criar micro-agentes.
- R6: `.astralis` de distribuição é binário trancado (ver doc 12). Nunca exponha JSON de distribuição em texto.
- R7: Não reabra decisão travada em DECISOES.md sem pedir ao usuário.

## 3. DONOS POR PASTA (respeite)

- `docs/ + arquitetura/` → Lead Architect
- `astralis/` (Godot) → Runtime Engineer
- `schemas/ data-model/` → Systems/Data Engineer
- `campaign/` → Campaign Engineer
- `astralis-studio/` (Rust/Tauri/Svelte) → Editor Engineer
- `tests/ tools/ ci/` → QA/Integration

Mudança compartilhada (schema, protocolo, formato .astralis) exige atualizar MANIFEST + doc dono + SESSAO.

## 3.1 MAPA + R8 (organização, regra dura)

- `astralis/duel|core|ui|campaign|debug` runtime; `astralis/testing` qa;
  `schemas/` systems; `tools/ ci/ tests/` qa; `docs/` lead.
- R8: nada solto — arquivo novo nasce na pasta do dono com nome claro;
  teste descartável vive e morre na mesma sessão (cria, mostra, apaga);
  sem `.tmp`/`.log`/pasta velha no repo; `git status` limpo todo fim.
- R9: commit + push no fim de toda tarefa (ordem do usuário). Nunca acumule trabalho sem commitar.

## 4. PROTOCOLO DE SESSÃO (anti-perda de contexto)

- INÍCIO: já fez bootstrap acima. Confirme em 1 linha: `Retomando de: <onde_estamos> → <próximo_passo>`.
- DURANTE: trabalhe em passos pequenos. Prefira 1 doc por vez.
- FIM (obrigatório): atualize `docs/SESSAO_ATUAL.md` com:
  ```text
  onde_estamos / acabamos_de_fazer / próximo_passo / travas / data_utc
  ```
  Nunca termine sem atualizar. Nunca deixe próximo_passo vazio.
- FIM (obrigatório): commit + push (R9) — confira `git status`, `git diff`, commite por área, `git push`.
- Decisão nova do usuário → anexe em `docs/DECISOES.md` como `Dnn: <decisão> | motivo | impacto | data`.

## 5. FORMATO DE RESPOSTA PARA HUMANO

- Curto, PT-BR simples, sem jargão. Usuário não é Godot-dev.
- Liste arquivos criados/editados com caminho exato.
- Termine com: `Próximo: <1 frase>` igual ao que gravou em SESSAO_ATUAL.
