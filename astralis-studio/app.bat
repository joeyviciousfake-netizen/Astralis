@echo off
REM Astralis Studio - abre o app ou cria o exe. Dono: editor.
REM Acha o Rust mesmo fora do PATH e entra na pasta do Studio.
set "CARGO_BIN=C:\Users\Max\.cargo\bin"
set "PATH=%CARGO_BIN%;%PATH%"
cd /d "%~dp0"

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
