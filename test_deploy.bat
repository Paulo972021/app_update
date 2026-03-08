@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM =========================================================
REM CONFIG
REM =========================================================
set "SCRIPT_DIR=%~dp0"
set "APP_DIR="
set "DEPLOY_BAT=%SCRIPT_DIR%deploy_mobile.bat"
set "OPEN_DEPLOY_BAT=%SCRIPT_DIR%abrir_deploy_mobile.bat"
set "REPORT_FILE=%SCRIPT_DIR%test_deploy_report.txt"
set "TMP_OUT=%SCRIPT_DIR%test_deploy_tmp_output.txt"
set "TMP_PS1=%SCRIPT_DIR%test_deploy_runner.ps1"
set "TMP_IN=%SCRIPT_DIR%test_deploy_stdin.txt"

if exist "%SCRIPT_DIR%english-exercises-mobile\app.json" (
  set "APP_DIR=%SCRIPT_DIR%english-exercises-mobile"
) else (
  set "APP_DIR=%SCRIPT_DIR%"
)

set /a PASS_COUNT=0
set /a FAIL_COUNT=0
set /a WARN_COUNT=0

REM =========================================================
REM INIT
REM =========================================================
if exist "%REPORT_FILE%" del /f /q "%REPORT_FILE%" >nul 2>nul
if exist "%TMP_OUT%" del /f /q "%TMP_OUT%" >nul 2>nul
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
if exist "%TMP_IN%" del /f /q "%TMP_IN%" >nul 2>nul

call :write_line "==============================================="
call :write_line "TESTE DEPLOY MOBILE"
call :write_line "Data/Hora: %date% %time%"
call :write_line "Script dir: %SCRIPT_DIR%"
call :write_line "App dir: %APP_DIR%"
call :write_line "==============================================="
call :write_line ""

REM =========================================================
REM MENU
REM =========================================================
:menu
cls
echo.
echo ===============================================
echo TESTE DEPLOY MOBILE
echo ===============================================
echo Projeto: %APP_DIR%
echo Relatorio: %REPORT_FILE%
echo.
echo 1 - Teste rapido
echo 2 - Teste completo
echo 3 - Ver relatorio
echo 4 - Limpar relatorio
echo 5 - Sair
echo ===============================================
set /p opt=Escolha uma opcao: 

if "%opt%"=="1" goto quick
if "%opt%"=="2" goto full
if "%opt%"=="3" goto show_report
if "%opt%"=="4" goto clear_report
if "%opt%"=="5" goto end
goto menu

REM =========================================================
REM QUICK TEST
REM =========================================================
:quick
cls
call :section "INICIANDO TESTE RAPIDO"

call :test_paths
call :test_tools
call :test_app_json
call :test_expo_export
call :test_deploy_exists
call :test_deploy_menu

call :summary
pause
goto menu

REM =========================================================
REM FULL TEST
REM =========================================================
:full
cls
call :section "INICIANDO TESTE COMPLETO"

call :test_paths
call :test_tools
call :test_app_json
call :test_expo_export
call :test_git_status
call :test_deploy_exists
call :test_open_deploy_exists
call :test_deploy_menu
call :test_deploy_validate_option
call :test_deploy_build_option
call :test_deploy_log_exists

call :summary
pause
goto menu

REM =========================================================
REM TESTS
REM =========================================================
:test_paths
call :section "TESTE: caminhos"

if exist "%APP_DIR%\app.json" (
  call :pass "app.json encontrado"
) else (
  call :fail "app.json nao encontrado em %APP_DIR%"
)

if exist "%APP_DIR%\package.json" (
  call :pass "package.json encontrado"
) else (
  call :fail "package.json nao encontrado em %APP_DIR%"
)

if exist "%APP_DIR%\src" (
  call :pass "pasta src encontrada"
) else (
  call :fail "pasta src nao encontrada"
)

exit /b 0

:test_tools
call :section "TESTE: ferramentas"

where node >nul 2>nul
if errorlevel 1 (
  call :fail "Node nao encontrado no PATH"
) else (
  for /f "delims=" %%i in ('node -v') do set "NODE_VER=%%i"
  call :pass "Node encontrado: !NODE_VER!"
)

