"""iniciar_blender.py — sobe o Blender COM o socket do MCP ja no ar.

POR QUE ISTO EXISTE (medido, naopalpite): o add-on `mcp-for-blender` (v1.8)
tem "auto-start" — o `blendermcp_auto_start_server` da cena vem `True` e o
add-on se registra num timer para subir o servidor sozinho. **No Blender
5.2.2 LTS esse auto-start NAO dispara**: medido em 2026-09-30, depois de abrir
o Blender com o add-on habilitado, `bpy.types.blendermcp_server` nao existe e
nao ha escuta na porta. Chamando `bpy.ops.blendermcp.start_server()` na mao,
sobe na hora (mesma sessao, mesmo build). Entao o auto-start fica documentado
como nao-confiavel e quem manda no inicio e ESTE arquivo.

O QUE ELE FAZ, em ordem:
  1. habilita o add-on, se ainda nao estiver (idempotente);
  2. abre o `.blend` pedido (o arquivo que a pessoa vai editar), se houver;
  3. sobe o servidor MCP na porta ASTRALIS_MCP_PORT (padrao 9876);
  4. imprime a linha de confirmacao — se ela nao aparecer, o MCP esta fora.

COMO RODAR (e o que o `abrir_blender.ps1` faz por voce):
    & "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" `
        --python tools/blender/iniciar_blender.py -- "caminho.blend"

NAO E' o jogo: aqui nao mora regra nenhuma (R1). E' a mao que o runtime usa
para produzir `assets/3d/*.glb` — e o unico caminho de entrada do Blender
para o repositorio (o outro lado e o exportador).
"""

import os
import sys

import bpy

ADDON = "blender_mcp"
PORTA_PADRAO = 9876


def porta():
    bruto = os.environ.get("ASTRALIS_MCP_PORT", str(PORTA_PADRAO))
    try:
        return int(bruto)
    except (TypeError, ValueError):
        return PORTA_PADRAO


def habilitar_addon():
    try:
        bpy.ops.preferences.addon_enable(module=ADDON)
        return True
    except Exception:  # noqa: BLE001 - ja habilitado tambem lanca aqui
        return hasattr(bpy.ops, "blendermcp")


def argumentos():
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1:]
    return []


def abrir_arquivo(caminho):
    if not caminho:
        return ""
    existe = os.path.exists(caminho)
    if not existe:
        print("[ASTRALIS] Arquivo nao existe, abrindo vazio: %s" % caminho)
        return ""
    bpy.ops.wm.open_mainfile(filepath=caminho)
    return caminho


def subir_servidor(porta_uso):
    if not hasattr(bpy.ops, "blendermcp"):
        print("[ASTRALIS] Add-on %s NAO esta carregado: o MCP nao sobe." % ADDON)
        return False
    try:
        bpy.context.scene.blendermcp_port = porta_uso
    except Exception as exc:  # noqa: BLE001
        print("[ASTRALIS] Nao deu para setar a porta: %r" % (exc,))
    try:
        bpy.ops.blendermcp.start_server()
    except Exception as exc:  # noqa: BLE001
        print("[ASTRALIS] start_server falhou: %r" % (exc,))
        return False
    srv = getattr(bpy.types, "blendermcp_server", None)
    rodando = bool(getattr(srv, "running", False))
    print("[ASTRALIS] MCP do Blender: %s na porta %d (arquivo aberto: %s)" % (
        "NO AR" if rodando else "NAO SUBIU", porta_uso, bpy.data.filepath or "(vazio)"))
    return rodando


def main():
    abrir = abrir_arquivo(argumentos()[0] if argumentos() else "")
    if not habilitar_addon():
        print("[ASTRALIS] Falha ao habilitar o add-on %s." % ADDON)
        return
    subir_servidor(porta())
    if not abrir:
        print("[ASTRALIS] Dica: passe o .blend depois de '--', ex.: --python iniciar_blender.py -- assets/3d/fonte/x.blend")


main()
