@echo off
REM Astralis Studio - abre o app ou cria o exe. Dono: editor.
REM Acha o cargo-tauri sem depender desta maquina e entra na pasta do Studio.
cd /d "%~dp0"

REM 1) cargo-tauri no PATH?  2) CARGO_BIN apontando pra ele?  3) ~/.cargo/bin.
where cargo-tauri >nul 2>nul
if not errorlevel 1 goto TEMCARGO
if defined CARGO_BIN if exist "%CARGO_BIN%\cargo-tauri.exe" (
  set "PATH=%CARGO_BIN%;%PATH%"
  goto TEMCARGO
)
if exist "%USERPROFILE%\.cargo\bin\cargo-tauri.exe" (
  set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
  goto TEMCARGO
)
echo [ERRO] Rust nao encontrado nesta maquina.
echo Instale o Rust em https://rustup.rs e depois feche e abra este script de novo.
echo Se voce instalou em outro lugar, defina CARGO_BIN apontando para a pasta do
echo cargo ^(ex.: setx CARGO_BIN C:\Ferramentas\cargo\bin^).
pause
goto FIM

:TEMCARGO

:MENU
cls
echo ===============================================
echo  Astralis Studio - Editor de Cartas
echo ===============================================
echo.
echo  [1] Abrir app sem build - modo dev
echo  [2] Criar build - gera o exe na maquina
echo.
set /p OPCAO="Escolha 1 ou 2: "
if "%OPCAO%"=="1" goto DEV
if "%OPCAO%"=="2" goto BUILD
echo Opcao invalida. Tente de novo.
pause
goto MENU

:DEV
where node >nul 2>nul
if errorlevel 1 goto SEMNODE
if not exist "node_modules" call npm install
cargo tauri dev
goto FIM

:BUILD
where node >nul 2>nul
if errorlevel 1 goto SEMNODE
if not exist "node_modules" call npm install
cargo tauri build
echo.
echo Pronto. O exe sai em src-tauri\target\release\astralis-studio.exe
echo.
pause
goto FIM

:SEMNODE
echo [ERRO] Node nao encontrado. Instale o Node 24 em https://nodejs.org
pause
goto FIM

:FIM
