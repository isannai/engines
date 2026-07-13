@echo off
REM Build (and optionally push) the isannai/llama image.
REM
REM Usage:
REM   build.bat                       # build only
REM   build.bat --push                # build + push
REM
REM Env overrides:
REM   set LLAMA_REF=b3000             (pin llama.cpp version)
REM   set IMAGE_TAG=v0.1.0            (custom image tag)
REM   set IMAGE_NAME=isannai/llama
REM   set CUDA_ARCHS=86               (single CUDA arch, faster build)
REM
REM Can be run from anywhere — uses its own location.

setlocal enabledelayedexpansion

REM SCRIPT_DIR ends with backslash. ENGINE_DIR is the parent — where
REM Dockerfile / docker-compose.yml / .env live.
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "ENGINE_DIR=%%~fI"

if "%IMAGE_NAME%"=="" set "IMAGE_NAME=isannai/llama"
if "%IMAGE_TAG%"==""  set "IMAGE_TAG=latest"
if "%LLAMA_REF%"==""  set "LLAMA_REF=master"
if "%DOCKERFILE%"=="" set "DOCKERFILE=%ENGINE_DIR%\Dockerfile"
if "%BUILD_CONTEXT%"=="" set "BUILD_CONTEXT=%ENGINE_DIR%"

set "PUSH=0"
for %%A in (%*) do (
  if "%%A"=="--push" set "PUSH=1"
)

set "IMAGE=%IMAGE_NAME%:%IMAGE_TAG%"

echo ==^> Building %IMAGE%
echo     llama.cpp ref: %LLAMA_REF%
echo     dockerfile:    %DOCKERFILE%
echo.

set "BUILD_ARGS=--build-arg LLAMA_REF=%LLAMA_REF%"
if not "%CUDA_ARCHS%"=="" (
  set "BUILD_ARGS=!BUILD_ARGS! --build-arg CUDA_ARCHS=%CUDA_ARCHS%"
)

docker build %BUILD_ARGS% -t "%IMAGE%" -f "%DOCKERFILE%" "%BUILD_CONTEXT%"

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
