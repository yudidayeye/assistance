# ============================================================
# Flutter App 发布脚本 (Windows PowerShell 版)
# 用法: powershell -ExecutionPolicy Bypass -File scripts/release.ps1 <版本号> "<发布说明>"
# 示例: powershell -ExecutionPolicy Bypass -File scripts/release.ps1 1.0.1 "修复了输入数据后首页卡片不更新的问题"
# ============================================================

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$VERSION,

  [Parameter(Position = 1)]
  [string]$NOTES = ""
)

$ErrorActionPreference = "Stop"

$TAG = "v$VERSION"
$APK_DIR = "build/app/outputs/flutter-apk"
$APK_PATHS = @(
  "$APK_DIR/app-armeabi-v7a-release.apk",
  "$APK_DIR/app-arm64-v8a-release.apk",
  "$APK_DIR/app-x86_64-release.apk"
)
$ISCC_PATH = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$INSTALLER_DIR = "build/windows/installer"
$SETUP_PATH = "$INSTALLER_DIR/my_assistant_setup_$VERSION.exe"

Write-Host "========================================"
Write-Host "  发布 v$VERSION"
Write-Host "========================================"

# --- 检查前置条件 ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Write-Host "错误: 未找到 gh CLI，请先安装 https://cli.github.com/" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path pubspec.yaml)) {
  Write-Host "错误: 请在项目根目录运行此脚本" -ForegroundColor Red
  exit 1
}

# --- 更新 pubspec.yaml 版本号 ---
Write-Host ">>> 更新版本号到 ${VERSION}"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pubspecContent = [System.IO.File]::ReadAllText((Resolve-Path 'pubspec.yaml'), [System.Text.Encoding]::UTF8)
$line = ($pubspecContent -split "`n" | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
$versionPart = ($line -replace '^version:\s*', '').Trim()
$build = [int](($versionPart -split '\+')[1])
$newBuild = $build + 1
$pubspecContent = [regex]::Replace($pubspecContent, '^version:.*$', "version: $VERSION+$newBuild", [System.Text.RegularExpressions.RegexOptions]::Multiline)
[System.IO.File]::WriteAllText((Resolve-Path 'pubspec.yaml'), $pubspecContent, $utf8)
Write-Host "    新版本: $VERSION+$newBuild"

# --- 提交 ---
Write-Host ">>> 提交版本变更"
git add pubspec.yaml
git commit -m "chore: 发布 v$VERSION"

# --- 构建 APK ---
Write-Host ">>> 构建 Release APK"
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# --- 构建 Windows 桌面版 ---
Write-Host ">>> 构建 Windows 桌面版"
flutter build windows --release

# --- 创建 setup.exe 安装包 (Inno Setup) ---
Write-Host ">>> 创建 setup.exe 安装包 (Inno Setup)"
if (-not (Test-Path $ISCC_PATH)) {
  Write-Host "错误: 未找到 Inno Setup 编译器，请安装 https://jrsoftware.org/isinfo.php" -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force -Path $INSTALLER_DIR | Out-Null
& $ISCC_PATH /DMyAppVersion=$VERSION scripts/setup_windows.iss
if ($LASTEXITCODE -ne 0) {
  Write-Host "错误: Inno Setup 编译失败" -ForegroundColor Red
  exit 1
}

# --- 汇总待上传产物 ---
$RELEASE_FILES = $APK_PATHS + @($SETUP_PATH)

# --- 打 Tag ---
Write-Host ">>> 打 Tag: ${TAG}"
foreach ($FILE in $RELEASE_FILES) {
  if (-not (Test-Path $FILE)) {
    Write-Host "错误: 发布产物构建失败，路径: $FILE" -ForegroundColor Red
    exit 1
  }
  $size = (Get-Item $FILE).Length / 1MB
  Write-Host ("    {0}: {1:N1} MB" -f (Split-Path $FILE -Leaf), $size)
}

git tag $TAG

# --- 推送到远程 ---
Write-Host ">>> 推送到远程"
git push
git push origin $TAG

# --- 创建 GitHub Release ---
Write-Host ">>> 创建 GitHub Release"

if ([string]::IsNullOrWhiteSpace($NOTES)) {
  # 无自定义说明，生成默认 Release Notes
  gh release create $TAG --title $TAG --generate-notes @RELEASE_FILES
} else {
  gh release create $TAG --title $TAG --notes $NOTES @RELEASE_FILES
}

Write-Host ""
Write-Host "========================================"
Write-Host "  ✔ 发布完成！"
$repo = (gh repo view --json nameWithOwner -q .nameWithOwner)
Write-Host "  https://github.com/$repo/releases/tag/$TAG"
Write-Host "========================================"