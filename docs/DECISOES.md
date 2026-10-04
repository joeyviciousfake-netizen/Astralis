# DECISOES — o que foi decidido e não se reabre

> Só vale o que está aqui. Cada regra **uma vez só**, em uma linha:
> `Dnn: REGRA | porque: MOTIVO | proibido: O QUE NAO PODE SER FEITO`.
>
> **Motivo é atemporal** ("X porque Z, senão W"). Como trocar uma regra e o que
> fazer com a que ficou sem valor é R14 no `AGENTS.md`.
>
> **Buraco é intencional:** nada se renumera e o índice marca o buraco (`D13`,
> `D46` reservadas; `D45b` fundida na `D45`). O motivo está no `git log`.
>
> Regra de processo e convenção de código é o **`AGENTS.md` seção 2** (R1-R14) e
> **não** se repete aqui.

## Dado, contrato e distribuição

- **D01** | DATA != LOGIC: conteúdo novo é dado, nunca código. | porque: script por carta vira N scripts e a regra morre no editor. | proibido: lógica de gameplay dentro do Studio.
- **D02** | Proibido motor falso (`FakeDuel/Effect/Fusion/Campaign`), inclusive em preview. | porque: "funcionou no editor mas não no jogo" é a classe de bug que o editor não pode ter. | proibido: preview que não execute o Astralis real. (= R2)
- **D08** | Fusão resolve em 2 camadas: receita explícita `{card_a, card_b}` primeiro, regra genérica `{attribute, type, min_atk}` por prioridade depois. | porque: o FM tem centenas de combinações e cadastrar todas é inviável. | proibido: cadastrar a regra genérica antes da receita.
- **D17** | Slot tem ID fixo (`p0/p1` + `m/s` + índice); a lógica só usa ID. | porque: mover um slot não pode quebrar regra. | proibido: lógica lendo coordenada de tela. A posição vem do arquivo da arena e **não tem fallback** (D50).
- **D18** | O lado 1 do dado já vem espelhado (X invertido, fileiras trocadas). | porque: quem espelha duas vezes se anula, e o desenho volta para o mesmo lado da tela. | proibido: espelhar a coluna de novo por perspectiva.
- **D20** | O conjunto de referência versionado é 100% FM original: 722 cartas, 39 duelistas, 39 decks, abertura Simon Muran x Jono com 8000 LP. | porque: é o dado de teste, não um limite do que o usuário pode autorar. | proibido: tratar os números do FM como regra de conteúdo.
- **D21** | `duel_setup.starting_lp` manda; `duelist.starting_lp` é sugestão do Studio. | porque: dois donos do mesmo número divergem. | proibido: o jogo ler o LP do duelista.
- **D29** | O Studio abre SEMPRE vazio (apaga o projeto e recria o esqueleto, sem backup, sem `sessao_*`); conteúdo só por Importar. | porque: a abertura é o estado inicial, e um preset esconde o que o jogo realmente carrega. | proibido: `schemas/examples/` entrar no caminho de produção.
- **D31** | O contrato é apertado para bater com o código: `card.attack/defense` ≤ 9999, `effect.flow.mode` só `sequence`, `starting_lp` ≤ 99999, `arena.slots[].x` 0-1920 e `.y` 0-1080. `schema_version` continua 1. | porque: schema frouxo deixa passar o que o código já impede. | proibido: fechar regra nova sem rodar `python tools/fm_import.py --check`.
- **D35** | O pack de criação é um arquivo só, `.apack`: zip com `manifest.json` (magic `APACK`, format 1, SHA-256 por arquivo) + `data/pack.json` byte-idêntico ao legado + `assets/` com dedup por hash. `.json` antigo abre como `.apack` sem imagens. | porque: texto e imagem num arquivo só, com extensão nossa, e nenhum algoritmo inventado. | proibido: ZipSlip — vale para o zip **e** para o manifest, nos dois lados (Python e Rust).
- **D36** | O layout da carta é molde em dado (`card_layout` V1): canvas 59x86 em por-mil do próprio eixo, 9 tipos fechados, `rect{x,y,w,h}` + `style` + `visible_when`. | porque: layout modificável tem que ser dado, senão vira código por carta. | proibido: id de layout acima de 64, ou `x+w`/`y+h` acima de 1000.
- **D38** | A carta usa as 6 molduras originais em `astralis-studio/static/frames/`, byte-idênticas às do usuário, e elas são a fonte única da medida do preview. | porque: moldura é do usuário, não da IA. | proibido: editar as molduras sem pedido explícito.
- **D03/D04/D05/D06** | Distribuição trancada (`.astralis` binário, cadeado por jogo, player + fita no mesmo zip) é **PLANO, 0% implementado** → `12_DISTRIBUICAO_EXPORTACAO.md` §PLANO. | porque: frágil e cópia fácil. | proibido: o Studio fingir que empacotou.