where npm >nul 2>nul
if errorlevel 1 (
  call :fail "npm nao encontrado no PATH"
) else (
  for /f "delims=" %%i in ('npm -v') do set "NPM_VER=%%i"
  call :pass "npm encontrado: !NPM_VER!"
)

where git >nul 2>nul
if errorlevel 1 (
  call :fail "git nao encontrado no PATH"
) else (
  for /f "delims=" %%i in ('git --version') do set "GIT_VER=%%i"
  call :pass "Git encontrado: !GIT_VER!"
)

where eas >nul 2>nul
if errorlevel 1 (
  call :warn "eas nao encontrado no PATH"
) else (
  for /f "delims=" %%i in ('eas --version') do set "EAS_VER=%%i"
  call :pass "EAS encontrado: !EAS_VER!"
)

exit /b 0

:test_app_json
call :section "TESTE: app.json"
call :reset_tmp_out
pushd "%APP_DIR%" >nul

node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')" > "%TMP_OUT%" 2>&1
if errorlevel 1 (
  call :fail "app.json invalido"
) else (
  call :pass "app.json valido"
)
call :append_file "%TMP_OUT%"

popd >nul
exit /b 0

:test_expo_export
call :section "TESTE: expo export"
call :reset_tmp_out
pushd "%APP_DIR%" >nul

call :run_with_timeout "npx expo export --platform android --platform ios" 180 "%TMP_OUT%"
if errorlevel 1 (
  call :fail "expo export falhou"
) else (
  if exist "%APP_DIR%\dist" (
    call :pass "expo export OK e pasta dist gerada"
  ) else (
    call :warn "expo export terminou sem erro, mas dist nao foi encontrada"
  )
)
call :append_file "%TMP_OUT%"

popd >nul
exit /b 0

:test_git_status
call :section "TESTE: git status"
call :reset_tmp_out
pushd "%APP_DIR%" >nul

git status > "%TMP_OUT%" 2>&1
if errorlevel 1 (
  call :warn "git status falhou"
) else (
  call :pass "git status executado"
)
call :append_file "%TMP_OUT%"

popd >nul
exit /b 0

:test_deploy_exists
call :section "TESTE: deploy_mobile.bat"

if exist "%DEPLOY_BAT%" (
  call :pass "deploy_mobile.bat encontrado"
) else (
  call :fail "deploy_mobile.bat nao encontrado em %SCRIPT_DIR%"
)

exit /b 0

:test_open_deploy_exists
call :section "TESTE: abrir_deploy_mobile.bat"

if exist "%OPEN_DEPLOY_BAT%" (
  call :pass "abrir_deploy_mobile.bat encontrado"
) else (
  call :warn "abrir_deploy_mobile.bat nao encontrado"
)

exit /b 0

:test_deploy_menu
call :section "TESTE: menu do deploy"
call :reset_tmp_out
if not exist "%DEPLOY_BAT%" (
  call :fail "Nao foi possivel testar menu: deploy_mobile.bat ausente"
  exit /b 0
)

call :run_deploy_input "8" 20 "%TMP_OUT%"
if errorlevel 1 (
  call :fail "deploy_mobile.bat nao respondeu corretamente ao menu/sair"
) else (
  call :pass "deploy_mobile.bat abriu e respondeu ao menu"
)
call :append_file "%TMP_OUT%"

exit /b 0

:test_deploy_validate_option
call :section "TESTE: opcao 1 do deploy (validacao)"
call :reset_tmp_out
if not exist "%DEPLOY_BAT%" (
  call :fail "Nao foi possivel testar validacao: deploy_mobile.bat ausente"
  exit /b 0
)

REM 1 = validar, ENTER para pause, 8 = sair
call :run_deploy_input "1; ;8" 240 "%TMP_OUT%"
if errorlevel 1 (
  call :fail "Opcao 1 do deploy falhou"
) else (
  findstr /i "app.json OK" "%TMP_OUT%" >nul 2>nul
  if errorlevel 1 (
    call :warn "Opcao 1 executou, mas nao encontrei 'app.json OK' na saida"
  ) else (
    call :pass "Opcao 1 executada com indicio de validacao correta"
  )
)
call :append_file "%TMP_OUT%"

exit /b 0

