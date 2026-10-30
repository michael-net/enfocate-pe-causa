@echo off
rem Desinstala Enfocate pe causa. No funciona durante una sesion activa.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desinstalar.ps1"
pause
