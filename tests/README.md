# tests/ — índice dos testes (GUT)

Dono: **QA/Integration**. Este arquivo é só o índice. A suíte mora dentro do
projeto Godot, em `astralis/testing/`. Ver `docs/10_PREVIEW_TESTE_DEBUG.md`.

Os testes usam a mesa e os sistemas **de verdade** do Astralis: o mesmo
`DuelManager`, `SummonSystem`, `BattleSystem`, `DamageSystem`, `TurnManager`,
`FusionSystem`, `DataLoader`, `BoardLayout` e a mesma cena `astralis/duel3d/mesa_3d.tscn`
que o jogo usa. Não existe cópia "fake" de nada (regra **R2**).

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
no terminal. O resultado bom é `---- All tests passed! ----` e o GUT saindo com
código 0. A quantidade de testes, de asserções e o tempo **saem do comando**: eles
envelhecem a cada leva, e um número escrito à mão no doc diverge do primeiro
teste novo.

> **A contagem é a única prova de que um teste rodou.** Um arquivo de teste que
> não compila **some da contagem do GUT em silêncio** (`Failing 0` continua
> verde). Confira sempre o `Scripts` e o `Tests` do resumo, não só o `Failing`.

Rodar direto no editor também funciona: abra `Godot/Godot_v4.7.2-stable_win64.exe`,
importe `astralis/`, aba **GUT** → **Run**.

## Os arquivos e o que cada um trava

