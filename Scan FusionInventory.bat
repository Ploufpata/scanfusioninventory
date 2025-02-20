@echo off
cd /d "%~dp0" >nul 2>&1

:: Exécuter le script PowerShell via CMD sans utiliser l'association de fichier
cmd /c start /b powershell -ExecutionPolicy Bypass -File "%~dp0bin\Script_Fusion.ps1"
exit