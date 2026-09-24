@echo off
REM Ver o Editor de Cartas no computador - duplo clique. Dono: editor.
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 goto SEMNODE
if not exist "node_modules" goto INSTALAR
goto INICIAR
:SEMNODE
echo [ERRO] Node nao encontrado. Instale o Node 24 em https://nodejs.org
pause
exit /b 1
:INSTALAR
echo Instalando dependencias, so na primeira vez. Aguarde...
call npm install
if errorlevel 1 goto ERROINSTALAR
goto INICIAR
:ERROINSTALAR
echo [ERRO] npm install falhou. Veja a mensagem acima.
pause
exit /b 1
:INICIAR
echo Abrindo o Astralis Studio no navegador...
start "" "http://localhost:1420"
call npm run dev
echo.
echo O servidor parou. Aperte qualquer tecla para fechar.
pause
