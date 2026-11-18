@echo off
setlocal
set PATH=%PATH%;C:\src\flutter\bin
cd /d "%~dp0app"
set LOG=%~dp0saida_verificacao.txt
echo === flutter --version === > "%LOG%"
call flutter --version >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo === flutter doctor === >> "%LOG%"
call flutter doctor >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo === flutter pub get === >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo === flutter analyze === >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo === flutter test === >> "%LOG%"
call flutter test >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo === FIM === >> "%LOG%"
type "%LOG%"
echo.
echo Saida gravada em %LOG%
pause
