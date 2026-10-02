# tools/ — Scripts de apoio

Dono: QA/Integration. Scripts de validação, conversão e manutenção (nunca gameplay).

- `gerar_cartas_teste.py` — gerou as 30 cartas-monstro do Starter Kit (D20):
  `python tools/gerar_cartas_teste.py` a partir da raiz; saída em `schemas/examples/cards/`.
- `fm_import.py` — gera o FM Original Pack (Systems, só leitura na fonte irmã `memories-decomp/`):
  `python tools/fm_import.py` a partir da raiz; saída em `schemas/packs/fm_original_pack.json` (722+39+39+25131+4041);
  `python tools/fm_import.py --check` valida as 40 atuais + pack contra os schemas.
- `checar_docs.py` — **portão de documento**: a R14 virando trava mecânica
  (QA, só leitura). Regex contra o disco, sem IA, ~0,7 s. Falha (`rc=1`) se
  qualquer `.md` guardar **data ISO, cabeçalho `VERSION:`, número de versão,
  changelog, contagem de teste, hash de commit, narrativa de mudança
  ("antes era", "agora é", "passou a", "virou", "saiu no Dnn"), caminho entre
  backticks que não existe em disco, ou `arquivo:linha` com linha maior que o
  arquivo** — mais doc acima do orçamento de KB.
  O item do caminho é o que mais importa: caminho morto é a divergência mais cara,
  porque a IA lê, acredita e escreve código que não compila.
  `AGENTS.md` fica de fora de propósito (é o protocolo e contém os exemplos de
  crônica da própria R14).
  ```powershell
  python tools/checar_docs.py --relatorio   # só o inventário (KB, teto, linhas)
  python tools/checar_docs.py               # o portão; rc=1 = não commitar
  ```
- `apack.py` — pack de criação `.apack` V1 (Systems, só stdlib, spec em
  `docs/12_DISTRIBUICAO_EXPORTACAO.md` §12.7):
  `pack` embrulha pack.json+assets num zip único; `check` valida formato+hashes+dado (reusa `fm_import.check_card`);
  `unpack` desempacota conferindo hashes. Legado `.json` = `.apack` sem assets (só aviso "sem imagens").
