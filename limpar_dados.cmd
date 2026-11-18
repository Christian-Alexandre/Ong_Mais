@echo off
start "limpar_dados" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0limpar_dados.ps1"
