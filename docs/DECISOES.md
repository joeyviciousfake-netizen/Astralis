# DECISOES — o que foi decidido e não se reabre

> Só vale o que está aqui. Cada regra **uma vez só**, em uma linha:
> `Dnn: REGRA | porque: MOTIVO | proibido: O QUE NAO PODE SER FEITO`.
>
> **Motivo é atemporal** ("X porque Z, senão W"). Mudança não entra: quem
> substitui uma regra escreve a nova, e a antiga sai do arquivo inteiro
> (R14/D1). O que ficou sem valor não vira linha de "supersedida".
>
> **Buraco é intencional.** `D13` e `D46` foram reservadas e as decisões
> sumiram; nada se renumera, o índice marca o buraco. `D45b` foi fundida na
> `D45`. O motivo de não existirem está no `git log`.
>
> A lista de regras de processo e convenção de código é o **`AGENTS.md` seção 2**
> (R1-R14). Decisão que já é regra ali **não** se repete aqui.

## Dado, contrato e distribuição

- **D01** | DATA != LOGIC: conteúdo novo é dado, nunca código. | porque: script por carta vira N scripts e a regra morre no editor. | proibido: lógica de gameplay dentro do Studio.
- **D02** | Proibido motor falso (`FakeDuel/Effect/Fusion/Campaign`), inclusive em preview. | porque: "funcionou no editor mas não no jogo" é a classe de bug que o editor não pode ter. | proibido: preview que não execute o Astralis real. (= R2)
- **D08** | Fusão resolve em 2 camadas: receita explícita `{card_a, card_b}` primeiro, regra genérica `{attribute, type, min_atk}` por prioridade depois. | porque: o FM tem centenas de combinações e cadastrar todas é inviável. | proibido: cadastrar a regra genérica antes da receita.
- **D17** | Slot tem ID fixo (`p0/p1` + `m/s` + índice); a lógica só usa ID. | porque: mover um slot não pode quebrar regra. | proibido: lógica lendo coordenada de tela. A posição vem do arquivo da arena e **não tem fallback** (D50).
- **D18** | O lado 1 do dado já vem espelhado (X invertido, fileiras trocadas). | porque: quem espelha duas vezes se anula, e o desenho volta para o mesmo lado da tela. | proibido: espelhar a coluna de novo por perspectiva.
- **D20** | O conjunto de referência versionado é 100% FM original: 722 cartas, 39 duelistas, 39 decks, abertura Simon Muran x Jono com 8000 LP. | porque: é o dado de teste, não um limite do que o usuário pode autorar. | proibido: tratar os números do FM como regra de conteúdo.
- **D21** | `duel_setup.starting_lp` manda; `duelist.starting_lp` é sugestão do Studio. | porque: dois donos do mesmo número divergem. | proibido: o jogo ler o LP do duelista.
- **D29** | O Studio abre SEMPRE vazio (apaga o projeto e recria o esqueleto, sem backup, sem `sessao_*`); conteúdo só por Importar. O jogo lê via `--project` (+ `--setup`). | porque: a abertura é o estado inicial, e um preset esconde o que o jogo realmente carrega. | proibido: `schemas/examples/` entrar no caminho de produção.
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
- **D33** | Campo de Testes com `duel_setup.test_state` V1: minha mão 0-5 + 4 zonas de 5 slots (meu e do rival), e "Iniciar teste" abre o Astralis real por `--project` + `--setup`. | porque: testar carta com o jogo de verdade, não com um duble. | proibido: campo de teste com estado inicial falso.
- **D34** | Com `test_state` o turno 1 **pode** atacar (`is_test`); no duelo normal continua fechado. | porque: o campo de testes existe para bater na carta já de cara. | proibido: liberar o turno 1 no duelo normal.
- **D41** | A mesa segue a referência do Tag Force, e é **só desenho**. O campo é um SubViewport à direita (x 29,3%..100%) com a câmera **sem deslocamento** e `frustum_offset = ZERO`; o campo ganha transform de apresentação (escala uniforme + deslocamento) sobre o layout da arena. | porque: deslocar a lente achata um lado e estica o outro. | proibido: mexer em `CAM_POS.x`, em `frustum_offset`, ou aplicar escala não uniforme. Se parecer torto, muda o retângulo do SubViewport, nunca a câmera.
- **D42** | `duel_setup.seed = 0` (ou ausente) é **sem semente**, sorteio de verdade; `seed != 0` é semente fixa para determinismo. A tela honra o `current_player` do motor, inclusive quando o rival começa, e conduz o turno dele pelo mesmo caminho real da jogada do jogador. | porque: quem começou o duelo é **dado do motor** (R3); semente fixa no Studio fazia o "aleatório" dar sempre o mesmo. | proibido: hardcode de "sempre jogador 0".
- **D43** | Ninguém ataca enquanto o contador de turno for 1. | porque: a trava é pelo **contador**, não pelo lado — quem começou joga o turno 1 inteiro. | proibido: filtrar `can_attack` por `attacker_player`.
- **D28/D55/D68** | A IA do rival é **temporária** e a escolha fina não é portada: ela escolhe o primeiro monstro da mão e o primeiro alvo, e só isso. A escolha mora em `astralis/ai/ia_rival.gd` e a **mesa executa**, pelo mesmo caminho da jogada do jogador. | porque: a escolha fina morava no 2D, que saiu, e a IA vai mudar quando o duelo parar de mudar. | proibido: a IA conduzir o turno, conhecer a tela, ou ter método de execução — se tivesse, a regra estaria morando nela e a R1 estaria quebrada. `target_slot` menor que zero é **ataque direto**, nunca "sem alvo".

