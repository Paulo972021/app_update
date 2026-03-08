@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "APP_DIR="
set "LOG_FILE=%~dp0deploy_mobile.log"
set "LAST_ERROR=0"

if exist "%SCRIPT_DIR%english-exercises-mobile\app.json" (
  set "APP_DIR=%SCRIPT_DIR%english-exercises-mobile"
) else (
  set "APP_DIR=%SCRIPT_DIR%"
)

cd /d "%APP_DIR%"
if errorlevel 1 (
  set "LAST_ERROR=%ERRORLEVEL%"
  goto handle_error
)

if not exist "app.json" (
  echo [ERRO] app.json nao encontrado em "%CD%" >> "%LOG_FILE%"
  set "LAST_ERROR=1"
  goto handle_error
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
call :run_and_log "Validar app.json" node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 goto handle_error

call :run_and_log "Expo export (android+ios)" npx expo export --platform android --platform ios
if errorlevel 1 goto handle_error

echo [OK] Validacao concluida.
pause
goto menu

:update
call :preflight_or_cancel
if errorlevel 1 goto handle_error

call :commit_changes "Update app logic/UI"
if errorlevel 1 goto handle_error

call :run_and_log "EAS update" eas update --branch preview --message "%FINAL_MSG%"
if errorlevel 1 goto handle_error

echo [OK] Update publicado com sucesso.
pause
goto menu

:build
call :preflight_or_cancel
if errorlevel 1 goto handle_error

call :commit_changes "Prepare new Android build"
if errorlevel 1 goto handle_error

set "BUILD_JSON_FILE=.eas_build_result.json"
if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul

echo [EXEC] EAS build (android preview)
echo [EXEC] eas build -p android --profile preview --clear-cache --json >> "%LOG_FILE%"
echo ===== %date% %time% | EAS build (android preview) ===== >> "%LOG_FILE%"
eas build -p android --profile preview --clear-cache --json > "%BUILD_JSON_FILE%" 2>> "%LOG_FILE%"
if errorlevel 1 (
  set "LAST_ERROR=%ERRORLEVEL%"
  echo ----- exit code: !LAST_ERROR! ----- >> "%LOG_FILE%"
  goto handle_error
)
echo ----- exit code: 0 ----- >> "%LOG_FILE%"

set "BUILD_LINK="
for /f "usebackq delims=" %%i in (`node -e "const fs=require('fs');const p='.eas_build_result.json';if(!fs.existsSync(p)) process.exit(0);let raw=fs.readFileSync(p,'utf8').trim();if(!raw) process.exit(0);let data=JSON.parse(raw);if(Array.isArray(data)) data=data[0]||{};const link=data.artifacts?.applicationArchiveUrl||data.artifacts?.buildUrl||data.buildDetailsPageUrl||data.logsUrl||'';if(link) console.log(link);"`) do set "BUILD_LINK=%%i"

if exist "%BUILD_JSON_FILE%" del /f /q "%BUILD_JSON_FILE%" >nul 2>nul

echo.
if defined BUILD_LINK (
  echo [OK] Build enviado ao EAS com sucesso.
  echo Link da build: !BUILD_LINK!
  echo QR para abrir o link:
  echo https://api.qrserver.com/v1/create-qr-code/?size=300x300^&data=!BUILD_LINK!
) else (
  echo [AVISO] Build executado, mas nao foi possivel extrair link automaticamente.
  echo Rode manualmente: eas build:list -p android --limit 1
)

pause
goto menu

:gitstatus
git status
pause
goto menu

:stage_safe
call :stage_safe_quiet

echo.
echo Status apos stage seguro:
git status
echo.
echo Ignorados no stage automatico: .expo/, dist/, node_modules/
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
call :run_and_log "Validar app.json" node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
if errorlevel 1 exit /b 1

call :run_and_log "Expo export (android+ios)" npx expo export --platform android --platform ios
if errorlevel 1 exit /b 1

call :stage_safe_quiet
call :run_and_log "Git status" git status
if errorlevel 1 exit /b 1

exit /b 0

:stage_safe_quiet
git add .
for %%p in (%EXCLUDE_PATHS%) do (
  git restore --staged -- "%%p" 1>nul 2>nul
  if errorlevel 1 git reset -- "%%p" 1>nul 2>nul
)
exit /b 0

:commit_changes
set "DEFAULT_MSG=%~1"
set "FINAL_MSG="

set /p USER_MSG=Mensagem do commit: 
if "%USER_MSG%"=="" (
  set "FINAL_MSG=%DEFAULT_MSG%"
) else (
  set "FINAL_MSG=%USER_MSG%"
)

git diff --cached --quiet
if not errorlevel 1 (
  echo [INFO] Git limpo (sem mudancas staged). Seguindo sem commit.
  echo ===== %date% %time% | Git commit (ignorado: sem mudancas staged) ===== >> "%LOG_FILE%"
  exit /b 0
)

call :run_and_log "Git commit" git commit -m "%FINAL_MSG%"
if errorlevel 1 exit /b 1

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
  set "LAST_ERROR=%CMD_RC%"
  exit /b %CMD_RC%
)

echo [OK] %STEP%
exit /b 0

:handle_error
echo.
echo ==============================
echo [ERRO] O comando falhou.
echo Codigo de erro: %LAST_ERROR%
echo Veja o log: %LOG_FILE%
echo ==============================
call :show_log_preview
pause
goto menu

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
echo.
echo Script finalizado.
pause
exit /b 0