## Duelo

- **D15** | Mão 5 e refill até 5 pros dois lados, deck 40, 5 slots de monstro + 5 de magia por lado, virar de costas desvira ao ser atacada, `turn_order` decide quem começa. | porque: é o tabuleiro do original. | proibido: o painel tratar o turno 1 por lado — a trava é pelo contador (D43).
- **D16** | Resolução fixa 1920x1080 (viewport + stretch `canvas_items`). | porque: o campo e a mão precisam de espaço previsível. | proibido: layout responsivo que mude a composição.
- **D19** | 100% controle, **zero mouse e teclado**: só as 11 ações de joypad. | porque: o jogo se joga no controle. | proibido: caminho de interaction que dependa do mouse.
- **D24** | Fluxo fiel: fase da mão travada (só mão) → carta ao centro → esquerda/direita alterna a face → slot próprio → menu estrela (2 da carta) → sempre desce em Ataque. Na fase de campo o jogador escolhe entre os dois campos. START passa o turno. | porque: é o flujo do original. | proibido: pular a fase da mão, ou passar o turno direto da carta ao centro.
- **D25** | Mão reta centralizada: levantar sobe, cresce e abre vão; o selo 1-2-3 acompanha; renumera sozinho. Fusão fiel: 0 = avulsa, 1 = bloqueia, 2+ = centro em ordem, par a par, a fundida desce e a novata fica face-up. | porque: é a mão do original. | proibido: fusão por equip na V1 (devolve "equip_pendente").
- **D26** | A mão tem sempre 5 (início 5 sem extra); completar o baralho é derrota na hora; a fusão é fila animada (ponta direita, flash de sucesso, chacoalhada de falha) sem mudar o resultado. | porque: mão curta e animação rápida quebraram o fluxo. | proibido: a animação decidir o resultado.
- **D27** | O slot é escolhido **antes** da fusão (vazio ou ocupado); o final encontra o campo, e falha descarta a acumulada; a estrela vem no fim. | porque: escolher o slot depois obriga a refazer. | proibido: abrir o menu da estrela no meio da fila.
- **D30** | Efeitos **não** são executados na mesa. O dado existe e é validado (`effects.json`, contrato fechado) e o Studio edita e valida, mas não há motor no runtime: a zona de magia navega e ativar magia avisa. | porque: sem motor no runtime, o editor não pode executar (R4), e um editor que finge é pior que um editor que avisa. | proibido: o Studio calcular efeito, ou o GUT "provar" um motor que não existe.
- **D33** | Campo de Testes com `duel_setup.test_state` V1: minha mão 0-5 + 4 zonas de 5 slots (meu e do rival), e "Iniciar teste" abre o Astralis real. | porque: testar carta com o jogo de verdade, não com um duble. | proibido: campo de teste com estado inicial falso.
- **D34** | Com `test_state` o turno 1 **pode** atacar (`is_test`); no duelo normal continua fechado. | porque: o campo de testes existe para bater na carta já de cara. | proibido: liberar o turno 1 no duelo normal.
- **D41** | A tela segue a referencia do Tag Force, e e **so desenho**. O campo e a cena da referencia; a lente fica no eixo e nunca e deslocada (doc 15). | porque: a referencia e o alvo visual, e qualquer numero de layout e do dado. | proibido: numero de campo no codigo, e lente deslocada.
- **D42** | `duel_setup.seed = 0` (ou ausente) é **sem semente**, sorteio de verdade; `seed != 0` é semente fixa para determinismo. A tela honra o `current_player` do motor, inclusive quando o rival começa, e conduz o turno dele pelo mesmo caminho real da jogada do jogador. | porque: quem começou o duelo é **dado do motor** (R3). | proibido: hardcode de "sempre jogador 0".
- **D43** | Ninguém ataca enquanto o contador de turno for 1. | porque: a trava é pelo **contador**, não pelo lado — quem começou joga o turno 1 inteiro. | proibido: filtrar `can_attack` por `attacker_player`.
- **D28/D55/D68** | A IA do rival e **temporaria**: escolhe o primeiro monstro e o primeiro alvo, e a **mesa executa** pelo mesmo caminho da jogada do jogador. | porque: escolher carta e alvo e **regra**, e regra mora no `duel/` — escolha fina na tela ja e a R1 quebrada. | proibido: a IA conduzir o turno, conhecer a tela, ou ter metodo de execucao. `target_slot` < 0 e **ataque direto**.

