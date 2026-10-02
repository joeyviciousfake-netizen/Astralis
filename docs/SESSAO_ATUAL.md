# SESSAO_ATUAL — onde estamos (mutável toda conversa)

> Caderno de bordo. **Bloque YAML único, chaves ÚNICAS** — é lido por máquina.
> Nada de ata de sessão aqui dentro: o que foi feito está no `git log`, e o que
> vale continua nos docs (R14). Este arquivo responde a três perguntas e só:
> **onde estamos, o que falta, o que está travado.**

```yaml
onde_estamos: "A carta de duelo 3D existe como asset na medida real do contrato
  (59 x 86 x 0,30 mm), com os 4 cantos em arco de 2 mm, e o portão do exportador
  mediu que a caixa dela é IDÊNTICA ao `BoxMesh` que a mesa monta hoje — a
  integração futura é trocar a malha, sem mexer em posição. A mesa 3D tem 8
  arquivos, um assunto cada, e a volta de 180° é da câmera (não das cartas). O
  pipeline de asset é o `.blend` fonte -> `.glb` artefato -> `manifest.json`
  como fonte única dos números, medido por dois lados independentes. Falta a
  limpeza dos documentos: o 16, o 15, o 13, o 00, o 04, o 05, o 08, o 09 e o
  12 ainda guardam o texto anterior a muitas regras."

faz_agora: "Limpeza dos documentos. O alvo é que a IA leia o mínimo e acerte:
  cada doc fica só com a regra viva, e o que é derivável do código passa a ser
  gerado. O `docs/DECISOES.md` já foi refeito por essa regra (91 KB -> 20 KB) e
  o `tools/checar_docs.py` já recusa data, versão, contagem de teste, hash de
  commit, narrativa de mudança, caminho morto e excesso de tamanho. Esta
  passagem é o resto: 16, 15, 13, 00, 17, 12, 10, 09, 08, 07, 06, 05, 04."

proximo_passo: "Escrever o doc 13 e o doc 15 com o que vale hoje: a grade
  (263 nas seis direções, 390 congelado), a arena sem fallback (D50), a volta da
  mesa (D47/D51/D52) e a faixa 2D (D45) — sem o 'o que existia' e sem a
  citação do usuário. Depois o 00, que ainda tem o changelog de 17 versões, e o
  17, que ainda tem a tabela das 6 construções de malha recusadas. No fim,
  `python tools/checar_docs.py` tem de dar `rc=0`."

travas: "R1 a R14 valem (seção 2 do AGENTS.md). Trava do domínio: a arena é do
  jogo e não tem fallback (D50); a câmera nunca se desloca e o `frustum_offset`
  é ZERO (D41); a lente nunca é deslocada (D47); a grade é 263 nas seis
  direções e 390 entre as fileiras de monstro (D49); a carta mede o contrato e
  a mesa é o único dono do número (D70); efeito não tem motor na mesa (D30);
  a malha da fonte é quad (D69); quem manda é o usuário (R7)."

dividas: "Motor de efeitos (D30) é o buraco de gameplay maior. Distribuição
  `.astralis` trancada é PLANO, 0% implementado. Campanha é PLANO, 0%
  implementado. Save/load, AudioManager e assets reais (as 722 cartas têm
  `description` vazio e `artwork` apontando para arquivo inexistente) não
  existem. Faltam os retratos dos 39 duelistas, as 722 descrições e a cidade de
  fundo. A mesa não chama o `RuntimeValidator` e ignora `load_errors`, então
  projeto corrompido entra em silêncio. `ai_preset` está no contrato e no
  Studio, e o runtime não lê. `mesa_3d.gd` tem 3.702 linhas contra o alvo de
  700 — a R9 pede a divisão pelo assunto, e ela é o resto do trabalho de
  organização do código."

estado: "GUT tem 183 funções de teste em 21 arquivos de `astralis/testing/`.
  O contrato tem 8 schemas. O dado de exemplo tem 722 cartas, 39 duelistas e 39
  decks. O `manifest.json` tem 2 assets 3D (`estrela_teste`, `carta_base`). O
  jogo lê projeto por `--project` e o log de boot é contrato (R11). A árvore
  está limpa no git."

data_utc: "2026-10-01"
```

## O QUE ESTÁ TRAVADO (leia antes de mexer em qualquer coisa)

- **A arena é do jogo.** Zero número de arena no código, sem fallback, sem mesa
  por projeto. Se o arquivo faltar, a mesa **não desenha o campo** e avisa.
- **A lente nunca é deslocada.** `CAM_POS.x = 0` e `frustum_offset = ZERO`.
  Deslocar a lente achata um lado e estica o outro; se parecer torto, muda o
  retângulo do SubViewport.
- **As cartas do campo não se mexem.** Quem gira é a câmera, em torno do pivô.
- **A grade é um valor só** (263) nas seis direções, e a distância entre as
  fileiras de monstro é 390 e congelada.
- **A medida da carta é a do contrato** (59 x 86 x 0,30 mm) e a mesa é o único
  dono do número: receptor sem a medida deve crescer do tamanho zero e gritar.
- **O doc é escrito pela IA** e lido pela IA. Mudou, substitui sem explicar
  (R14). O `python tools/checar_docs.py` é a trava e diz qual regra quebrou.
