#!/usr/bin/env pwsh
<#
    limpar_cache.ps1 - apaga o cache de compilacao do Studio (o `target/` do Cargo).

    POR QUE EXISTE
    O Cargo cria uma subpasta de sessao nova em
    `target/debug/incremental/<crate>-<hash>/` a cada compilacao, e apaga a
    anterior **so quando a sessao termina limpa**. Build interrompido (o app
    fechado, Ctrl+C, crash) deixa a sessao velha no disco para sempre. Como o
    `main.rs` concentra o codigo do Studio, cada mudanca nele recria a sessao
    inteira, e a pasta cresce sem teto.

    O QUE E SEGURO APAGAR
    `incremental/` e cache PURO: o proximo build recompila o crate em vez de
    compilar so o que mudou. O resultado do build e identico; so demora mais.
    `deps/` NAO e mexido: ali esta o artefato real (`.rlib`, `.pdb`) e apagar
    forcaria recompilar a arvore inteira de dependencias.

    O QUE O SCRIPT FAZ
      1. Recusa rodar se houver cargo, rustc ou o Studio aberto (apagar cache de
         build em andamento corrompe a sessao).
      2. Apaga `target/debug/incremental/` inteiro, e as subpastas de sessao
         antigas de qualquer outra pasta que sobrar.
      3. Com -Release, apaga `target/release/` tambem (1,3 GB parados aqui ha
         semanas; so e recriado por `cargo tauri build`).
      4. Com -Backup, apaga `projects/*/backups/`, que e lixo do Importar.
      5. Mede e mostra o que devolveu.

    USO (a partir da raiz do repo)
      pwsh tools/limpar_cache.ps1                  # so o incremental (barato)
      pwsh tools/limpar_cache.ps1 -Release         # + a build de distribuicao
      pwsh tools/limpar_cache.ps1 -Release -Backup # + os backups do Importar
      pwsh tools/limpar_cache.ps1 -Tudo            # tudo acima
      pwsh tools/limpar_cache.ps1 -DryRun          # so mostra, nao apaga
#>

[CmdletBinding()]
param(
    [switch]$Release,
    [switch]$Backup,
    [switch]$Tudo,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$alvo = Join-Path $repo 'astralis-studio\src-tauri\target'

if ($Tudo) { $Release = $true; $Backup = $true }

function Get-Tamanho([string]$caminho) {
    if (-not (Test-Path -LiteralPath $caminho)) { return 0 }
    $s = (Get-ChildItem -LiteralPath $caminho -Recurse -Force -File -ErrorAction SilentlyContinue |
          Measure-Object -Property Length -Sum).Sum
    if ($null -eq $s) { return 0 }
    return $s
}

function Mb([double]$bytes) { return [math]::Round($bytes / 1MB, 1) }

# --- Trava 1: nao apagar cache com build em andamento -------------------------
$ocupado = Get-Process -Name 'cargo', 'rustc', 'astralis-studio', 'astralis_studio' -ErrorAction SilentlyContinue
if ($ocupado) {
    Write-Host "ERRO: tem build em andamento. Feche o Studio (opcao 1 do app.bat)," -ForegroundColor Red
    Write-Host "espere o cargo terminar, e rode de novo. Nao apague cache no meio de" -ForegroundColor Red
    Write-Host "uma sessao de compilacao: a sessao fica corrompida e o proximo build falha." -ForegroundColor Red
    Write-Host ""
    Write-Host "Processos que impedem a limpeza:"
    $ocupado | ForEach-Object { Write-Host ("  {0} (pid {1})" -f $_.Name, $_.Id) }
    exit 1
}

# --- Trava 2: a pasta tem que ser mesmo o target do Cargo ---------------------
if (-not (Test-Path -LiteralPath $alvo)) {
    Write-Host "Nada a fazer: $alvo nao existe (o Studio nunca foi buildado aqui)."
    exit 0
}

$antesTotal = Get-Tamanho $alvo
Write-Host "target/ antes:  $(Mb $antesTotal) MB" -ForegroundColor Cyan

$alvos = @()

# 1) o incremental inteiro: cache puro, o mais seguro
$inc = Join-Path $alvo 'debug\incremental'
if (Test-Path -LiteralPath $inc) { $alvos += @{ Caminho = $inc; Rotulo = 'debug/incremental (cache puro)' } }

# 2) as subpastas de sessao velhas que sobraram em debug/incremental, por seguranca
#    (o passo 1 ja pega tudo; aqui fica a rede se a estrutura mudar)

# 3) release, so quando pedido: e o artefato de distribuicao e recria com build
if ($Release) {
    $rel = Join-Path $alvo 'release'
    if (Test-Path -LiteralPath $rel) { $alvos += @{ Caminho = $rel; Rotulo = 'release (so com -Release)' } }
}

# 4) backups do Importar: lixo, o projeto abre vazio (D29)
if ($Backup) {
    Get-ChildItem -Path (Join-Path $repo 'astralis-studio\projects') -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $b = Join-Path $_.FullName 'backups'
            if (Test-Path -LiteralPath $b) { $alvos += @{ Caminho = $b; Rotulo = "$($_.Name)/backups" } }
        }
}

if ($alvos.Count -eq 0) {
    Write-Host "Nada a fazer: nao ha cache para limpar."
    exit 0
}

# --- Mostra o plano antes de apagar ------------------------------------------
Write-Host ""
foreach ($a in $alvos) {
    $mb = Mb (Get-Tamanho $a.Caminho)
    Write-Host ("  {0,-40} {1,9:N1} MB   {2}" -f $a.Rotulo, $mb, $a.Caminho.Replace($repo, '...'))
}

if ($DryRun) {
    $total = 0; foreach ($a in $alvos) { $total += Get-Tamanho $a.Caminho }
    Write-Host ""
    Write-Host ("DRY RUN: devolveria {0:N1} MB. Nada foi apagado." -f (Mb $total)) -ForegroundColor Yellow
    exit 0
}

# --- Apaga -------------------------------------------------------------------
$liberado = 0
foreach ($a in $alvos) {
    $liberado += Get-Tamanho $a.Caminho
    Remove-Item -LiteralPath $a.Caminho -Recurse -Force -ErrorAction SilentlyContinue
}

$depois = Get-Tamanho $alvo
Write-Host ""
Write-Host "target/ depois: $(Mb $depois) MB" -ForegroundColor Cyan
Write-Host ("Liberado:       {0:N1} MB" -f (Mb $liberado)) -ForegroundColor Green
Write-Host ""
Write-Host "O proximo `cargo tauri dev` recompila o crate do Studio uma vez" -ForegroundColor DarkGray
Write-Host "(alguns minutos) e depois volta a ser incremental normal." -ForegroundColor DarkGray
exit 0
