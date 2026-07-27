@echo off
chcp 65001 >nul
echo ========================================
echo  SQLite3 DLL Setup for Windows
echo ========================================
echo.

set SQLITE_DLL_DIR=%~dp0runner
set SQLITE_DLL=%SQLITE_DLL_DIR%\sqlite3.dll

REM 检查是否已存在 sqlite3.dll
if exist "%SQLITE_DLL%" (
    echo [INFO] sqlite3.dll 已存在于 %SQLITE_DLL_DIR%
    echo [INFO] 如需重新下载，请先删除该文件
    goto :success
)

echo [STEP 1] 正在下载 SQLite3 DLL...
echo.

REM 尝试使用 PowerShell 下载
set DOWNLOAD_URL=https://www.sqlite.org/2024/sqlite-dll-win-x64-3450000.zip
set ZIP_FILE=%TEMP%\sqlite-dll-%RANDOM%.zip
set EXTRACT_DIR=%TEMP%\sqlite3-extract-%RANDOM%

echo 下载地址: %DOWNLOAD_URL%
echo 临时文件: %ZIP_FILE%
echo.

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] 下载失败！
    echo.
    echo 请手动下载 SQLite DLL：
    echo 1. 访问 https://www.sqlite.org/download.html
    echo 2. 下载 "Precompiled Binaries for Windows" 中的 sqlite-dll-win-x64-*.zip
    echo 3. 解压并将 sqlite3.dll 复制到: %SQLITE_DLL_DIR%
    echo.
    pause
    exit /b 1
)

echo [STEP 2] 下载成功，正在解压...
echo.

REM 创建解压目录
mkdir "%EXTRACT_DIR%" 2>nul

REM 解压文件
powershell -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%EXTRACT_DIR%' -Force"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 解压失败！
    pause
    exit /b 1
)

echo [STEP 3] 正在复制文件...
echo.

REM 确保目标目录存在
if not exist "%SQLITE_DLL_DIR%" mkdir "%SQLITE_DLL_DIR%"

REM 复制 DLL 文件
copy "%EXTRACT_DIR%\sqlite3.dll" "%SQLITE_DLL%" /Y

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 复制文件失败！
    echo 请检查是否有写入权限
    pause
    exit /b 1
)

echo [STEP 4] 清理临时文件...
del "%ZIP_FILE%" 2>nul
rmdir /s /q "%EXTRACT_DIR%" 2>nul

:success
echo.
echo ========================================
echo  安装完成！
echo ========================================
echo.
echo sqlite3.dll 已安装到: %SQLITE_DLL%
echo.
echo 现在可以运行以下命令构建应用：
echo.
echo   flutter clean
echo   flutter pub get
echo   flutter run -d windows
echo.
pause