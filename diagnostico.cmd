@echo off
start "Diagnostico" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnostico.ps1"
