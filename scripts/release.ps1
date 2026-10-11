# ============================================================
# Flutter App 发布脚本 (Windows PowerShell 版)
# 用法: powershell -ExecutionPolicy Bypass -File scripts/release.ps1 <版本号> ["<发布说明>"] [-Clean]
# 为现有 Release 补 Windows 安装包：检出对应标签后，加 -WindowsOnly（保持版本和标签）。
# 示例: powershell -ExecutionPolicy Bypass -File scripts/release.ps1 1.2.9 "修复了输入数据后首页卡片不更新的问题"
#
# 默认**不执行 `flutter clean`**。build/ 通常存有约 1.7 GB 热缓存（Gradle /
# CMake / 原生插件），clean 会让每次发布都从零重建，Android 端代价最大。
# 已实测：不 clean 的增量构建同样会把新版本号注入产物——APK 的 versionName /
# versionCode 与 exe 的 FileVersion / ProductVersion 都会自动更新（Gradle 与
# MSBuild 的 up-to-date 检查都覆盖了 pubspec）。脚本在构建后**逐项断言**这两处，
# 断言不过才需要加 -Clean 重跑。
#
# 何时该加 -Clean：切换 Flutter SDK 版本、增删原生插件、或怀疑产物被污染。
# ============================================================

param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$VERSION,

  [Parameter(Position = 1)]
  [string]$NOTES = "",

  # 从零重建（慢，仅在需要时用）
  [switch]$Clean,

  # 同版本重发：保留 Release，构建成功后更新标签与附件。
  [switch]$Republish,

  # 给已发布的标签补充 Windows 安装包，不递增版本或修改标签。
  [switch]$WindowsOnly
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
$EXE_PATH = "build/windows/x64/runner/Release/my_assistant.exe"
$MANIFEST_META = "build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json"

function Fail([string]$Message) {
  Write-Host "错误: $Message" -ForegroundColor Red
  if ($env:GITHUB_ACTIONS -eq "true") { Write-Host "::error::$Message" }
  exit 1
}

Write-Host "========================================"
Write-Host "  发布 v$VERSION"
Write-Host "========================================"

# ============================================================
# --- 前置条件：全部检查完再动手 ---
# 这些检查必须在改 pubspec、跑构建**之前**完成。原先 Inno Setup 的检查放在
# 两个平台都构建完之后，缺 ISCC 时会白白等一整套构建；而分支 upstream、tag
# 重名、工作区脏这些更致命的检查原先根本没有。
# ============================================================
Write-Host ">>> 检查前置条件"

if ($VERSION -notmatch '^\d+\.\d+\.\d+$') {
  Fail "版本号格式应为 x.y.z，收到: $VERSION"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Fail "未找到 gh CLI，请先安装 https://cli.github.com/"
}

if (-not (Test-Path pubspec.yaml)) {
  Fail "请在项目根目录运行此脚本"
}

if (-not (Test-Path $ISCC_PATH)) {
  Fail "未找到 Inno Setup 编译器，请安装 https://jrsoftware.org/isinfo.php"
}

# 工作区必须干净：本次发布只该产生一个 pubspec 的版本提交。若夹带其他改动，
# 那个提交会变成一锅乱炖，事后也无法靠 `git checkout pubspec.yaml` 回退。
$dirty = git status --porcelain
if ($dirty) {
  Write-Host $dirty
  Fail "工作区有未提交的改动，请先提交或 stash 后再发布"
}

