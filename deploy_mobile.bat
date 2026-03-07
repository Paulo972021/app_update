@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "APP_DIR="

if exist "%SCRIPT_DIR%english-exercises-mobile\app.json" (
  set "APP_DIR=%SCRIPT_DIR%english-exercises-mobile"
) else (
  set "APP_DIR=%SCRIPT_DIR%"
)

cd /d "%APP_DIR%"
if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel acessar a pasta do app.
  pause
  exit /b 1
)

if not exist "app.json" (
  echo.
  echo [ERRO] app.json nao encontrado em "%CD%".
  echo Coloque o script na raiz do app ou ao lado da pasta english-exercises-mobile.
  pause
  exit /b 1
)

set EXCLUDE_PATHS=.expo dist node_modules

:menu
cls
echo ==============================
echo   MOBILE DEPLOY MENU
echo ==============================
echo Projeto atual: %CD%
echo.
echo 1 - Validar projeto
echo 2 - Publicar update (EAS Update)
echo 3 - Gerar novo APK (EAS Build)
echo 4 - Ver status do git
echo 5 - Stage seguro + status
echo 6 - Sair
echo ==============================
set /p opt=Escolha uma opcao: 

if "%opt%"=="1" goto validate
if "%opt%"=="2" goto update
if "%opt%"=="3" goto build
if "%opt%"=="4" goto gitstatus
if "%opt%"=="5" goto stage_safe
if "%opt%"=="6" goto end
goto menu

:validate
echo.
echo Validando app.json...
node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 (
  echo.
  echo [ERRO] app.json invalido. Corrija antes de continuar.
  pause
  goto menu
)

echo.
echo Rodando expo export...
npx expo export --platform android --platform ios
if errorlevel 1 (
  echo.
  echo [ERRO] Falha no expo export. Publicacao bloqueada.
)
pause
goto menu

:update
call :preflight_or_cancel
if errorlevel 1 goto menu
call :commit_changes "Update app logic/UI"
if errorlevel 1 goto menu

eas update --branch preview --message "%FINAL_MSG%"
pause
goto menu

:build
call :preflight_or_cancel
if errorlevel 1 goto menu
call :commit_changes "Prepare new Android build"
if errorlevel 1 goto menu

set "BUILD_JSON_FILE=.eas_build_result.json"
if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul

echo.
echo Iniciando EAS Build (Android)...
eas build -p android --profile preview --clear-cache --json > "%BUILD_JSON_FILE%"
if errorlevel 1 (
  echo.
  echo [ERRO] Falha ao iniciar build no EAS.
  if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul
  pause
  goto menu
)

set "BUILD_LINK="
for /f "usebackq delims=" %%i in (`node -e "const fs=require('fs');const p='.eas_build_result.json';if(!fs.existsSync(p)){process.exit(0)};let raw=fs.readFileSync(p,'utf8').trim();if(!raw){process.exit(0)};let data=JSON.parse(raw);if(Array.isArray(data)) data=data[0]||{};const link=data.buildDetailsPageUrl||data.logsUrl||data.artifacts?.buildUrl||data.artifacts?.applicationArchiveUrl||'';if(link)console.log(link);"`) do set "BUILD_LINK=%%i"

if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul

echo.
if defined BUILD_LINK (
  echo Build iniciado com sucesso.
  echo Link da build: !BUILD_LINK!
  echo QR para abrir o link: https://api.qrserver.com/v1/create-qr-code/?size=300x300^&data=!BUILD_LINK!
) else (
  echo Build iniciado, mas nao foi possivel extrair link automaticamente.
  echo Rode: eas build:list -p android --limit 1
)

pause
goto menu

:gitstatus
git status
pause
goto menu

:stage_safe
echo.
echo Aplicando stage seguro...
call :stage_safe_quiet

echo.
echo Status apos stage seguro:
git status
echo.
echo Ignorados no stage automatico: .expo/, dist/, node_modules/
echo Dica: mantenha esses caminhos no .gitignore para reduzir ruido.
pause
goto menu

:preflight_or_cancel
echo.
echo Validando app.json...
node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 (
  echo.
  echo [ERRO] app.json invalido. Corrija antes de continuar.
  pause
  exit /b 1
)

echo.
echo Rodando expo export...
npx expo export --platform android --platform ios
if errorlevel 1 (
  echo.
  echo [ERRO] Falha no expo export. Publicacao cancelada.
  pause
  exit /b 1
)

echo.
call :stage_safe_quiet
echo Status antes de publicar:
git status
echo.
exit /b 0

:stage_safe_quiet
REM 1) Stage amplo (rastreado + novos arquivos)
git add .

REM 2) Remove do stage somente ruido comum
for %%p in (%EXCLUDE_PATHS%) do (
  git restore --staged -- "%%p" 1>nul 2>nul
  if errorlevel 1 git reset -- "%%p" 1>nul 2>nul
)

exit /b 0

:commit_changes
set "DEFAULT_MSG=%~1"
set "FINAL_MSG="

echo.
set /p USER_MSG=Mensagem do commit: 
if "%USER_MSG%"=="" (
  set "FINAL_MSG=%DEFAULT_MSG%"
) else (
  set "FINAL_MSG=%USER_MSG%"
)

git diff --cached --quiet
if not errorlevel 1 (
  echo.
  echo [AVISO] Nao ha mudancas staged para commit.
  echo Se houver arquivos novos, confira se estao fora de .expo/dist/node_modules.
  pause
  exit /b 1
)

git commit -m "%FINAL_MSG%"
if errorlevel 1 (
  echo.
  echo [ERRO] Falha ao criar commit. Publicacao cancelada.
  pause
  exit /b 1
)

exit /b 0

:end
endlocal
exit /b 0
