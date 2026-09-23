# astralis/ — Runtime (Godot 4.7)

Dono: Runtime Engineer. Ver `docs/05_RUNTIME_DUELO.md`, `docs/13_TABULEIRO_DUELO.md`.
Status: ETAPA 1 — só carregar + validar Starter Kit (sem duelo/efeito/fusão ainda, R5).

## O que tem aqui

```text
astralis/
  project.godot            <- projeto Godot "Astralis" (2D, 1280x720)
  main.tscn / main.gd      <- cena inicial: carrega Starter Kit, valida, imprime no console
  core/                    <- data_loader.gd, project_loader.gd, runtime_validator.gd
  duel/ campaign/ ui/      <- vazias por enquanto (.gitkeep)
  assets/ debug/ testing/  <- vazias por enquanto (.gitkeep)
```

O programa Godot fica em `Godot/` na raiz (ignorado no git), não aqui.

## Como abrir no Godot

1. Abra o Godot 4.7 (arquivo `Godot/Godot_v4.7.2-stable_win64.exe` na raiz do repo).
2. Clique em **Importar**, escolha a pasta `astralis/` (arquivo `project.godot`).
3. Aperte **Play** (ou F5). Olhe o console embaixo: deve aparecer `STP: 10 cartas, 2 duelistas...`.

## Como rodar sem abrir a janela (headless)

Na raiz do repo, rode no PowerShell:

```powershell
.\Godot\Godot_v4.7.2-stable_win64.exe --headless --path astralis --quit-after 5
```

Saída esperada (sem erros):

```text
[Astralis] STP: 10 cartas, 2 duelistas, 2 decks, erros=0
[Astralis] OK: Starter Kit válido, sem erros.
```

Se aparecer `ERRO: ...`, a mensagem diz o que falta (ex.: carta que não existe, vida zerada).