:test_deploy_build_option
call :section "TESTE: opcao 3 do deploy (build)"
call :reset_tmp_out
if not exist "%DEPLOY_BAT%" (
  call :fail "Nao foi possivel testar build: deploy_mobile.bat ausente"
  exit /b 0
)

REM 3 = build, mensagem commit, ENTER para pause, 8 = sair
call :run_deploy_input "3;teste-build-auto; ;8" 600 "%TMP_OUT%"
if errorlevel 1 (
  call :warn "Opcao 3 nao concluiu com sucesso total (isso pode ser aceitavel se o build falhar de forma tratada)"
)
call :append_file "%TMP_OUT%"

REM elimina falso positivo: exige URL real apos Link da build
findstr /R /I /C:"Link da build: https\?://" "%TMP_OUT%" >nul 2>nul
if errorlevel 1 (
  findstr /i "eas build:list -p android --limit 1" "%TMP_OUT%" >nul 2>nul
  if errorlevel 1 (
    call :warn "Opcao 3 nao mostrou link automatico nem fallback claro"
  ) else (
    call :pass "Opcao 3 mostrou fallback manual para localizar a build"
  )
) else (
  call :pass "Opcao 3 mostrou link da build"
)

findstr /R /I /C:"https://api.qrserver.com/v1/create-qr-code/" "%TMP_OUT%" >nul 2>nul
if errorlevel 1 (
  call :warn "Opcao 3 nao mostrou URL de QR Code"
) else (
  call :pass "Opcao 3 mostrou URL de QR Code"
)

exit /b 0

:test_deploy_log_exists
call :section "TESTE: log do deploy"

if exist "%SCRIPT_DIR%deploy_mobile.log" (
  call :pass "deploy_mobile.log encontrado"
) else (
  call :warn "deploy_mobile.log nao encontrado"
)

exit /b 0

REM =========================================================
REM HELPERS
REM =========================================================
:reset_tmp_out
if exist "%TMP_OUT%" del /f /q "%TMP_OUT%" >nul 2>nul
> "%TMP_OUT%" echo.
exit /b 0

:run_deploy_input
set "RUN_INPUT=%~1"
set "RUN_TIMEOUT=%~2"
set "RUN_OUT=%~3"
if exist "%RUN_OUT%" del /f /q "%RUN_OUT%" >nul 2>nul
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
if exist "%TMP_IN%" del /f /q "%TMP_IN%" >nul 2>nul

setlocal DisableDelayedExpansion
> "%TMP_IN%" (
  for %%L in (%RUN_INPUT:;= %) do echo %%~L
)
endlocal

> "%TMP_PS1%" (
  echo $wd = Get-Location
  echo Set-Location -LiteralPath "%SCRIPT_DIR%"
  echo $psi = New-Object System.Diagnostics.ProcessStartInfo
  echo $psi.FileName = "cmd.exe"
  echo $psi.Arguments = "/c deploy_mobile.bat"
  echo $psi.RedirectStandardInput = $true
  echo $psi.RedirectStandardOutput = $true
  echo $psi.RedirectStandardError = $true
  echo $psi.UseShellExecute = $false
  echo $psi.CreateNoWindow = $true
  echo $p = New-Object System.Diagnostics.Process
  echo $p.StartInfo = $psi
  echo [void]$p.Start()
  echo Get-Content -LiteralPath "%TMP_IN%" ^| ForEach-Object { $p.StandardInput.WriteLine($_) }
  echo $p.StandardInput.Close()
  echo if (-not $p.WaitForExit(%RUN_TIMEOUT%000)) { try { $p.Kill() } catch {} ; $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); Set-Content -LiteralPath "%RUN_OUT%" -Value ($out + "`r`n" + $err) -Encoding UTF8; Set-Location $wd; exit 124 }
  echo $out = $p.StandardOutput.ReadToEnd()
  echo $err = $p.StandardError.ReadToEnd()
  echo Set-Content -LiteralPath "%RUN_OUT%" -Value ($out + "`r`n" + $err) -Encoding UTF8
  echo $rc = $p.ExitCode
  echo Set-Location $wd
  echo exit $rc
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%"
set "RUN_ERR=%ERRORLEVEL%"
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
if exist "%TMP_IN%" del /f /q "%TMP_IN%" >nul 2>nul
exit /b %RUN_ERR%

