# SESSAO_ATUAL — onde estamos (mutável toda conversa)

> Caderno de bordo. **Bloque YAML único, chaves ÚNICAS** — é lido por máquina.
> Nada de ata de sessão aqui dentro: o que foi feito está no `git log`, e o que
> vale continua nos docs (R14). Este arquivo responde a três perguntas e só:
> **onde estamos, o que falta, o que está travado.**

```yaml
onde_estamos: "A mesa 3D tem 11 arquivos, um assunto cada. O DUELO DE MOEDA e um
  fluxo so: a distribuicao inicial usa a animacao da compra (as 5 cartas de cada
  lado, uma por uma) e so depois a moeda entra na frente da camera. A moeda e IRMA
  do pivo, cresce no lugar com um clarao, tomba em torno do eixo vertical da tela e
  para na face: estrela = jogador, losango = rival, e nao ha nome escrito. Ela
  COMECA sempre na estrela e o rival ganha meia volta a mais, feita no instante de
  maior velocidade, entao os dois veem a mesma velocidade no primeiro instante e so
  terminam diferentes. A tela NAO vira: perspectiva, cartas e painel ficam a coluna
  inteira, e quem gira a mesa depois da resposta e a mesma `_girar_campo` de toda
  volta. Nao existe pulo nem tempo curto. A ESPERA (D80) e uma coisa so, e a MESA
  que diz que ela existe: existe moeda na tela quando o DADO do duelo e
  `turn_order: \"moeda\"`, e e dessa resposta que vem o painel em branco (sem carta
  e sem verso), a navegacao travada (teclado e analogico) e o `?` ambar no roxo. A
  janela cobre a distribuicao E a moeda, e acaba com a resposta. Sem moeda no dado
  nao ha espera: nao ha o que esconder, e o painel responde desde o primeiro quadro.
  O tamanho e a altura da moeda sao FRACOES da tela e nao unidades de mundo,
  porque a camera e de perspectiva (FOV 20). Cada doc tem so a regra viva, e o que e
  derivavel do codigo e gerado: `python tools/checar_docs.py` recusa data, versao,
  contagem de teste, hash, narrativa de mudanca, caminho morto e excesso de
  tamanho. A regra das ferramentas e a R12: documentacao (o doc 17 e a copia local
  do manual) ANTES de fazer o que nao se sabe, depois nativa, internet, e manual so
  em ultimo caso (D71)."

 faz_agora: "O rival mostra a carta virada no palco (sem nome, sem menu),
  sobe ao topo e desce virada com estrela aleatoria; virada nao ataca (regra
  do sistema). O GUT passa inteiro."

  proximo_passo: "Fazer `carta_3d.gd` ler o `card_layout` em vez dos literais
  (orbe, estrela, nome, ATK/DEF estao no `.gd`, e o molde em por-mil so alimenta o
  `CardView` 2D)."
 travas: "R1 a R14 valem (seção 2 do AGENTS.md). Trava do domínio: a arena é do
   jogo e não tem fallback (D50); a lente nunca é deslocada e o `frustum_offset`
    é ZERO (D41, D47); a grade é 237 nas seis direções e 390 entre as fileiras de
   monstro (D49); a carta mede o contrato e a mesa é o único dono do número
   (D70); a carta do painel é a peça 3D e a janela dela é reta, com mundo próprio
   (D75); a entrada da mão é só da carta comprada, e a compra só é mostrada na
   tela de quem comprou, depois que a câmera parou nela (D76); a espera da moeda é
   uma coisa só e a mesa que diz que ela existe — sem `turn_order: "moeda"` no dado
   não há espera, e teste não liga a espera na mão para provocá-la (D80); efeito não tem motor na mesa (D30); quem manda é o usuário; a mesa nasce na vista de quem tem a vez (D47); modelar 3D e na frente da pessoa, nunca headless (D72/R15); o canto da face e' o canto do corpo, medido e conferido (D70); documentacao antes do codigo e o motor arbitra a versao (D74/R17); consultar a documentação antes do que nao se sabe, e a nativa gera a topologia (D71/R12); tri e quad entram, n-gon nao, e a face e medida (D73/R16)."

 dividas: "Motor de efeitos (D30) é o buraco de gameplay maior. Distribuição
   `.astralis` trancada é PLANO, 0% implementado. Campanha é PLANO, 0%
   implementado. Save/load, AudioManager e assets reais não existem: as 722
   cartas têm `description` vazio e `artwork` apontando para arquivo inexistente,
   e nenhum dos 39 duelistas tem retrato. Faltam também a cidade de fundo e a
   barra de fases da referência. A mesa não chama o `RuntimeValidator` e ignora
   `load_errors`, então projeto corrompido entra no jogo em silêncio. `ai_preset`
   está no contrato e no Studio, e o runtime não lê. A `mesa_3d.gd` ainda
   carrega assunto demais: a R9 pede a divisão pelo assunto, e ela é o resto do
   trabalho de organização do código. A janela 3D do painel é um `SubViewport`
   com `UPDATE_ALWAYS`: ela redesenha todo quadro mesmo sem carta focada, e o
   jeito de só atualizar quando a carta troca ainda não foi medido."

 estado: "O contrato tem 8 schemas. O dado de exemplo tem 722 cartas, 39
   duelistas e 39 decks. A suíte GUT está em `astralis/testing/` e passa inteira
   (rode `Godot --headless --path astralis -s
   res://addons/gut/gut_cmdln.gd -gdir=res://testing -gexit`; a contagem exata
   não é escrita aqui porque envelhece — o número sai do comando). O jogo lê
   projeto por `--project` e o log de boot é contrato (R11). O painel esquerdo é
   a única tela do duelo, e a carta dele é a peça 3D: `--mesa3d-foto=<arquivo>`
   tira a prova na tela."

  data_utc: "2026-10-04"

```

## O QUE ESTÁ TRAVADO (leia antes de mexer em qualquer coisa)

- **A arena é do jogo.** Zero número de arena no código, sem fallback, sem mesa
  por projeto. Se o arquivo faltar, a mesa **não desenha o campo** e avisa.
- **A lente nunca é deslocada.** `CAM_POS.x = 0` e `frustum_offset = ZERO`.
  Deslocar a lente achata um lado e estica o outro; se parecer torto, muda o
  retângulo do SubViewport, nunca a câmera.
- **As cartas do campo não se mexem.** Quem gira é a câmera, em torno do pivô.
- **A grade é um valor só** (237) nas seis direções, e a distância entre as
  fileiras de monstro é 390 e congelada.
- **A medida da carta é a do contrato** (59 x 86 x 0,30 mm) e a mesa é a única
  dona do número: receptor sem a medida cresce do tamanho zero e grita.
- **O doc é escrito pela IA e lido pela IA.** Mudou, substitui sem explicar
  (R14). `python tools/checar_docs.py` é a trava e diz qual regra quebrou.