## Mesa (o ponto de vista)

- **D45** | A faixa do meio e **2D**, na camada -1 (atras do mundo 3D, que e transparente no vao), dentro do vao entre as fileiras, com 7 celulas na ordem do D45b (MeuCemiterio, MeuDeck, LpVoce, **Turno** no meio, LpRival, DeckRival, CemRival). Todo numero e BRANCO. A posicao nao e chutada: a barra se encaixa nas bordas REAIS das fileiras, medidas do dado + da camera. | porque: em 3D a posicao de um objeto e a soma de tres numeros e a "altura do chao" e uma faixa, nao uma linha; em 2D a posicao e o pixel. | proibido: hardcode de posicao da faixa, e cor de numero fora do branco (doc 15 15.6).
- **D47** | A tela e o ponto de vista de **quem esta jogando**, girando a **camera** 180 em torno do centro do campo. A camera e filha de um pivo e nunca se move nem gira: quem gira e o pivo, e `giro_campo` (0 = voce, 180 = rival) e o numero unico da volta. As cartas do campo **nao se mexem**. | porque: mexer nas cartas por perspectiva e mais codigo para o mesmo resultado. | proibido: perspectiva por carta, esmaecer, carta viajando, ou guardar o ponto de vista em variavel. O HUD 2D nao gira: vira de carta com `abs(cos(graus))` e troca o conteudo nos 90 - **a barra de fases nao inverte**, porque mostra a fase real de quem joga. Nao existe pular a volta. A mesa **nasce** na vista de quem tem a vez: quando o rival comeca, o boot coloca a vista em 180 (`colocar_vista`, sem tween).
- **D49** | A grade do campo e **perfeita**: **um valor so, 263**, nas seis direcoes (EXCETO o 390 entre as fileiras de monstros, que vem da outra medida da arena). | porque: dois numeros iguais escritos em lugares diferentes divergem no primeiro ajuste de layout. | proibido: um segundo valor de vao.
- **D50** | **A arena e do jogo.** Os numeros da mesa vivem em `schemas/`, e a pasta `arenas/` do projeto e IGNORADA com aviso. | porque: duas arenas sao duas mesas, e numero de mesa em dois lugares diverge sozinho. | proibido: `arenas/` no projeto, e a mesa ler layout de fora do dado.
- **D51** | A vista do rival é o **espelho exato** da sua: `z_local = cam_pos.z - 2 * z_simetria * (giro / 180)`, com `z_simetria` medido do dado (a média das posições de monstro da arena oficial). | porque: o plano de simetria do campo não está na origem, então girar em torno dela chega perto demais da mesa e o campo sai enviesado. | proibido: reposicionar a faixa 2D por vista, e mudar a perspectiva da sua vez. A correção tem de estar em 0° **exatamente** como `cam_pos.z`.
- **D52** | Quem está jogando ocupa o lugar de **baixo** e o outro o de **cima**; na vista do rival cada lugar é o espelho do mesmo lugar na sua vista. A troca acontece nos 90°, as duas mãos ficam de pé mostrando o verso e o cursor some na vista do rival. As cartas do campo param. | porque: o verso de uma carta não é o espelho da frente dela, então virar de cabeça para baixo mostraria a arte do jogador. | proibido: guardar a pose da mão por `instance_id` da câmera (ela não muda na volta) — o boot resolve os dois lugares antes de qualquer carta.
- **D53** | A compra animada é da mão que comprou; a chacoalhada é da carta do slot e **nunca** sacode a mesa inteira; o passo de cursor só reposiciona cursor e painel. | porque: um desenho que se mexe sem precisar denuncia escolha errada. | proibido: trava de "só com render" na entrada da mão e no `_sacudir` — sem ela o GUT **vê quem animou**.
- **D76** | A entrada da carta comprada é de QUEM COMPROU e só da carta que COMPROU: as outras da mão DESLIZAM para o lugar novo, e a compra só é mostrada DEPOIS que a câmera parou na perspectiva de quem comprou. | porque: a mão é centrada, então comprar uma carta muda o lugar de todas, e o salto delas é o que faz a compra parecer quebrada; e compra mostrada na tela de outro é a tela mentindo sobre de quem é a vez. | proibido: animar a mão inteira de uma vez, e entregar a vez (e a compra) antes de a volta acabar.

## Processo, ferramentas e assets

