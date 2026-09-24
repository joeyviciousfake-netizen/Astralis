#!/usr/bin/env python3
"""fm_import.py — PACK DE IMPORTACAO do jogo original (Forbidden Memories).

Dono: Systems/Data Engineer. Leitura SOMENTE da fonte local (nunca escreve la):
  <fm-root>/notes/card-catalog.csv (722 cartas)
  <fm-root>/notes/research/fusion-and-drop-tables/{fusions.csv, equips.csv, drops.csv, drops_summary.csv}

Gera UM arquivo (fora de examples/, R8):
  schemas/packs/fm_original_pack.json
  {cartas[722], duelistas[39], decks[39], fusoes{recipes}, equips[pares]}

Regras (ordem do usuario):
  - cartas: id fm_0001..fm_0722, description "" (SEM texto no repo),
    artwork "assets/fm/card_XXXX.png" (SEM imagem no repo).
  - Magic FM vira spell (sem renomear); Equip->equip; Ritual FM->ritual (nao-monstro).
  - duelistas 1-39 (0 e unused): nome FM + ai_preset equilibrado + deck_id + starting_lp 8000.
  - decks: 40 cartas por peso do pool 'deck' (drops.csv), seed fixa 42, max 3 copias.
  - fusoes: TODAS as receitas (A+B=C); equips: todos os pares.
  - SEM libs extras (stdlib). SEM Fake (dado puro). SEM texto/imagem FM no repo.

Uso (a partir da raiz do repo Astralis):
  python tools/fm_import.py                 # gera o pack
  python tools/fm_import.py --check         # valida 40 atuais + pack contra os schemas
  python tools/fm_import.py --fm-root PATH  # outra copia local da fonte (sempre so leitura)
"""

import argparse
import csv
import json
import random
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHEMAS = REPO / "schemas"
DEFAULT_FM_ROOT = REPO.parent / "memories-decomp"

CARD_CATALOG = "notes/card-catalog.csv"
FUSIONS_CSV = "notes/research/fusion-and-drop-tables/fusions.csv"
EQUIPS_CSV = "notes/research/fusion-and-drop-tables/equips.csv"
DROPS_CSV = "notes/research/fusion-and-drop-tables/drops.csv"
DROPS_SUMMARY_CSV = "notes/research/fusion-and-drop-tables/drops_summary.csv"

SEED = 42
DECK_SIZE = 40
MAX_COPIES = 3
FM_STARTING_LP = 8000  # FM usa 8000 LP em todo duelo

ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
PW_RE = re.compile(r"^[0-9]{8}$")

# FM type -> nosso card_type (Magic vira spell; NUNCA renomear spell).
FM_TYPE_TO_CARD = {"Magic": "spell", "Trap": "trap", "Equip": "equip", "Ritual": "ritual"}


def fm_id(n: int) -> str:
    return "fm_%04d" % int(n)


def map_monster_type(fm_type: str) -> str:
    return fm_type.strip().lower().replace(" ", "-")  # "Winged Beast"->winged-beast etc.


def read_csv(path: Path):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def build_cards(catalog):
    cards = []
    for row in catalog:
        n = int(row["id"])
        fm_type = row["type"].strip()
        card_type = FM_TYPE_TO_CARD.get(fm_type, "monster")
        card = {
            "schema_version": 1,
            "id": fm_id(n),
            "name": row["name"].strip(),
            "description": "",  # SEM texto FM no repo (gap documentado)
            "artwork": "assets/fm/card_%04d.png" % n,  # SEM imagem no repo (gap documentado)
            "card_type": card_type,
            "effects": [],
            "tags": ["fm_original"],
        }
        if card_type == "monster":
            card["monster_type"] = map_monster_type(fm_type)
            card["attribute"] = row["attribute"].strip().lower()
            card["level"] = int(row["level"])
            card["attack"] = int(row["attack"])
            card["defense"] = int(row["defense"])
            g1 = (row.get("guardian_star_1") or "").strip().lower()
            g2 = (row.get("guardian_star_2") or "").strip().lower()
            if g1:
                card["guardian_star_1"] = g1
            if g2:
                card["guardian_star_2"] = g2
            card["tags"].append(card["monster_type"])
        else:
            card["tags"].append(card_type)
        pw = (row.get("password") or "").strip()
        if PW_RE.fullmatch(pw):
            card["password"] = pw  # string: preserva zero a esquerda
        cost = (row.get("starchip_cost") or "").strip()
        if cost.isdigit():
            card["starchip_cost"] = int(cost)
        cards.append(card)
    cards.sort(key=lambda c: c["id"])
    return cards


