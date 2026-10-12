#!/bin/bash
set -e

# ============================================================
# Flutter App 发布脚本
# 用法：bash scripts/release.sh <版本号> ["发布说明"] [--clean]
# 示例：bash scripts/release.sh 1.2.9 "修复了导入数据后首页卡片不更新的问题"
#
# 默认**不执行 `flutter clean`**。build/ 通常存有约 1.7 GB 热缓存（Gradle /
# CMake / 原生插件），clean 会让每次发布都从零重建，Android 端代价最大。
# 已实测：不 clean 的增量构建同样会把新版本号注入产物——APK 的 versionName /
# versionCode 与 exe 的 FileVersion / ProductVersion 都会自动更新（Gradle 与
# MSBuild 的 up-to-date 检查都覆盖了 pubspec）。脚本在构建后**逐项断言**这两处，
# 断言不过才需要加 --clean 重跑。
#
# 何时该加 --clean：切换 Flutter SDK 版本、增删原生插件、或怀疑产物被污染。
# ============================================================

VERSION=""
NOTES=""
CLEAN=0
CI_BUILD=0
CI_PUBLISH=0
CI_SINGLE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --clean) CLEAN=1 ;;
    --ci-build) CI_BUILD=1 ;;
    --ci-publish) CI_PUBLISH=1 ;;
    --ci-single-publish) CI_SINGLE=1 ;;
    -*)
      echo "未知选项: $1"
      exit 1
      ;;
    *)
      if [ -z "$VERSION" ]; then
        VERSION="$1"
      elif [ -z "$NOTES" ]; then
        NOTES="$1"
      fi
      ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  echo "用法: $0 <版本号> [\"发布说明\"] [--clean]"
  echo "示例: $0 1.2.9 \"修复了XX问题\""
  exit 1
fi

TAG="v${VERSION}"
APK_DIR="build/app/outputs/flutter-apk"
APK_PATHS=(
  "$APK_DIR/app-armeabi-v7a-release.apk"
  "$APK_DIR/app-arm64-v8a-release.apk"
  "$APK_DIR/app-x86_64-release.apk"
)
ISCC="C:/Program Files (x86)/Inno Setup 6/ISCC.exe"
INSTALLER_DIR="build/windows/installer"
SETUP_PATH="$INSTALLER_DIR/my_assistant_setup_${VERSION}.exe"
EXE_PATH="build/windows/x64/runner/Release/my_assistant.exe"
MANIFEST_META="build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json"

