@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "APP_DIR="
set "LOG_FILE=%~dp0deploy_mobile.log"

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
echo.
echo ==============================
echo   MOBILE DEPLOY MENU
echo ==============================
echo Projeto atual: %CD%
echo Log: %LOG_FILE%
echo.
echo 1 - Validar projeto
echo 2 - Publicar update (EAS Update)
echo 3 - Gerar novo APK (EAS Build)
echo 4 - Ver status do git
echo 5 - Stage seguro + status
echo 6 - Ver log (ultimas 120 linhas)
echo 7 - Limpar log
echo 8 - Sair
echo ==============================
set /p opt=Escolha uma opcao: 

if "%opt%"=="1" goto validate
if "%opt%"=="2" goto update
if "%opt%"=="3" goto build
if "%opt%"=="4" goto gitstatus
if "%opt%"=="5" goto stage_safe
if "%opt%"=="6" goto show_log
if "%opt%"=="7" goto clear_log
if "%opt%"=="8" goto end
goto menu

:validate
echo.
echo Validando app.json...
call :run_and_log "Validar app.json" node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 goto menu

echo.
echo Rodando expo export...
call :run_and_log "Expo export (android+ios)" npx expo export --platform android --platform ios
if errorlevel 1 (
  echo [ERRO] Falha no expo export. Publicacao bloqueada.
  call :show_log_preview
  pause
  goto menu
)

echo [OK] Validacao concluida.
pause
goto menu

:update
call :preflight_or_cancel
if errorlevel 1 goto menu
call :commit_changes "Update app logic/UI"
if errorlevel 1 goto menu

echo.
echo Publicando update...
call :run_and_log "EAS update" eas update --branch preview --message "%FINAL_MSG%"
if errorlevel 1 (
  echo [ERRO] Falha no EAS Update. Veja o log: %LOG_FILE%
  call :show_log_preview
  pause
  goto menu
)

echo [OK] Update publicado com sucesso.
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
echo [EXEC] eas build -p android --profile preview --clear-cache --json >> "%LOG_FILE%"
echo ===== %date% %time% | EAS build (android preview) ===== >> "%LOG_FILE%"
eas build -p android --profile preview --clear-cache --json > "%BUILD_JSON_FILE%" 2>> "%LOG_FILE%"
if errorlevel 1 (
  echo ----- exit code: %ERRORLEVEL% ----- >> "%LOG_FILE%"
  echo.
  echo [ERRO] Falha ao iniciar build no EAS. Veja o log: %LOG_FILE%
  call :show_log_preview
  if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul
  pause
  goto menu
)
echo ----- exit code: 0 ----- >> "%LOG_FILE%"

set "BUILD_LINK="
for /f "usebackq delims=" %%i in (`node -e "const fs=require('fs');const p='.eas_build_result.json';if(!fs.existsSync(p)){process.exit(0)};let raw=fs.readFileSync(p,'utf8').trim();if(!raw){process.exit(0)};let data=JSON.parse(raw);if(Array.isArray(data)) data=data[0]||{};const link=data.buildDetailsPageUrl||data.logsUrl||data.artifacts?.buildUrl||data.artifacts?.applicationArchiveUrl||'';if(link)console.log(link);"`) do set "BUILD_LINK=%%i"

if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul

echo.
if defined BUILD_LINK (
  echo [OK] Build iniciado com sucesso.
  echo Link da build: !BUILD_LINK!
  echo QR para abrir o link: https://api.qrserver.com/v1/create-qr-code/?size=300x300^&data=!BUILD_LINK!
) else (
  echo [AVISO] Build iniciado, mas nao foi possivel extrair link automaticamente.
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

:show_log
echo.
echo ===== ULTIMAS 120 LINHAS DO LOG =====
if exist "%LOG_FILE%" (
  powershell -NoProfile -Command "Get-Content -Path '%LOG_FILE%' -Tail 120"
) else (
  echo (log ainda nao criado)
)
echo ======================================
pause
goto menu

:clear_log
if exist "%LOG_FILE%" del /f /q "%LOG_FILE%" >nul 2>nul
echo Log limpo.
pause
goto menu

:preflight_or_cancel
echo.
echo Validando app.json...
call :run_and_log "Validar app.json" node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 (
  echo [ERRO] app.json invalido. Corrija antes de continuar.
  call :show_log_preview
  pause
  exit /b 1
)

echo.
echo Rodando expo export...
call :run_and_log "Expo export (android+ios)" npx expo export --platform android --platform ios
if errorlevel 1 (
  echo [ERRO] Falha no expo export. Publicacao cancelada.
  call :show_log_preview
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
  echo [INFO] Git limpo (sem mudancas staged). Seguindo sem commit.
  echo [INFO] Commit ignorado por nao haver mudancas.
  echo ===== %date% %time% | Git commit (ignorado: sem mudancas staged) ===== >> "%LOG_FILE%"
  exit /b 0
)

call :run_and_log "Git commit" git commit -m "%FINAL_MSG%"
if errorlevel 1 (
  echo.
  echo [ERRO] Falha ao criar commit. Publicacao cancelada.
  call :show_log_preview
  pause
  exit /b 1
)

exit /b 0

:run_and_log
set "STEP=%~1"
shift
set "TMP_OUT=%TEMP%\deploy_mobile_cmd_output_%RANDOM%_%RANDOM%.log"

echo.
echo [EXEC] %STEP%
echo [EXEC] %* >> "%LOG_FILE%"
echo ===== %date% %time% | %STEP% ===== >> "%LOG_FILE%"

call %* > "%TMP_OUT%" 2>&1
set "CMD_RC=%ERRORLEVEL%"

if exist "%TMP_OUT%" (
  type "%TMP_OUT%"
  type "%TMP_OUT%" >> "%LOG_FILE%"
  del /f /q "%TMP_OUT%" >nul 2>nul
)

echo ----- exit code: %CMD_RC% ----- >> "%LOG_FILE%"
if not "%CMD_RC%"=="0" (
  echo [ERRO] %STEP% falhou (code %CMD_RC%).
  echo Veja detalhes em: %LOG_FILE%
  exit /b %CMD_RC%
)

echo [OK] %STEP%
exit /b 0

:show_log_preview
echo.
echo ===== RESUMO DO ERRO (ultimas 60 linhas) =====
if exist "%LOG_FILE%" (
  powershell -NoProfile -Command "Get-Content -Path '%LOG_FILE%' -Tail 60"
) else (
  echo (log ainda nao criado)
)
echo ===============================================
exit /b 0

:end
endlocal
exit /b 0
