"""Ficha do personagem (descritor v2: automatico + revisao humana).

Gera o RASCUNHO da ficha a partir da referencia usando o PromptGen-large
(analise estruturada + legenda mista + tags). O rascunho NAO e usado direto:
humano confere e congela `prompt_aparencia` + `nao_fazer` (1 vez por
personagem). A ficha congelada vale p/ todas as poses dele.

Uso:
    python tools/comfy/ficha.py <imagem> --nome relogio [--saida fichas/x.json]
"""
import json
import os
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8188"
MODELO = "MiaoshouAI/Florence-2-large-PromptGen-v2.0"


def api(method, path, data=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def descrever(img_path):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from limpar import upload
    up = upload(img_path)
    tarefas = ["prompt_gen_analyze", "prompt_gen_mixed_caption_plus",
               "prompt_gen_tags"]
    wf = {"1": {"class_type": "DownloadAndLoadFlorence2Model",
                "inputs": {"model": MODELO, "precision": "fp16"}},
          "2": {"class_type": "LoadImage", "inputs": {"image": up["name"]}}}
    for i, t in enumerate(tarefas, start=3):
        wf[str(i)] = {"class_type": "Florence2Run",
                      "inputs": {"image": ["2", 0], "florence2_model": ["1", 0],
                                 "text_input": "", "task": t, "fill_mask": True}}
        wf[str(i + 10)] = {"class_type": "PreviewAny",
                           "inputs": {"source": [str(i), 2]}}
    pid = api("POST", "/prompt", {"prompt": wf})["prompt_id"]
    print("trabalho:", pid, flush=True)
    for _ in range(120):
        time.sleep(5)
        h = api("GET", f"/history/{pid}")
        if pid in h and h[pid].get("status", {}).get("completed"):
            saidas = {}
            for nid, o in h[pid]["outputs"].items():
                v = o.get("caption", o.get("text"))
                if v:
                    saidas[nid] = v[0] if isinstance(v, list) else str(v)
            return {"analise": saidas.get("13", ""),
                    "legenda_mista": saidas.get("14", ""),
                    "tags": saidas.get("15", "")}
    raise TimeoutError("descricao demorou demais (10 min)")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a or a[0].startswith("--"):
        print("uso: ficha.py <imagem> --nome <id> [--saida <json>]")
        sys.exit(1)
    nome = a[a.index("--nome") + 1] if "--nome" in a else "personagem"
    saida = (a[a.index("--saida") + 1] if "--saida" in a
             else os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "fichas", f"{nome}.rascunho.json"))
    auto = descrever(a[0])
    ficha = {"personagem": nome, "fonte_ref": a[0],
             "rascunho_auto": auto,
             "prompt_aparencia": "REVISAR: junte analise+legenda+tags num bloco "
                                 "ingles fixo (corpo, rosto, roupa, acessorios, cores)",
             "nao_fazer": ["REVISAR: liste o que o modelo costuma errar"],
             "congelada": False}
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    json.dump(ficha, open(saida, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print("rascunho:", saida, flush=True)
    print("REVISE o prompt_aparencia/nao_fazer e troque congelada p/ true.",
          flush=True)
