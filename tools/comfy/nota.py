"""Nota de fidelidade do Astralis (portao de qualidade, sem olho humano).

Compara a referencia com a imagem gerada via CLIP (cosseno 0..1):
quanto mais perto de 1, mais fiel. Serve p/ bake-off (escolher a
melhor semente/config) e p/ fiscalizar o lote dos 700 por amostragem.

Uso:
    python tools/comfy/nota.py <referencia> <gerada> [gerada2 ...]
Na 1a vez baixa o ViT-B/32 (~350 MB).
"""
import sys

import open_clip
import torch
from PIL import Image


def carregar():
    modelo, _, prep = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k")
    tok = open_clip.get_tokenizer("ViT-B-32")
    modelo.eval()
    return modelo, prep


@torch.no_grad()
def vetor(modelo, prep, caminho):
    img = prep(Image.open(caminho).convert("RGB")).unsqueeze(0)
    v = modelo.encode_image(img)
    return v / v.norm(dim=-1, keepdim=True)


def nota(ref_v, modelo, prep, caminho):
    v = vetor(modelo, prep, caminho)
    return float((ref_v @ v.T).item())


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("uso: nota.py <referencia> <gerada> [gerada2 ...]")
        sys.exit(1)
    modelo, prep = carregar()
    ref_v = vetor(modelo, prep, sys.argv[1])
    for g in sys.argv[2:]:
        print(f"{nota(ref_v, modelo, prep, g):.3f}  {g}", flush=True)
