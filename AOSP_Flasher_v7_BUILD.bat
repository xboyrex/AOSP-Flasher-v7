@echo off
setlocal EnableExtensions
title AOSP Flasher v7 - Build
cd /d "%~dp0"

set "ROOT=%~dp0"
set "LOG=%ROOT%build_log.txt"
set "PY="
set "VENV=%ROOT%.build_venv"
set "VPY=%VENV%\Scripts\python.exe"

echo ============================================================
echo AOSP FLASHER v7 - BUILD
echo ============================================================
echo Folder: %ROOT%
echo Log: %LOG%
echo.

> "%LOG%" echo AOSP Flasher v7 build log
>>"%LOG%" echo Started: %DATE% %TIME%

REM Find Python 3.13 first, then 3.12, 3.11, 3.10.
where py >nul 2>&1
if not errorlevel 1 (
  for %%V in (3.13 3.12 3.11 3.10) do (
    py -%%V -c "import sys; sys.exit(0 if sys.maxsize > 2**32 else 1)" >>"%LOG%" 2>&1
    if not errorlevel 1 (
      for /f "delims=" %%P in ('py -%%V -c "import sys; print(sys.executable)"') do set "PY=%%P"
      goto PY_FOUND
    )
  )
)

if exist "%LOCALAPPDATA%\AOSPFlasher\Python313\python.exe" set "PY=%LOCALAPPDATA%\AOSPFlasher\Python313\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PY (
  echo [ERROR] Python 3.10-3.13 x64 not found.
  echo Install Python 3.13 x64 and retry.
  goto FAIL
)

:PY_FOUND
echo [OK] Python: "%PY%"
"%PY%" --version
if errorlevel 1 goto FAIL

echo.
echo [1/6] Checking project files...
if not exist "%ROOT%main.py" (
 echo [ERROR] main.py is missing from this folder.
 goto FAIL
)
if not exist "%ROOT%core" (
 echo [ERROR] core folder is missing.
 goto FAIL
)
if not exist "%ROOT%assets\icon.ico" (
 echo [ERROR] assets\icon.ico is missing.
 goto FAIL
)

echo.
echo [2/6] Preparing virtual environment...
if not exist "%VPY%" (
  "%PY%" -m venv "%VENV%" >>"%LOG%" 2>&1
  if errorlevel 1 goto FAIL
)
if not exist "%VPY%" (
 echo [ERROR] Virtual environment python.exe was not created.
 goto FAIL
)

echo.
echo [3/6] Updating pip tools...
"%VPY%" -m pip install --upgrade pip setuptools wheel >>"%LOG%" 2>&1
if errorlevel 1 (
 echo [ERROR] pip upgrade failed. See build_log.txt
 goto FAIL
)

echo.
echo [4/6] Installing dependencies...
"%VPY%" -m pip install --only-binary=:all: "zstandard>=0.22.0" >>"%LOG%" 2>&1
if errorlevel 1 (
 echo [ERROR] Could not install zstandard wheel. See build_log.txt
 goto FAIL
)

if exist "%ROOT%requirements.txt" (
  "%VPY%" -m pip install --prefer-binary -r "%ROOT%requirements.txt" >>"%LOG%" 2>&1
) else (
  "%VPY%" -m pip install --prefer-binary pyinstaller customtkinter Pillow psutil >>"%LOG%" 2>&1
)
if errorlevel 1 (
 echo [ERROR] Requirements installation failed. See build_log.txt
 goto FAIL
)

"%VPY%" -m pip install --prefer-binary pyinstaller >>"%LOG%" 2>&1
if errorlevel 1 goto FAIL

"%VPY%" -c "import PyInstaller, customtkinter, PIL, psutil, zstandard; print('Imports OK')" >>"%LOG%" 2>&1
if errorlevel 1 (
 echo [ERROR] Dependency import check failed. See build_log.txt
 goto FAIL
)

echo.
echo [5/6] Checking Python source...
"%VPY%" -m compileall -q "%ROOT%main.py" "%ROOT%core" >>"%LOG%" 2>&1
if errorlevel 1 (
 echo [ERROR] Python syntax error. See build_log.txt
 goto FAIL
)

echo.
echo [6/6] Building EXE...
if exist "%ROOT%build" rmdir /s /q "%ROOT%build"
if exist "%ROOT%dist" rmdir /s /q "%ROOT%dist"
if exist "%ROOT%AOSP_Flasher_v7_By_Mayank_Droid.spec" del /f /q "%ROOT%AOSP_Flasher_v7_By_Mayank_Droid.spec"

if exist "%ROOT%adb\adb.exe" (
 "%VPY%" -m PyInstaller --noconfirm --clean --onefile --windowed --uac-admin ^
  --name "AOSP_Flasher_v7_By_Mayank_Droid" ^
  --icon "%ROOT%assets\icon.ico" ^
  --add-data "%ROOT%assets;assets" ^
  --add-data "%ROOT%core;core" ^
  --add-data "%ROOT%adb;adb" ^
  --collect-all customtkinter --collect-all zstandard ^
  --hidden-import core.driver_manager --hidden-import core.flasher_backend ^
  --hidden-import core.ram_cleaner --hidden-import core.turbo_engine ^
  "%ROOT%main.py" >>"%LOG%" 2>&1
) else (
 "%VPY%" -m PyInstaller --noconfirm --clean --onefile --windowed --uac-admin ^
  --name "AOSP_Flasher_v7_By_Mayank_Droid" ^
  --icon "%ROOT%assets\icon.ico" ^
  --add-data "%ROOT%assets;assets" ^
  --add-data "%ROOT%core;core" ^
  --collect-all customtkinter --collect-all zstandard ^
  --hidden-import core.driver_manager --hidden-import core.flasher_backend ^
  --hidden-import core.ram_cleaner --hidden-import core.turbo_engine ^
  "%ROOT%main.py" >>"%LOG%" 2>&1
)

if errorlevel 1 (
 echo [ERROR] PyInstaller failed. Full output is in build_log.txt
 goto FAIL
)

if not exist "%ROOT%dist\AOSP_Flasher_v7_By_Mayank_Droid.exe" (
 echo [ERROR] Expected EXE not found in dist.
 goto FAIL
)

copy /y "%ROOT%dist\AOSP_Flasher_v7_By_Mayank_Droid.exe" "%ROOT%AOSP_Flasher_v7_By_Mayank_Droid.exe" >nul
if errorlevel 1 goto FAIL

echo.
echo ============================================================
echo BUILD SUCCESSFUL
echo Output: %ROOT%AOSP_Flasher_v7_By_Mayank_Droid.exe
echo Log: %LOG%
echo ============================================================
echo.
pause
exit /b 0

:FAIL
echo.
echo ============================================================
echo BUILD FAILED. No EXE success is claimed.
echo Check: %LOG%
echo ============================================================
echo.
pause
exit /b 1