## Mesa (o ponto de vista)

- **D45** | A faixa do meio é **2D**, no HUD, dentro do vão entre as fileiras de monstros. Ordem das 7 células: meu cemitério, meu deck, meu LP, turno, LP rival, deck rival, cemitério rival. Deck é só contagem; cemitério mostra a foto da última carta, à esquerda no meu e à direita no do rival, em corte quadrado. Três conjuntos de cor (azul = você, vermelho = rival, preto = os dois cemitérios), todo número branco, e a célula do turno tinge com quem está jogando. | porque: em 3D a base depende de três números que precisam concordar e a "altura do chão" na tela é uma faixa, não uma linha — em 2D a posição é o pixel. | proibido: palavra ou ícone nos blocos, e inventar foto de cemitério vazio. A posição vem das bordas reais das fileiras, nunca chutada.
- **D47** | A tela é o ponto de vista de **quem está jogando**, girando a **câmera** 180° em torno do centro do campo. A câmera é filha de um pivô e nunca se move nem gira: quem gira é o pivô, e `giro_campo` (0 = você, 180 = rival) é o número único da volta. As cartas do campo **não se mexem**. | porque: mexer nas cartas por perspectiva é mais código para o mesmo resultado, e a troca de lado vira espelho. | proibido: perspectiva por carta, esmaecer, carta viajando, ou guardar o ponto de vista em variável (é o dono da vez, R1). O HUD 2D não gira: vira de carta com `abs(cos(graus))` e troca o conteúdo nos 90°, quando a largura é zero — **a barra de fases não inverte**, porque mostra a fase real de quem joga e espelhar dado de regra seria a tela mentir. Não existe pular a volta.
- **D49** | A grade do campo é perfeita: **um valor só, 263, nas seis direções** (o passo horizontal das 4 fileiras e o vão vertical monstro→magia dos dois lados). A distância entre as fileiras de monstro fica **congelada em 390**. | porque: com a volta da mesa o mesmo intervalo de mundo aparece com 276, 257 e 220 px na tela, então a medida é em **unidades de mundo**, nunca em pixel. | proibido: número de grid escondido no código por cima do dado. Se o vão ficar feio, muda o JSON.
- **D50** | **A arena é do jogo.** Os números da mesa vivem em um lugar só, `schemas/examples/arenas/arena_starter.json`; `default_pos`/`default_layout` devolvem nulo e o chamador decide. O `arena_id` do `duel_setup` é lido e **ignorado**; uma pasta `arenas/` num projeto é ignorada com aviso. | porque: existiam três cópias dos mesmos números, e a que servia de fallback fazia o jogo cair numa mesa diferente **em silêncio**. | proibido: constante de grade, fallback de arena, ou mesa por projeto. Arquivo faltando ou quebrado é **erro honesto**: o log avisa e a mesa não desenha o campo.
- **D51** | A vista do rival é o **espelho exato** da sua: `z_local = cam_pos.z - 2 * z_simetria * (giro / 180)`, com `z_simetria` medido do dado (a média das 10 posições de monstro da arena oficial). | porque: o plano de simetria do campo não está na origem, então girar em torno dela chega perto demais da mesa e o campo sai enviesado. | proibido: reposicionar a faixa 2D por vista, e mudar a perspectiva da sua vez. A correção tem de estar em 0° **exatamente** como `cam_pos.z`.
- **D52** | Quem está jogando ocupa o lugar de **baixo** e o outro o de **cima**; na vista do rival cada lugar é o espelho do mesmo lugar na sua vista. A troca acontece nos 90°, e as duas mãos ficam de pé mostrando o verso. O cursor some na vista do rival. As cartas do campo continuam paradas. | porque: o verso de uma carta não é o espelho da frente dela, então virar de cabeça para baixo mostraria a arte do jogador. | proibido: guardar a pose da mão por `instance_id` da câmera (ela não muda na volta) — o boot resolve os dois lugares antes de qualquer carta.
- **D53** | A compra animada é da mão que comprou; a chacoalhada é da carta do slot e **nunca** sacode a mesa inteira; o passo de cursor só reposiciona cursor e painel. | porque: um desenho que se mexe sem precisar denuncia escolha errada. | proibido: reintroduzir a trava dentro de `_sacudir` e `_animar_compra` para testá-los — as duas perderam a trava de "só com render" de propósito, para o GUT **ver quem animou**.

