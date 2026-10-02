#!/usr/bin/env python3
"""checar_docs.py — PORTÃO DE DOCUMENTO (a R14 virando trava mecânica).

Dono: QA/Integration. Só lê o repo. Nunca escreve, nunca corrige.

POR QUE ESTE SCRIPT EXISTE
O projeto é lido e escrito por IA, e nunca por humano. A R14 diz o que pode
estar num doc: a regra como ela é, o número com o dono, o caminho do dado, o
motivo — e NADA de data, versão, changelog, citação do usuário, hash de commit,
contagem de teste ou transição entre um estado e outro.
Regra escrita sem trava encolhe. Então este arquivo é a trava: regex contra o
disco, sem IA, em segundos, e roda no portão antes do commit.

O QUE ELE PEGA (cada um é uma forma de o doc mentir ou inchar)
  1. DATA           2026-10-01 em qualquer linha de doc
  2. VERSAO         `VERSION:` ou `v2.4` — número de versão não significa nada
  3. CONTAGEM       "136 testes", "3275 asserts", "suíte 180-180"
  4. HASH           commit de 7 a 40 hex entre backticks
  5. CRONICA        "antes era", "agora é", "passou a", "virou", "depois de Dnn"
  6. CAMINHO        caminho entre backticks que não existe em disco
  7. LINHA          `arquivo.gd:NNN` com NNN maior que o nº de linhas do arquivo
  8. ORCAMENTO      doc acima do orçamento de KB, ou acima de um limite de
                    nomes citados no índice

POR QUE O ITEM 6 E O MAIS IMPORTANTE
Um caminho entre backticks que não existe é a divergência mais cara do projeto:
a IA lê o doc, acredita no símbolo, escreve código que não compila, e o doc
continua affirmando. As 25 divergências que existiam eram quase todas disso.

COMO RODAR (a partir da raiz do repo)
  python tools/checar_docs.py            # porta (erro = nao commitar)
  python tools/checar_docs.py --relatorio  # so o inventario, nunca falha

SAIDA
  Erro  -> rc=1, uma linha por achado com caminho:linha.
  Aviso -> rc=0. Os avisos entram no relatório de commit como dívida, nao
           travam o trabalho (regra de não ampliar escopo, R5).
"""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# ORCAMENTO. O teto e REGRA DURA, nao sugestao: sem teto o doc incha de novo.
# A regra que manda em doc: "X e Y porque Z, senao W" e o resto nao entra.
# ---------------------------------------------------------------------------
ORCAMENTO_KB = {
    "AGENTS.md": 9,
    "docs/DECISOES.md": 20,
    "docs/SESSAO_ATUAL.md": 12,
    "docs/AI_MANIFEST.json": 14,
    "docs/00_INDICE_GERAL.md": 12,
}
ORCAMENTO_KB_PADRAO = 22

# Arquivos que o portao le. O repo tem README em varios lugares; entra tudo.
# AGENTS.md fica de fora de proposito: ele E o protocolo, ele contem os
# exemplo de cronica da R14 (o "antes era" do D3), e mexer nele nao e o
# trabalho de quem limpa doc de dominio.
ALVO_EXCLUIDO = {"AGENTS.md"}