:run_with_timeout
set "RUN_CMD=%~1"
set "RUN_TIMEOUT=%~2"
set "RUN_OUT=%~3"
if exist "%RUN_OUT%" del /f /q "%RUN_OUT%" >nul 2>nul
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul

> "%TMP_PS1%" (
  echo $wd = Get-Location
  echo Set-Location -LiteralPath "%APP_DIR%"
  echo $psi = New-Object System.Diagnostics.ProcessStartInfo
  echo $psi.FileName = "cmd.exe"
  echo $psi.Arguments = "/c %RUN_CMD%"
  echo $psi.RedirectStandardOutput = $true
  echo $psi.RedirectStandardError = $true
  echo $psi.UseShellExecute = $false
  echo $psi.CreateNoWindow = $true
  echo $p = New-Object System.Diagnostics.Process
  echo $p.StartInfo = $psi
  echo [void]$p.Start()
  echo if (-not $p.WaitForExit(%RUN_TIMEOUT%000)) { try { $p.Kill() } catch {} ; $out = $p.StandardOutput.ReadToEnd(); $err = $p.StandardError.ReadToEnd(); Set-Content -LiteralPath "%RUN_OUT%" -Value ($out + "`r`n" + $err) -Encoding UTF8; Set-Location $wd; exit 124 }
  echo $out = $p.StandardOutput.ReadToEnd()
  echo $err = $p.StandardError.ReadToEnd()
  echo Set-Content -LiteralPath "%RUN_OUT%" -Value ($out + "`r`n" + $err) -Encoding UTF8
  echo $rc = $p.ExitCode
  echo Set-Location $wd
  echo exit $rc
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%"
set "RUN_ERR=%ERRORLEVEL%"
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
exit /b %RUN_ERR%

:section
set "SEC=%~1"
echo.
echo ===============================================
echo %SEC%
echo ===============================================
call :write_line ""
call :write_line "==============================================="
call :write_line "%SEC%"
call :write_line "==============================================="
exit /b 0

:pass
set /a PASS_COUNT+=1
echo [PASS] %~1
call :write_line "[PASS] %~1"
exit /b 0

:fail
set /a FAIL_COUNT+=1
echo [FAIL] %~1
call :write_line "[FAIL] %~1"
exit /b 0

:warn
set /a WARN_COUNT+=1
echo [WARN] %~1
call :write_line "[WARN] %~1"
exit /b 0

:write_line
>> "%REPORT_FILE%" echo(%~1
exit /b 0

:append_file
if exist "%~1" (
  call :write_line "----- output begin -----"
  powershell -NoProfile -Command "Get-Content -Path '%~1'" >> "%REPORT_FILE%"
  call :write_line "----- output end -----"
)
exit /b 0

:summary
call :write_line ""
call :write_line "==============================================="
call :write_line "RESUMO FINAL"
call :write_line "==============================================="
call :write_line "PASS: %PASS_COUNT%"
call :write_line "WARN: %WARN_COUNT%"
call :write_line "FAIL: %FAIL_COUNT%"

echo.
echo ===============================================
echo RESUMO FINAL
echo ===============================================
echo PASS: %PASS_COUNT%
echo WARN: %WARN_COUNT%
echo FAIL: %FAIL_COUNT%
echo.
echo Relatorio salvo em:
echo %REPORT_FILE%
echo ===============================================

exit /b 0

:show_report
cls
if exist "%REPORT_FILE%" (
  type "%REPORT_FILE%"
) else (
  echo Relatorio ainda nao existe.
)
echo.
pause
goto menu

:clear_report
if exist "%REPORT_FILE%" del /f /q "%REPORT_FILE%" >nul 2>nul
if exist "%TMP_OUT%" del /f /q "%TMP_OUT%" >nul 2>nul
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
if exist "%TMP_IN%" del /f /q "%TMP_IN%" >nul 2>nul
echo Relatorio limpo.
pause
goto menu

:end
if exist "%TMP_OUT%" del /f /q "%TMP_OUT%" >nul 2>nul
if exist "%TMP_PS1%" del /f /q "%TMP_PS1%" >nul 2>nul
if exist "%TMP_IN%" del /f /q "%TMP_IN%" >nul 2>nul
echo.
echo Script finalizado.
pause
exit /b 0
