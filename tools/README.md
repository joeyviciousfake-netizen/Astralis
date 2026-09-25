# tools/ — Scripts de apoio

Dono: QA/Integration. Scripts de validação, conversão e manutenção (nunca gameplay).

- `gerar_cartas_teste.py` — gerou as 30 cartas-monstro do Starter Kit (D20):
  `python tools/gerar_cartas_teste.py` a partir da raiz; saída em `schemas/examples/cards/`.
- `fm_import.py` — gera o FM Original Pack (Systems, só leitura na fonte irmã `memories-decomp/`):
  `python tools/fm_import.py` a partir da raiz; saída em `schemas/packs/fm_original_pack.json` (722+39+39+25131+4041);
  `python tools/fm_import.py --check` valida as 40 atuais + pack contra os schemas.
- `apack.py` — pack de criação `.apack` V1 (Systems, só stdlib, spec em `docs/12_DISTRIBUICAO_EXPORTACAO.md` §12.7):
  `pack` embrulha pack.json+assets num zip único; `check` valida formato+hashes+dado (reusa `fm_import.check_card`);
  `unpack` desempacota conferindo hashes. Legado `.json` = `.apack` sem assets (só aviso "sem imagens").
