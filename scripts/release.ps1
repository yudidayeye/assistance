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
# 提取当前 build number，并 +1
$line = (Select-String -Path pubspec.yaml -Pattern '^version:' | Select-Object -First 1).Line
$versionPart = ($line -replace '^version:\s*', '').Trim()
$build = [int](($versionPart -split '\+')[1])
$newBuild = $build + 1
(Get-Content pubspec.yaml) -replace '^version:.*', "version: $VERSION+$newBuild" | Set-Content pubspec.yaml
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

# --- 打 Tag ---
Write-Host ">>> 打 Tag: ${TAG}"
foreach ($APK_PATH in $APK_PATHS) {
  if (-not (Test-Path $APK_PATH)) {
    Write-Host "错误: 分包 APK 构建失败，路径: $APK_PATH" -ForegroundColor Red
    exit 1
  }
  $size = (Get-Item $APK_PATH).Length / 1MB
  Write-Host ("    {0}: {1:N1} MB" -f (Split-Path $APK_PATH -Leaf), $size)
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
  gh release create $TAG --title $TAG --generate-notes @APK_PATHS
} else {
  gh release create $TAG --title $TAG --notes $NOTES @APK_PATHS
}

Write-Host ""
Write-Host "========================================"
Write-Host "  ✔ 发布完成！"
$repo = (gh repo view --json nameWithOwner -q .nameWithOwner)
Write-Host "  https://github.com/$repo/releases/tag/$TAG"
Write-Host "========================================"
