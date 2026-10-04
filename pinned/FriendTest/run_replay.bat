@echo off
setlocal
rem T4: replays Dawson's recorded MP session on this PC and writes a small result file.
rem Uses its OWN profile folder (%USERPROFILE%\rw-mp-test): your normal saves and mod list are not touched.
set "KIT=%~dp0"
set "GAME=%KIT%..\..\..\..\..\common\RimWorld\RimWorldWin64.exe"
if not exist "%GAME%" (
  echo Could not find RimWorld next to this Workshop folder.
  set /p "GAME=Paste the full path to RimWorldWin64.exe and press Enter: "
)
if not exist "%GAME%" ( echo Still not found: "%GAME%" & pause & exit /b 1 )
set "PROFILE=%USERPROFILE%\rw-mp-test"
set "OUT=%USERPROFILE%\rw-mp-out"
mkdir "%PROFILE%\Config" 2>nul
mkdir "%PROFILE%\MpReplays" 2>nul
mkdir "%OUT%" 2>nul
del /q "%OUT%\friend" 2>nul
copy /y "%KIT%baseline-01.zip" "%PROFILE%\MpReplays\baseline-01.zip" >nul || ( echo baseline-01.zip is missing from the kit & pause & exit /b 1 )
(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<ModsConfigData^>
echo   ^<version^>1.6.4871 rev600^</version^>
echo   ^<activeMods^>
echo     ^<li^>zetrith.prepatcher^</li^>
echo     ^<li^>brrainz.harmony^</li^>
echo     ^<li^>ludeon.rimworld^</li^>
echo     ^<li^>ludeon.rimworld.biotech^</li^>
echo     ^<li^>rwmt.multiplayer^</li^>
echo   ^</activeMods^>
echo ^</ModsConfigData^>
) > "%PROFILE%\Config\ModsConfig.xml"
echo.
echo RimWorld will open and run by itself for a few minutes, then close on its own.
echo DON'T click inside the game window while it runs.
echo.
"%GAME%" -savedatafolder="%PROFILE%" -logfile "%PROFILE%\Player.log" -username=Friend -replay=friend:baseline-01:60000:60 -replaydata="%OUT%"
if exist "%OUT%\friend" (
  echo.
  echo ===== DONE. Send Dawson the file "friend" from the folder that just opened: =====
  type "%OUT%\friend"
  explorer "%OUT%"
) else (
  echo.
  echo No result file. Send Dawson this file instead: "%PROFILE%\Player.log"
  explorer "%PROFILE%"
)
pause
