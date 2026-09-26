# Agente de imagens (ComfyUI local)

O ComfyUI Desktop do Max virou nosso gerador de imagens: o Lead manda o
trabalho pela API (`http://127.0.0.1:8188`) e busca o resultado. Sem subagente
novo — é ferramenta operada pelo Lead via terminal.

## Modelos instalados (2026-09-26, pasta `ComfyUI-Shared/models/`)

| Modelo | Pasta/arquivo | Tamanho | Uso |
|---|---|---|---|
| Illustrious-XL-v2.0 | `checkpoints/Illustrious-XL-v2.0.safetensors` | 6,46 GB | arte anime (cartas) |
| SDXL VAE | `vae/sdxl_vae.safetensors` | 319 MB | decodificador dedicado |
| SDXL inpainting 0.1 | `diffusers/sdxl-1.0-inpainting-0.1/` (fp16) | 6,62 GB | limpar molduras (via `DiffusersLoader`) |

Hardware: RTX 5060 8 GB + 24 GB RAM. Geração 1024² ≈ 1 min.

## Usar

1. Abra o ComfyUI Desktop (a API precisa estar no ar).
2. `python tools/comfy/gerar.py "um mago sombrio com cajado" [largura altura]`
3. A imagem cai no `output` do ComfyUI; o script imprime o nome do arquivo.

## Regras

- Carta nunca leva texto/marca gerados: o negativo fixo barra
  (`text, watermark, signature`).
- Resultado bom vira asset do projeto via fluxo normal
  (importar asset → `.apack` leva junto).
- Prova de funcionamento: dragão branco de olhos azuis 1024²
  (`astralis_test_00001_.png` no output do Comfy, 2026-09-26).
