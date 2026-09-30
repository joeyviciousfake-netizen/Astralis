# tests/ — índice dos testes (GUT)

Dono: **QA/Integration**. Este arquivo é só o índice. A suíte mora dentro do
projeto Godot, em `astralis/testing/`. Ver `docs/10_PREVIEW_TESTE_DEBUG.md`.

Os testes usam a mesa e os sistemas **de verdade** do Astralis: o mesmo
`DuelManager`, `SummonSystem`, `BattleSystem`, `DamageSystem`, `TurnManager`,
`FusionSystem`, `DataLoader`, `BoardLayout` e a mesma cena `duel3d/mesa_3d.tscn`
que o jogo usa. Não existe cópia "fake" de nada (regra **R2**).

## Números de hoje

| | |
|---|---|
| Arquivos de teste | **20** (+ 1 base de helpers) |
| Testes | **178** |
| Asserções | **3835** |
| Tempo (headless) | **~160 s** (~10 s deles são 2 testes que esperam a IA real) |
| Conteúdo oficial usado | **722 cartas / 39 duelistas / 39 decks / 25081 receitas de fusão** |
| Framework | **GUT 9.7.1** (`astralis/addons/gut/`) |
| Godot | **4.7.2 headless** |

## Como rodar (PowerShell, da raiz do repo)

```powershell
# 1) Importar o projeto. OBRIGATÓRIO num clone novo: a pasta Godot/ e a
#    .godot/ estão no .gitignore, então nada disso vem junto no git.
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path astralis --import

# 2) Rodar TODOS os testes.
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path astralis -s res://addons/gut/gut_cmdln.gd -gdir=res://testing -gexit

# 3) Rodar UM arquivo só.
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path astralis -s res://addons/gut/gut_cmdln.gd -gtest=res://testing/test_duel_core.gd -gexit
```

Use o executável **console** (`..._console.exe`): é ele que imprime o resumo
no terminal. O resultado bom é `175/175 passed` + `---- All tests passed! ----`
e o `Time` em ~160 s. O GUT sai com código 0 quando passa.

Rodar direto no editor também funciona: abra `Godot/Godot_v4.7.2-stable_win64.exe`,
importe `astralis/`, aba **GUT** → **Run**.

## Os 20 arquivos e o que cada um trava