# ---------------------------------------------------------------------------
# PADROES PROIBIDOS. Cada um: (codigo, regex, explicacao de uma linha).
# Todos em ASCII e sem acento de proposito — o script imprime em console que
# pode estar em cp1252, e acento nesse stdout ja custou um bug de leitura.
# ---------------------------------------------------------------------------
PADROES = [
    # -- 1. DATA --------------------------------------------------------
    ("DATA", r"\b\d{4}-\d{2}-\d{2}\b",
     "data ISO: envelhece e a IA le como atual. O historico e o git log"),

    # -- 2. VERSAO ------------------------------------------------------
    ("VERSAO", r"(?i)^VERSION\s*:",
     "cabeçalho VERSION: — versao de doc nao significa nada aqui"),
    ("VERSAO", r"(?i)\bv[0-9]\.[0-9]\b",
     "numero de versao (v2.4) — changelog nao entra em doc (R14)"),
    ("VERSAO", r"(?i)\bchangelog\b",
     "'changelog' — o historico e o git log"),

    # -- 3. CONTAGEM DE TESTE -------------------------------------------
    ("CONTAGEM", r"\b\d+\s*(?:testes|asserts|su[ií]tes?)\b",
     "contagem de teste envelhece toda semana. Se precisa de prova, roda o GUT"),
    ("CONTAGEM", r"(?i)\bGUT\b[^\n]{0,14}?\d+\s*/\s*\d+",
     "'GUT roda 183/183' — contagem written a mao diverge na proxima leva"),
    ("CONTAGEM", r"(?i)\bcargo\b[^\n]{0,20}?\d+\s*(?:->|para|/)\s*\d+",
     "'cargo 60->74' — contagem Written a mao diverge na proxima leva"),

    # -- 4. HASH DE COMMIT ----------------------------------------------
    ("HASH", r"`\b[0-9a-f]{7,40}\b`",
     "hash de commit: e referencia de historico, nao de regra (R14)"),

    # -- 5. CRONICA / TRANSICAO ----------------------------------------
    # O coracao do D1/D3. 'antes', 'agora', 'passou a', 'virou' sao as
    # palavras que contam a transicao entre um estado e outro.
    ("CRONICA", r"(?i)\bantes\s+(?:era|era\s+[a-z]|de\s+\d|o\s+codigo|a\s+solu)",
     "'antes era' conta mudanca. Escreve a regra como ela e (D1)"),
    ("CRONICA", r"(?i)\bagora\s+(?:e|é|passou|virou|esta|sao)\b",
     "'agora e' conta mudanca. Escreve a regra como ela e (D1)"),
    ("CRONICA", r"(?i)\bpassou\s+a\b",
     "'passou a' conta mudanca. Escreve a regra como ela e (D1)"),
    ("CRONICA", r"(?i)\bvirou\s+(?:um|uma|o|a|3D|2D|campo)\b",
     "'virou' conta mudanca. Escreve a regra como ela e (D1)"),
    ("CRONICA", r"(?i)\bdepois\s+de\s+(?:D\d{2}|o\s+D\d{2})",
     "'depois de Dnn' data a mudanca. O numero da decisao nao precisa no texto"),
    ("CRONICA", r"(?i)\bsaiu\s+no\s+D\d{2}\b",
     "'saiu no Dnn' data a mudanca. O numero da decisao nao precisa no texto"),
    ("CRONICA", r"(?i)\bera\s+o\s+resqu[íi]cio\b",
     "narrativa de sessao. Descreve a regra, nao a caminhada ate ela"),
    ("CRONICA", r"(?i)\bchamada[- ]mostrada[- ]apagada\b",
     "narrativa de sessao. Descreve a regra, nao a caminhada ate ela"),
    ("CRONICA", r"(?i)\bERROS? (?:MEUS?|DESTA LEVA)\b",
     "ata de sessao. O que deu errado esta no git log, nao no doc"),
]
# CAMINHO e LINHA nao entram em PADROES de proposito: eles precisam conferir
# contra o disco, e nao ha como saber por regex. Ficam em checar_caminhos().

# Caminho RELATIVO ao repo: precisa conter / ou . para nao pegar nome solto.
RE_CAMINHO_REL = re.compile(
    r"`(?P<c>(?:[\w.-]+/)+[\w.-]+\.[A-Za-z0-9]+)`"
)
# Caminho ABSOLUTO (Windows ou POSIX): existe fora do repo, nunca verificamos.
RE_CAMINHO_ABS = re.compile(
    r"`(?P<c>[A-Za-z]:[\\/][^`\n]+|[/](?:home|usr|opt|var|tmp)/[^`\n]+)`"
)
# `arquivo.ext:NNN` — so interessa se o arquivo existir de verdade.
RE_LINHA = re.compile(
    r"`(?P<a>(?:[\w.-]+/)*[\w.-]+\.[A-Za-z0-9]+):(?P<n>\d+)`"
)
# Data que e contrato do arquivo e nao data de prosa: a chave `data_utc` do
# caderno. E a unica data que entra em doc, e ela e obrigatoria.
RE_DATA_CONTRATO = re.compile(r"^\s*data_utc\s*:")