## Processo, ferramentas e assets

- **D22** | O Studio é app Tauri 2 (`app.bat` no menu dev/build) e o botão Jogar **lança o Godot de verdade**. Importar pack substitui com backup automático. | porque: editor que simula o jogo não serve para nada. | proibido: preview dentro do processo do Studio.
- **D23** | Quem manda é o usuário: muda qualquer decisão a qualquer hora, sem burocracia, e a IA executa. | porque: é o dono do projeto. | proibido: trava de decisão contra o usuário. (= R7)
- **D14** | Ferramentas oficiais: godot-mcp do Coding-Solo (Godot 4.7.2, headless) e GUT 9.7.1 em `astralis/testing/`. | porque: são as que executam de verdade. | proibido: instalar MCP de terceiros por link adivinhado.
- **D39** | O MCP é o do Coding-Solo; o MCP não tem nenhuma ferramenta de editar `.gd`. | porque: a ponte do Godot não escreve código — `.gd` se edita por arquivo. | proibido: "corrigir" o `.gd` pela ponte.
- **D56** | O log de BOOT é contrato, e só ele sai sempre; diagnóstico vai atrás de `-- --debug`. | porque: `astralis/testing/test_project_arg.gd` roda o jogo como processo filho e prova o `--project` lendo a saída, então o log é interface. | proibido: `push_error` no caminho de boot (o GUT conta como erro inesperado) — use `push_warning` + `print`.
- **D57** | Um `.gd` = um assunto, e o assunto manda na divisão; o comentário é finalidade, invariante e dono, nunca a história. | porque: o projeto é lido por IA, e um comentário de 20 linhas de história são 20 linhas a mais em toda leitura futura, sem informação útil. | proibido: criar arquivo minúsculo só para existir, e citar `Dnn` no comentário. **Estas duas regras são R9 e R10 no `AGENTS.md` — uma casa só.**
- **D70** | A medida da carta é a do contrato: **59 x 86 x 0,30 mm**, e a mesa é o **único dono** do número. Os receptores (`carta_3d.gd`, `cursor_3d.gd`, `painel_carta_3d.gd`) **não têm default** e cada um tem `assert` que reclama se a medida não chegar. | porque: `GROSS_CARTA` estava arredondado (0,005 em vez de 0,0050847458) e o mesmo número aparecia com valores contraditórios em 3 outros lugares; a peça nascia 10x mais grossa sem nenhuma falha. | proibido: default de medida em receptor. É melhor a peça nascer do tamanho zero com grito do que com a medida errada em silêncio.
- **D71** | **Regra das ferramentas:** nativa do programa → pesquisa na internet → manual só em último caso. | porque: o Blender tem bevel, subdiv, remesh, snap e Geometry Nodes, e ele gera a topologia por você. | proibido: reconstruir geometria à mão sem antes perguntar "o programa já faz isso?". (= R12)