| Arquivo | O que trava |
|---|---|
| `test_duel_core.gd` | O motor de duelo: mão 5/5 sem carta extra + refill até 5 nos 2 lados, ordem das fases, 1 invocação por MAIN, 1 ataque por monstro, a trava do **turno 1** e a liberação no turno 3 **para os dois lados** (D43, sem mesa nenhuma), só virado para cima em Ataque ataca, a virada desvira ao ser atacada, dano e cura com teto no LP inicial, LP zerado declara vencedor, deck out, duelo automático termina em até 20 turnos, mesma seed = mesmo vencedor, empate Ataque×Defesa e Ataque×Ataque, ATK/DEF limitados a 9999, e a carta real `fm_0001` (Blue-eyes 3000) causando 3000 de dano direto. |
| `test_loader_validator.gd` | O conteúdo e o contrato: 722 cartas `fm_*`, 39 duelistas, 39 decks de 40 cartas, duelo de abertura (Simon Muran × Jono, 8000 LP), `fm_0001` dentro do schema, customs preservados no `starter_backup`, validação sem nenhum erro, e as 25081 receitas de fusão com a receita explícita `fm_0002 + fm_0008 = fm_0638` e 0 regras genéricas. |
| `test_board_layout.gd` | O desenho da arena: 20 slots com ID fixo, XY do JSON só move o desenho (a carta continua indo pelo índice), espelho do rival no X e nas fileiras (D25), mão p0/p1, rival desenhado só com a **quantidade** (nunca id nem nome), criar/liberar a mesa 2× sem erro, a **grade perfeita (D49)** medida no arquivo (um valor só, 263, nas seis direções; o 390 entre as fileiras de monstro congelado com `assert_ne`), **`test_d50_sem_grade_no_codigo`** (`default_pos`/`default_layout` são `NULO`, `project_arena_path` cai na oficial para qualquer id, o projeto do Studio não tem `arenas/`) e, sem layout ou com arquivo ruim, **nenhuma posição é inventada**. |
| `test_compra_fila.gd` | A compra fiel FM: início 5/5 sem extra, refill até 5 nos 2 lados depois de jogar, deck out só na hora de completar (mão cheia com deck vazio **não** perde), e a animação da fila de fusão que é só visual (não mexe no estado, funciona headless). |
| `test_fusao_fiel.gd` | Mão reta + fusão fiel: levantar/abaixar com selo que renumera sozinho, cancelar desce o último e renumera, 0 levantadas = avulsa e 1 = bloqueia com aviso, receita que ignora a ordem, regra genérica por prioridade, equip pendente, cadeia par a par que descarta a acumulada na falha (a carta vai pro cemitério e a novata desce), resultado descendo face para cima em Ataque contando a jogada, slot escolhido **antes** da fusão, e o slot ocupado (avulsa e combinação encontram o campo pelo `FusionSystem` real). |
| `test_fluxo_fiel.gd` | O fluxo da mesa na 3D: na fase da mão o cursor nunca sai da mão, a carta desce sempre em Ataque com a face e a estrela escolhidas, RB/LB travado depois do ataque, e START que não passa na fase da mão mas passa na de campo. |
| `test_mesa_6bugs.gd` | 4 dos 6 bugs originais da mesa, agora na 3D: o menu da estrela abre por cima da carta, a navegação alcança as 4 fileiras (20 slots, magia inclusa), cima/baixo nas bordas não fogem para o LP nem para a mão, e rival vazio oferece o LP com dano ATK cheio + a IA atacando direto. (Os outros dois foram para o fluxo fiel e para a volta da mesa; o 2D saiu no D58.) |
| `test_ia_rival.gd` | A **IA do rival é o arquivo real** `astralis/ai/ia_rival.gd`, sem duble nem mock (D68): ela ESCOLHE o primeiro monstro da mão, avisa mão vazia / só magia, mira o primeiro monstro em campo, escolhe o **ataque direto** quando o campo do outro está vazio (o `-1` do motor), não ataca slot vazio, e **sabe o motivo** de cada escolha. O 9º trava a **R1 em forma de teste**: a IA NÃO tem método de execução — quem executa é a mesa. |
| `test_gamepad.gd` | Controle 100% gamepad (D19/D26): as 11 ações existem, confirmar e cancelar são botões diferentes, o cursor anda e volta pelo passo real, cancelar limpa a escolha real, e as 11 ações são **só joypad, zero teclado e zero mouse** (a mesa não tem nada clicável). |
| `test_project_arg.gd` | O `--project` e o `--setup`: sem argumento usa a pasta embutida, pasta inválida é reprovada, pasta válida é reconhecida pelos marcadores, caminho relativo resolve na raiz do repo, relativo inexistente avisa e cai na embutida, as duas formas (`--project pasta` e `--project=pasta`) dão o mesmo resultado, `--setup` por cima do projeto **vence** o duelo do projeto e `--setup` inválido avisa e segue com o do projeto. E a regra do **D50** (a mesa é do jogo, uma só): projeto sem `arenas/` usa a arena oficial, o `arena_id` do setup é **ignorado com aviso**, uma pasta `arenas/` no projeto é **ignorada com aviso** (jogo real como processo filho), e a arena oficial é a única e tem a grade perfeita (263 nas seis direções, 390 congelado). |
| `test_campo_testes.gd` | O Campo de Testes (tab Testes do Studio): com `test_state`, o duelo começa em p0 na DRAW (fase da mão, D24), `my_hand` (fm_0001 + fm_0002) vira a mão de p0 na ordem + refill real até 5, o campo vira instâncias reais (ATK/DEF da base, face/posição do dado, estrela = guardiã 1, null = vazio nas magias), seed 42 fixa dá o mesmo campo + mão + deck em 2 montagens, sem `test_state` tudo igual a antes (5/5, campo vazio), o duelo de teste é jogável (DRAW→MAIN + 1 invocação normal), e o ataque no turno 1: **com** `test_state` p0 ataca na BATTLE e mata como o motor manda (fm_0001 3000 × fm_0004 1200 = 1800 de dano, 8000→6200), **sem** `test_state` p0 continua bloqueado com `Sem ataque no 1º turno.` (D15/D17). |
| `test_card_layout.gd` | O molde da carta em dado (V1 só monstro): default embutido idêntico ao JSON oficial peça por peça, por-mil→px, molde válido move a peça (loader + carta), ausente/inválido cai no default, peça/campo ausente vira default, `visible_when` esconde o ATK fora de monstro, o `CardView` mostra o dado FM real (nome, estrelas=level, ATK/DEF, id) e nunca quebra, e a trava **Rust × jogo**: matriz espelhada válido/inválido, molde movido no formato do Studio lido e desenhado pelo jogo de verdade, e 13 divergências pinadas com prova (extras, null explícito, z 5.0, versão "1.0"/"1", id de 71 chars — sem corrigir produto, dono corrige). |
| `test_mesa_3d_oficial.gd` | O campo 3D OFICIAL (D40/D41/D45/D49): a cena sobe com duelo real do `DuelManager`, sem mesa/tampo/moldura, o mundo 3D dentro do SubViewport do campo, a lente **no eixo** (`frustum_offset = 0`), o HUD 2D com o dado real (painel da carta, placa de ATK/DEF, fases, retratos, contadores), a carta desenhada pelo molde, a carta deitada exatamente no painel do ladrilho **visual**, o menu da estrela com os guardiões reais, o verso, o campo à direita sem perspectiva torta, as mãos centralizadas no X do campo, e a leva D45/D45b da faixa do meio (as 7 células na ordem do usuário, o vão entre as fileiras, os blocos limpos, o número branco, as três cores, a foto quadrada do último carta do cemitério, a contagem real, o cor do turno acompanhando o `current_player`); e a **grade perfeita (D49)**: os 20 slots são o dado puro (tolerância 1e-6), o vão vertical monstro→magia dos 2 lados **igual ao horizontal** (2,1566 em unidades de mundo) e o 390 entre as fileiras de monstros congelado com `assert_ne`. |
| `test_queda_cursor_rival.gd` | A **queda de linha** (D45): a troca de linha e de carta não pode derrubar a tela. Reproduz a pilha real varrendo as fileiras do rival, trava que o cursor e as cartas continuam onde devem, e que as zonas do `GameState` são lidas pelo tradutor único (`_chave_zona`) — lado fora de 0..1, chave desconhecida ou ausente viram lista vazia, nunca crash. |
| `test_regra_turno1.gd` | A regra do **turno 1** (D43, corrigindo a D15): ninguém ataca enquanto o contador de turno for 1, para QUEM ESTIVER jogando — quem começou a partida não ataca, e o outro lado já entra no turno 2 atacando. Não é regra por jogador. A exceção do Campo de Testes (`is_test`, D34) fica igual, e a mensagem do dono da regra (`BattleSystem.ERRO_TURNO_1`) é uma só, sem string duplicada. |
| `test_seed_sorteio.gd` | A **semente** `duel_setup.seed` (D42): `seed = 0` (ou ausente) = SEM SEMENTE, sorteio de verdade; `seed != 0` = semente fixa, e o mesmo duelo reproduzido carta por carta (mesmo primeiro jogador, mesma mão, mesma ordem do baralho). Trava que a semente fixa dá o mesmo resultado, que duas sementes dão baralhos diferentes, e que `first_p1`/`first_p2` são deterministas mesmo com seed 0. |
| `test_turno_quem_comeca.gd` | **Quem começa** (D42): o motor sorteia o primeiro jogador e a tela 3D HONRA o `current_player` devolvido, inclusive quando o **rival** começa — nesse caso ela conduz o turno dele pelos sistemas reais e devolve a vez (antes o jogo travava em "Aguarde o rival"). Trava que o turno do rival sempre termina em `current_player == 0`, com trava de progresso (teto de passos) e sem reentrada em paralelo. |
| `test_volta_mesa.gd` | A **volta da mesa** (doc 16 §16.15 a §16.18 / D47-D53): a tela do duelo é o ponto de vista de QUEM ESTÁ JOGANDO e quem anda é a CÂMERA, que dá 180° em torno do centro do campo — **as cartas do campo não se mexem**. Trava que a câmera é filha de um pivô e não se move (é o pivô que gira), que a lente continua no eixo e o centro do campo no mesmo x da tela, que **a vista do rival é o espelho exato da sua** e a faixa do meio cai no mesmo vão nas duas (D51), que **as duas mãos trocam de lugar e as duas aparecem** com o mesmo tamanho na tela (D52), que o cursor some na vista do rival, que o HUD vira de carta (`|cos(graus)|`, troca nos 90°) e a faixa se espelha e volta, que o painel esquerdo continua neutro (D46b), que o `GameState` não se mexe, e que **andar na mão não move a mão do outro lado** (D53: a compra é da mão que comprou e a chacoalhada da fusão é da carta do slot, nunca da mesa inteira). |

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