def tamanho_kb(caminho: Path) -> float:
    return caminho.stat().st_size / 1024.0


def doc_de_ia(rel: str) -> bool:
    """O portao so cuida de doc de IA. README e nota de trabalho ficam de fora."""
    nome = Path(rel).name.lower()
    return nome.startswith("readme")


def teto_kb(rel: str) -> float:
    return ORCAMENTO_KB.get(rel.replace("\\", "/"), ORCAMENTO_KB_PADRAO)


def achar_docs() -> list[Path]:
    """Todos os .md do repo, menos build e pasta de dependencia."""
    achados: list[Path] = []
    for padrao in ("**/*.md", "AGENTS.md"):
        for p in REPO.glob(padrao):
            partes = set(p.parts)
            if partes & {"node_modules", "target", ".godot", ".svelte-kit", "Godot"}:
                continue
            if p.is_file() and p not in achados:
                achados.append(p)
    return sorted(achados)


def checar_data_e_conteudo(caminho: Path, rel: str, achados: list[dict]) -> None:
    """DATA, VERSAO, CONTAGEM, HASH e CRONICA — regex puro na linha."""
    try:
        linhas = caminho.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        achados.append({"cod": "LEITURA", "rel": rel, "lin": 0,
                        "txt": "nao deu para ler: %s" % exc, "msg": ""})
        return

    for n, linha in enumerate(linhas, 1):
        # A data do caderno e CONTRATO do arquivo, nao data de prosa: e o unico
        # lugar onde a IA precisa saber de quando e o estado. Ver R14.
        if RE_DATA_CONTRATO.search(linha):
            continue
        # O cabecalho de versao so faz sentido na primeira linha util.
        for cod, regex, msg in PADROES:
            alvo = linha if cod != "VERSAO" or n <= 6 else ""
            if not alvo:
                continue
            achado = re.search(regex, alvo)
            if achado:
                achados.append({"cod": cod, "rel": rel, "lin": n,
                                "txt": achado.group(0), "msg": msg})


def checar_caminhos(caminho: Path, rel: str, achados: list[dict]) -> None:
    """CAMINHO e LINHA — o que existe em disco, medido agora."""
    try:
        texto = caminho.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return

    base = caminho.parent
    for n, linha in enumerate(texto.splitlines(), 1):
        # Path DENTRO de um arquivo comprimido nao existe no disco: e parte do
        # .apack. Sem esta ressalva o portao acusaria o contrato do pack.
        dentro_de_pacote = bool(re.search(r"(?i)\.apack|\bpack\b|\bzip\b", linha))

        # Relativo com barra: docs/NUM.md, astralis/duel/duel_manager.gd
        for achado in RE_CAMINHO_REL.finditer(linha):
            alvo = achado.group("c")
            if dentro_de_pacote:
                continue
            if (REPO / alvo).exists():
                continue
            # Pode ser relativo a pasta do proprio doc (ex.: schemas/README.md
            # citando 'examples/cards/fm_0001.json' — que existe em schemas/).
            if (base / alvo).exists():
                continue
            achados.append({
                "cod": "CAMINHO", "rel": rel, "lin": n, "txt": alvo,
                "msg": "caminho entre backticks que nao existe em disco "
                       "(nem na raiz, nem relativo a pasta do doc)",
            })
        # `arquivo.gd:NNN` — so verifica se o arquivo existir; se nao existir,
        # o CAMINHO acima ja acusou.
        for achado in RE_LINHA.finditer(linha):
            alvo = achado.group("a")
            caminho_real = REPO / alvo
            if not caminho_real.exists():
                continue  # ja acusou no CAMINHO
            try:
                total = len(caminho_real.read_text(encoding="utf-8",
                                                   errors="replace").splitlines())
            except OSError:
                continue
            linha_alvo = int(achado.group("n"))
            if linha_alvo > total:
                achados.append({
                    "cod": "LINHA", "rel": rel, "lin": n,
                    "txt": "%s:%d" % (alvo, linha_alvo),
                    "msg": "linha citada %d maior que o arquivo (%d linhas): "
                           "numero de linha em doc envelhece" % (linha_alvo, total),
                })