---

# ÍNDICE (R13: a maior decisão que existe é a **D71**)

```text
D01 DATA != LOGIC
D02 Proibido motor falso
D08 Fusao = receita explicita + regra generica
D03/D04/D05/D06 Distribuicao trancada: PLANO, 0% implementado
D11 --- (reservada)
D12 --- (reservada)
D13 --- (reservada)
D14 Ferramentas oficiais: godot-mcp + GUT 9.7.1
D15 Mao 5, refill ate 5, deck 40, 5+5 slots por lado
D16 Resolucao fixa 1920x1080
D17 Slot com ID fixo; posicao no arquivo da arena, sem fallback
D18 O lado 1 do dado ja vem espelhado
D19 100% controle, zero mouse e teclado
D20 Referencia versionada = 100% FM original
D21 starting_lp do setup manda; o do duelista e sugestao
D22 Studio e Tauri 2; Jogar lanca o Godot de verdade
D23 Quem manda e o usuario
D24 Fluxo fiel: mao -> centro -> face -> slot -> estrela -> Ataque
D25 Mao reta centralizada; fusao fiel
D26 Mao sempre 5; deckout perde; fusao em fila
D27 Slot escolhido antes da fusao
D28/D55/D68 IA do rival e TEMPORARIA; ela SO ESCOLHE, a mesa executa
D29 Studio abre SEMPRE vazio; o jogo le via --project
D30 Efeitos NAO sao executados na mesa (dado existe, motor nao)
D31 Contrato apertado
D32 Reload no dev nao zera; abrir o app zera
D33 Campo de Testes com duel_setup.test_state V1
D34 Com test_state o turno 1 pode atacar
D35 Pack de criacao e um .apack
D36 Layout da carta e molde em dado
D37 --- (reservada)
D38 As 6 molduras ORIGINAIS do usuario, proibido editar
D39 MCP e o do Coding-Solo; nao edita .gd
D40 --- (reservada)
D41 Mesa segue o Tag Force; SubViewport, frustum_offset = ZERO
D42 seed 0 = sem semente; a tela honra current_player
D43 Sem ataque enquanto o turno for 1 (pelo contador)
D44 --- (reservada)
D45 Faixa do meio 2D no HUD, 7 celulas, 3 conjuntos de cor
D46 --- (reservada)
D47 A tela gira a CAMERA 180 em torno do campo; as cartas nao se mexem
D48 --- (reservada)
D49 Grade perfeita: 263 nas seis direcoes, 390 congelado
D50 A arena e DO JOGO: zero numero de arena no codigo
D51 A vista do rival e o ESPELHO EXATO da sua
D52 As DUAS maos, uma em cada lugar, nas duas vistas
D53 Um desenho que se mexe sem precisar
D54 --- (reservada)
D56 O log de BOOT e contrato; o resto so com -- --debug
D57 Um .gd = um assunto; comentario nunca e historia (= R9/R10)
D58 --- (reservada)
D61 --- (reservada)
D62 --- (reservada)
D68 A IA do rival tem arquivo proprio e so escolhe
D69 --- (reservada)
D70 A medida da carta e a do contrato; a mesa e o unico dono
D71 SEMPRE usar a ferramenta do programa
```
