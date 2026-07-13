@echo off
REM Build (and optionally push) the isannai/sd image.
REM
REM Usage:
REM   deploy\engines\sd\build.bat              # build only
REM   deploy\engines\sd\build.bat --push       # build + push
REM
REM Env overrides:
REM   set SDCPP_REF=v1.0.0      (pin sd.cpp version)
REM   set IMAGE_TAG=v0.1.0      (custom image tag)
REM   set IMAGE_NAME=isannai/sd
REM
REM Can be run from anywhere -uses its own location.

setlocal enabledelayedexpansion

REM SCRIPT_DIR ends with backslash (Windows convention). ENGINE_DIR is the
REM parent — where Dockerfile / docker-compose.yml / .env.example live.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ENGINE_DIR=%%~fI"

if "%IMAGE_NAME%"=="" set "IMAGE_NAME=isannai/sd"
if "%IMAGE_TAG%"==""  set "IMAGE_TAG=latest"
if "%SDCPP_REF%"==""  set "SDCPP_REF=master"
if "%DOCKERFILE%"=="" set "DOCKERFILE=%ENGINE_DIR%\Dockerfile"
if "%BUILD_CONTEXT%"=="" set "BUILD_CONTEXT=%ENGINE_DIR%"

set "PUSH=0"
for %%A in (%*) do (
  if "%%A"=="--push" set "PUSH=1"
)

set "IMAGE=%IMAGE_NAME%:%IMAGE_TAG%"

echo ==^> Building %IMAGE%
echo     sd.cpp ref: %SDCPP_REF%
echo     dockerfile: %DOCKERFILE%
echo.

docker build ^
  --build-arg "SDCPP_REF=%SDCPP_REF%" ^
  -t "%IMAGE%" ^
  -f "%DOCKERFILE%" ^
  "%BUILD_CONTEXT%"

if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo.
echo ==^> Build done: %IMAGE%

if "%PUSH%"=="1" (
  echo ==^> Pushing %IMAGE%
  docker push "%IMAGE%"
  if errorlevel 1 (
    echo Push failed.
    exit /b 1
  )
  echo ==^> Push done
)

endlocal