| Arquivo | Testes | O que trava |
|---|---:|---|
| `test_duel_core.gd` | 16 | O motor de duelo: mão 5/5 sem carta extra + refill até 5 nos 2 lados, ordem das fases, 1 invocação por MAIN, 1 ataque por monstro, D17 (jogador 0 não ataca no 1º turno, só virado em Ataque ataca, a virada desvira ao ser atacada), dano e cura com teto no LP inicial, LP zerado declara vencedor, deck out, duelo automático termina em até 20 turnos, mesma seed = mesmo resultado, empate Ataque×Defesa e Ataque×Ataque, ATK/DEF limitados a 9999, e a carta real `fm_0001` (Blue-eyes 3000) causando 3000 de dano. |
| `test_loader_validator.gd` | 5 | O conteúdo e o contrato: 722 cartas `fm_*`, 39 duelistas, 39 decks de 40 cartas, duelo de abertura (Simon Muran × Jono, 8000 LP), `fm_0001` dentro do schema, customs preservados no `starter_backup`, validação sem nenhum erro, e as 25081 receitas de fusão com a receita explícita `fm_0002 + fm_0008 = fm_0638` e 0 regras genéricas. |
| `test_board_layout.gd` | 15 | O desenho da arena: 20 slots com ID fixo, XY do JSON só move o desenho (a carta continua indo pelo índice), arquivo ausente/ruído cai na grade padrão, espelho do rival no X e nas fileiras (D25), mão p0/p1 com fallback para arena antiga, rival desenhado só com a **quantidade** (nunca id nem nome), mão centralizada, criar/liberar a mesa 2× sem erro, e **`test_grade_embutida_igual_arena_oficial` (D48)**: a grade embutida tem que ser a arena oficial slot por slot (20/20), com `SLOT + GAP == 263` e as constantes do 2D legado iguais às do `BoardLayout` — sem arena e com arena é a mesma tela. |
| `test_compra_fila.gd` | 5 | A compra fiel FM: início 5/5 sem extra, refill até 5 nos 2 lados depois de jogar, deck out só na hora de completar (mão cheia com deck vazio **não** perde), e a animação da fila de fusão que é só visual (não mexe no estado, funciona headless). |
| `test_fusao_fiel.gd` | 16 | Mão reta + fusão fiel: mão sempre reta e centralizada, levantar/abaixar com selo que renumera sozinho, 0 levantadas = avulsa e 1 = bloqueia com aviso, receita que ignora a ordem, regra genérica por prioridade, equip pendente, cadeia par a par que descarta a acumulada na falha, resultado descendo face para cima em Ataque, slot escolhido **antes** da fusão, e o slot ocupado (avulsa e combinação encontram o campo pelo `FusionSystem` real). |
| `test_fluxo_fiel.gd` | 5 | O fluxo da mesa: na fase da mão o cursor nunca sai da mão, a carta desce sempre em Ataque com a face e a estrela escolhidas, RB/LB travado depois do ataque, e START que não passa na fase da mão mas passa na de campo. |
| `test_mesa_3bugs.gd` | 3 | 3 bugs da mesa: o menu não oferece Atacar inválido no 1º turno (a mesa pergunta ao `can_attack` real), a carta fica centrada no slot nos 2 lados, e o rival virado 180° (frente e verso) com Defesa somando 90°. |
| `test_mesa_6bugs.gd` | 6 | 6 bugs da mesa: carta virada desce escondida nos 2 lados, o menu da estrela abre por cima da carta, a navegação alcança as 4 fileiras (20 slots, magia inclusa), no rival a direita aumenta o X de tela, cima/baixo nas bordas não fogem para o LP nem para a mão, e rival vazio oferece o LP com dano ATK cheio + a IA atacando direto. |
| `test_ia_ataque.gd` | 5 | A escolha de ataque da IA: campo vazio → direto com o mais forte, abate com o mais fraco que vence, só Defesa forte → o rival passa, empate Ataque×Ataque ataca e os dois caem, e o bônus de guardião que ainda devolve 0 (adiado, D28). |
| `test_gamepad.gd` | 7 | Controle 100% gamepad (D19/D26): as 11 ações existem, confirmar e cancelar não dividem botão, as direções são só joypad, o cursor anda e volta pelo passo real, cancelar limpa a escolha, e a mesa **não tem nenhum** botão/texto/carta clicável. |
| `test_project_arg.gd` | 12 | O `--project` e o `--setup`: sem argumento usa a pasta embutida, pasta inválida é reprovada, pasta válida é reconhecida pelos marcadores, caminho relativo resolve na raiz do repo, relativo inexistente avisa e cai na embutida, as duas formas (`--project pasta` e `--project=pasta`) dão o mesmo resultado, `--setup` por cima do projeto **vence** o duelo do projeto, `--setup` inválido avisa e segue com o do projeto, e a regra nova: projeto **sem arena** → o jogo avisa, `project_arena_path()` devolve vazio e a mesa usa a grade padrão com os 20 slots e o espelho certo. |
| `test_campo_testes.gd` | 8 | O Campo de Testes (tab Testes do Studio): com `test_state`, o duelo começa em p0 na DRAW (fase da mão, D24), `my_hand` (fm_0001 + fm_0002) vira a mão de p0 na ordem + refill real até 5, o campo vira instâncias reais (ATK/DEF da base, face/posição do dado, estrela = guardiã 1, null = vazio nas magias), seed 42 fixa dá o mesmo campo + mão + deck em 2 montagens, sem `test_state` tudo igual a antes (5/5, campo vazio), o duelo de teste é jogável (DRAW→MAIN + 1 invocação normal), e o ataque no turno 1: **com** `test_state` p0 ataca na BATTLE e mata como o motor manda (fm_0001 3000 × fm_0004 1200 = 1800 de dano, 8000→6200), **sem** `test_state` p0 continua bloqueado com `Sem ataque no 1º turno.` (D15/D17). |
| `test_card_layout.gd` | 14 | O molde da carta em dado (V1 só monstro): default embutido idêntico ao JSON oficial peça por peça, por-mil→px, molde válido move a peça (loader + carta), ausente/inválido cai no default, peça/campo ausente vira default, `visible_when` esconde o ATK fora de monstro (inclusive após virar/desvirar), carta mostra o dado real FM (nome, estrelas=level, ATK/DEF, id), mesa real renderiza pelo molde — e a trava **Rust × jogo**: matriz espelhada válido/inválido (kinds, somas x+w/y+h≤1000, enums, cores hex, versão 1, canvas 59×86), molde movido no formato do Studio (`layouts/card_layout_monster_default.json` com 9 peças, nome 35→70) lido e desenhado pelo jogo de verdade, e 13 divergências pinadas com prova (extras, null explícito, z 5.0, versão 1.0/"1", id longo 71 chars, name número — sem corrigir produto, dono corrige). |
| `test_assets_embutidos.gd` | 4 | Os 17 assets de carta do jogo (`astralis/assets/`) são **byte-idênticos** aos do Studio (`astralis-studio/static/`, D38 — as molduras são do usuário e é PROIBIDO editar): os 17 pares batem em nome + tamanho + SHA-256, a lista de 17 é a mesma que o jogo procura (`ASSETS_EMBUTIDOS`), sem `--project` (é como o GUT roda) o jogo acha 17/17 e a carta sai com a moldura REAL (832×1248), e a carta deitada no campo tem a mesma composição da carta da mão, com nome/ATK/DEF do dado. |
| `test_mesa_3d_oficial.gd` | 25 | O campo 3D OFICIAL (D40/D41): a cena sobe com duelo real do `DuelManager`, sem mesa/tampo/moldura, o mundo 3D dentro do SubViewport do campo, a lente **no eixo** (`frustum_offset = 0`), o HUD 2D com o dado real (painel da carta, placa de ATK/DEF, fases, retratos, contadores), a carta desenhada pelo molde, e a leva D45/D45b da faixa do meio: as 7 células na ordem do usuário, o vão entre as fileiras, os blocos limpos, o número branco, as três cores (azul/você, vermelho/rival, preto/cemitério), a foto quadrada do último carta do cemitério e a cor do turno acompanhando o `current_player`. |
| `test_queda_cursor_rival.gd` | 6 | A **queda de linha** (D45): a troca de linha e de carta não pode derrubar a tela. Reproduz a pilha real varrendo as fileiras do rival, trava que o cursor e as cartas continuam onde devem, e que as zonas do `GameState` são lidas pelo tradutor único (`_chave_zona`) — lado fora de 0..1, chave desconhecida ou ausente viram lista vazia, nunca crash. |
| `test_regra_turno1.gd` | 6 | A regra do **turno 1** (D43, corrigindo a D15): ninguém ataca enquanto o contador de turno for 1, para QUEM ESTIVER jogando — quem começou a partida não ataca, e o outro lado já entra no turno 2 atacando. Não é regra por jogador. A exceção do Campo de Testes (`is_test`, D34) fica igual, e a mensagem do dono da regra (`BattleSystem.ERRO_TURNO_1`) é uma só, sem string duplicada. |
| `test_seed_sorteio.gd` | 5 | A **semente** `duel_setup.seed` (D42): `seed = 0` (ou ausente) = SEM SEMENTE, sorteio de verdade; `seed != 0` = semente fixa, e o mesmo duelo reproduzido carta por carta (mesmo primeiro jogador, mesma mão, mesma ordem do baralho). Trava que a semente fixa dá o mesmo resultado, que duas sementes dão baralhos diferentes, e que `first_p1`/`first_p2` são deterministas mesmo com seed 0. |
| `test_turno_quem_comeca.gd` | 5 | **Quem começa** (D42): o motor sorteia o primeiro jogador e a tela 3D HONRA o `current_player` devolvido, inclusive quando o **rival** começa — nesse caso ela conduz o turno dele pelos sistemas reais e devolve a vez (antes o jogo travava em "Aguarde o rival"). Trava que o turno do rival sempre termina em `current_player == 0`, com trava de progresso (teto de passos) e sem reentrada em paralelo. |
| `test_volta_mesa.gd` | 10 | A **volta da mesa** (doc 16 §16.15 / D47): a tela do duelo é o ponto de vista de QUEM ESTÁ JOGANDO e quem anda é a CÂMERA, que dá 180° em torno do centro do campo — **as cartas não se mexem**. Trava que a câmera é filha de um pivô e não se move (é o pivô que gira), que a lente continua no eixo (`frustum_offset` = 0) e o centro do campo no mesmo x da tela (a volta espelha, não desloca), que a sua fileira é a de baixo na sua visão e a de cima na do rival, que a volta vai a 180 e **volta** a 0 (idempotente), que **nenhuma carta do campo e nenhuma das duas mãos muda de lugar um milímetro** no mundo, que o `GameState` não se mexe, que cada jogador vê a própria fileira na ordem normal (o espelho do rival no dado e a volta se cancelam), que o HUD 2D **não gira** mas vira de carta (`|cos(graus)|`, largura zero nos 90°, onde o conteúdo troca) e que a faixa do meio se espelha e volta, que o painel esquerdo continua neutro na vez do rival (D46b) e que o controle fica travado enquanto a mesa gira. |