**Coberto:** motor de duelo e todas as regras fixas do tabuleiro (incluindo a
trava do turno 1 para os dois lados); compra e deck out; conteúdo FM e validação
de contrato; fusão (receita, regra, cadeia, equip, slot ocupado); o desenho da
arena, o espelho e a regra do D50 (uma mesa só, zero número no código); o fluxo
da mesa ponta a ponta; navegação e render do campo; a **volta da mesa** (câmera
no pivô, espelho exato entre as duas vistas, as duas mãos trocando de lugar, o
HUD virando de carta e a mão do outro lado parada quando você anda na sua — D47
a D53); a **IA do rival como arquivo real** (`astralis/ai/ia_rival.gd`) e a trava de que
ela só escolhe e a mesa que executa; o controle 100% gamepad; o
`--project`/`--setup`; o Campo de Testes (`test_state`: mão na ordem + refill,
instâncias reais no campo, p0 na DRAW, determinismo, paridade sem `test_state`,
duelo jogável, ataque no turno 1 liberado só com `test_state` e bloqueado sem
ele); o molde da carta (default = oficial, por-mil→px, molde válido move a
peça, ausente/inválido = default, ATK só em monstro, dado FM na carta, matriz
Rust × jogo + 13 divergências pinadas); e a carta 3D com moldura/orbe/estrela/verso do pack do editor.

