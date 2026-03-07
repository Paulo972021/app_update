@echo off
setlocal
cd /d "%~dp0english-exercises-mobile"

if errorlevel 1 (
  echo.
  echo [ERRO] Pasta "english-exercises-mobile" nao encontrada ao lado deste script.
  echo Verifique a estrutura e tente novamente.
  pause
  exit /b 1
)

:menu
cls
echo ==============================
echo   MOBILE DEPLOY MENU
echo ==============================
echo 1 - Validar projeto
echo 2 - Publicar update (EAS Update)
echo 3 - Gerar novo APK (EAS Build)
echo 4 - Ver status do git
echo 5 - Sair
echo ==============================
set /p opt=Escolha uma opcao: 

if "%opt%"=="1" goto validate
if "%opt%"=="2" goto update
if "%opt%"=="3" goto build
if "%opt%"=="4" goto gitstatus
if "%opt%"=="5" goto end
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
  echo [ERRO] Falha no expo export. Update cancelado.
  pause
  goto menu
)

echo.
git status
echo.
set /p msg=Mensagem do update: 
if "%msg%"=="" set msg=Update app logic/UI
git add .
git commit -m "%msg%"
if errorlevel 1 (
  echo.
  echo [AVISO] Commit nao criado (talvez sem alteracoes). Prosseguindo para update.
)
eas update --branch preview --message "%msg%"
pause
goto menu

:build
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
  echo [ERRO] Falha no expo export. Build cancelado.
  pause
  goto menu
)

echo.
git status
echo.
set /p msg=Mensagem do build: 
if "%msg%"=="" set msg=Prepare new Android build
git add .
git commit -m "%msg%"
if errorlevel 1 (
  echo.
  echo [AVISO] Commit nao criado (talvez sem alteracoes). Prosseguindo para build.
)
eas build -p android --profile preview --clear-cache
pause
goto menu

:gitstatus
git status
pause
goto menu

:end
endlocal
exit /b 0
