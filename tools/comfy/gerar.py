"""Agente de imagens do Astralis (via ComfyUI local).

Uso:
    python tools/comfy/gerar.py "um dragao de fogo, carta de monstro" [largura altura] [--sem-estilo] [--up]

Requer o ComfyUI Desktop aberto (http://127.0.0.1:8188).
A imagem cai na pasta output do ComfyUI e o caminho e impresso no final.
Modelo padrao: Illustrious-XL-v2.0 (anime, otimo p/ arte de carta).
--sem-estilo desliga o LoRA estilo TCG (padrao: ligado 0.7).
--up sobe 2x com UltraSharp (1024 -> 2048, nitido p/ impressao).
 negative fixo anti-texto/marca (carta nao pode ter assinatura).
"""
import json
import random
import sys
import time
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8188"
CKPT = "Illustrious-XL-v2.0.safetensors"
LORA_ESTILO = "yugioh_style_illustrious.safetensors"
FORCA_ESTILO = 0.7
GATILHO_ESTILO = "yugioh_style"
UPSCALER = "4x-UltraSharp.pth"
NEGATIVO = ("bad quality, worst quality, sketch, blurry, censored, "
            "text, watermark, signature, username")


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def gerar(prompt_pos, width=1024, height=1024, steps=28, cfg=6.0, seed=None,
          estilo=True, up=False):
    seed = seed if seed is not None else random.randint(0, 2**31 - 1)
    if estilo:
        prompt_pos = f"{GATILHO_ESTILO}, {prompt_pos}"
    wf = {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPSetLastLayer",
              "inputs": {"stop_at_clip_layer": -2, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode",
              "inputs": {"text": prompt_pos, "clip": ["2", 0]}},
        "4": {"class_type": "CLIPTextEncode",
              "inputs": {"text": NEGATIVO, "clip": ["2", 0]}},
        "5": {"class_type": "EmptyLatentImage",
              "inputs": {"width": width, "height": height, "batch_size": 1}},
        "6": {"class_type": "KSampler",
              "inputs": {"seed": seed, "steps": steps, "cfg": cfg,
                         "sampler_name": "euler_ancestral", "scheduler": "karras",
                         "denoise": 1.0, "model": ["1", 0],
                         "positive": ["3", 0], "negative": ["4", 0],
                         "latent_image": ["5", 0]}},
        "7": {"class_type": "VAEDecode",
              "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage",
              "inputs": {"images": ["7", 0], "filename_prefix": "astralis"}},
    }
    if estilo:
        wf["9"] = {"class_type": "LoraLoader",
                   "inputs": {"lora_name": LORA_ESTILO,
                              "strength_model": FORCA_ESTILO,
                              "strength_clip": FORCA_ESTILO,
                              "model": ["1", 0], "clip": ["2", 0]}}
        wf["3"]["inputs"]["clip"] = ["9", 1]
        wf["4"]["inputs"]["clip"] = ["9", 1]
        wf["6"]["inputs"]["model"] = ["9", 0]
    if up:
        wf["10"] = {"class_type": "UpscaleModelLoader",
                    "inputs": {"model_name": UPSCALER}}
        wf["11"] = {"class_type": "ImageUpscaleWithModel",
                    "inputs": {"upscale_model": ["10", 0], "image": ["7", 0]}}
        wf["8"]["inputs"]["images"] = ["11", 0]
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, "| seed:", seed, flush=True)
    for _ in range(120):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            for im in h[pid]["outputs"]["8"]["images"]:
                print("PRONTO: output/%s" % im["filename"], flush=True)
            return h[pid]["outputs"]["8"]["images"]
    raise TimeoutError("geracao demorou demais (10 min)")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pos = args[0] if len(args) > 0 else "fantasy monster"
    w = int(args[1]) if len(args) > 1 else 1024
    h = int(args[2]) if len(args) > 2 else 1024
    gerar(f"{pos}, trading card game illustration, detailed anime fantasy art, "
          f"masterpiece, best quality, amazing quality", w, h,
          estilo="--sem-estilo" not in sys.argv, up="--up" in sys.argv)
