#!/usr/bin/env python3
"""apack.py — PACK DE CRIACAO (.apack) V1: arquivo unico texto+imagens.

Dono: Systems/Data Engineer. Formato de CRIACAO (aberto, editavel), NAO e
a fita final .astralis (binaria trancada, doc 12). Regra D23: pack de
criacao = UM arquivo com extensao nossa `.apack` (textos + imagens juntos).

O que e um .apack V1: um ZIP comum (deflate, abre em qualquer lib) com
extensao .apack. O "custom" e a extensao + manifest + regras, NENHUM
algoritmo inventado. Conteudo:

  manifest.json        <- magic "APACK", versoes, contagens, SHA256 de tudo
  data/pack.json       <- O MESMO JSON legado (fm_original_pack.json),
                          byte-compativel: legado .json = .apack sem assets
  assets/...           <- png/webp/jpg/jpeg + ogg referenciados pelo pack
  preview.{png,jpg,webp} (opcional) <- capa do pack, so desenho

Regras V1 (contrato, espelho em docs/12_DISTRIBUICAO_EXPORTACAO.md §12.7):
  - imagem repetida grava 1x (content-addressed por SHA256; as copias
    voltam no unpack). Referencia sempre por path estavel ("assets/...").
  - asset faltando = AVISO, nao erro (as 722 do FM nao tem imagem no repo).
  - hash quebrado, limite estourado, extensao proibida = ERRO.
  - schema_version continua 1 (compativel, sem migracao).

Limites V1:
  por asset: 5 MB | total assets: 200 MB | .apack total: 250 MB
  max 5000 assets | extensoes: .png .webp .jpg .jpeg .ogg | preview: 2 MB

Uso (a partir da raiz do repo Astralis, so stdlib):
  python tools/apack.py pack schemas/packs/fm_original_pack.json --out saida.apack [--assets-dir .] [--preview capa.png]
  python tools/apack.py unpack saida.apack --out-dir destino/
  python tools/apack.py check saida.apack

Port Rust (Editor): algoritmo em 5 passos no §12.7. O importador atual
(importar_pack_valor) NAO muda: recebe o texto de data/pack.json + copia
assets/* para projects/default/assets/ (com trava de path).
"""

import argparse
import datetime
import hashlib
import json
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCHEMAS = REPO / "schemas"

MAGIC = "APACK"
FORMAT_VERSION = 1
SCHEMA_VERSION = 1

MAX_ASSET_BYTES = 5_000_000      # 5 MB por arquivo
MAX_ASSETS_TOTAL = 200_000_000   # 200 MB somados
MAX_APACK_TOTAL = 250_000_000    # 250 MB o arquivo final
MAX_ASSET_FILES = 5000
ALLOWED_EXT = {".png", ".webp", ".jpg", ".jpeg", ".ogg"}
PREVIEW_NAMES = {"preview.png", "preview.jpg", "preview.jpeg", "preview.webp"}
PREVIEW_MAX = 2_000_000          # 2 MB

AVISOS_TETO = 10  # quantos assets faltantes listar (o resto vira "+N")


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def utc_agora() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def coletar_refs(obj, refs: set):
    """Todo string 'assets/...' no pack e referencia de asset (artwork hoje,
    portraits/backgrounds amanha). Generico de proposito: campo novo que
    apontar para assets/ passa a valer sem mudar o formato."""
    if isinstance(obj, dict):
        for v in obj.values():
            coletar_refs(v, refs)
    elif isinstance(obj, list):
        for v in obj:
            coletar_refs(v, refs)
    elif isinstance(obj, str) and obj.startswith("assets/"):
        refs.add(obj)


def zip_seguro(nome: str) -> bool:
    """Trava ZipSlip (espelho do Rust apack.rs:96-113): so paths relativos
    dentro do zip, sem '..', sem letra de unidade, sem barra inicial.
    Vale pros nomes do zip E pros files[].path/stored_as do manifest."""
    if not isinstance(nome, str) or not nome:
        return False
    n = nome.replace("\\", "/")
    if n.startswith("/"):
        return False
    if len(n) >= 2 and n[1] == ":":
        return False
    if ".." in n.split("/"):
        return False
    return True


