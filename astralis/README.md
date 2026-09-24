# astralis/ — Runtime jogável (Godot 4.7, 1920x1080)

Dono: Runtime Engineer. Ver `docs/05_RUNTIME_DUELO.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: 1ª TELA JOGÁVEL (D22) — duelo real: invocar/atacar/passar, IA do rival, LP, vitória/derrota.

## O que tem aqui

```text
astralis/
  project.godot            <- projeto "Astralis" (2D, 1920x1080, cena inicial = duel_table)
  main.tscn / main.gd      <- simulação automática do duelo no console (STP)
  core/                    <- data_loader, project_loader, runtime_validator
  duel/                    <- game_state, duel_manager, turn_manager, summon/battle/damage_system
  ui/                      <- duel_board (campo), duel_table (mesa jogável), card_view (carta)
  testing/                 <- testes GUT (15/15 verde)
  campaign/ debug/         <- vazias por enquanto (.gitkeep)
  addons/gut/              <- framework de testes (único addon)
```

O programa Godot fica em `Godot/` na raiz (ignorado no git), não aqui.

## Como jogar

1. Abra o Godot 4.7 (`Godot/Godot_v4.7.2-stable_win64.exe`) e importe `astralis/`.
2. Aperte **F5**: o duelo abre na sua vez, cartas voando pra mão.
3. Clique na carta → slot vazio → Ataque/Defesa/Virada. **Passar** → Batalha → clique no monstro → no rival. Rival joga sozinho.

## Como rodar sem abrir a janela (headless)

Na raiz do repo, no PowerShell:

```powershell
.\Godot\Godot_v4.7.2-stable_win64.exe --headless --path astralis --quit-after 5
```

Saída esperada (sem erros):

```text
[BOARD] Campo pronto: 20 slots (5+5 por lado) + 4 laterais + emblema.
[TABLE] Duelo começou! Sua vez.
```

Testes: ver `tests/README.md` (GUT 15/15).