def build_duelists_decks(summary, drops):
    duelists = [r for r in summary if r["duelist_id"].strip() != "0"]
    duelists.sort(key=lambda r: int(r["duelist_id"]))
    deck_pool = {}
    for r in drops:
        if r["pool"].strip() != "deck":
            continue
        deck_pool.setdefault(r["duelist_id"].strip(), []).append((r["card_id"].strip(), int(r["weight"])))
    rng = random.Random(SEED)
    out_duelists, out_decks = [], []
    for r in duelists:
        did = r["duelist_id"].strip()
        name = r["duelist"].strip()
        duelist_id = "fm_duelist_%02d" % int(did)
        deck_id = "fm_deck_%02d" % int(did)
        out_duelists.append({
            "schema_version": 1,
            "id": duelist_id,
            "name": name,
            "deck_id": deck_id,
            "starting_lp": FM_STARTING_LP,
            "ai_preset": {"dificuldade": "normal", "agressividade": 50,
                           "uso_fusao": 50, "protecao_lp": 50},
        })
        pool = deck_pool[did]
        ids = [c for c, _ in pool]
        wts = [w for _, w in pool]
        counts, picks = {}, []
        guard = 0
        while len(picks) < DECK_SIZE:
            guard += 1
            if guard > 100000:
                raise RuntimeError("pool insuficiente p/ 40 cartas: duelista %s" % did)
            c = rng.choices(ids, weights=wts, k=1)[0]
            if counts.get(c, 0) >= MAX_COPIES:
                continue
            counts[c] = counts.get(c, 0) + 1
            picks.append(fm_id(int(c)))
        out_decks.append({"schema_version": 1, "id": deck_id,
                          "name": "Deck FM %s" % name, "cards": picks})
    return out_duelists, out_decks


def build_fusions(fusions):
    rows = sorted(fusions, key=lambda r: (int(r["material_a_id"]), int(r["material_b_id"]), int(r["result_id"])))
    recipes = []
    for i, r in enumerate(rows, 1):
        recipes.append({
            "id": "fm_fusion_%05d" % i,
            "input": {"card_a": fm_id(int(r["material_a_id"])),
                      "card_b": fm_id(int(r["material_b_id"]))},
            "result": fm_id(int(r["result_id"])),
        })
    return {"schema_version": 1, "recipes": recipes, "rules": []}


def build_equips(equips):
    pairs = sorted({(int(r["equip_id"]), int(r["monster_id"])) for r in equips})
    return [{"equip": fm_id(e), "monster": fm_id(m)} for e, m in pairs]


