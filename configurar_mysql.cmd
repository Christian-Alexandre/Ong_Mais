@echo off
start "Configurar MySQL" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0configurar_mysql.ps1"
