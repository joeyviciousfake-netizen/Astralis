"""Agente de imagens do Astralis (via ComfyUI local).

Uso:
    python tools/comfy/gerar.py "um dragao de fogo, carta de monstro" [largura altura] [--sem-estilo] [--up]

Requer o ComfyUI Desktop aberto (http://127.0.0.1:8188).
A imagem cai na pasta output do ComfyUI e o caminho e impresso no final.
Modelo padrao: Illustrious-XL-v2.0 (anime, otimo p/ arte de carta).
--sem-estilo desliga o LoRA estilo TCG (padrao: ligado 0.7).
--estilo2 usa o LoRA 14k (sabor mais sombrio/pintado).
--ref <imagem> mostra uma referencia p/ o IP-Adapter copiar SO o estilo
   (nunca o desenho) — pede Comfy reiniciado apos instalar o node.
--peso-ref <0..1> forca da referencia (padrao 0.5).
--ckpt <arquivo> troca a base; --base2 = NoobAI (alternativa p/ humanoides);
   --cfg <n> afina o CFG.
--detalhar refina mao + rosto com detector (Impact, mais lento).
--up sobe 2x com UltraSharp (1024 -> 2048, nitido p/ impressao).
 negative fixo anti-texto/marca (carta nao pode ter assinatura).
"""
import json
import os
import random
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:8188"
CKPT = "Illustrious-XL-v2.0.safetensors"
LORA_ESTILO = "yugioh_style_illustrious.safetensors"
FORCA_ESTILO = 0.7
GATILHO_ESTILO = "yugioh_style"
LORA_ESTILO2 = "yugioh_14k_sdxl.safetensors"
FORCA_ESTILO2 = 0.7
GATILHO_ESTILO2 = "glowing, yugioh style, yugioh monster, duel monster"
BASE2 = "NoobAI-XL-v1.1.safetensors"
CFG_BASE2 = 6.5
IPADAPTER = "ip-adapter-plus_sdxl_vit-h.safetensors"
CLIP_VISION = "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
PESO_REF = 0.5
UPSCALER = "4x-UltraSharp.pth"
NEGATIVO = ("bad quality, worst quality, sketch, blurry, censored, "
            "text, letters, words, caption, watermark, signature, username, "
            "logo, copyright, card frame, border, text box, ui, interface")


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def gerar(prompt_pos, width=1024, height=1024, steps=28, cfg=6.0, seed=None,
          estilo=True, estilo2=False, up=False, ref=None, peso_ref=PESO_REF,
          ckpt=CKPT, detalhar=False):
    seed = seed if seed is not None else random.randint(0, 2**31 - 1)
    lora_nome, lora_forca, gatilho = LORA_ESTILO, FORCA_ESTILO, GATILHO_ESTILO
    if estilo2:
        estilo, lora_nome = True, LORA_ESTILO2
        lora_forca, gatilho = FORCA_ESTILO2, GATILHO_ESTILO2
    if estilo:
        prompt_pos = f"{gatilho}, {prompt_pos}"
    modelo_no, clip_no = "1", "2"
    if ref:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from limpar import upload
        up = upload(ref)
        wf_ref = {
            "20": {"class_type": "IPAdapterModelLoader",
                   "inputs": {"ipadapter_file": IPADAPTER}},
            "21": {"class_type": "CLIPVisionLoader",
                   "inputs": {"clip_name": CLIP_VISION}},
            "22": {"class_type": "LoadImage",
                   "inputs": {"image": up["name"]}},
        }
    else:
        wf_ref = {}
    wf = {
        "1": {"class_type": "CheckpointLoaderSimple",
              "inputs": {"ckpt_name": ckpt}},
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
                   "inputs": {"lora_name": lora_nome,
                              "strength_model": lora_forca,
                              "strength_clip": lora_forca,
                              "model": [modelo_no, 0], "clip": ["2", 0]}}
        wf["3"]["inputs"]["clip"] = ["9", 1]
        wf["4"]["inputs"]["clip"] = ["9", 1]
        wf["6"]["inputs"]["model"] = ["9", 0]
        modelo_no = "9"
    if ref:
        wf.update(wf_ref)
        wf["23"] = {"class_type": "IPAdapterAdvanced",
                    "inputs": {"model": [modelo_no, 0],
                               "ipadapter": ["20", 0],
                               "image": ["22", 0],
                               "clip_vision": ["21", 0],
                               "weight": peso_ref,
                               "weight_type": "style transfer precise",
                               "combine_embeds": "concat",
                               "start_at": 0.0, "end_at": 1.0,
                               "embeds_scaling": "V only"}}
        wf["6"]["inputs"]["model"] = ["23", 0]
    if up:
        wf["10"] = {"class_type": "UpscaleModelLoader",
                    "inputs": {"model_name": UPSCALER}}
        wf["11"] = {"class_type": "ImageUpscaleWithModel",
                    "inputs": {"upscale_model": ["10", 0], "image": ["7", 0]}}
        wf["8"]["inputs"]["images"] = ["11", 0]
    if detalhar:
        import subprocess
        import tempfile
        venv = ("C:/Users/Max/AppData/Local/Comfy-Desktop/ComfyUI-Installs/"
                "ComfyUI/ComfyUI/.venv/Scripts/python.exe")
        det = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "detalhar.py")
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, "| seed:", seed, flush=True)
    for _ in range(120):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            for im in h[pid]["outputs"]["8"]["images"]:
                print("PRONTO: output/%s" % im["filename"], flush=True)
                receita = {"trabalho": pid, "seed": seed, "prompt": prompt_pos,
                           "tamanho": [width, height], "lora": lora_nome if estilo else None,
                           "referencia": ref, "peso_ref": peso_ref if ref else None,
                           "up": up, "detalhar": detalhar, "base": ckpt,
                           "fluxo_tela": "tools/comfy/workflows/gerar_tela.json"}
                try:
                    outdir = os.path.join(os.path.expanduser("~"),
                                          "AppData", "Local", "Comfy-Desktop",
                                          "ComfyUI-Shared", "output")
                    base = os.path.splitext(im["filename"])[0] + ".job.json"
                    json.dump(receita, open(os.path.join(outdir, base), "w", encoding="utf-8"),
                              ensure_ascii=False, indent=1)
                    print("receita:", base, flush=True)
                except OSError:
                    pass
                if detalhar:
                    q = urllib.parse.urlencode(
                        {"filename": im["filename"],
                         "subfolder": im["subfolder"], "type": im["type"]})
                    raw = urllib.request.urlopen(
                        f"{BASE}/view?{q}", timeout=120).read()
                    with tempfile.NamedTemporaryFile(
                            suffix=".png", delete=False) as tf:
                        tf.write(raw)
                        tmp_img = tf.name
                    dst = os.path.join(
                        os.path.expanduser("~"), "AppData", "Local",
                        "Comfy-Desktop", "ComfyUI-Shared", "output",
                        os.path.splitext(im["filename"])[0] + "_det.png")
                    r = subprocess.run(
                        [venv, det, tmp_img, "--saida", dst],
                        capture_output=True, text=True, timeout=1500)
                    print(r.stdout[-500:] if r.stdout else r.stderr[-500:],
                          flush=True)
                    os.remove(tmp_img)
                    print("DETALHADO:", os.path.basename(dst), flush=True)
            return h[pid]["outputs"]["8"]["images"]
    raise TimeoutError("geracao demorou demais (10 min)")


