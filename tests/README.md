# tests/ — Testes (GUT + cenários)

Dono: QA/Integration. Ver `docs/10_PREVIEW_TESTE_DEBUG.md`.

GUT (código interno do Astralis) + cenários do Test Lab (autor: "esta carta devia...").

## Onde ficam os testes GUT

Os testes GUT moram dentro do projeto Godot, em `astralis/testing/test_*.gd`,
e usam os sistemas reais (R2: proibido Fake — DataLoader, ProjectLoader e
RuntimeValidator de verdade). Framework: GUT 9.7.1 (bitwes, asset 1709),
pasta `astralis/addons/gut/`, compatível com Godot 4.7.

Testes atuais em `astralis/testing/` (GUT 15/15 verde, 77 asserts):
- `test_loader_validator.gd` (3): 40 cartas/2 duelistas/2 decks, 0 erros, fusão receita vence regra.
- `test_duel_core.gd` (12): mão/fases/invocação/ataques/D17 (sem ataque turno 1, só virado em ATK, virada desvira)/dano/LP/deckout/fim em 20 turnos/seed 42.

## Como rodar os testes (sem abrir janela)

Na raiz do repo, no PowerShell:

```powershell
# 1. Importar o projeto (só precisa 1 vez após instalar/atualizar addons)
.\Godot\Godot_v4.7.2-stable_win64.exe --headless --path astralis --import

# 2. Rodar TODOS os testes
.\Godot\Godot_v4.7.2-stable_win64.exe --headless --path astralis -s res://addons/gut/gut_cmdln.gd -gdir=res://testing -gexit

# 3. Rodar UM teste só
.\Godot\Godot_v4.7.2-stable_win64.exe --headless --path astralis -s res://addons/gut/gut_cmdln.gd -gtest=res://testing/test_loader_validator.gd -gexit
```

Resultado esperado: `15/15 passed` + `---- All tests passed! ----`
(exit 0 = passou; diferente de 0 = falhou).

## Como rodar no editor Godot

1. Abra o Godot (`Godot/Godot_v4.7.2-stable_win64.exe`) e importe `astralis/`.
2. Aba **GUT** (embaixo) → botão **Run** (ou F5 com a cena GUT aberta).
3. Teste novo: crie `astralis/testing/test_<assunto>.gd` começando com
   `extends GutTest` e uma função `func test_<caso>() -> void:`.

## Regra de QA

Bug vira teste permanente: SPEC → TEST → IMPLEMENT → RUN → FIX → REGRESSION.
Todo teste novo usa os sistemas reais do Astralis, nunca cópia fake.