- **D22** | O Studio é app Tauri 2 (`app.bat` no menu dev/build) e o botão Jogar **lança o Godot de verdade**. Importar pack substitui com backup automático. | porque: editor que simula o jogo não serve para nada. | proibido: preview dentro do processo do Studio.
- **D23** | Quem manda é o usuário: muda qualquer decisão a qualquer hora, sem burocracia, e a IA executa. | porque: é o dono do projeto. | proibido: trava de decisão contra o usuário. (= R7)
- **D14** | Ferramentas oficiais: godot-mcp do Coding-Solo (Godot 4.7.2, headless) e GUT 9.7.1 em `astralis/testing/`. | porque: são as que executam de verdade. | proibido: instalar MCP de terceiros por link adivinhado.
- **D39** | O MCP é o do Coding-Solo; o MCP não tem nenhuma ferramenta de editar `.gd`. | porque: a ponte do Godot não escreve código. | proibido: "corrigir" o `.gd` pela ponte.
- **D56** | O log de BOOT é contrato, e só ele sai sempre; diagnóstico vai atrás de `-- --debug`. | porque: o teste prova o `--project` lendo a saída, então o log é interface. | proibido: `push_error` no caminho de boot (o GUT conta como erro inesperado) — use `push_warning` + `print`.
- **D57** | Um `.gd` = um assunto, e o assunto manda na divisão; o comentário é finalidade, invariante e dono, nunca a história. | porque: o projeto é lido por IA, e um comentário de 20 linhas de história são 20 linhas a mais em toda leitura futura, sem informação útil. | proibido: criar arquivo minúsculo só para existir, e citar `Dnn` no comentário.
- **D70** | A medida da carta e a do contrato (**59 x 86 x 0,30 mm**) e a mesa e o **unico dono**; os receptores nao tem default e cada um grita se a medida nao chegar. | porque: medida em dois lugares diverge sozinha, e a peca nasce errada sem nenhuma falha. | proibido: default de medida em receptor.
- **D71** | **Regra das ferramentas:** documentacao (o `docs/17_BLENDER.md` e o manual, a copia local quando existe) ANTES do que nao se sabe; depois nativa, internet, manual so em ultimo caso. | porque: consultar a doc antes e o caminho curto, e depois de errar e registro de erro. | proibido: reconstruir geometria a mao sem consultar a doc e perguntar "o programa ja faz isso?". (= R12)
- **D74** | **A documentacao e lida ANTES do codigo, e o motor arbitra quando elas discordam:** ler a doc do que se vai usar e, como a copia local do Godot e do `master` enquanto o motor e o da `project.godot`, conferir a API no motor com `ClassDB.class_has_method`. | porque: o motor muda o tempo todo e o jeito facil ja existe quase sempre. | proibido: mexer em codigo de motor sem ler a doc, e usar API que a doc marca como recente sem conferir no motor. (= R17)
- **D75** | **A carta do painel esquerdo e a CARTA 3D de verdade, nao uma imagem 2D** (doc 15 §15.9). | porque: uma segunda carta so para o painel seria um duble do que a mesa mostra. | proibido: carta desenhada so no painel, e janela do painel em perspectiva ou deslocada (D41/D47 travam a camera do CAMPO).
- **D77** | **A moeda do sorteio e um desenho NA FRENTE DA CAMERA, e ela NAO some o jogo:** perspectiva, cartas, painel e marcador ficam a coluna inteira. Ela e IRMA do pivo (nao filha), cresce com clarao, tomba em torno do eixo VERTICAL da tela e para na face — estrela = jogador, losango = rival, a face e a resposta, e **nao ha nome escrito nem pulo**. E **UNSHADED** (a cena nao tem luz) e cabe INTEIRA no vao entre o cemiterio de cima e o marcador (doc 15 15.10). | porque: um sorteio que vira a mesa de lado faz o jogador perder as proprias cartas no instante em que vai jogar; e a face se le em um quinto de segundo e um nome em um segundo. | proibido: moeda dentro do pivo, girar na normal da face (o giro sumiria), moeda fora do vao (some atras das cartas), e material PBR (sai preto sem luz).
- **D78** | **A DISTRIBUIÇÃO INICIAL usa a MESMA animação da compra** (`entrada_mao_3d.gd`), e as DUAS mãos animam juntas: as 5 cartas do jogador embaixo e as 5 do rival em cima, uma por uma do baralho. A ordem do boot e **distribuição -> moeda**. | porque: quem abre o duelo precisa ver a mao se encher antes de saber de quem e a vez, e um tempo novo de distribuicao seria uma segunda fonte da mesma medida do voo. | proibido: tempo de distribuicao escrito fora de `entrada_mao_3d.gd`, animar so uma mao na distribuicao, e a moeda antes das cartas chegarem.
- **D79** | **O TURNO E PERGUNTA durante a espera: `?` ambar no ROXO, e o numero branco so depois.** | porque: o motor ja sabe quem comeca antes do giro, entao a cor de lado dava a resposta ANTES da hora; e o numero precisa ser branco de verdade, nao cinza. | proibido: celula na cor de lado antes da resposta, e herdar o `modulate` do pulso (alpha baixo sobre fundo escuro = cinza).
- **D80** | **A ESPERA E UMA COISA SO, E A MESA QUE DIZ QUE ELA EXISTE:** existe moeda na tela quando o DADO do duelo e `turn_order: "moeda"` (ou a flag de prova), e dai vem o PAINEL em branco (sem carta e sem verso), a NAVEGACAO travada (teclado e analogico) e o marcador. A janela cobre a distribuicao E a moeda, e acaba com a resposta. | porque: o motor ja sabe quem comeca (D42) e a tela ainda nao virou, entao o cursor esta no LUGAR da mao de quem ganhou; e sem moeda nao ha o que esconder. | proibido: `?`, carta ou verso no painel, cursor andando na espera, e espera em duelo sem moeda.
- **D81** | A ordem da tela e fundo, faixa, campo, HUD e menus: fundo na -2, faixa na -1 e campo transparente no vao, entao a carta passa por cima sem trocar de camada. | porque: camada vale para a tela toda, e viewport opaco esconderia a faixa. | proibido: campo opaco, e segurada em outra camada.