# 已发布版本补包：源码必须来自目标标签，保留原版本和已有附件。
if ($WindowsOnly) {
  if ($Republish) { Fail "-WindowsOnly 不能与 -Republish 同时使用" }
  $headCommit = git rev-parse HEAD
  if ($LASTEXITCODE -ne 0) { Fail "无法读取当前提交" }
  $tagCommit = git rev-parse "refs/tags/${TAG}^{commit}"
  if ($LASTEXITCODE -ne 0 -or $headCommit -ne $tagCommit) {
    Fail "补包必须在 $TAG 对应的源码检出中执行"
  }
  $versionLine = Get-Content pubspec.yaml -Encoding UTF8 | Where-Object { $_ -match '^version:' } | Select-Object -First 1
  if ($versionLine -notmatch "^version:\s+$([regex]::Escape($VERSION))\+(\d+)\s*$") {
    Fail "源码版本与 $VERSION 不匹配"
  }
  $expectedProductVersion = "$VERSION+$($Matches[1])"
  $releaseJson = gh release view $TAG --json tagName,isDraft,isPrerelease
  if ($LASTEXITCODE -ne 0) { Fail "目标 Release $TAG 不存在" }
  $release = $releaseJson | ConvertFrom-Json
  if ($release.tagName -ne $TAG -or $release.isDraft -or $release.isPrerelease) {
    Fail "补包要求 $TAG 已正式发布"
  }
  if ($Clean) {
    flutter clean
    if ($LASTEXITCODE -ne 0) { Fail "flutter clean 失败" }
  }
  flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { Fail "依赖安装失败" }
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { Fail "Windows 构建失败" }
  $actualVersion = (Get-Item $EXE_PATH).VersionInfo.ProductVersion
  if ($actualVersion -ne $expectedProductVersion) {
    Fail "exe 版本为 $actualVersion，期望 $expectedProductVersion"
  }
  New-Item -ItemType Directory -Force -Path $INSTALLER_DIR | Out-Null
  & $ISCC_PATH /DMyAppVersion=$VERSION scripts/setup_windows.iss
  if ($LASTEXITCODE -ne 0) { Fail "Inno Setup 编译失败" }
  if (-not (Test-Path $SETUP_PATH)) { Fail "安装包未生成" }
  $setup = Get-Item $SETUP_PATH
  $setupVersion = $setup.VersionInfo.ProductVersion
  $setupVersionParts = ([version]$setupVersion)
  $expectedVersionParts = ([version]$VERSION)
  if ($setupVersionParts.Major -ne $expectedVersionParts.Major -or $setupVersionParts.Minor -ne $expectedVersionParts.Minor -or $setupVersionParts.Build -ne $expectedVersionParts.Build) {
    Fail "安装包版本为 $setupVersion，期望 $VERSION"
  }
  $digest = (Get-FileHash $SETUP_PATH -Algorithm SHA256).Hash.ToLowerInvariant()
  gh release upload $TAG $SETUP_PATH --clobber
  if ($LASTEXITCODE -ne 0) { Fail "上传 Windows 安装包失败" }
  $releaseRepo = gh repo view --json nameWithOwner -q .nameWithOwner
  if ($LASTEXITCODE -ne 0) { Fail "读取仓库身份失败" }
  $uploadedJson = gh api "repos/$releaseRepo/releases/tags/$TAG"
  if ($LASTEXITCODE -ne 0) { Fail "读取上传结果失败" }
  $uploaded = $uploadedJson | ConvertFrom-Json
  $asset = @($uploaded.assets | Where-Object { $_.name -eq $setup.Name })
  if ($asset.Count -ne 1 -or $asset[0].state -ne 'uploaded' -or $asset[0].size -ne $setup.Length -or $asset[0].digest -ne "sha256:$digest") {
    Fail "上传产物的大小或 SHA-256 校验失败"
  }
  Write-Host "Windows 补包完成：$expectedProductVersion，SHA-256 $digest"
  Write-Host $asset[0].browser_download_url
  exit 0
}

# tag 重名：原先会走到 `git tag` 才失败，而那时 `git push` 可能已经执行，
# 留下「代码已推、tag 没打」的半截状态。
$tagExists = git rev-parse -q --verify "refs/tags/$TAG" 2>$null
if ($LASTEXITCODE -eq 0 -and -not $Republish) {
  Fail "tag $TAG 已存在，请换一个版本号"
}