# 是否是 Windows 环境（决定是否构建桌面版与安装包）
IS_WINDOWS=0
if [[ "$OS" == "Windows_NT" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$(uname -s)" == MSYS* ]]; then
  IS_WINDOWS=1
fi

fail() {
  echo "错误: $1"
  exit 1
}

# Actions 分平台构建与统一发布；常规本地发布流程保持不变。
if [ "$((CI_BUILD + CI_PUBLISH + CI_SINGLE))" -gt 1 ]; then
  fail "CI 构建和发布选项不能混用"
fi
if [ "$CI_SINGLE" -eq 1 ]; then
  python3 scripts/ci_release.py publish-single "$VERSION" "$CI_RELEASE_BUILD" "$CI_RELEASE_PLATFORM" "$CI_SOURCE_SHA" "$CI_BASE_SHA"
  exit 0
fi
if [ "$CI_BUILD" -eq 1 ]; then
  python3 "${CI_RELEASE_HELPER:-scripts/ci_release.py}" set-version "$VERSION" "$CI_RELEASE_BUILD"
  flutter pub get --enforce-lockfile
  flutter build apk --release --split-per-abi
  python3 "${CI_RELEASE_HELPER:-scripts/ci_release.py}" android "$VERSION" "$CI_RELEASE_BUILD"
  exit 0
fi
if [ "$CI_PUBLISH" -eq 1 ]; then
  python3 scripts/ci_release.py publish "$VERSION" "$CI_RELEASE_BUILD" "$CI_RELEASE_MODE" "$CI_SOURCE_SHA"
  exit 0
fi

echo "========================================"
echo "  发布 v${VERSION}"
echo "========================================"

# ============================================================
# --- 前置条件：全部检查完再动手 ---
# 这些检查必须在改 pubspec、跑构建**之前**完成。原先 Inno Setup 的检查夹在
# 构建流程中间，缺 ISCC 时会白白等一整套构建；而分支 upstream、tag 重名、
# 工作区脏这些更致命的检查原先根本没有。
# ============================================================
echo ">>> 检查前置条件"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "版本号格式应为 x.y.z，收到: $VERSION"
fi

if ! command -v gh &> /dev/null; then
  fail "未找到 gh CLI，请先安装 https://cli.github.com/"
fi

if [ ! -f pubspec.yaml ]; then
  fail "请在项目根目录运行此脚本"
fi

if [ "$IS_WINDOWS" -eq 1 ] && [ ! -f "$ISCC" ]; then
  fail "未找到 Inno Setup 编译器，请安装 https://jrsoftware.org/isinfo.php"
fi

# 工作区必须干净：本次发布只该产生一个 pubspec 的版本提交。若夹带其他改动，
# 那个提交会变成一锅乱炖，事后也无法靠 `git checkout pubspec.yaml` 回退。
if [ -n "$(git status --porcelain)" ]; then
  git status --porcelain
  fail "工作区有未提交的改动，请先提交或 stash 后再发布"
fi

# tag 重名：原先会走到 `git tag` 才失败，而那时代码可能已经推上去了，
# 留下「代码已推、tag 没打」的半截状态。
if git rev-parse -q --verify "refs/tags/$TAG" > /dev/null 2>&1; then
  fail "tag $TAG 已存在，请换一个版本号"
fi

# 上游分支：当前分支若无 upstream，`git push` 会失败（set -e 会拦下，但那时
# 已经晚了），且无法判断该推到哪里。先查清楚。
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || \
  fail "当前分支未设置 upstream，发布会把 tag 推到不可达的提交上。请先 git push -u origin <分支>，或切到 master 再发布"
echo "    分支: $(git branch --show-current) -> $UPSTREAM"

# ============================================================
# --- 更新 pubspec.yaml 版本号 ---
# 必须在构建**之前**：版本号会被编译进产物（APK 的 versionName/versionCode、
# exe 的 FileVersion/ProductVersion），构建后再改就晚了。
# ============================================================
echo ">>> 更新版本号到 ${VERSION}"
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | sed 's/version: *//' | cut -d'+' -f2)
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i "s/^version: .*/version: ${VERSION}+${NEW_BUILD}/" pubspec.yaml
echo "    新版本: ${VERSION}+${NEW_BUILD}"

# ============================================================
# --- 构建 ---
# ============================================================
if [ "$CLEAN" -eq 1 ]; then
  echo ">>> 清理构建缓存（--clean）"
  flutter clean
else
  echo ">>> 跳过 flutter clean（保留热缓存；需要从零重建请加 --clean）"
fi

echo ">>> flutter pub get"
flutter pub get

echo ">>> 构建 Release APK"
flutter build apk --release --split-per-abi

RELEASE_FILES=("${APK_PATHS[@]}")
if [ "$IS_WINDOWS" -eq 1 ]; then
  echo ">>> 构建 Windows 桌面版"
  flutter build windows --release

  echo ">>> 创建 setup.exe 安装包 (Inno Setup)"
  mkdir -p "$INSTALLER_DIR"
  "$ISCC" "/DMyAppVersion=${VERSION}" scripts/setup_windows.iss
  RELEASE_FILES+=("$SETUP_PATH")
else
  echo ">>> 跳过 Windows 安装包（当前非 Windows 环境）"
fi

# ============================================================
# --- 校验产物确实来自本次构建 ---
# 光判断「文件存在」不够：构建失败时上一版的产物仍在原地，会被原样传上去。
# 这里断言版本号真的被注入，是「跳过 flutter clean」这一提速的前提条件。
# ============================================================
echo ">>> 校验产物版本号"

for FILE in "${RELEASE_FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    fail "构建产物缺失，路径: $FILE"
  fi
done

if [ ! -f "$MANIFEST_META" ]; then
  fail "找不到 APK 版本元数据: $MANIFEST_META（请加 --clean 重跑）"
fi

APK_VERSIONS=$(grep -o '"versionName": *"[^"]*"' "$MANIFEST_META" | grep -o '"[^"]*"$' | tr -d '"' | sort -u)
if [ "$APK_VERSIONS" != "$VERSION" ]; then
  fail "APK 内嵌版本号为 [$(echo $APK_VERSIONS | tr '\n' ' ')]，期望 $VERSION —— Gradle 未拾取版本变更，请加 --clean 重跑"
fi

# versionCode 为 <ABI 偏移>*1000 + build number，取模 1000 即得 build number
APK_BUILDS=$(grep -o '"versionCode": *[0-9]*' "$MANIFEST_META" | grep -o '[0-9]*$' | while read -r c; do echo $((c % 1000)); done | sort -u)
if [ "$APK_BUILDS" != "$NEW_BUILD" ]; then
  fail "APK 内嵌 build number 为 [$(echo $APK_BUILDS | tr '\n' ' ')]，期望 $NEW_BUILD —— 请加 --clean 重跑"
fi
echo "    APK: ${VERSION}+${NEW_BUILD} ✓"

if [ "$IS_WINDOWS" -eq 1 ]; then
  EXE_VERSION=$(powershell.exe -NoProfile -Command "(Get-Item '$EXE_PATH').VersionInfo.ProductVersion" | tr -d '\r')
  if [ "$EXE_VERSION" != "${VERSION}+${NEW_BUILD}" ]; then
    fail "exe 的 ProductVersion 为 $EXE_VERSION，期望 ${VERSION}+${NEW_BUILD} —— MSBuild 未拾取版本变更，请加 --clean 重跑"
  fi
  echo "    exe: $EXE_VERSION ✓"
fi

for FILE in "${RELEASE_FILES[@]}"; do
  echo "    $(basename "$FILE"): $(du -h "$FILE" | cut -f1)"
done

# ============================================================
# --- 提交 ---
# 放在构建与校验**之后**：原先先提交再构建，构建失败会留下一个「chore: 发布
# vX.Y.Z」的提交却没有对应发布，且状态难以回退。现在失败时只需
# `git checkout pubspec.yaml` 即可干净复原。
# ============================================================
echo ">>> 提交版本变更"
git add pubspec.yaml
git commit -m "chore: 发布 v${VERSION}"

# ============================================================
# --- 打 Tag 并推送 ---
# ============================================================
echo ">>> 打 Tag: ${TAG}"
git tag "$TAG"

echo ">>> 推送到远程"
git push
git push origin "$TAG"

# ============================================================
# --- 创建 GitHub Release ---
# ============================================================
echo ">>> 创建 GitHub Release"

if [ -z "$NOTES" ]; then
  # 无自定义说明，生成默认 Release Notes
  gh release create "$TAG" \
    --title "$TAG" \
    --generate-notes \
    "${RELEASE_FILES[@]}"
else
  # 带自定义说明
  gh release create "$TAG" \
    --title "$TAG" \
    --notes "$NOTES" \
    "${RELEASE_FILES[@]}"
fi

echo ""
echo "========================================"
echo "  ✅ 发布完成！"
echo "  https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
echo "========================================"