# ÍNDICE (R13: a maior decisão que existe é a **D81**)

```text
D01 DATA != LOGIC
D02 Proibido motor falso
D08 Fusao = receita explicita + regra generica
D03/D04/D05/D06 Distribuicao trancada: PLANO
D11 --- (reservada)
D12 --- (reservada)
D13 --- (reservada)
D14 Ferramentas oficiais: godot-mcp + GUT 9.7.1
D15 Mao 5, deck 40, 5+5 slots
D16 Resolucao fixa 1920x1080
D17 Slot com ID fixo; posicao no dado
D18 O lado 1 do dado ja vem espelhado
D19 100% controle, zero mouse e teclado
D20 Referencia = 100% FM original
D21 starting_lp do setup manda
D22 Studio e Tauri 2
D23 Quem manda e o usuario
D24 Fluxo fiel do turno
D25 Mao reta; fusao fiel
D26 Mao 5; deckout perde
D27 Slot escolhido antes da fusao
D28/D55/D68 IA SO ESCOLHE; a mesa executa
D29 Studio abre vazio; --project
D30 Efeitos sem motor na mesa
D31 Contrato apertado
D32 Reload no dev nao zera; abrir o app zera
D33 Campo de Testes (test_state)
D34 Com test_state o turno 1 pode atacar
D35 Pack de criacao e um .apack
D36 Layout da carta em dado
D37 --- (reservada)
D38 As 6 molduras do usuario
D39 MCP e o do Coding-Solo; nao edita .gd
D40 --- (reservada)
D41 SubViewport, lente nunca deslocada
D42 seed 0 = sem semente
D43 Sem ataque enquanto o turno for 1 (pelo contador)
D44 --- (reservada)
D45 Faixa do meio 2D na camada de tras
D46 --- (reservada)
D47 A tela gira a CAMERA 180
D48 --- (reservada)
D49 Grade perfeita: 263 nas seis direcoes, 390 congelado
D50 A arena e do jogo
D51 A vista do rival e o ESPELHO EXATO da sua
D52 As DUAS maos, uma em cada lugar, nas duas vistas
D53 Um desenho que se mexe sem precisar
D54 --- (reservada)
D56 O log de BOOT e contrato; o resto so com -- --debug
D57 Um .gd = um assunto; comentario nunca e historia (= R9/R10)
D58 --- (reservada)
D61 --- (reservada)
D62 --- (reservada)
D69 --- (reservada)
D70 Medida da carta: a mesa e o dono
D71 Documentacao, depois a ferramenta
D72 Modelar na frente da pessoa, nunca headless
D73 Tri e quad entram, n-gon nao
D74 Documentacao antes do codigo
D75 A carta do painel e a CARTA 3D de verdade
D76 A entrada e so da carta comprada, na tela de quem comprou
D77 A moeda e um desenho na frente da camera, sem virar a tela
D78 A distribuicao inicial usa a animacao da compra
D79 O marcador pergunta durante a espera
D80 A espera e uma coisa so, decidida pela mesa
D81 Fundo, faixa, campo, HUD e menus: a carta passa por cima sem trocar de camada
```