if __name__ == "__main__":
    full = sys.argv[1:]
    ref = full[full.index("--ref") + 1] if "--ref" in full else None
    peso = float(full[full.index("--peso-ref") + 1]) if "--peso-ref" in full else PESO_REF
    ckpt = full[full.index("--ckpt") + 1] if "--ckpt" in full else CKPT
    cfgv = float(full[full.index("--cfg") + 1]) if "--cfg" in full else 6.0
    if "--base2" in full:
        ckpt, cfgv = BASE2, CFG_BASE2
    det = "--detalhar" in full
    pos = [a for a in full if not a.startswith("--") and a != ref
           and a != str(peso)]
    pos = pos[0] if len(pos) > 0 else "fantasy monster"
    nums = []
    for a in full:
        if a.startswith("--") or a == ref:
            continue
        try:
            nums.append(int(a))
        except ValueError:
            pass
    w = nums[0] if len(nums) > 0 else 1024
    h = nums[1] if len(nums) > 1 else 1024
    gerar(f"{pos}, trading card game illustration, detailed anime fantasy art, "
          f"masterpiece, best quality, amazing quality", w, h,
          estilo="--sem-estilo" not in full,
          estilo2="--estilo2" in full, up="--up" in full,
          ref=ref, peso_ref=peso, ckpt=ckpt, cfg=cfgv, detalhar=det)
