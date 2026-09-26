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
| IP-Adapter Plus SDXL | `ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors` | 808 MB | referência visual (fluxo configurável) |
| CLIP Vision H | `clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 2,4 GB | olhos do IP-Adapter |
| ControlNet Union SDXL | `controlnet/controlnet-union-sdxl-1.0.safetensors` | 2,5 GB | controle de pose (esqueleto OpenPose) — workflow fiel v2 |
| Florence-2-large PromptGen v2 | `ComfyUI-Installs/.../models/LLM/Florence-2-large-PromptGen-v2.0` | ~1,5 GB | descritor profissional (analise + legenda + tags) — `ficha.py` |
| CLIP ViT-B/32 | cache do Python (`nota.py` baixa sozinho) | ~350 MB | nota de fidelidade 0..1 (filtro grosso, não veredito) |

> Nota de rede (2026-09-26): o Python do ComfyUI está com SSL quebrado
> (certificado autoassinado na cadeia) e NÃO baixa do HuggingFace sozinho.
> Modelo que o node pedir e não achar: baixe por fora com o script
> temporário de download HF (Python do sistema alcança a rede) direto p/
> a pasta do node, e rode de novo.

Hardware: RTX 5060 8 GB + 24 GB RAM. Geração 1024² ≈ 1 min.

## Usar

1. Abra o ComfyUI Desktop (a API precisa estar no ar).
2. Gerar (com estilo TCG ligado por padrão):
   `python tools/comfy/gerar.py "um mago sombrio com cajado" [largura altura] [--sem-estilo] [--estilo2] [--up] [--base2] [--raw] [--negative <texto>] [--ref <imagem> --peso-ref 0.5] [--ref-weight-type <tipo>]`
   `--base2` troca p/ NoobAI (melhor em humanoide/mãos); `--cfg` afina. `--raw` envia o prompt exatamente como digitado e desliga as adições automáticas; `--estilo`/`--estilo2` podem ser usados explicitamente.
   `--detalhar` refina mãos+rosto sozinho (detecta, refaz em alta, cola sem costura).
   `--ref` envia uma imagem de referência ao IP-Adapter. O preset atual usa `style transfer precise`, mas isso é configuração técnica do workflow, não uma regra de conteúdo; o usuário pode alterar o workflow para outras formas de referência (precisa do node `ComfyUI_IPAdapter_plus`).
3. Limpar assinatura/marca da borda de baixo:
   `python tools/comfy/limpar.py <imagem> [--base 12] [--saida <png>] [--denoise 0.9]`
4. Descrever imagem (olha e escreve o que ve, vira base de prompt):
   `python tools/comfy/descrever.py <imagem> [--saida <txt>]`
5. Workflow FIEL v2 (mesmo personagem, pose nova — o padrão p/ os 700):
   `python tools/comfy/ficha.py <ref> --nome <id>` gera o RASCUNHO da ficha;
   humano revisa e congela `prompt_aparencia` + `nao_fazer` (1x por personagem).
   `python tools/comfy/gerar_fiel.py --ref <img> --ficha fichas/<id>.json --pose <nome> --acao "<nova acao>"`
   junta identidade (IPAdapter `strong middle` 0.75) + pose (ControlNet Union 1.0
   com tipo `openpose` explícito via SetUnionControlNetType + esqueleto de
   `pose.py`: neutra, pular, voar_lancar, surfar, correr).
   Config congelada no piloto do relógio: LoRA TCG em 0.5 (0.0/0.3 quebram o
   personagem em bola+coadjuvante; 0.5≈0.7, fica 0.5); ficha com palavras de
   arquétipo MANTIDAS (tirar "creature/magician/belly" colapsou tudo em mandala
   mecânica — testado e revertido; a teoria de "só geometria" perdeu no bake-off).
   `python tools/comfy/partes.py checar <gerada> <ficha>` confere partes críticas
   por grounding (caixa+região) sem node novo; `python tools/comfy/reparo.py
   <gerada> <ref> <ficha> <parte>` tenta inpaint regional da parte (máscara no
   corpo achado por grounding + crop da ref via IPAdapter; ainda em ajuste de
   força — pintar elemento novo resiste, reparar preserva o resto).
   `python tools/comfy/nota.py <ref> <geradas...>` dá a nota 0..1 p/ bake-off.
   Na tela: arraste `gerar_fiel_tela.json`. Ficha modelo: `fichas/relogio.json`.
   Regra honesta: nota é filtro grosso (fundo parecido infla); veredito final é
   checklist humano (silhueta, partes obrigatórias, pose). Não negativar
   citando o defeito com enfase costuma piorar (virou bobo com chifres ao
   proibir "jester" — registrado no bake-off do relógio).
6. Ver na tela do ComfyUI: arraste `gerar_tela.json`, `gerar_livre_tela.json` ou `limpar_tela.json` para dentro da tela. `gerar_livre_tela.json` é o fluxo de autoria direta: sem LoRA obrigatório, prompt editável e negativo apenas de qualidade.
   Seus trabalhos por comando também aparecem na fila e no output.

## Regras

- O Studio não impõe blacklist de personagem, franquia, copyright, marca ou estilo.
- O negativo padrão do `gerar.py` é apenas de qualidade (`bad quality`, etc.). Use `--negative` ou edite o workflow para definir exatamente os condicionamentos desejados.
- Referências visuais são parâmetros do workflow: nenhuma substituição automática por personagem genérico/original é feita.
- Resultado bom vira asset do projeto via fluxo normal
  (importar asset → `.apack` leva junto).
- Prova de funcionamento: dragão branco de olhos azuis 1024²
  (`astralis_test_00001_.png` no output do Comfy, 2026-09-26).