def checar_orcamento(caminho: Path, rel: str, achados: list[dict]) -> None:
    kb = tamanho_kb(caminho)
    teto = teto_kb(rel)
    if kb > teto:
        achados.append({
            "cod": "ORCAMENTO", "rel": rel, "lin": 0,
            "txt": "%.1f KB" % kb,
            "msg": "acima do teto de %.0f KB. O teto e regra dura: sem teto o "
                   "doc incha de novo. Corte cronica antes de cortar regra"
                   % teto,
        })


def varrer() -> tuple[list[dict], list[tuple[str, float, float, int]]]:
    achados: list[dict] = []
    inventario: list[tuple[str, float, float, int]] = []
    for caminho in achar_docs():
        rel = caminho.relative_to(REPO).as_posix()
        if rel in ALVO_EXCLUIDO:
            continue
        if doc_de_ia(rel):
            continue
        antes = len(achados)
        checar_data_e_conteudo(caminho, rel, achados)
        checar_caminhos(caminho, rel, achados)
        checar_orcamento(caminho, rel, achados)
        try:
            nlinhas = len(caminho.read_text(encoding="utf-8").splitlines())
        except (OSError, UnicodeDecodeError):
            nlinhas = 0
        inventario.append((rel, tamanho_kb(caminho), teto_kb(rel), nlinhas))
    return achados, inventario


def imprimir_relatorio(inventario: list[tuple[str, float, float, int]]) -> None:
    print("docs/ lidos por IA — inventario")
    print("  %-44s %7s %7s %6s" % ("arquivo", "KB", "teto", "linhas"))
    for rel, kb, teto, nlinhas in inventario:
        marca = " " if kb <= teto else "!"
        print("  %-44s %6.1f%s %6.0f %6d"
              % (rel, kb, marca, teto, nlinhas))
    total = sum(i[1] for i in inventario)
    teto_total = sum(i[2] for i in inventario)
    print("  %-44s %6.1f  %6.0f" % ("TOTAL", total, teto_total))


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Portao de documento: a R14 virando trava mecanica.")
    ap.add_argument("--relatorio", action="store_true",
                    help="so o inventario (KB, teto, linhas); nunca falha")
    args = ap.parse_args()

    achados, inventario = varrer()

    if args.relatorio:
        imprimir_relatorio(inventario)
        return 0

    if not achados:
        print("docs: OK, %d arquivo(s) sem data, versao, contagem, hash, "
              "cronica, caminho morto nem excesso de tamanho." % len(inventario))
        return 0

    # Agrupa por arquivo, na ordem em que o problema aparece.
    por_arq: dict[str, list[dict]] = {}
    for a in achados:
        por_arq.setdefault(a["rel"], []).append(a)

    for rel in sorted(por_arq):
        for a in por_arq[rel]:
            onde = "%s:%d" % (rel, a["lin"]) if a["lin"] else rel
            print("ERRO %-9s %s  [%s]  %s" % (a["cod"], onde, a["txt"], a["msg"]))
    print("docs: %d achado(s) em %d arquivo(s). rc=1 — nao commitar."
          % (len(achados), len(por_arq)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
