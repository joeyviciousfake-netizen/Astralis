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
  3. FORCA o Cycles na GPU — o backend e preferencia de maquina, nao mora
     no `.blend`, entao quem escolhe e este arquivo;
  4. sobe o servidor MCP na porta ASTRALIS_MCP_PORT (padrao 9876);
  5. imprime a linha de confirmacao — se ela nao aparecer, o MCP esta fora.

O PROJETO RENDERIZA EM CYCLES NA GPU E NAO EM CPU. Isso nao e preferencia,
e a invariante: um render "de GPU" que escorrega para a CPU em silencio
nao prova nada, que e a mesma familia do defeito que o D50 apagou. Entao, se
nenhuma GPU for encontrada, o script AVISA em vez de seguir calado.

COMO RODAR (e o que o `abrir_blender.ps1` faz por voce):
    & "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" `
        --python tools/blender/iniciar_blender.py -- "caminho.blend"

NAO E' o jogo: aqui nao mora regra nenhuma (R1). E' a ferramenta que abre o
Blender com o socket do MCP no ar, para modelar e exportar o que o runtime
usa.
"""

import json
import os
import sys

import bpy

ADDON = "blender_mcp"
PORTA_PADRAO = 9876
BACKEND_GPU = ("OPTIX", "CUDA", "HIP", "ONEAPI")

# Onde o launcher le o que aconteceu. O Blender nao pode "falar" com o terminal:
# ele e um app GUI, entao o stdout dele morre junto com o processo. Escrever um
# arquivo e o unico jeito de o launcher mostrar a verdade para a pessoa - e sem
# sequestrar o console de ninguem (testado: `-NoNewWindow` faz o Blender
# derrubar o shell junto, e `-RedirectStandardOutput` trava o PowerShell).
STATUS = os.environ.get("ASTRALIS_STATUS", "")


def registrar(**campos):
    """Grava o estado do boot num arquivo, para o launcher imprimir.

    Falha de escrita NAO derruba o Blender: o MCP e o que importa, e o log no
    console ainda existe para quem le o System Console do proprio Blender.
    """
    if not STATUS:
        return
    try:
        with open(STATUS, "w", encoding="utf-8") as f:
            json.dump(campos, f, ensure_ascii=False, indent=2)
    except OSError as exc:  # noqa: BLE001
        print("[ASTRALIS] Nao deu para gravar o arquivo de status: %r" % (exc,))


def deixar_cycles_na_gpu():
    """O render do projeto e em CYCLES, na GPU. A maquina tem RTX 5060 e o
    backend medido e OPTIX (Blender 5.2.2 LTS ve a 5060 em OPTIX e em CUDA).

    O backend e preferencia de MAQUINA (nao mora no .blend), entao e aqui que
    ele e escolhido — senao a interface abriria com o padrao do Blender, que
    seria EEVEE na CPU, e a previa da interface mentiria sobre a previa oficial.

    A ordem de tentativa e a preferencia de maquina (OPTIX primeiro, medido).
    O dispositivo CPU do Cycles e DESLIGADO de proposito: com ele ligado, o
    render "da GPU" escorrega para o processador sem avisar.
    """
    prefs = bpy.context.preferences.addons.get("cycles")
    if prefs is None:
        print("[ASTRALIS] ATENCAO: o Cycles nao esta neste build. O projeto "
              "renderiza em Cycles na GPU; sem ele nao existe previa oficial.")
        return "nenhum", []
    cp = prefs.preferences
    for backend in BACKEND_GPU:
        try:
            cp.compute_device_type = backend
        except TypeError:
            continue
        cp.get_devices_for_type(backend)
        gpus = [d for d in cp.devices if d.type == backend]
        if not gpus:
            continue
        for d in cp.devices:
            d.use = (d.type == backend)
        print("[ASTRALIS] Cycles: backend %s | %s" % (backend, ", ".join(d.name for d in gpus)))
        return backend, [d.name for d in gpus]
    print("[ASTRALIS] ATENCAO: NENHUMA GPU encontrada para o Cycles (OPTIX/CUDA/HIP/ONEAPI). "
          "O projeto NAO renderiza em CPU: se o render saiu do mesmo jeito, o backend "
          "esta errado e a previa nao serve como prova.")
    return "nenhum", []


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
    backend, gpus = "nenhum", []
    if not habilitar_addon():
        print("[ASTRALIS] Falha ao habilitar o add-on %s." % ADDON)
        registrar(addon=False, mcp=False, arquivo=bpy.data.filepath)
        return
    backend, gpus = deixar_cycles_na_gpu()
    mcp = subir_servidor(porta())
    registrar(addon=True, mcp=mcp, porta=porta(), backend=backend, gpus=gpus,
              arquivo=bpy.data.filepath or "(vazio)")
    if not abrir:
        print("[ASTRALIS] Dica: passe o arquivo depois de '--', ex.: --python iniciar_blender.py -- modelo.blend")


main()