$remoteTag = $null
if ($Republish) {
  gh release view $TAG --json url | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "重发要求远端 Release $TAG 已存在" }
  $remoteTagLine = git ls-remote origin "refs/tags/$TAG"
  if ($LASTEXITCODE -ne 0 -or -not $remoteTagLine) { Fail "无法读取远端标签 $TAG" }
  $remoteTag = ($remoteTagLine -split '\s+')[0]
}

# 上游分支：当前分支若无 upstream，脚本里的 `git push` 会失败但**脚本不会因此
# 中断**（PowerShell 不因原生命令非零退出而停止），接着 `git push origin $TAG`
# 却会成功——结果 tag 指向一个不在任何远端分支上的提交。
$upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
if ($LASTEXITCODE -ne 0) {
  Fail "当前分支未设置 upstream，发布会把 tag 推到不可达的提交上。请先 git push -u origin <分支>，或切到 master 再发布"
}
Write-Host "    分支: $(git branch --show-current) -> $upstream"

# ============================================================
# --- 更新 pubspec.yaml 版本号 ---
# 必须在构建**之前**：版本号会被编译进产物（APK 的 versionName/versionCode、
# exe 的 FileVersion/ProductVersion），构建后再改就晚了。
# ============================================================
Write-Host ">>> 更新版本号到 ${VERSION}"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pubspecPath = (Resolve-Path 'pubspec.yaml').Path
$pubspecContent = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)
$line = ($pubspecContent -split "`n" | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
if (-not $line) { Fail "pubspec.yaml 中找不到 version 行" }
$versionPart = ($line -replace '^version:\s*', '').Trim()
$build = [int](($versionPart -split '\+')[1])
$newBuild = $build + 1
$pubspecContent = [regex]::Replace($pubspecContent, '^version:.*$', "version: $VERSION+$newBuild", [System.Text.RegularExpressions.RegexOptions]::Multiline)
[System.IO.File]::WriteAllText($pubspecPath, $pubspecContent, $utf8)
Write-Host "    新版本: $VERSION+$newBuild"

# ============================================================
# --- 构建 ---
# ============================================================
if ($Clean) {
  Write-Host ">>> 清理构建缓存（-Clean）"
  flutter clean
  if ($LASTEXITCODE -ne 0) { Fail "flutter clean 失败" }
} else {
  Write-Host ">>> 跳过 flutter clean（保留热缓存；需要从零重建请加 -Clean）"
}

Write-Host ">>> flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get 失败" }

Write-Host ">>> 构建 Release APK"
flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { Fail "APK 构建失败" }

Write-Host ">>> 构建 Windows 桌面版"
flutter build windows --release
if ($LASTEXITCODE -ne 0) { Fail "Windows 构建失败" }

Write-Host ">>> 创建 setup.exe 安装包 (Inno Setup)"
New-Item -ItemType Directory -Force -Path $INSTALLER_DIR | Out-Null
& $ISCC_PATH /DMyAppVersion=$VERSION scripts/setup_windows.iss
if ($LASTEXITCODE -ne 0) { Fail "Inno Setup 编译失败" }

# ============================================================
# --- 校验产物确实来自本次构建 ---
# 光判断「文件存在」不够：构建失败时上一版的产物仍在原地，会被原样传上去。
# 这里断言版本号真的被注入，是「跳过 flutter clean」这一提速的前提条件。
# ============================================================
Write-Host ">>> 校验产物版本号"

foreach ($FILE in $APK_PATHS + @($SETUP_PATH, $EXE_PATH)) {
  if (-not (Test-Path $FILE)) { Fail "构建产物缺失，路径: $FILE" }
}