## A base única de helpers

`astralis/testing/astralis_test_base.gd` reúne, **numa cópia só**, os helpers
que antes estavam duplicados em 7 arquivos (≈200 linhas repetidas). Todo
arquivo de teste começa assim:

```gdscript
extends "res://testing/astralis_test_base.gd"
```

Use o **caminho**, não o nome da classe: rodar `godot --headless -s ...` não
reconstrói o cache de classes globais, então `extends AstralisTestBase` quebra
com *"Could not find base class"*.

Detalhe importante: os helpers **só organizam dado ou observam estado**.
Quem decide a regra é sempre o sistema real do Astralis.

## Cobertura e buracos conhecidos

**Coberto:** motor de duelo e todas as regras fixas do tabuleiro; compra e
deck out; conteúdo FM e validação de contrato; fusão (receita, regra, cadeia,
equip, slot ocupado); o desenho da arena e o espelho; o fluxo da mesa ponta a
ponta; navegação e render do campo; a IA de ataque; o controle 100% gamepad;
  o `--project`/`--setup` e o fallback da arena; o Campo de Testes (`test_state`:
  mão na ordem + refill, instâncias reais no campo, p0 na DRAW, determinismo,
  paridade sem `test_state`, duelo jogável, ataque no turno 1 liberado só com
  `test_state` e bloqueado sem ele); o molde da carta (default = oficial,
  por-mil→px, molde válido move a peça, ausente/inválido = default, ATK só em
  monstro, dado FM na carta, mesa renderiza, matriz Rust × jogo + molde movido
  no formato do Studio + 13 divergências pinadas).

