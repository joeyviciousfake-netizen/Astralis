# astralis/ — Runtime jogável (Godot 4.7, 1920x1080)

Dono: Runtime Engineer. Ver `docs/05_RUNTIME_DUELO.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: mesa 3D jogável e testada — invocar/atacar/fundir/passar, LP, vitória/derrota,
a volta da mesa (a câmera dá 180° e vira o ponto de vista de quem joga, D47-D53) e a
IA do rival, que hoje é **temporária** de propósito (D55: só o primeiro monstro e o
primeiro em campo; a escolha fina mora em `ai/ia_rival.gd` quando existir, D68).
**100% controle (D19): zero mouse e teclado.**

## O que tem aqui

```text
astralis/
  project.godot            <- projeto "Astralis" (3D, 1920x1080, cena inicial = duel3d/mesa_3d)
  main.tscn / main.gd      <- simulação automática do duelo no console (STP; não é o boot)
  core/                    <- data_loader, project_loader, runtime_validator,
                              board_layout (arena) e asset_3d (carregador de .glb)
  duel/                    <- game_state, duel_manager, turn_manager, summon/battle/damage/
                              position/fusion_system (REGRA — a única verdade de gameplay)
  duel3d/                  <- A TELA do duelo em 8 arquivos, UM ASSUNTO CADA (D57/D59-D67):
                              mesa_3d (orquestrador + dono das medidas), painel_carta_3d,
                              faixa_2d, carta_3d (fabrica), menus_3d, vista_3d (camera e a
                              volta), campo_3d (os 20 paineis), cursor_3d
  ai/                      <- ia_rival (a IA ESCOLHE: carta e alvo; a mesa EXECUTA, D68)
  ui/                      <- card_view (a carta 2D/molde; a mesa do duelo saiu no D54/D58)
  testing/                 <- testes GUT + astralis_test_base.gd (base comum)
  campaign/ debug/         <- vazias por enquanto (.gitkeep)
  assets/                  <- 17 assets de carta embutidos (frames/attributes/estrelas/backs)
                              + assets/3d/ (manifest.json = fonte unica dos numeros, D61/D62)
  addons/gut/              <- framework de testes (único addon)
```

O programa Godot fica em `Godot/` na raiz (ignorado no git), não aqui.

## De onde vêm os dados

Sem argumento, o jogo usa a base embutida em `schemas/examples/` (é assim que a suíte de teste roda).
Com pasta de projeto, usa a pasta e **nunca** o `examples/`:

```powershell
.\Godot\Godot_v4.7.2-stable_win64.exe --path astralis -- --project <pasta>
.\Godot\Godot_v4.7.2-stable_win64.exe --path astralis -- --project <pasta> --setup <duel_setup.json>
```

É assim que o Astralis Studio chama (D29): o projeto do editor fica em
`astralis-studio/projects/default/` e abre sempre vazio — o conteúdo entra por Importar pack.
Caminho relativo resolve a partir da raiz do repo. Pasta inválida = aviso PT-BR + cai na embutida.

## Como jogar (só controle, D19/D26)

São 11 ações, todas de controle. Direcional move o cursor; **A/X** confirma; **B** cancela;
**START** passa o turno (só na fase do campo); **L1/R1** alterna Ataque/Defesa; **Y** e **Select** são
reservados (só avisam).

1. D-pad na mão, **A** na carta → ela vai pro centro.
2. **esq/dir** escolhe a face (de costas ou de frente) → **A**.
3. **esq/dir** escolhe um dos 5 slots do seu campo → **A**.
4. **cima/baixo** no menu escolhe a estrela guardiã → **A**. A carta desce **sempre em Ataque**.
5. No campo: **A** na sua carta, **A** no alvo (ou no menu de "direto" se o rival estiver vazio). **START** passa.
6. **cima/baixo** na mão levanta/abaixa cartas: 1 levantada avisa, 2 ou mais combinam (fusão).
   O slot vem **antes** da fusão; a carta final desce em Ataque, de frente, com a estrela escolhida.

Rival joga sozinho. Abaixo de 0 de vida alguém ganha; tentar completar a mão 5 com o deck vazio
também perde.

## Como rodar sem abrir a janela (headless)

Na raiz do repo, no PowerShell:

```powershell
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path astralis --quit-after 30
```

O boot abre **sempre** a mesa 3D, que é a única tela do duelo. Saída real, medida
em 2026-09-30 sem nenhuma flag:

```text
[MESA3D] Duelo: Simon Muran x Jono.
[Duel] Seed 42 -> semente fixa, deterministico. Primeiro jogador: p0 (voce).
[ARENA] Arena oficial OK: 20 slots, uma mesa só (D50).
[ARENA] Arena oficial OK: 20 slots, uma mesa só (D50).
[MESA3D] Arena carregada: 20 slots + mão p0(1240,980,95) p1(1240,20,60).
[MESA3D] Fusões carregadas: 25081 receitas + 0 regras.
[MESA3D] Mesa 3D: duelo real carregado.
[MESA3D] Duelo começou! Sua vez.
```

Esse log é **contrato**: o `test_project_arg.gd` roda o jogo de verdade como
processo filho e prova o `--project`/`--setup` lendo o que ele imprimiu. Por isso
não se mexa nessas linhas sem quebrar o teste.

### Flags (todas depois de `--`, todas de prova — zero regra)

| Flag | O que faz |
|---|---|
| `-- --debug` | liga o log de **diagnóstico** da mesa (janela do campo em pixel, câmera, vão das fileiras, calibração das mãos). O log de boot acima sai **sem** ela (D56) |
| `-- --mesa3d-foto=<caminho.png>` | salva o viewport e sai |
| `-- --mesa3d-foto-frame=N` | em qual quadro a foto sai (padrão 90) |
| `-- --mesa3d-calib=1` | quadrado vermelho de calibração: o que entrar dentro dele está afundado na mesa |
| `-- --mesa3d-auto-passa=<s>` | passa a vez sozinho depois de N segundos, pelo mesmo caminho do START |
| `-- --mesa3d-sair=<s>` | sai sozinho depois de N segundos (validação headless) |

Arena: **uma só, e é do jogo** (D50). A posição dos 20 slots vem SO de
`schemas/examples/arenas/arena_starter.json`; não existe grade no código nem
override por projeto, e o `arena_id` do `duel_setup` é lido e ignorado com
aviso. Arquivo faltando ou quebrado = erro honesto: o log avisa e a mesa não
desenha o campo em vez de inventar uma mesa.

Testes: ver `tests/README.md` (**183/183, 3495 asserts**, ~112 s) — tem o
comando exato e o passo `--import`.
