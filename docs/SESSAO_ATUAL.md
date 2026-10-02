# SESSAO_ATUAL — onde estamos (mutável toda conversa)

> Caderno de bordo. **Bloque YAML único, chaves ÚNICAS** — é lido por máquina.
> Nada de ata de sessão aqui dentro: o que foi feito está no `git log`, e o que
> vale continua nos docs (R14). Este arquivo responde a três perguntas e só:
> **onde estamos, o que falta, o que está travado.**

```yaml
onde_estamos: "A carta de duelo é desenhada com `BoxMesh` procedural, medida no
  valor do contrato (59 x 86 x 0,30 mm), e a mesa é a única dona do número
  (D70). A mesa 3D tem 8 arquivos, um assunto cada, e a volta de 180° é da
  câmera, não das cartas. O pipeline de asset 3D saiu do projeto junto com o
  doc 17; a carta de papel continua sendo 2D, desenhada pelo molde em dado.
  Falta a limpeza dos documentos: o 16, o 15, o 13, o 00, o 04, o 05, o 08, o
  09 e o 12 ainda guardam o texto anterior a muitas regras."

faz_agora: "Limpeza dos documentos pela R14. Cada doc fica só com a regra viva,
  e o que é derivável do código passa a ser gerado. Já foram: o
  `docs/DECISOES.md` (91 KB -> 20 KB, as decisões que foram registro de
  substituição saíram inteiras) e o `docs/SESSAO_ATUAL.md` (129 KB -> 4 KB).
  O `tools/checar_docs.py` recusa data, versão, contagem de teste, hash de
  commit, narrativa de mudança, caminho morto e excesso de tamanho. Esta
  passagem é o resto: 16, 15, 13, 00, 12, 10, 09, 08, 07, 06, 05, 04."

proximo_passo: "Escrever o doc 13 e o doc 15 com o que vale hoje: a grade (263
  nas seis direções, 390 congelado), a arena sem fallback (D50), a volta da mesa
  (D47, D51, D52) e a faixa 2D (D45) — sem o 'o que existia' e sem citação do
  usuário. Depois o 00, que ainda tem o changelog de versões, e o 12, que ainda
  tem 86 linhas de distribuição trancada que não existe no código. No fim,
  `python tools/checar_docs.py` tem de dar `rc=0`."

travas: "R1 a R14 valem (seção 2 do AGENTS.md). Trava do domínio: a arena é do
  jogo e não tem fallback (D50); a lente nunca é deslocada e o `frustum_offset`
  é ZERO (D41, D47); a grade é 263 nas seis direções e 390 entre as fileiras de
  monstro (D49); a carta mede o contrato e a mesa é o único dono do número
  (D70); efeito não tem motor na mesa (D30); quem manda é o usuário (R7)."

dividas: "Motor de efeitos (D30) é o buraco de gameplay maior. Distribuição
  `.astralis` trancada é PLANO, 0% implementado. Campanha é PLANO, 0%
  implementado. Save/load, AudioManager e assets reais não existem: as 722
  cartas têm `description` vazio e `artwork` apontando para arquivo inexistente,
  e nenhum dos 39 duelistas tem retrato. Faltam também a cidade de fundo e a
  barra de fases da referência. A mesa não chama o `RuntimeValidator` e ignora
  `load_errors`, então projeto corrompido entra no jogo em silêncio. `ai_preset`
  está no contrato e no Studio, e o runtime não lê. `mesa_3d.gd` tem 3.702
  linhas contra o alvo de 700: a R9 pede a divisão pelo assunto, e ela é o
  resto do trabalho de organização do código."

estado: "GUT tem 183 funções de teste em 20 arquivos de `astralis/testing/`. O
  contrato tem 8 schemas. O dado de exemplo tem 722 cartas, 39 duelistas e 39
  decks. O jogo lê projeto por `--project` e o log de boot é contrato (R11). A
  árvore está limpa no git."

data_utc: "2026-10-01"
```

## O QUE ESTÁ TRAVADO (leia antes de mexer em qualquer coisa)

- **A arena é do jogo.** Zero número de arena no código, sem fallback, sem mesa
  por projeto. Se o arquivo faltar, a mesa **não desenha o campo** e avisa.
- **A lente nunca é deslocada.** `CAM_POS.x = 0` e `frustum_offset = ZERO`.
  Deslocar a lente achata um lado e estica o outro; se parecer torto, muda o
  retângulo do SubViewport, nunca a câmera.
- **As cartas do campo não se mexem.** Quem gira é a câmera, em torno do pivô.
- **A grade é um valor só** (263) nas seis direções, e a distância entre as
  fileiras de monstro é 390 e congelada.
- **A medida da carta é a do contrato** (59 x 86 x 0,30 mm) e a mesa é a única
  dona do número: receptor sem a medida cresce do tamanho zero e grita.
- **O doc é escrito pela IA e lido pela IA.** Mudou, substitui sem explicar
  (R14). `python tools/checar_docs.py` é a trava e diz qual regra quebrou.