# ---------------- PACK ----------------

def cmd_pack(pack_json: Path, out: Path, assets_dir: Path | None,
             author_id: str, runtime_version: str, preview: Path | None) -> int:
    raw = pack_json.read_bytes()
    pack = json.loads(raw.decode("utf-8"))
    if pack.get("schema_version") != 1:
        print("ERRO: pack nao e V1 (falta \"schema_version\": 1).")
        return 1

    refs: set = set()
    coletar_refs(pack, refs)

    # Resolve assets (faltando = aviso, nao erro).
    achados: dict[str, bytes] = {}   # path logico -> bytes
    faltando: list[str] = []
    for ref in sorted(refs):
        if not zip_seguro(ref):
            print("ERRO: referencia fora do zip: %r (use 'assets/...')." % ref)
            return 1
        ext = Path(ref).suffix.lower()
        if ext not in ALLOWED_EXT:
            print("ERRO: extensao proibida em %r (V1 aceita: %s)."
                  % (ref, ", ".join(sorted(ALLOWED_EXT))))
            return 1
        disco = (assets_dir / ref) if assets_dir else None
        if disco is not None and disco.is_file():
            b = disco.read_bytes()
            if len(b) > MAX_ASSET_BYTES:
                print("ERRO: %s tem %d bytes (teto V1: %d por arquivo)."
                      % (ref, len(b), MAX_ASSET_BYTES))
                return 1
            achados[ref] = b
        else:
            faltando.append(ref)

    if len(achados) > MAX_ASSET_FILES:
        print("ERRO: %d assets (teto V1: %d)." % (len(achados), MAX_ASSET_FILES))
        return 1
    if sum(len(b) for b in achados.values()) > MAX_ASSETS_TOTAL:
        print("ERRO: assets passam de %d MB (teto V1)." % (MAX_ASSETS_TOTAL // 1_000_000))
        return 1

    # Dedup content-addressed: mesmo SHA256 grava 1x no zip.
    por_hash: dict[str, str] = {}    # sha -> path armazenado
    stored_as: dict[str, str] = {}   # path logico -> entrada no zip
    for ref in sorted(achados):
        h = sha256_bytes(achados[ref])
        if h not in por_hash:
            por_hash[h] = ref
        stored_as[ref] = por_hash[h]

    fusoes = pack.get("fusoes") or pack.get("fusions") or {}
    manifest = {
        "magic": MAGIC,
        "format_version": FORMAT_VERSION,
        "schema_version": SCHEMA_VERSION,
        "runtime_version": runtime_version,
        "author_id": author_id,
        "mode": "aberto",
        "pack_id": pack.get("pack_id", pack_json.stem),
        "name": pack.get("name", pack_json.stem),
        "counts": {
            "cartas": len(pack.get("cartas", pack.get("cards", []))),
            "duelistas": len(pack.get("duelistas", pack.get("duelists", []))),
            "decks": len(pack.get("decks", [])),
            "fusoes_recipes": len(fusoes.get("recipes", [])),
            "fusoes_rules": len(fusoes.get("rules", [])),
            "equips": len(pack.get("equips", [])),
            "assets": len(achados),
            "assets_bytes": sum(len(b) for b in achados.values()),
        },
        "files": [{"path": "data/pack.json",
                   "sha256": sha256_bytes(raw), "size": len(raw)}]
        + [{"path": ref, "sha256": sha256_bytes(achados[ref]),
            "size": len(achados[ref]), "stored_as": stored_as[ref]}
           for ref in sorted(achados)],
        "pack_sha256": sha256_bytes(raw),
        "created_utc": utc_agora(),
        "tool": "tools/apack.py V1",
    }

    preview_bytes: bytes | None = None
    preview_nome = ""
    if preview is not None:
        if not preview.is_file():
            print("ERRO: preview nao achado: %s" % preview)
            return 1
        if preview.name not in PREVIEW_NAMES:
            print("ERRO: preview precisa se chamar preview.png|jpg|webp.")
            return 1
        preview_bytes = preview.read_bytes()
        if len(preview_bytes) > PREVIEW_MAX:
            print("ERRO: preview passa de 2 MB.")
            return 1
        preview_nome = preview.name
        manifest["files"].append({"path": preview_nome,
                                  "sha256": sha256_bytes(preview_bytes),
                                  "size": len(preview_bytes)})

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        z.writestr("data/pack.json", raw)
        gravados = set()
        for ref in sorted(achados):
            entrada = stored_as[ref]
            if entrada in gravados:
                continue  # repetida: ja gravada 1x (content-addressed)
            z.writestr(entrada, achados[ref])
            gravados.add(entrada)
        if preview_bytes is not None:
            z.writestr(preview_nome, preview_bytes)

    if out.stat().st_size > MAX_APACK_TOTAL:
        print("ERRO: .apack passa de %d MB (teto V1)." % (MAX_APACK_TOTAL // 1_000_000))
        return 1

    c = manifest["counts"]
    print("apack: %s" % out)
    print("pack: cartas=%d duelistas=%d decks=%d recipes=%d rules=%d equips=%d"
          % (c["cartas"], c["duelistas"], c["decks"],
             c["fusoes_recipes"], c["fusoes_rules"], c["equips"]))
    print("assets: %d arquivo(s), %d bytes, %d repetida(s) gravada(s) 1x"
          % (c["assets"], c["assets_bytes"], len(achados) - len(gravados)))
    if faltando:
        print("AVISO: %d referencia(s) sem arquivo (pack abre como legado 'sem imagens'):"
              % len(faltando))
        for r in faltando[:AVISOS_TETO]:
            print("  - %s" % r)
        if len(faltando) > AVISOS_TETO:
            print("  …e mais %d" % (len(faltando) - AVISOS_TETO))
    print("PACK OK")
    return 0


# ---------------- UNPACK ----------------

def cmd_unpack(apack: Path, out_dir: Path) -> int:
    try:
        z = zipfile.ZipFile(apack, "r")
    except zipfile.BadZipFile:
        print("ERRO: %s nao e um zip valido (todo .apack e um zip)." % apack)
        return 1
    with z:
        nomes = z.namelist()
        if "manifest.json" not in nomes or "data/pack.json" not in nomes:
            print("ERRO: faltam manifest.json e/ou data/pack.json (nao e .apack V1).")
            return 1
        manifest = json.loads(z.read("manifest.json").decode("utf-8"))
        if manifest.get("magic") != MAGIC or manifest.get("format_version") != 1:
            print("ERRO: magic/format_version invalidos (esperava APACK/1).")
            return 1
        for nome in nomes:
            if not zip_seguro(nome):
                print("ERRO: entrada fora do zip (ZipSlip barrado): %r" % nome)
                return 1
        # Confere hash de tudo (stored_as: hash do bytes guardado 1x).
        # Trava ZipSlip do manifest (espelho do Rust apack.rs:275-281):
        # files[].path e stored_as passam pelo mesmo zip_seguro dos nomes.
        for f in manifest.get("files", []):
            if not isinstance(f, dict) or not zip_seguro(f.get("path")):
                print("ERRO: path fora do zip no manifest (ZipSlip barrado): %r"
                      % ((f.get("path") if isinstance(f, dict) else f),))
                return 1
            sa = f.get("stored_as")
            entrada = f["path"] if sa is None else sa
            if not zip_seguro(entrada):
                print("ERRO: stored_as fora do zip no manifest (ZipSlip barrado): %r"
                      % (entrada,))
                return 1
            if entrada not in nomes:
                print("ERRO: %s listado no manifest mas fora do zip." % f["path"])
                return 1
            if sha256_bytes(z.read(entrada)) != f["sha256"]:
                print("ERRO: hash nao bate em %s (arquivo adulterado?)." % f["path"])
                return 1
        # Materializa (repetida volta como copia em cada path logico).
        # Chegou aqui = todo files[].path/stored_as ja passou no zip_seguro.
        por_path = {f["path"]: f for f in manifest.get("files", [])}
        for f in manifest.get("files", []):
            sa2 = f.get("stored_as")
            entrada = f["path"] if sa2 is None else sa2
            destino = out_dir / f["path"]
            destino.parent.mkdir(parents=True, exist_ok=True)
            destino.write_bytes(z.read(entrada))
        raw = z.read("data/pack.json")
        if sha256_bytes(raw) != manifest.get("pack_sha256", ""):
            print("ERRO: pack_sha256 nao bate (manifest adulterado?).")
            return 1
    print("unpack: %s -> %s (%d arquivo(s))" % (apack, out_dir, len(por_path)))
    print("UNPACK OK")
    return 0


# ---------------- CHECK ----------------

def cmd_check(apack: Path) -> int:
    try:
        z = zipfile.ZipFile(apack, "r")
    except zipfile.BadZipFile:
        print("ERRO: %s nao e um zip valido." % apack)
        return 1
    with z:
        nomes = z.namelist()
        if "manifest.json" not in nomes or "data/pack.json" not in nomes:
            print("ERRO: faltam manifest.json e/ou data/pack.json.")
            return 1
        manifest = json.loads(z.read("manifest.json").decode("utf-8"))
        errs: list[str] = []
        avisos: list[str] = []
        if manifest.get("magic") != MAGIC:
            errs.append("magic=%r (esperava 'APACK')" % manifest.get("magic"))
        if manifest.get("format_version") != 1:
            errs.append("format_version=%r (V1 so aceita 1)" % manifest.get("format_version"))
        if manifest.get("schema_version") != 1:
            errs.append("schema_version=%r (contrato V1 = 1)" % manifest.get("schema_version"))
        if not manifest.get("runtime_version"):
            errs.append("runtime_version ausente (info obrigatoria, sem trava V1)")
        if not manifest.get("author_id"):
            errs.append("author_id ausente (info obrigatoria, sem trava V1)")
        if manifest.get("mode") != "aberto":
            errs.append("mode=%r (V1 .apack e sempre 'aberto'; trancado e .astralis)"
                        % manifest.get("mode"))
        # Hashes + limites.
        # Trava ZipSlip do manifest (espelho do Rust apack.rs:275-281).
        total_assets = 0
        for f in manifest.get("files", []):
            if not isinstance(f, dict) or not zip_seguro(f.get("path")):
                errs.append("path fora do zip no manifest (ZipSlip barrado): %r"
                            % ((f.get("path") if isinstance(f, dict) else f),))
                continue
            sa = f.get("stored_as")
            entrada = f["path"] if sa is None else sa
            if not zip_seguro(entrada):
                errs.append("stored_as fora do zip no manifest (ZipSlip barrado): %r"
                            % (entrada,))
                continue
            if entrada not in nomes:
                errs.append("%s listado mas fora do zip" % f["path"])
                continue
            real = sha256_bytes(z.read(entrada))
            if real != f["sha256"]:
                errs.append("hash nao bate: %s" % f["path"])
            if f["path"].startswith("assets/"):
                total_assets += f.get("size", 0)
                if f.get("size", 0) > MAX_ASSET_BYTES:
                    errs.append("%s passa de 5 MB" % f["path"])
                if Path(f["path"]).suffix.lower() not in ALLOWED_EXT:
                    errs.append("extensao proibida: %s" % f["path"])
        if total_assets > MAX_ASSETS_TOTAL:
            errs.append("assets passam de 200 MB")
        if apack.stat().st_size > MAX_APACK_TOTAL:
            errs.append(".apack passa de 250 MB")

        # Dado: reusa o validador do contrato (fonte unica = fm_import).
        sys.path.insert(0, str(REPO / "tools"))
        import fm_import
        pack = json.loads(z.read("data/pack.json").decode("utf-8"))
        enums_src = json.loads((SCHEMAS / "card.schema.json").read_text(encoding="utf-8"))
        cp = enums_src["properties"]
        enums = {"card_type": cp["card_type"]["enum"],
                 "monster_type": cp["monster_type"]["enum"],
                 "attribute": cp["attribute"]["enum"],
                 "star": cp["guardian_star_1"]["enum"]}
        derrs: list[str] = []
        cartas = pack.get("cartas", pack.get("cards", []))
        for c in cartas:
            fm_import.check_card(c, enums, derrs, "apack")
        ids = {c["id"] for c in cartas if "id" in c}
        duelistas = pack.get("duelistas", pack.get("duelists", []))
        decks = pack.get("decks", [])
        fusoes = pack.get("fusoes", pack.get("fusions", {})) or {}
        recipes = fusoes.get("recipes", [])
        mesma = sum(1 for r in recipes
                    if r.get("input", {}).get("card_a") == r.get("input", {}).get("card_b"))
        for d in decks:
            for cid in d.get("cards", []):
                if cid not in ids:
                    derrs.append("apack deck %s: carta %s nao existe" % (d.get("id"), cid))
        for r in recipes:
            for k in (r.get("input", {}).get("card_a"),
                      r.get("input", {}).get("card_b"), r.get("result")):
                if k not in ids:
                    derrs.append("apack fusao %s: ref %s nao existe" % (r.get("id"), k))
        errs.extend(derrs[:20])

        # Assets faltando = aviso (legado "sem imagens" abre normal).
        # Vale o PATH LOGICO do manifest (repetida gravada 1x continua
        # presente em cada path; so falta o que nem esta listado).
        no_zip = {f["path"] for f in manifest.get("files", [])
                  if isinstance(f, dict) and isinstance(f.get("path"), str)}
        refs: set = set()
        coletar_refs(pack, refs)
        faltando = sorted(r for r in refs if r not in no_zip)
        if faltando:
            avisos.append("%d referencia(s) sem imagem (legado 'sem imagens'):" % len(faltando))
            avisos.extend("  - %s" % r for r in faltando[:AVISOS_TETO])
            if len(faltando) > AVISOS_TETO:
                avisos.append("  …e mais %d" % (len(faltando) - AVISOS_TETO))

        c = manifest.get("counts", {})
        print("manifest: magic=%s format=%s schema=%s runtime=%s author=%s mode=%s"
              % (manifest.get("magic"), manifest.get("format_version"),
                 manifest.get("schema_version"), manifest.get("runtime_version"),
                 manifest.get("author_id"), manifest.get("mode")))
        print("pack: cartas=%d duelistas=%d decks=%d recipes=%d rules=%d equips=%d"
              % (len(cartas), len(duelistas), len(decks),
                 len(recipes), len(fusoes.get("rules", [])),
                 len(pack.get("equips", []))))
        print("importavel: %d fusoes (%d A+A filtradas no Importar, igual ao Studio)"
              % (len(recipes) - mesma, mesma))
        print("assets no zip: %d (%d bytes)" % (c.get("assets", 0), c.get("assets_bytes", 0)))
        for a in avisos:
            print("AVISO: %s" % a if not a.startswith(" ") else a)
        if errs:
            print("ERROS (%d):" % len(errs))
            for e in errs[:20]:
                print("  -", e)
            return 1
    print("CHECK OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Pack de criacao .apack V1 (zip unico texto+imagens).")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("pack", help="embrulha pack.json (+assets) num .apack")
    p.add_argument("pack_json")
    p.add_argument("--out", required=True)
    p.add_argument("--assets-dir", default=None,
                   help="raiz onde 'assets/...' resolve (ausente = legado sem imagens)")
    p.add_argument("--author-id", default="desconhecido")
    p.add_argument("--runtime-version", default="1")
    p.add_argument("--preview", default=None, help="preview.png|jpg|webp (opcional)")
    u = sub.add_parser("unpack", help="desempacota .apack (confere hashes)")
    u.add_argument("apack")
    u.add_argument("--out-dir", required=True)
    k = sub.add_parser("check", help="valida .apack (formato + hashes + dado)")
    k.add_argument("apack")
    args = ap.parse_args()
    if args.cmd == "pack":
        return cmd_pack(Path(args.pack_json), Path(args.out),
                        Path(args.assets_dir) if args.assets_dir else None,
                        args.author_id, args.runtime_version,
                        Path(args.preview) if args.preview else None)
    if args.cmd == "unpack":
        return cmd_unpack(Path(args.apack), Path(args.out_dir))
    return cmd_check(Path(args.apack))


if __name__ == "__main__":
    sys.exit(main())