**Não coberto (e por quê):**

- **Efeitos:** o dado existe (`effects.json`) e é validado, mas **nenhum sistema
  executa efeito** — ainda não existe motor de efeitos (D30). Cobertura possível
  hoje: 0.
- **Campanha, save/load, áudio, exportação `.astralis` e CI:** não existem no repo.
  Cobertura: 0.
- **Zona de magia:** é navegável e testada (20 slots, 4 fileiras), mas
  **invocar/ativar magia nunca é exercitado** — a regra não existe.
- **A escolha fina da IA:** o rival invoca o primeiro monstro e ataca o primeiro
  em campo. É o que a D55 travou de propósito (a IA é temporária e a escolha
  fina morava no 2D, que saiu no D54/D58) — o que existe hoje **está** coberto
  pelo `test_ia_rival.gd`; o que não existe ainda não pode ser testado.
- **`--project`:** coberto pelo jogo de verdade rodando como processo filho
  (o GUT em si não recebe argumentos de linha de comando). As funções
  `project_base_dir()` e `load_starter_kit()` sem argumento só têm o caminho
  negativo testado no próprio processo; o caminho delas com `--project` só é
  provado pelo jogo filho.
- **Regra que não existe no código** (portanto sem cobertura possível):
  *pierce*, *chain*, reação em cascata, oferta/tributo, equipar/ritual e a
  **guardiã ±500** (existe só um gancho que devolve 0, e isso é testado).
- **Flakiness conhecida:** dois testes esperam a IA de verdade com
  `await wait_seconds(5.0)` —
  `test_fluxo_fiel.gd::test_start_na_mao_nao_passa_e_no_campo_passa` e
  `test_mesa_6bugs.gd::test_bug6_rival_vazio_menu_LP_dano_ATK_cheio_e_IA_direta`.
  Em máquina lenta esses dois podem falhar. Se isso acontecer, **é bug do
  runtime** (a IA roda sem guarda de fim de turno), não do teste: reporte,
  não adapte.
- **`test_seed_sorteio.gd`** pode cair por acaso (o sorteio de quem começa pode
  sair igual nas duelos). É dado do motor (R3), não do teste.
- Os **avisos** de Float/Int comparison vêm do arquivo da faixa 2D e são
  antigos; não são falha.
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