**Não coberto (e por quê):**

- **Efeitos:** o dado existe (`effects.json`) e é validado, mas **nenhum sistema
  executa efeito** — ainda não existe motor de efeitos. Cobertura possível
  hoje: 0.
- **Campanha, save, exportação `.astralis` e CI:** não existem no repo.
  Cobertura: 0.
- **Zona de magia:** é navegável e testada (20 slots, 4 fileiras), mas
  **invocar/ativar magia nunca é exercitado** — a regra não existe.
- **`--project`:** coberto pelo jogo de verdade rodando como processo filho
  (o GUT em si não recebe argumentos de linha de comando). As funções
  `project_base_dir()` e `load_starter_kit()` sem argumento só têm o caminho
  negativo testado no próprio processo; o caminho delas com `--project` só é
  provado pelo jogo filho.
- **Regra que não existe no código** (portanto sem cobertura possível):
  *pierce*, *chain*, reação em cascata, oferta/tributo e a **guardiã ±500**
  (existe só um gancho que devolve 0, e isso é testado).
- **Flakiness conhecida:** 2 testes esperam a IA de verdade com
  `await wait_seconds(5.0)` —
  `test_fluxo_fiel.gd::test_start_na_mao_nao_passa_e_no_campo_passa` e
  `test_mesa_6bugs.gd::test_bug6_rival_vazio_menu_LP_dano_ATK_cheio_e_IA_direta`.
  Em máquina lenta esses 2 podem falhar. Se isso acontecer, **é bug do
  runtime** (a IA roda sem guarda de fim de turno), não do teste: reporte,
  não adapte.
- **Sem `.gutconfig.json` e sem `[autoload]` no `project.godot`:** toda a
  configuração do GUT é por flag de linha de comando (`-gdir`, `-gtest`,
  `-gexit`). Se mudar a forma de rodar, mude junto neste arquivo.

## Como criar um teste novo

1. Arquivo em `astralis/testing/test_<assunto>.gd`.
2. Primeira linha: `extends "res://testing/astralis_test_base.gd"`.
3. Um cabeçalho em PT-BR explicando **o que o arquivo trava**.
4. Um `func test_<caso>() -> void:` por regra, com `assert_*` e uma frase
   explicando o esperado em português simples.
5. Use os sistemas reais. Se o teste precisa montar cenário, use um helper da
   base. Se falta um helper, **adicione na base** (não copie para o arquivo).
6. Rode o GUT antes de commitar.

## Regra de QA

Bug vira teste permanente: **SPEC → TEST → IMPLEMENT → RUN → FIX → REGRESSION**.
Se um teste falha, é bug do runtime: **reporte, não adapte**.
Teste descartável vive e morre na mesma sessão (R8) — a pasta de projeto de
teste do `test_project_arg.gd` é criada em `user://` e apagada no `after_each`.
