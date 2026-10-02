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

Antes de commitar o que toca `docs/`, rode o portão: `python tools/checar_docs.py`.
É a R14 virando trava (regex contra o disco, sem IA). `rc=1` significa que o doc
guarda data, versão, contagem de teste, hash, narrativa de mudança, caminho que
não existe ou excesso de tamanho. **Corrige o doc, não o portão.**

- R1: Astralis = runtime, única verdade de gameplay. Studio nunca calcula resultado.
- R2: Proibido `FakeDuelEngine/Effect/Fusion/Campaign`. Preview/Test usam Astralis real.
- R3: DATA != LOGIC. Novo conteúdo = dado, não código. Sem script por carta.
- R4: Studio só expõe o que Astralis sabe executar. Feature nova: contrato → Astralis → Studio → testes → docs.
- R5: Não ampliar escopo, não genericizar engine.
- R6: `.astralis` de distribuição é binário trancado (ver doc 12). Nunca exponha JSON de distribuição em texto.
- R7: Não reabra decisão travada em DECISOES.md sem pedir ao usuário.
- R8: Nada solto — arquivo novo nasce na pasta do dono com nome claro;
  teste descartável vive e morre na mesma sessão (cria, mostra, apaga);
  sem `.tmp`/`.log`/pasta velha no repo; `git status` limpo todo fim.
- R9: Um `.gd` = um assunto, e a divisão é pelo assunto (nunca pela contagem,
  nunca arquivo minusculo só para existir).
- R10: Comentário = o que é, quem é o dono do número, a invariante e o porquê
  quando não for óbvio. Sem história, sem citação do usuário, sem número de
  decisão (que já está em DECISOES.md).
- R11: O log de BOOT do jogo é contrato (o `test_project_arg` lê). Diagnóstico
  só com `-- --debug`.
- R12: **Regra das ferramentas:** em qualquer programa, a ordem é
  **documentação → ferramenta nativa → pesquisa na internet → manual, só em
  último caso.**
  1. **Documentação, antes de fazer o que não se sabe ou não se tem certeza:**
     o `docs/17_BLENDER.md` e o manual do programa (a cópia local quando
     existe, ver `blender_manual_v520_en.html/`). Consultar antes é o caminho
     curto; consultar depois de errar é registro de erro.
  2. **Ferramenta nativa** — o que o programa já tem. O Blender tem bevel,
     subdiv, remesh, snap e Geometry Nodes, e ele **gera a topologia por
     você**. Antes de reconstruir geometria à mão, pergunte "o programa já faz
     isso?".
  3. **Pesquisa na internet** — quando não se sabe qual ferramenta existe ou
     como se usa.
  4. **Manual, só em último caso** — só para o que a ferramenta realmente não
     faz, e com a topologia medida antes de gravar.
  Vale para qualquer programa, não só Blender.
- R13: Antes de anexar uma decisão `Dnn` em DECISOES.md, olhe a MAIOR que já
  existe lá e use a seguinte. Ela entra no corpo **e** no índice do fim do
  arquivo.
