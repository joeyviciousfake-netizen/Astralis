# abrir_blender.ps1 — abre o Blender COM o socket do MCP ja no ar.
#
# Por que um launcher e nao "abra o Blender e clique no painel": o auto-start
# do add-on NAO dispara no Blender 5.2.2 LTS (medido em 2026-09-30, ver o
# comentario do inicio em iniciar_blender.py). Quem sobe o servidor e o
# iniciar_blender.py, entao o caminho certo e sempre este script — sem clique,
# sem depender de estado anterior.
#
# Como usar (da raiz do repo):
#   .\tools\blender\abrir_blender.ps1                       # vazio, so pra mexer
#   .\tools\blender\abrir_blender.ps1 -Blend x.blend        # abre um arquivo
#   $env:ASTRALIS_MCP_PORT = 9881; .\tools\blender\abrir_blender.ps1   # outra porta
#
# A porta tem que ser a MESMA dos dois lados: a do Blender (aqui) e a do
# servidor MCP que o opencode lanca (abrir/registrar em
# ~/.config/opencode/opencode.json). Padrao 9876.

param(
    [string]$Blend = "",
    [int]$Porta = 9876
)

$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$script = Join-Path $raiz "tools\blender\iniciar_blender.py"

function Achar-Blender {
    if ($env:BLENDER -and (Test-Path $env:BLENDER)) { return $env:BLENDER }
    $base = "C:\Program Files\Blender Foundation"
    if (Test-Path $base) {
        # A versao LTS mais alta primeiro (5.2 > 5.1): o pipeline 3D foi medido
        # no 5.2.2 LTS e e' nele que o glb sai com as opcoes do exportador.
        $achado = Get-ChildItem $base -Directory |
            Sort-Object { [version]($_.Name -replace '^Blender\s*', '') } -Descending |
            ForEach-Object { Join-Path $_.FullName "blender.exe" } |
            Where-Object { Test-Path $_ } |
            Select-Object -First 1
        if ($achado) { return $achado }
    }
    return ""
}

$exe = Achar-Blender
if (-not $exe) {
    Write-Host "Blender nao encontrado." -ForegroundColor Red
    Write-Host "Instale o 5.2 LTS ou aponte a variavel BLENDER:"
    Write-Host '  $env:BLENDER = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"'
    exit 1
}

$env:ASTRALIS_MCP_PORT = "$Porta"
Write-Host "Blender: $exe" -ForegroundColor Cyan
Write-Host "Socket do MCP: 127.0.0.1:$Porta" -ForegroundColor Cyan
if ($Blend) { Write-Host "Abrindo: $Blend" -ForegroundColor Cyan }

$argumentos = @("--python", $script)
if ($Blend) { $argumentos += @("--", $Blend) }

# -NoNewWindow: sem isso o Blender e um app GUI sem console ligado e o stdout
# dele (as linhas "[ASTRALIS] ..." do iniciar_blender.py) e DESCARTADO — foi
# assim que o aviso de "nenhuma GPU encontrada" passou anos invisivel. Com a
# flag, as linhas aparecem NESTA janela, que e onde a pessoa esta olhando.
Start-Process -FilePath $exe -ArgumentList $argumentos -NoNewWindow
Write-Host "Sobeu. Leia as linhas [ASTRALIS] acima:-backend de render, se o MCP subiu e a porta." -ForegroundColor Green