if (-not (Test-Path $MANIFEST_META)) { Fail "找不到 APK 版本元数据: $MANIFEST_META（请加 -Clean 重跑）" }
$meta = Get-Content -Raw -Encoding UTF8 $MANIFEST_META | ConvertFrom-Json
$apkVersions = @($meta.elements | ForEach-Object { $_.versionName } | Sort-Object -Unique)
if ($apkVersions.Count -ne 1 -or $apkVersions[0] -ne $VERSION) {
  Fail "APK 内嵌版本号为 [$($apkVersions -join ', ')]，期望 $VERSION —— Gradle 未拾取版本变更，请加 -Clean 重跑"
}
# versionCode 为 <ABI 偏移>*1000 + build number，取模即得 build number
$apkBuilds = @($meta.elements | ForEach-Object { $_.versionCode % 1000 } | Sort-Object -Unique)
if ($apkBuilds.Count -ne 1 -or $apkBuilds[0] -ne $newBuild) {
  Fail "APK 内嵌 build number 为 [$($apkBuilds -join ', ')]，期望 $newBuild —— 请加 -Clean 重跑"
}
Write-Host "    APK: $VERSION+$newBuild ✓"

$exeVersion = (Get-Item $EXE_PATH).VersionInfo.ProductVersion
if ($exeVersion -ne "$VERSION+$newBuild") {
  Fail "exe 的 ProductVersion 为 $exeVersion，期望 $VERSION+$newBuild —— MSBuild 未拾取版本变更，请加 -Clean 重跑"
}
Write-Host "    exe: $exeVersion ✓"

foreach ($FILE in $APK_PATHS + @($SETUP_PATH)) {
  $size = (Get-Item $FILE).Length / 1MB
  Write-Host ("    {0}: {1:N1} MB" -f (Split-Path $FILE -Leaf), $size)
}

# ============================================================
# --- 提交 ---
# 放在构建与校验**之后**：原先先提交再构建，构建失败会留下一个「chore: 发布
# vX.Y.Z」的提交却没有对应发布，且状态难以回退。现在失败时只需
# `git checkout pubspec.yaml` 即可干净复原。
# ============================================================
Write-Host ">>> 提交版本变更"
git add pubspec.yaml
git commit -m "chore: release v$VERSION"
if ($LASTEXITCODE -ne 0) { Fail "提交失败" }

# ============================================================
# --- 打 Tag 并推送 ---
# ============================================================
Write-Host ">>> 打 Tag: ${TAG}"
if ($Republish) { git tag -f $TAG } else { git tag $TAG }
if ($LASTEXITCODE -ne 0) { Fail "打 tag 失败" }

Write-Host ">>> 推送到远程"
git push
if ($LASTEXITCODE -ne 0) { Fail "推送分支失败" }
if ($Republish) {
  git push "--force-with-lease=refs/tags/${TAG}:$remoteTag" origin "refs/tags/$TAG"
} else {
  git push origin $TAG
}
if ($LASTEXITCODE -ne 0) { Fail "推送 tag 失败" }

# ============================================================
# --- 创建 GitHub Release ---
# ============================================================
Write-Host ">>> 创建 GitHub Release"
$RELEASE_FILES = $APK_PATHS + @($SETUP_PATH)

if ($Republish) {
  gh release upload $TAG --clobber @RELEASE_FILES
  if ($LASTEXITCODE -ne 0) { Fail "替换 Release 附件失败" }
  if (-not [string]::IsNullOrWhiteSpace($NOTES)) {
    gh release edit $TAG --notes $NOTES
    if ($LASTEXITCODE -ne 0) { Fail "更新 Release 说明失败" }
  }
} elseif ([string]::IsNullOrWhiteSpace($NOTES)) {
  # 无自定义说明，生成默认 Release Notes
  gh release create $TAG --title $TAG --generate-notes @RELEASE_FILES
} else {
  gh release create $TAG --title $TAG --notes $NOTES @RELEASE_FILES
}
if ($LASTEXITCODE -ne 0) { Fail "创建 Release 失败" }

Write-Host ""
Write-Host "========================================"
Write-Host "  ✔ 发布完成！"
$repo = (gh repo view --json nameWithOwner -q .nameWithOwner)
Write-Host "  https://github.com/$repo/releases/tag/$TAG"
Write-Host "========================================"
