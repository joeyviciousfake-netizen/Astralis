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

## `blender/` — a ponte para o Blender (doc 17)

Dono: QA/Integration (script de dev) + o carregador no jogo é do runtime
(`astralis/core/asset_3d.gd`). Especificação completa em `docs/17_ASSETS_3D.md`.

- `iniciar_blender.py` — roda **dentro** do Blender (`--python`): habilita o
  add-on `mcp-for-blender`, **força o Cycles na GPU (OptiX, RTX 5060)**, abre o
  `.blend` pedido e sobe o socket do MCP.
  Existe porque o auto-start do add-on **não dispara no Blender 5.2.2 LTS**
  (medido em 2026-09-30); chamar `start_server` na mão sobe na hora.
  **A GPU é forçada, não é preferência** (D62): o backend é escolha de máquina
  e não mora no `.blend`, e o dispositivo **CPU do Cycles é desligado** para o
  render "de GPU" não escorregar para o processador em silêncio. Se nenhuma GPU
  for encontrada, o script **avisa em vez de seguir calado**.
- `abrir_blender.ps1` — o launcher de uso: acha o Blender (env `BLENDER`, senão
  a versão mais nova em `Program Files\Blender Foundation`), chama o
  `iniciar_blender.py` e informa a porta. Um comando, sem clique.
  Ele sobe com **`-NoNewWindow`** de propósito: sem isso o Blender é um app GUI
  sem console ligado e as linhas `[ASTRALIS]` (backend de render, se o MCP
  subiu) são **descartadas** — foi assim que um aviso de GPU ficou invisível.
  As linhas aparecem **na janela do PowerShell de onde você chamou**.
  ```powershell
  .\tools\blender\abrir_blender.ps1 -Blend astralis\assets\3d\fonte\estrela_teste.blend
  ```
- `exportar_assets.py` — o **único** caminho do Blender para o repositório
  (headless, determinístico, CI-ável). Lê `astralis/assets/3d/manifest.json`,
  exporta cada `.blend` em `.glb`, **mede o `.glb` gerado** (lendo o arquivo,
  não reimportando no Blender — medir no ida-e-volta devolveria os eixos do
  Blender e a trava passaria errado) e falha se não bater com o manifesto.
  Também recusa `.glb` com transform no nó.
  ```powershell
  & $env:BLENDER --background --factory-startup --python tools\blender\exportar_assets.py -- exportar
  & $env:BLENDER --background --factory-startup --python tools\blender\exportar_assets.py -- medir
  ```
- `preview.py` — a **prévia oficial** de um asset: **Cycles na GPU** (D62;
  backend OptiX medido nesta máquina, RTX 5060). GPU é obrigatória — sem GPU o
  script falha em vez de renderizar na CPU — e o dispositivo CPU do Cycles fica
  desligado, para o render não escorregar para ele. Amostras e semente fixas,
  cenário de 3 luzes montado pelo script (sem HDRI e sem arquivo externo) e
  enquadramento 3/4 calculado da caixa do asset, para duas prévias serem
  comparáveis. Não salva o `.blend`.
  ```powershell
  & $env:BLENDER --background --factory-startup `
      --python tools\blender\preview.py -- --asset estrela_teste --out "$env:TEMP\pv.png"
  # e o A/B pixel a pixel (o Cycles na GPU não é bit-exato entre execuções):
  & $env:BLENDER --background --factory-startup `
      --python tools\blender\preview.py -- --asset estrela_teste --out b.png --comparar a.png
  ```

O outro lado da trava é `astralis/testing/test_assets_3d.gd` (GUT), que mede o
mesmo `.glb` do lado do Godot. Duas medidas independentes, um manifesto só.