- R14: **COMO SE ESCREVE DOCUMENTO.** Vale para `docs/` e para comentário de
  código. O projeto é lido e escrito por IA; doc não é para humano ler.

  **D1 — MUDOU, SUBSTITUI.** Se algo já está no doc e mudou, **apague o texto
  antigo e escreva o novo no lugar.** Não guarde o antes, não registre a
  mudança, não escreva "antes era", "agora é", "passou a", "virou", "mudou
  de", "saiu no Dnn". Se mudou, é porque o usuário mandou. Ponto final.

  **D2 — NOVO, ESCREVE.** Se nunca esteve no doc, escreve novo.

  **D3 — POR QUÊ SIM, MUDANÇA NÃO.** O motivo de uma regra é atemporal e se
  escreve: "X é Y porque Z, senão W". O que não se escreve é a transição
  entre um estado e outro. Mesmo fato, duas formas:
  - **fica** — "A lente nunca é deslocada (`frustum_offset` = ZERO, x = 0):
    deslocar achata um lado e estica o outro. Se parecer torto, muda o
    retângulo do SubViewport."
  - **sai** — "Antes a solução movia a lente (CAM_OFFSET_X = 0,16) e deformava
    o lado direito; agora a câmera está no eixo."

  **NUNCA entra em doc:** data, número de versão, changelog, citação do
  usuário, hash de commit, contagem de teste ("183 testes"), "estado em
  2026-09-28", o que se perdeu, o que foi tentado antes. Tudo isso está no
  `git log`, e o `git log` é o histórico.

  **SEMPRE entra:** a regra como ela é, o número com o dono do número, o
  caminho do dado, o motivo (D3), e o que não pode ser feito.

  **Decisão que ficou sem valor sai do `DECISOES.md` inteiro** — não vira
  linha de "supersedida". Se a regra nova substitui a antiga, a nova é que
  fica. Número reservado marca buraco, como a D13 e a D46.
- R15: **Modelagem 3D é na frente da pessoa, nunca headless.** Onde o
  trabalho é num programa com janela (Blender), abra o programa e faça nele, e
  mostre o estado a cada passo. Headless é para o que não tem tela (o jogo pelo
  GUT), não para o que a pessoa precisa ver. Motivo: o dono do asset precisa
  aprovar a forma, e uma captura de tela tirada do batch é tarde demais para
  barrar um erro de escala. Procedimento em `docs/17_BLENDER.md`.
- R16: **Malha que vai para o jogo: triângulo e quad entram, n-gon não.** Toda
  face tem 3 ou 4 lados, e o total de faces é **medido** antes de exportar — o
  custo sai da topologia (`triângulos = 16 × segmentos + 12` numa peça
  arredondada), então o segmento do arco é o único botão e se escolhe sabendo o
  que custa. Medição, conta e receita em `docs/17_BLENDER.md` §17.5.

## 3. DONOS POR PASTA (respeite)

- `docs/ + arquitetura/` → Lead Architect
- `astralis/` (Godot) → Runtime Engineer
- `schemas/ data-model/` → Systems/Data Engineer
- `campaign/` → Campaign Engineer
- `astralis-studio/` (Rust/Tauri/Svelte) → Editor Engineer
- `tests/ tools/ ci/` → QA/Integration

Mudança compartilhada (schema, protocolo, formato .astralis) exige atualizar MANIFEST + doc dono + SESSAO.

## 3.1 MAPA (organização)

- `astralis/duel|core|ui|campaign|debug` runtime; `astralis/testing` qa;
  `schemas/` systems; `tools/ ci/ tests/` qa; `docs/` lead.
- R8, R9 e R10 acima valem para tudo, sem exceção.

## 4. PROTOCOLO DE SESSÃO (anti-perda de contexto)

- INÍCIO: já fez bootstrap acima. Confirme em 1 linha: `Retomando de: <onde_estamos> → <próximo_passo>`.
- DURANTE: trabalhe em passos pequenos. Prefira 1 doc por vez.
- FIM (obrigatório): atualize `docs/SESSAO_ATUAL.md` com:
  ```text
  onde_estamos / acabamos_de_fazer / próximo_passo / travas / data_utc
  ```
  Nunca termine sem atualizar. Nunca deixe próximo_passo vazio.
- FIM (obrigatório): commit + push (R10) — confira `git status`, `git diff`, commite por área, `git push`.
- Decisão nova do usuário → anexe em `docs/DECISOES.md` como `Dnn: <decisão> | motivo | impacto`.

## 5. FORMATO DE RESPOSTA PARA HUMANO

- Curto, PT-BR simples, sem jargão. Usuário não é Godot-dev.
- Liste arquivos criados/editados com caminho exato.
- Termine com: `Próximo: <1 frase>` igual ao que gravou em SESSAO_ATUAL.
