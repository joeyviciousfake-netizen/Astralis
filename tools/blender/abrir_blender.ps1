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

# O Blender e um app GUI: o stdout dele morre com o processo, entao nao ha como
# "ver o que ele Prints" sem sequestrar o console de alguem. Tres formas foram
# testadas nesta maquina e duas quebram:
#   sem nada          -> o aviso some (foi assim que o D62 passou meses sem ninguem ver)
#   -NoNewWindow      -> o Blender divide o console do shell: encerrar o Blender
#                        derruba junto o shell que o lancou
#   -Redirect...      -> trava o PowerShell
# A forma que funciona: o Blender GRAVA um arquivo de status
# (ASTRALIS_STATUS, escrito pelo iniciar_blender.py) e o launcher le e imprime.
# A pessoa ve a mesma informacao, o console fica limpo e o Blender pode ser
# encerrado sozinho.
$status = Join-Path ([System.IO.Path]::GetTempPath()) ("astralis-blender-{0}.json" -f (Get-Random))
Remove-Item $status -ErrorAction SilentlyContinue
$env:ASTRALIS_STATUS = $status
Start-Process -FilePath $exe -ArgumentList $argumentos | Out-Null

# O Blender sobe o servidor DEPOIS de abrir o arquivo e configurar a GPU, entao
# esperar a porta e o jeito honesto de saber que o script ja rodou.
$espera = 0
while ($espera -lt 40 -and -not (Get-NetTCPConnection -LocalPort $Porta -State Listen -ErrorAction SilentlyContinue)) {
    Start-Sleep -Milliseconds 500
    $espera += 1
}
Start-Sleep -Milliseconds 500   # o status e gravado logo depois de subir o servidor

if (Test-Path $status) {
    $s = Get-Content $status -Raw | ConvertFrom-Json
    if ($s.backend -and $s.backend -ne "nenhum") {
        Write-Host ("Cycles: backend {0} | {1}" -f $s.backend, ($s.gpus -join ", ")) -ForegroundColor Cyan
    } else {
        Write-Host "Cycles: NENHUMA GPU — o projeto NAO renderiza em CPU (D62)." -ForegroundColor Red
    }
    if ($s.mcp) {
        Write-Host ("MCP do Blender: NO AR na porta {0} (arquivo: {1})" -f $s.porta, $s.arquivo) -ForegroundColor Green
    } else {
        Write-Host "MCP do Blender: NAO SUBIU." -ForegroundColor Red
    }
} else {
    Write-Host "Nao achei o arquivo de status — o Blender pode ter demorado ou falhado." -ForegroundColor Yellow
}
Remove-Item $status -ErrorAction SilentlyContinue
