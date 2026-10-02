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
  commit, narrativa de mudança, caminho morto e excesso de tamanho. A regra das
  ferramentas é a R12: documentação (o doc 17 e a cópia local do manual) ANTES de
  fazer o que não se sabe, depois nativa, internet, e manual só em último caso
  (D71). O manual do Blender é uma pasta na máquina, fora do git, com um README
  dentro que diz de onde veio e como se busca dentro dela."

faz_agora: "A R12 mudou: agora a DOCUMENTAÇÃO vem antes da ferramenta nativa, e o passo 1 é o `docs/17_BLENDER.md` mais a cópia local do manual do Blender. A carta de duelo 3D esta no JOGO: o corpo e o artefato `astralis/assets/3d/carta_de_duelo.glb`, publicado em `assets/3d/` com a fonte ao lado, com a fonte em `assets/3d/fonte/` e o publicador em `tools/blender/exportar_carta.py`, que roda o portao da R16 antes de exportar e confere o `.glb` depois. Medido no arquivo: centro (0,0,0), tamanho 1,0 x 1,457627 x 0,005085 — os numeros da mesa, 104 faces (36 quads, 68 triangulos), 0 n-gon, malha fechada. A R16 entrou: tri e quad entram, n-gon nao, e a face e medida antes de exportar. O Bevel entregava a tampa como uma face de 36 lados; agora so ela e triangular, e a conta `triangulos = 16 x segmentos + 12` diz o que cada segmento custa. A arte continua vindo do jogo em `QuadMesh` texturizados colados no corpo, entao o modelo nao leva UV de textura (a `UVMap` que ele tem e a projecao padrao do cubo, e o material do corpo e cor solida). O que falta: as posicoes das imagens ainda sao literais no `.gd` e nao vem do `card_layout`, que e o que da a opcao de editor para mexer na arte. O procedimento esta em `docs/17_BLENDER.md` e cresce a cada modelo (D72)."


proximo_passo: "Fazer `carta_3d.gd` ler o `card_layout` em vez dos literais: orbe em (0,3805, 0,6173), estrela com passo 0,0537, nome em (-0,43, 0,6434) e ATK/DEF em (0, -0,48) estao escritos no `.gd`, e o molde em por-mil que existe para isto so alimenta o `CardView` 2D. E o que da a opcao de editor para mover a foto do monstro ou as estrelas."


travas: "R1 a R14 valem (seção 2 do AGENTS.md). Trava do domínio: a arena é do
  jogo e não tem fallback (D50); a lente nunca é deslocada e o `frustum_offset`
  é ZERO (D41, D47); a grade é 263 nas seis direções e 390 entre as fileiras de
  monstro (D49); a carta mede o contrato e a mesa é o único dono do número
  (D70); efeito não tem motor na mesa (D30); quem manda é o usuário; a mesa nasce na vista de quem tem a vez (D47); modelar 3D e na frente da pessoa, nunca headless (D72/R15); consultar a documentação antes do que nao se sabe, e a nativa gera a topologia (D71/R12); tri e quad entram, n-gon nao, e a face e medida (D73/R16)."

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

data_utc: "2026-10-02"
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