def generate(fm_root: Path):
    catalog = read_csv(fm_root / CARD_CATALOG)
    assert len(catalog) == 722, "esperava 722 cartas, achei %d" % len(catalog)
    fusions = read_csv(fm_root / FUSIONS_CSV)
    equips = read_csv(fm_root / EQUIPS_CSV)
    drops = read_csv(fm_root / DROPS_CSV)
    summary = read_csv(fm_root / DROPS_SUMMARY_CSV)
    cards = build_cards(catalog)
    duelists, decks = build_duelists_decks(summary, drops)
    fusoes = build_fusions(fusions)
    equip_pairs = build_equips(equips)
    pack = {
        "schema_version": 1,
        "pack_id": "fm_original_pack",
        "name": "FM Original Pack (dado importado, sem texto/imagem FM)",
        "source": {"game": "Forbidden Memories (decomp local, somente leitura)",
                   "seed": SEED, "deck_size": DECK_SIZE, "max_copies": MAX_COPIES},
        "cartas": cards,
        "duelistas": duelists,
        "decks": decks,
        "fusoes": fusoes,
        "equips": equip_pairs,
    }
    out_dir = SCHEMAS / "packs"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "fm_original_pack.json"
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(pack, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    no_desc = sum(1 for c in cards if not c["description"])
    no_pw = sum(1 for c in cards if "password" not in c)
    no_cost = sum(1 for c in cards if "starchip_cost" not in c)
    print("pack: %s" % out_path)
    print("cartas=%d (sem description=%d; sem password=%d; sem starchip_cost=%d)"
          % (len(cards), no_desc, no_pw, no_cost))
    print("duelistas=%d decks=%d (40 cartas, seed %d, max %d copias)"
          % (len(duelists), len(decks), SEED, MAX_COPIES))
    print("fusoes=%d equips=%d" % (len(fusoes["recipes"]), len(equip_pairs)))
    return out_path


# ---------------- validacao (espelha os schemas; sem libs extras) ----------------

def load_json(path: Path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def check_card(c, enums, errs, where):
    allowed = {"schema_version", "id", "name", "description", "artwork", "card_type",
               "monster_type", "attribute", "level", "attack", "defense", "effects", "tags",
               "guardian_star_1", "guardian_star_2", "password", "starchip_cost"}
    if c.get("schema_version") != 1:
        errs.append("%s %s: schema_version != 1" % (where, c.get("id")))
    if not ID_RE.fullmatch(c.get("id", "")):
        errs.append("%s: id invalido %r" % (where, c.get("id")))
    if not c.get("name"):
        errs.append("%s %s: name vazio" % (where, c.get("id")))
    ct = c.get("card_type")
    if ct not in enums["card_type"]:
        errs.append("%s %s: card_type %r fora do enum" % (where, c.get("id"), ct))
        return
    for k in c:
        if k not in allowed:
            errs.append("%s %s: campo extra %r" % (where, c.get("id"), k))
    if ct == "monster":
        for f in ("monster_type", "attribute", "level", "attack", "defense"):
            if f not in c:
                errs.append("%s %s: monstro sem %s" % (where, c.get("id"), f))
        if c.get("monster_type") not in enums["monster_type"]:
            errs.append("%s %s: monster_type %r" % (where, c.get("id"), c.get("monster_type")))
        if c.get("attribute") not in enums["attribute"]:
            errs.append("%s %s: attribute %r" % (where, c.get("id"), c.get("attribute")))
        lv = c.get("level")
        if not isinstance(lv, int) or not 1 <= lv <= 12:
            errs.append("%s %s: level %r" % (where, c.get("id"), lv))
        for f in ("attack", "defense"):
            v = c.get(f)
            if not isinstance(v, int) or v < 0:
                errs.append("%s %s: %s %r" % (where, c.get("id"), f, v))
    for f in ("guardian_star_1", "guardian_star_2"):
        if f in c and c[f] not in enums["star"]:
            errs.append("%s %s: %s %r" % (where, c.get("id"), f, c[f]))
    if "password" in c and not PW_RE.fullmatch(c["password"]):
        errs.append("%s %s: password %r" % (where, c.get("id"), c["password"]))
    if "starchip_cost" in c and (not isinstance(c["starchip_cost"], int) or c["starchip_cost"] < 0):
        errs.append("%s %s: starchip_cost %r" % (where, c.get("id"), c["starchip_cost"]))
    if "effects" in c and (not isinstance(c["effects"], list)
                            or any(not ID_RE.fullmatch(e) for e in c["effects"])):
        errs.append("%s %s: effects invalido" % (where, c.get("id")))
    if "tags" in c and (not isinstance(c["tags"], list)
                        or any(not isinstance(t, str) for t in c["tags"])):
        errs.append("%s %s: tags invalido" % (where, c.get("id")))


def run_check():
    errs = []
    card_schema = load_json(SCHEMAS / "card.schema.json")
    deck_schema = load_json(SCHEMAS / "deck.schema.json")
    cp = card_schema["properties"]
    enums = {"card_type": cp["card_type"]["enum"],
             "monster_type": cp["monster_type"]["enum"],
             "attribute": cp["attribute"]["enum"],
             "star": cp["guardian_star_1"]["enum"]}

    # 1) 40 atuais continuam validas
    cards_dir = SCHEMAS / "examples" / "cards"
    current = sorted(cards_dir.glob("*.json"))
    for p in current:
        check_card(load_json(p), enums, errs, "examples")
    print("atuais: %d cartas validadas" % len(current))

    # 2) exemplos minimo valido / invalidos (contrato)
    valid_min = {"schema_version": 1, "id": "fm_equip_teste", "name": "Espada Teste",
                 "description": "", "artwork": "assets/fm/card_0301.png",
                 "card_type": "equip", "effects": [], "tags": ["fm_original"]}
    before = len(errs)
    check_card(valid_min, enums, errs, "minimo-valido")
    ok_valid = len(errs) == before
    invalids = [
        dict(valid_min, id="x1", card_type="magic"),          # Magic FM vira spell; "magic" nao existe
        dict(valid_min, id="x2", card_type="monster"),        # monstro sem campos obrigatorios
        dict(valid_min, id="x3", password="123"),             # senha curta
        dict(valid_min, id="x4", guardian_star_1="terra"),    # estrela fora das 10
        dict(valid_min, id="x5", card_type="monster", monster_type="dragon",
             attribute="light", level=13, attack=0, defense=0),  # level > 12
    ]
    ok_invalid = True
    for i, inv in enumerate(invalids):
        n0 = len(errs)
        check_card(inv, enums, errs, "minimo-invalido-%d" % i)
        if len(errs) == n0:
            ok_invalid = False
            print("FALHA: invalido-%d passou (devia reprovar)" % i)
    errs[:] = [e for e in errs if not e.startswith("minimo-invalido")]
    print("minimo valido: %s | 5 invalidos reprovados: %s" % ("OK" if ok_valid else "FALHA", "OK" if ok_invalid else "FALHA"))
    if not ok_valid or not ok_invalid:
        errs.append("contrato minimo falhou")

    # 3) pack bate nos schemas
    pack_path = SCHEMAS / "packs" / "fm_original_pack.json"
    if not pack_path.exists():
        print("ERRO: pack nao gerado: %s (rode sem --check primeiro)" % pack_path)
        return 1
    pack = load_json(pack_path)
    cards = pack["cartas"]
    for c in cards:
        check_card(c, enums, errs, "pack")
    ids = {c["id"] for c in cards}
    print("pack cartas: %d (monstros=%d spell=%d trap=%d equip=%d ritual=%d)"
          % (len(cards), sum(1 for c in cards if c["card_type"] == "monster"),
             sum(1 for c in cards if c["card_type"] == "spell"),
             sum(1 for c in cards if c["card_type"] == "trap"),
             sum(1 for c in cards if c["card_type"] == "equip"),
             sum(1 for c in cards if c["card_type"] == "ritual")))
    for d in pack["duelistas"]:
        if d.get("schema_version") != 1 or not ID_RE.fullmatch(d.get("id", "")) or not d.get("name"):
            errs.append("pack duelista invalido: %r" % d.get("id"))
        ap = d.get("ai_preset", {})
        if ap.get("dificuldade") not in ("facil", "normal", "dificil") or any(
                not isinstance(ap.get(k), int) or not 0 <= ap.get(k, -1) <= 100
                for k in ("agressividade", "uso_fusao", "protecao_lp")):
            errs.append("pack duelista %s: ai_preset invalido" % d.get("id"))
    deck_ids = {d["id"] for d in pack["decks"]}
    for d in pack["duelistas"]:
        if d["deck_id"] not in deck_ids:
            errs.append("pack duelista %s: deck %s nao existe" % (d["id"], d["deck_id"]))
    dmin = deck_schema["properties"]["cards"]["minItems"]
    dmax = deck_schema["properties"]["cards"]["maxItems"]
    for d in pack["decks"]:
        cs = d.get("cards", [])
        if not (dmin <= len(cs) <= dmax):
            errs.append("pack deck %s: %d cartas (limite %d-%d)" % (d["id"], len(cs), dmin, dmax))
        if len(cs) != DECK_SIZE:
            errs.append("pack deck %s: esperava %d, tem %d" % (d["id"], DECK_SIZE, len(cs)))
        for cid in cs:
            if cid not in ids:
                errs.append("pack deck %s: carta %s nao existe" % (d["id"], cid))
        from collections import Counter
        if Counter(cs).most_common(1)[0][1] > MAX_COPIES:
            errs.append("pack deck %s: >%d copias" % (d["id"], MAX_COPIES))
    for r in pack["fusoes"]["recipes"]:
        for k in (r["input"]["card_a"], r["input"]["card_b"], r["result"]):
            if k not in ids:
                errs.append("pack fusao %s: ref %s nao existe" % (r["id"], k))
    for p in pack["equips"]:
        for k in (p["equip"], p["monster"]):
            if k not in ids:
                errs.append("pack equip: ref %s nao existe" % k)
    print("pack duelistas=%d decks=%d fusoes=%d equips=%d"
          % (len(pack["duelistas"]), len(pack["decks"]),
             len(pack["fusoes"]["recipes"]), len(pack["equips"])))
    if errs:
        print("ERROS (%d):" % len(errs))
        for e in errs[:20]:
            print("  -", e)
        return 1
    print("CHECK OK: 40 atuais validas + pack bate nos schemas.")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Gera/valida o FM Original Pack (somente leitura na fonte).")
    ap.add_argument("--fm-root", default=str(DEFAULT_FM_ROOT),
                    help="pasta da fonte local (padrao: irma do repo)")
    ap.add_argument("--check", action="store_true",
                    help="valida 40 atuais + pack contra os schemas (nao gera)")
    args = ap.parse_args()
    if args.check:
        return run_check()
    fm_root = Path(args.fm_root)
    for rel in (CARD_CATALOG, FUSIONS_CSV, EQUIPS_CSV, DROPS_CSV, DROPS_SUMMARY_CSV):
        if not (fm_root / rel).exists():
            print("ERRO: fonte nao encontrada: %s" % (fm_root / rel))
            return 1
    generate(fm_root)
    return run_check()


if __name__ == "__main__":
    sys.exit(main())
