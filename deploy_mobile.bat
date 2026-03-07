@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0english-exercises-mobile"

if errorlevel 1 (
  echo.
  echo [ERRO] Pasta "english-exercises-mobile" nao encontrada ao lado deste script.
  echo Verifique a estrutura e tente novamente.
  pause
  exit /b 1
)

set EXCLUDE_PATHS=.expo dist node_modules

:menu
cls
echo ==============================
echo   MOBILE DEPLOY MENU
echo ==============================
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

eas build -p android --profile preview --clear-cache
pause
goto menu

:gitstatus
git status
pause
goto menu

:stage_safe
echo.
echo Aplicando stage seguro (inclui mudancas e remove ruido comum)...
git add -A
for %%p in (%EXCLUDE_PATHS%) do (
  git reset -- "%%p" 1>nul 2>nul
)

echo.
echo Status apos stage seguro:
git status
echo.
echo Dica: para evitar ruido recorrente, garanta que .expo/, dist/ e node_modules/ estejam no .gitignore.
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
git add -A
for %%p in (%EXCLUDE_PATHS%) do (
  git reset -- "%%p" 1>nul 2>nul
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
  echo [AVISO] Nao ha mudancas staged apos limpeza de ruido (^.expo/dist/node_modules^).
  echo Revise o git status e adicione arquivos necessarios antes de publicar.
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
