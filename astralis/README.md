# astralis/ — Runtime jogável (Godot 4.7, 1920x1080)

Dono: Runtime Engineer. Ver `docs/05_RUNTIME_DUELO.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: mesa jogável e testada (D22-D29) — invocar/atacar/fundir/passar, IA do rival, LP, vitória/derrota. **100% controle (D19): zero mouse e teclado.**

## O que tem aqui

```text
astralis/
  project.godot            <- projeto "Astralis" (3D, 1920x1080, cena inicial = duel3d/mesa_3d)
  main.tscn / main.gd      <- simulação automática do duelo no console (STP; não é o boot)
  core/                    <- data_loader, project_loader, runtime_validator, board_layout
  duel/                    <- game_state, duel_manager, turn_manager, summon/battle/damage/
                               position/fusion_system (regra, usada pelo 3D e pelo legado)
  duel3d/                  <- mesa_3d (mesa 3D OFICIAL, orquestrador; boot + --cenario3d)
  duel_legacy2d/           <- duel_table + duel_board (mesa 2D aposentada, só emergência)
  ui/                      <- card_view (carta 2D, usada pelo legado)
  testing/                 <- testes GUT + astralis_test_base.gd (base comum)
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

O boot abre sempre a mesa 3D. Volta ao legado 2D só em emergência:

```powershell
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path astralis --quit-after 30 -- --cenario3d 0
```

Saída esperada (sem erros):

```text
[MESA3D] Janela do campo: x=562..1920 px (29.3%..100% da tela), 1358x1080, altura toda.
[MESA3D] Ambiente: céu azul + neblina + pilares + câmera no PIVÔ da mesa (a volta da mesa, D47).
[MESA3D] Arena carregada: 20 slots + mão p0(1240,980,95) p1(1240,20,60).
[MESA3D] Campo: 20 painéis + faixa do meio (7 itens) + Cursor3D.
[MESA3D] Faixa 2D: 7 celulas em x=620..1862 y=450..514 (vao das fileiras 438..525 px).
[MESA3D] Fusões carregadas: 25081 receitas + 0 regras.
[MESA3D] Mesa 3D: duelo real carregado.
[MESA3D] Duelo começou! Sua vez.
[MESA3D] Pronta: mão p0=5 p1=5, assets embutidos=17/17.
```

Prova de que a arena é uma só (D48): com o projeto **sem** pasta `arenas/`, o
jogo avisa `[ARENA] Sem arena no projeto: usando a grade padrão.` e mesmo assim
o `p0_m2` cai em `janela=(679.0, 597.246) tela_x=1241.0` — coordenada idêntica à
de quem tem o arquivo, porque a grade embutida É a arena oficial.

Testes: ver `tests/README.md` (**178/178, 3835 asserts**, ~160 s) — tem o comando exato e o passo `--import`.
