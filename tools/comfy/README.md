# Agente de imagens (ComfyUI local)

O ComfyUI Desktop do Max virou nosso gerador de imagens: o Lead manda o
trabalho pela API (`http://127.0.0.1:8188`) e busca o resultado. Sem subagente
novo — é ferramenta operada pelo Lead via terminal.

## Modelos instalados (2026-09-26, pasta `ComfyUI-Shared/models/`)

| Modelo | Pasta/arquivo | Tamanho | Uso |
|---|---|---|---|
| Illustrious-XL-v2.0 | `checkpoints/Illustrious-XL-v2.0.safetensors` | 6,46 GB | base padrão (limpa, CFA 5) |
| NoobAI-XL-v1.1 | `checkpoints/NoobAI-XL-v1.1.safetensors` | 6,62 GB | base alternativa (humanoides/mãos, CFG 6.5, `--base2`) |
| SDXL VAE | `vae/sdxl_vae.safetensors` | 319 MB | decodificador dedicado |
| SDXL inpainting 0.1 | `diffusers/sdxl-1.0-inpainting-0.1/` (fp16) | 6,62 GB | limpar molduras (via `DiffusersLoader`) |
| LoRA estilo TCG | `loras/yugioh_style_illustrious.safetensors` | 218 MB | traço estilo carta (gatilho `yugioh_style`, força 0,7) |
| LoRA 14k (sabor sombrio) | `loras/yugioh_14k_sdxl.safetensors` | 651 MB | treinado em 14 mil cartas, traço mais pintado/dramático (gatilho `glowing, yugioh style, yugioh monster, duel monster`, `--estilo2`) |
| UltraSharp 4x | `upscale_models/4x-UltraSharp.pth` | ~67 MB | hi-res 1024 → 2048 |
| IP-Adapter Plus SDXL | `ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors` | 808 MB | referência visual (só estilo) |
| CLIP Vision H | `clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 2,4 GB | olhos do IP-Adapter |

Hardware: RTX 5060 8 GB + 24 GB RAM. Geração 1024² ≈ 1 min.

## Usar

1. Abra o ComfyUI Desktop (a API precisa estar no ar).
2. Gerar (com estilo TCG ligado por padrão):
   `python tools/comfy/gerar.py "um mago sombrio com cajado" [largura altura] [--sem-estilo] [--estilo2] [--up] [--base2] [--ref <imagem> --peso-ref 0.5]`
   `--base2` troca p/ NoobAI (melhor em humanoide/mãos); `--cfg` afina.
   `--detalhar` refina mãos+rosto sozinho (detecta, refaz em alta, cola sem costura).
   `--ref` mostra uma imagem de referência e copia SÓ o estilo
   (precisa do node `ComfyUI_IPAdapter_plus`; referência quadrada funciona melhor).
3. Limpar assinatura/marca da borda de baixo:
   `python tools/comfy/limpar.py <imagem> [--base 12] [--saida <png>] [--denoise 0.9]`
4. Descrever imagem (olha e escreve o que ve, vira base de prompt):
   `python tools/comfy/descrever.py <imagem> [--saida <txt>]`
5. Ver na tela do ComfyUI: arraste `tools/comfy/workflows/gerar_tela.json`
   ou `limpar_tela.json` para dentro da tela (são os mesmos fluxos dos scripts).
   Seus trabalhos por comando também aparecem na fila e no output.

## Regras

- Carta nunca leva texto/marca gerados: o negativo fixo barra
  (`text, watermark, signature`).
- Resultado bom vira asset do projeto via fluxo normal
  (importar asset → `.apack` leva junto).
- Prova de funcionamento: dragão branco de olhos azuis 1024²
  (`astralis_test_00001_.png` no output do Comfy, 2026-09-26).
