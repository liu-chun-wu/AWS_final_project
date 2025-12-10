@echo off
REM ################################################################################
REM Discord Bot Testing Startup Script (Windows)
REM ################################################################################
REM
REM Purpose: Automatically start backend container and Discord bot for testing
REM
REM This script:
REM 1. Starts the Flask backend in Docker
REM 2. Waits for backend to be ready
REM 3. Starts the Discord bot
REM 4. Handles cleanup on exit
REM
REM Usage:
REM   start-discord-test.bat
REM
REM To stop:
REM   Press Ctrl+C (will clean up automatically)
REM
REM ################################################################################

setlocal enabledelayedexpansion

REM Configuration
set CONTAINER_NAME=flask-test-container
set BACKEND_PORT=8000
set IMAGE_NAME=aws-lab-flask-demo:local
set BACKEND_DIR=%~dp0
set PROJECT_ROOT=%BACKEND_DIR%..
set ENV_FILE=%BACKEND_DIR%.env

echo.
echo ================================================================
echo           DISCORD BOT TESTING STARTUP SCRIPT
echo ================================================================
echo.

REM ################################################################################
REM Step 1: Check Prerequisites
REM ################################################################################

echo ========================================
echo Step 1: Checking Prerequisites
echo ========================================
echo.

REM Check Docker
echo   Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Docker is not installed
    exit /b 1
)

docker ps >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Docker is not running. Please start Docker Desktop.
    exit /b 1
)
echo   [OK] Docker is ready

REM Check Python
echo   Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Python is not installed
    exit /b 1
)
echo   [OK] Python is ready

REM Check .env file
echo   Checking .env file...
if not exist "%ENV_FILE%" (
    echo   [ERROR] .env file not found at %ENV_FILE%
    exit /b 1
)
echo   [OK] .env file found

REM Check Discord bot script
echo   Checking Discord bot script...
if not exist "%BACKEND_DIR%test-discord-bot.py" (
    echo   [ERROR] test-discord-bot.py not found
    exit /b 1
)
echo   [OK] Discord bot script found

echo.

REM ################################################################################
REM Step 2: Start Backend Container
REM ################################################################################

echo ========================================
echo Step 2: Starting Backend Container
echo ========================================
echo.

REM Check if container already exists
docker ps -a --format "{{.Names}}" | findstr /x "%CONTAINER_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo   [WARNING] Container '%CONTAINER_NAME%' already exists
    echo   Removing old container...
    docker stop %CONTAINER_NAME% >nul 2>&1
    docker rm %CONTAINER_NAME% >nul 2>&1
)

echo   Starting container '%CONTAINER_NAME%'...
docker run -d --name %CONTAINER_NAME% -p %BACKEND_PORT%:%BACKEND_PORT% --env-file "%ENV_FILE%" %IMAGE_NAME%

if errorlevel 1 (
    echo   [ERROR] Failed to start container
    exit /b 1
)

echo   [OK] Container started
echo.

REM ################################################################################
REM Step 3: Wait for Backend to be Ready
REM ################################################################################

echo ========================================
echo Step 3: Waiting for Backend
echo ========================================
echo.

echo   Checking backend health...
set MAX_RETRIES=10
set RETRY_COUNT=0

:wait_loop
set /a RETRY_COUNT+=1

REM Try to connect to health endpoint
curl -s http://localhost:%BACKEND_PORT%/health >nul 2>&1
if not errorlevel 1 (
    echo   [OK] Backend is ready!

    REM Show health response
    echo   Response:
    curl -s http://localhost:%BACKEND_PORT%/health
    echo.
    goto backend_ready
)

if %RETRY_COUNT% geq %MAX_RETRIES% (
    echo   [ERROR] Backend failed to start
    echo   Check logs: docker logs %CONTAINER_NAME%
    goto cleanup
)

echo   Waiting... (%RETRY_COUNT%/%MAX_RETRIES%)
timeout /t 2 /nobreak >nul
goto wait_loop

:backend_ready
echo.

REM ################################################################################
REM Step 4: Start Discord Bot
REM ################################################################################

echo ========================================
echo Step 4: Starting Discord Bot
echo ========================================
echo.

echo   Starting Discord bot...
echo.
echo ------------------------------------------------------------------
echo Discord Bot Output (Press Ctrl+C to stop everything):
echo ------------------------------------------------------------------
echo.

cd /d "%BACKEND_DIR%"
python test-discord-bot.py

REM If we get here, Discord bot exited
goto cleanup

REM ################################################################################
REM Cleanup
REM ################################################################################

:cleanup
echo.
echo ========================================
echo Cleaning Up
echo ========================================
echo.

echo   Stopping backend container...
docker stop %CONTAINER_NAME% >nul 2>&1

echo   [OK] Cleanup complete!
echo.
exit /b 0
