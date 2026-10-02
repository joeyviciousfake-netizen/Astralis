# SESSAO_ATUAL — onde estamos (mutável toda conversa)

> Caderno de bordo. **Bloque YAML único, chaves ÚNICAS** — é lido por máquina.
> Nada de ata de sessão aqui dentro: o que foi feito está no `git log`, e o que
> vale continua nos docs (R14). Este arquivo responde a três perguntas e só:
> **onde estamos, o que falta, o que está travado.**

```yaml
onde_estamos: "A carta de duelo é desenhada com `BoxMesh` procedural, medida no
  valor do contrato (59 x 86 x 0,30 mm), e a mesa é a única dona do número
  (D70). A mesa 3D tem 8 arquivos, um assunto cada, e a volta de 180° é da
  câmera, não das cartas. A carta de papel é 2D, desenhada pelo molde em dado.
  Cada doc tem só a regra viva, e o que é derivável do código é gerado:
  `python tools/checar_docs.py` recusa data, versão, contagem de teste, hash de
  commit, narrativa de mudança, caminho morto e excesso de tamanho."

faz_agora: "A carta de duelo 3D esta criada no Blender, na frente da pessoa, com 59 x 86 x 0,30 mm medidos e as 4 pontas arredondadas em raio de 2,0000 mm. Falta decidir ONDE salvar o `.blend` e COMO o jogo vai pegar o modelo quando a pessoa mandar colocar: o jogo hoje monta a carta com `BoxMesh` + dois `QuadMesh` texturizados, entao ainda nao ha mapa de textura no modelo. O procedimento esta em `docs/17_BLENDER.md` e cresce a cada modelo (D72)."


proximo_passo: "Escolher com a pessoa ONDE o `.blend` da carta mora no repo (a pasta `assets/3d/` antiga foi removida e nao ha caminho novo definido), e se o modelo entra no jogo com MAPA DE TEXTURA ou se o jogo continua montando a carta com primitivas. So depois disso o modelo vai para o jogo, e so quando a pessoa disser que esta bom."


travas: "R1 a R14 valem (seção 2 do AGENTS.md). Trava do domínio: a arena é do
  jogo e não tem fallback (D50); a lente nunca é deslocada e o `frustum_offset`
  é ZERO (D41, D47); a grade é 263 nas seis direções e 390 entre as fileiras de
  monstro (D49); a carta mede o contrato e a mesa é o único dono do número
  (D70); efeito não tem motor na mesa (D30); quem manda é o usuário; a mesa nasce na vista de quem tem a vez (D47); modelar 3D e na frente da pessoa, nunca headless (D72/R15)."

dividas: "Motor de efeitos (D30) é o buraco de gameplay maior. Distribuição
  `.astralis` trancada é PLANO, 0% implementado. Campanha é PLANO, 0%
  implementado. Save/load, AudioManager e assets reais não existem: as 722
  cartas têm `description` vazio e `artwork` apontando para arquivo inexistente,
  e nenhum dos 39 duelistas tem retrato. Faltam também a cidade de fundo e a
  barra de fases da referência. A mesa não chama o `RuntimeValidator` e ignora
  `load_errors`, então projeto corrompido entra no jogo em silêncio. `ai_preset`
  está no contrato e no Studio, e o runtime não lê. A `mesa_3d.gd` ainda
  carrega assunto demais: a R9 pede a divisão pelo assunto, e ela é o resto do
  trabalho de organização do código."

estado: "O contrato tem 8 schemas. O dado de exemplo tem 722 cartas, 39
  duelistas e 39 decks. A suíte GUT está em `astralis/testing/` e passa inteira
  (rode `Godot --headless --path astralis -s
  res://addons/gut/gut_cmdln.gd -gdir=res://testing -gexit`; a contagem exata
  não é escrita aqui porque envelhece — o número sai do comando). O jogo lê
  projeto por `--project` e o log de boot é contrato (R11). Nenhuma linha de
  código mudou nesta leva: só documento."

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
