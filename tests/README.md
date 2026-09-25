# tests/ — índice dos testes (GUT)

Dono: **QA/Integration**. Este arquivo é só o índice. A suíte mora dentro do
projeto Godot, em `astralis/testing/`. Ver `docs/10_PREVIEW_TESTE_DEBUG.md`.

Os testes usam a mesa e os sistemas **de verdade** do Astralis: o mesmo
`DuelManager`, `SummonSystem`, `BattleSystem`, `DamageSystem`, `TurnManager`,
`FusionSystem`, `DataLoader`, `BoardLayout` e a mesma cena `duel_table.tscn`
que o jogo usa. Não existe cópia "fake" de nada (regra **R2**).

## Números de hoje

| | |
|---|---|
| Arquivos de teste | **12** (+ 1 base de helpers) |
| Testes | **102** |
| Asserções | **1544** |
| Tempo (headless) | **~45 s** (~10 s deles são 2 testes que esperam a IA real) |
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
no terminal. O resultado bom é `102/102 passed` + `---- All tests passed! ----`
e o `Time` em ~45 s. O GUT sai com código 0 quando passa.

Rodar direto no editor também funciona: abra `Godot/Godot_v4.7.2-stable_win64.exe`,
importe `astralis/`, aba **GUT** → **Run**.

## Os 12 arquivos e o que cada um trava

| Arquivo | Testes | O que trava |
|---|---:|---|
| `test_duel_core.gd` | 16 | O motor de duelo: mão 5/5 sem carta extra + refill até 5 nos 2 lados, ordem das fases, 1 invocação por MAIN, 1 ataque por monstro, D17 (jogador 0 não ataca no 1º turno, só virado em Ataque ataca, a virada desvira ao ser atacada), dano e cura com teto no LP inicial, LP zerado declara vencedor, deck out, duelo automático termina em até 20 turnos, mesma seed = mesmo resultado, empate Ataque×Defesa e Ataque×Ataque, ATK/DEF limitados a 9999, e a carta real `fm_0001` (Blue-eyes 3000) causando 3000 de dano. |
| `test_loader_validator.gd` | 5 | O conteúdo e o contrato: 722 cartas `fm_*`, 39 duelistas, 39 decks de 40 cartas, duelo de abertura (Simon Muran × Jono, 8000 LP), `fm_0001` dentro do schema, customs preservados no `starter_backup`, validação sem nenhum erro, e as 25081 receitas de fusão com a receita explícita `fm_0002 + fm_0008 = fm_0638` e 0 regras genéricas. |
| `test_board_layout.gd` | 14 | O desenho da arena: 20 slots com ID fixo, XY do JSON só move o desenho (a carta continua indo pelo índice), arquivo ausente/ruído cai na grade padrão, espelho do rival no X e nas fileiras (D25), mão p0/p1 com fallback para arena antiga, rival desenhado só com a **quantidade** (nunca id nem nome), mão centralizada, e criar/liberar a mesa 2× sem erro. |
| `test_compra_fila.gd` | 5 | A compra fiel FM: início 5/5 sem extra, refill até 5 nos 2 lados depois de jogar, deck out só na hora de completar (mão cheia com deck vazio **não** perde), e a animação da fila de fusão que é só visual (não mexe no estado, funciona headless). |
| `test_fusao_fiel.gd` | 16 | Mão reta + fusão fiel: mão sempre reta e centralizada, levantar/abaixar com selo que renumera sozinho, 0 levantadas = avulsa e 1 = bloqueia com aviso, receita que ignora a ordem, regra genérica por prioridade, equip pendente, cadeia par a par que descarta a acumulada na falha, resultado descendo face para cima em Ataque, slot escolhido **antes** da fusão, e o slot ocupado (avulsa e combinação encontram o campo pelo `FusionSystem` real). |
| `test_fluxo_fiel.gd` | 5 | O fluxo da mesa: na fase da mão o cursor nunca sai da mão, a carta desce sempre em Ataque com a face e a estrela escolhidas, RB/LB travado depois do ataque, e START que não passa na fase da mão mas passa na de campo. |
| `test_mesa_3bugs.gd` | 3 | 3 bugs da mesa: o menu não oferece Atacar inválido no 1º turno (a mesa pergunta ao `can_attack` real), a carta fica centrada no slot nos 2 lados, e o rival virado 180° (frente e verso) com Defesa somando 90°. |
| `test_mesa_6bugs.gd` | 6 | 6 bugs da mesa: carta virada desce escondida nos 2 lados, o menu da estrela abre por cima da carta, a navegação alcança as 4 fileiras (20 slots, magia inclusa), no rival a direita aumenta o X de tela, cima/baixo nas bordas não fogem para o LP nem para a mão, e rival vazio oferece o LP com dano ATK cheio + a IA atacando direto. |
| `test_ia_ataque.gd` | 5 | A escolha de ataque da IA: campo vazio → direto com o mais forte, abate com o mais fraco que vence, só Defesa forte → o rival passa, empate Ataque×Ataque ataca e os dois caem, e o bônus de guardião que ainda devolve 0 (adiado, D28). |
| `test_gamepad.gd` | 7 | Controle 100% gamepad (D19/D26): as 11 ações existem, confirmar e cancelar não dividem botão, as direções são só joypad, o cursor anda e volta pelo passo real, cancelar limpa a escolha, e a mesa **não tem nenhum** botão/texto/carta clicável. |
| `test_project_arg.gd` | 12 | O `--project` e o `--setup`: sem argumento usa a pasta embutida, pasta inválida é reprovada, pasta válida é reconhecida pelos marcadores, caminho relativo resolve na raiz do repo, relativo inexistente avisa e cai na embutida, as duas formas (`--project pasta` e `--project=pasta`) dão o mesmo resultado, `--setup` por cima do projeto **vence** o duelo do projeto, `--setup` inválido avisa e segue com o do projeto, e a regra nova: projeto **sem arena** → o jogo avisa, `project_arena_path()` devolve vazio e a mesa usa a grade padrão com os 20 slots e o espelho certo. |
| `test_campo_testes.gd` | 8 | O Campo de Testes (tab Testes do Studio): com `test_state`, o duelo começa em p0 na DRAW (fase da mão, D24), `my_hand` (fm_0001 + fm_0002) vira a mão de p0 na ordem + refill real até 5, o campo vira instâncias reais (ATK/DEF da base, face/posição do dado, estrela = guardiã 1, null = vazio nas magias), seed 42 fixa dá o mesmo campo + mão + deck em 2 montagens, sem `test_state` tudo igual a antes (5/5, campo vazio), o duelo de teste é jogável (DRAW→MAIN + 1 invocação normal), e o ataque no turno 1: **com** `test_state` p0 ataca na BATTLE e mata como o motor manda (fm_0001 3000 × fm_0004 1200 = 1800 de dano, 8000→6200), **sem** `test_state` p0 continua bloqueado com `Sem ataque no 1º turno.` (D15/D17). |

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
- paridade sem `test_state`, duelo jogável, ataque no turno 1 liberado só com
 `test_state` e bloqueado sem ele).

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
