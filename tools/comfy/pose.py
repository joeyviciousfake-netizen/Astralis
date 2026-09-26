"""Poses do Astralis (guia do ControlNet, sem node novo).

Desenha o esqueleto no formato OpenPose-18 (fundo preto, membros
coloridos) a partir de poses nomeadas. O ControlNet le esse desenho
e forca a pose; a identidade vem da referencia via IPAdapter.

Uso:
    python tools/comfy/pose.py voar_lancar [--saida pose.png] [--ver]
Poses: neutra, pular, voar_lancar, surfar, correr
"""
import os
import sys

# 18 pontos OpenPose (x, y em 0..1): tb vale p/ criatura (guia aproximado)
# 0 nariz, 1 pescoco, 2 ombro_D, 3 cotovelo_D, 4 pulso_D, 5 ombro_E,
# 6 cotovelo_E, 7 pulso_E, 8 quadril, 9 quadril_D, 10 joelho_D,
# 11 pe_D, 12 quadril_E, 13 joelho_E, 14 pe_E, 15 olho_D, 16 olho_E,
# 17 orelha_D, 18 orelha_E
MEMBROS = [(1, 2), (1, 5), (2, 3), (3, 4), (5, 6), (6, 7), (1, 8),
           (8, 9), (8, 12), (9, 10), (10, 11), (12, 13), (13, 14),
           (1, 0), (0, 15), (0, 16), (15, 17), (16, 18)]
CORES = [(255, 0, 85), (255, 0, 85), (255, 85, 0), (255, 170, 0),
         (255, 255, 0), (170, 255, 0), (85, 255, 0), (0, 255, 0),
         (0, 255, 85), (0, 255, 170), (0, 255, 255), (0, 170, 255),
         (0, 85, 255), (85, 0, 255), (170, 0, 255), (255, 0, 255),
         (255, 0, 170), (255, 0, 85)]

POSES = {
    "neutra": dict(nariz=(.5, .2), pescoco=(.5, .3), ombro_D=(.38, .32),
                   cotovelo_D=(.3, .45), pulso_D=(.26, .58), ombro_E=(.62, .32),
                   cotovelo_E=(.7, .45), pulso_E=(.74, .58), quadril=(.5, .6),
                   quadril_D=(.42, .62), joelho_D=(.4, .78), pe_D=(.4, .94),
                   quadril_E=(.58, .62), joelho_E=(.6, .78), pe_E=(.6, .94),
                   olho_D=(.46, .17), olho_E=(.54, .17), orelha_D=(.4, .2),
                   orelha_E=(.6, .2)),
    "pular": dict(nariz=(.5, .22), pescoco=(.5, .32), ombro_D=(.38, .34),
                  cotovelo_D=(.28, .22), pulso_D=(.22, .1), ombro_E=(.62, .34),
                  cotovelo_E=(.72, .22), pulso_E=(.78, .1), quadril=(.5, .6),
                  quadril_D=(.42, .62), joelho_D=(.3, .72), pe_D=(.22, .66),
                  quadril_E=(.58, .62), joelho_E=(.7, .72), pe_E=(.78, .66),
                  olho_D=(.46, .19), olho_E=(.54, .19), orelha_D=(.4, .22),
                  orelha_E=(.6, .22)),
    "voar_lancar": dict(nariz=(.52, .2), pescoco=(.5, .3), ombro_D=(.38, .32),
                        cotovelo_D=(.3, .42), pulso_D=(.3, .55), ombro_E=(.62, .32),
                        cotovelo_E=(.74, .22), pulso_E=(.84, .12), quadril=(.5, .6),
                        quadril_D=(.44, .62), joelho_D=(.4, .8), pe_D=(.44, .95),
                        quadril_E=(.56, .62), joelho_E=(.68, .7), pe_E=(.78, .78),
                        olho_D=(.48, .17), olho_E=(.56, .17), orelha_D=(.42, .2),
                        orelha_E=(.62, .2)),
    "surfar": dict(nariz=(.46, .24), pescoco=(.48, .34), ombro_D=(.38, .36),
                   cotovelo_D=(.3, .46), pulso_D=(.34, .58), ombro_E=(.58, .36),
                   cotovelo_E=(.68, .3), pulso_E=(.76, .2), quadril=(.5, .62),
                   quadril_D=(.4, .64), joelho_D=(.34, .78), pe_D=(.3, .9),
                   quadril_E=(.6, .64), joelho_E=(.64, .78), pe_E=(.68, .9),
                   olho_D=(.42, .21), olho_E=(.5, .21), orelha_D=(.36, .24),
                   orelha_E=(.56, .24)),
    "correr": dict(nariz=(.55, .22), pescoco=(.53, .32), ombro_D=(.42, .34),
                   cotovelo_D=(.34, .46), pulso_D=(.42, .52), ombro_E=(.64, .34),
                   cotovelo_E=(.74, .4), pulso_E=(.66, .48), quadril=(.53, .6),
                   quadril_D=(.45, .62), joelho_D=(.38, .76), pe_D=(.3, .86),
                   quadril_E=(.6, .62), joelho_E=(.68, .74), pe_E=(.66, .9),
                   olho_D=(.51, .19), olho_E=(.59, .19), orelha_D=(.45, .22),
                   orelha_E=(.65, .22)),
}
NOMES = ["nariz", "pescoco", "ombro_D", "cotovelo_D", "pulso_D", "ombro_E",
         "cotovelo_E", "pulso_E", "quadril", "quadril_D", "joelho_D", "pe_D",
         "quadril_E", "joelho_E", "pe_E", "olho_D", "olho_E", "orelha_D",
         "orelha_E"]


def desenhar(nome, lado=1024):
    from PIL import Image, ImageDraw
    if nome not in POSES:
        raise SystemExit(f"pose desconhecida: {nome} (tenho: {', '.join(POSES)})")
    pts = [tuple(int(POSES[nome][n][i] * lado) for i in (0, 1)) for n in NOMES]
    img = Image.new("RGB", (lado, lado), "black")
    d = ImageDraw.Draw(img)
    for (a, b), cor in zip(MEMBROS, CORES):
        d.line([pts[a], pts[b]], fill=cor, width=max(8, lado // 128))
    for (x, y) in pts:
        r = max(6, lado // 170)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))
    return img


if __name__ == "__main__":
    nome = sys.argv[1] if len(sys.argv) > 1 else "neutra"
    saida = None
    if "--saida" in sys.argv:
        saida = sys.argv[sys.argv.index("--saida") + 1]
    img = desenhar(nome)
    if saida:
        img.save(saida)
        print("pose salva:", saida, flush=True)
    else:
        base = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            f"pose_{nome}.png")
        img.save(base)
        print("pose salva:", base, flush=True)
