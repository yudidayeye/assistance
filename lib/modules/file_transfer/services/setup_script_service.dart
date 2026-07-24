/// Windows 电脑端配置脚本生成服务
/// 生成 .bat 脚本，用户在电脑上以管理员身份运行即可完成共享文件夹配置
class SetupScriptService {
  /// 生成 Windows 共享文件夹配置脚本
  ///
  /// [username] 专用账户用户名
  /// [password] 专用账户密码
  /// [shareName] 共享文件夹名（不含 $ 后缀，自动添加）
  /// [folderPath] 共享文件夹路径（默认 C:\PhoneShare）
  static String generateBatScript({
    String username = 'phone',
    required String password,
    String shareName = 'PhoneShare',
    String folderPath = r'C:\PhoneShare',
  }) {
    final hiddenShare = '\$shareName\$';
    return '''@echo off
chcp 65001 >nul
echo ========================================
echo    文件互传 - 电脑端配置脚本
echo ========================================
echo.
echo 此脚本将完成以下操作：
echo   1. 创建专用账户: $username
echo   2. 创建共享文件夹: $folderPath
echo   3. 设置隐藏共享: $hiddenShare
echo   4. 配置文件夹权限
echo.
echo 请以管理员身份运行此脚本！
echo.
pause

echo.
echo [1/4] 创建专用账户...
net user $username $password /add 2>nul
if %errorlevel% equ 0 (
    echo   [OK] 已创建账户: $username
) else (
    echo   [INFO] 账户 $username 可能已存在，跳过创建
)

echo.
echo [2/4] 创建共享文件夹...
if not exist "$folderPath" (
    mkdir "$folderPath"
    echo   [OK] 已创建文件夹: $folderPath
) else (
    echo   [INFO] 文件夹已存在，跳过创建
)

echo.
echo [3/4] 设置隐藏共享...
net share $hiddenShare=$folderPath /GRANT:$username,FULL /REMARK:"File Transfer Shared Folder" 2>nul
if %errorlevel% equ 0 (
    echo   [OK] 已创建隐藏共享: $hiddenShare
) else (
    echo   [INFO] 共享可能已存在，尝试重新设置...
    net share $hiddenShare /DELETE 2>nul
    net share $hiddenShare=$folderPath /GRANT:$username,FULL /REMARK:"File Transfer Shared Folder"
    echo   [OK] 已重新创建隐藏共享: $hiddenShare
)

echo.
echo [4/4] 配置文件夹权限...
icacls "$folderPath" /inheritance:r >nul 2>&1
icacls "$folderPath" /grant:r "$username":(OI)(CI)F >nul 2>&1
icacls "$folderPath" /grant:r "Administrators":(OI)(CI)F >nul 2>&1
icacls "$folderPath" /grant:r "SYSTEM":(OI)(CI)F >nul 2>&1
echo   [OK] 已设置文件夹权限

echo.
echo ========================================
echo    配置完成！
echo ========================================
echo.
echo 共享信息：
echo   共享名称: $hiddenShare
echo   账户名:   $username
echo   文件夹:   $folderPath
echo.
echo 请在手机 App 中使用以下信息连接：
echo   IP 地址:   [你的电脑IP]
echo   共享名称:  $hiddenShare
echo   用户名:   $username
echo   密码:     ****
echo.
echo 提示：可在 cmd 中运行 ipconfig 查看电脑 IP 地址
echo.
pause
''';
  }

  /// 生成 PowerShell 格式的配置脚本（更可靠，推荐）
  static String generatePowerShellScript({
    String username = 'phone',
    required String password,
    String shareName = 'PhoneShare',
    String folderPath = r'C:\PhoneShare',
  }) {
    final hiddenShare = '$shareName\$';
    return '''# 文件互传 - 电脑端配置脚本 (PowerShell)
# 请以管理员身份运行 PowerShell，然后执行此脚本

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   文件互传 - 电脑端配置脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 创建专用账户
Write-Host "[1/4] 创建专用账户..." -ForegroundColor Yellow
try {
    \$securePass = ConvertTo-SecureString "$password" -AsPlainText -Force
    New-LocalUser -Name "$username" -Password \$securePass -FullName "File Transfer User" -Description "文件互传专用账户" -ErrorAction Stop
    Write-Host "  [OK] 已创建账户: $username" -ForegroundColor Green
} catch {
    Write-Host "  [INFO] 账户可能已存在: \$_" -ForegroundColor Gray
}

# 2. 创建共享文件夹
Write-Host "[2/4] 创建共享文件夹..." -ForegroundColor Yellow
if (-not (Test-Path "$folderPath")) {
    New-Item -ItemType Directory -Path "$folderPath" -Force | Out-Null
    Write-Host "  [OK] 已创建文件夹: $folderPath" -ForegroundColor Green
} else {
    Write-Host "  [INFO] 文件夹已存在" -ForegroundColor Gray
}

# 3. 设置隐藏共享
Write-Host "[3/4] 设置隐藏共享..." -ForegroundColor Yellow
try {
    # 删除旧共享（如果存在）
    Remove-SmbShare -Name "$hiddenShare" -Force -ErrorAction SilentlyContinue
    # 创建新共享
    New-SmbShare -Name "$hiddenShare" -Path "$folderPath" -FullAccess "$username" -Description "File Transfer Shared Folder" -ErrorAction Stop
    Write-Host "  [OK] 已创建隐藏共享: $hiddenShare" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] 创建共享失败: \$_" -ForegroundColor Red
}

# 4. 配置 NTFS 权限
Write-Host "[4/4] 配置文件夹权限..." -ForegroundColor Yellow
icacls "$folderPath" /inheritance:r | Out-Null
icacls "$folderPath" /grant:r "${username}:(OI)(CI)F" | Out-Null
icacls "$folderPath" /grant:r "Administrators:(OI)(CI)F" | Out-Null
icacls "$folderPath" /grant:r "SYSTEM:(OI)(CI)F" | Out-Null
Write-Host "  [OK] 已设置文件夹权限" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   配置完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "共享信息：" -ForegroundColor White
Write-Host "  共享名称: $hiddenShare"
Write-Host "  账户名:   $username"
Write-Host "  文件夹:   $folderPath"
Write-Host ""
Write-Host "请在手机 App 中使用以下信息连接：" -ForegroundColor White
Write-Host "  IP 地址:   [你的电脑IP]"
Write-Host "  共享名称:  $hiddenShare"
Write-Host "  用户名:   $username"
Write-Host "  密码:     ****"
Write-Host ""
Write-Host "提示：运行 ipconfig 查看电脑 IP 地址" -ForegroundColor Gray
Write-Host ""
Read-Host "按 Enter 退出"
''';
  }
}
