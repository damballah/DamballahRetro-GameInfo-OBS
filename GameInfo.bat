@echo off
setlocal
title DamballahRetro - Game Info pour OBS
set "ROOT=C:\RetroBat"
set "SCRIPT=%ROOT%\system\gameinfo_obs\GameInfo.ps1"

if not exist "%SCRIPT%" (
  echo.
  echo [ERREUR] Fichier introuvable :
  echo %SCRIPT%
  echo.
  pause
  exit /b 1
)

echo ============================================================
echo   DamballahRetro - RetroBat Game Info pour OBS
echo ============================================================
echo.
echo RetroBat : %ROOT%
echo.
echo Le programme va surveiller automatiquement le jeu en cours.
echo Laissez cette fenetre ouverte pendant vos streams.
echo.
echo Pour arreter : fermez cette fenetre ou appuyez sur Ctrl+C.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
endlocal
