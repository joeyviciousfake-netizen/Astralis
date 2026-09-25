# astralis/ — Runtime jogável (Godot 4.7, 1920x1080)

Dono: Runtime Engineer. Ver `docs/05_RUNTIME_DUELO.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: mesa jogável e testada (D22-D29) — invocar/atacar/fundir/passar, IA do rival, LP, vitória/derrota. **100% controle (D19): zero mouse e teclado.**

## O que tem aqui

```text
astralis/
  project.godot            <- projeto "Astralis" (2D, 1920x1080, cena inicial = duel_table)
  main.tscn / main.gd      <- simulação automática do duelo no console (STP; não é o boot)
  core/                    <- data_loader, project_loader, runtime_validator, board_layout
  duel/                    <- game_state, duel_manager, turn_manager, summon/battle/damage/
                              position/fusion_system
  ui/                      <- duel_board (campo), duel_table (mesa jogável, orquestrador), card_view
  testing/                 <- testes GUT (94/94 verde) + astralis_test_base.gd (base comum)
  campaign/ debug/ assets/ <- vazias por enquanto (.gitkeep)
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

Saída esperada (sem erros):

```text
[BOARD] Campo pronto: 20 slots (5+5 por lado) + 4 laterais + emblema.
[TABLE] Arena carregada: 20 slots + mão p0(1240,980,95) p1(1240,20,60).
[TABLE] Fusões carregadas: 25081 receitas + 0 regras.
[TABLE] Duelo começou! Sua vez.
```

Testes: ver `tests/README.md` (GUT 94/94, 1412 asserts) — tem o comando exato e o passo `--import`.
