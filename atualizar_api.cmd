@echo off
start "atualizar_api" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0atualizar_api.ps1"
