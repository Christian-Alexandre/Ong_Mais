@echo off
start "Publicar no GitHub" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publicar_github.ps1"
