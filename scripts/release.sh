#!/bin/bash
set -e

# ============================================================
# Flutter App 发布脚本
# 用法：bash scripts/release.sh <版本号> "<发布说明>"
# 示例：bash scripts/release.sh 1.0.1 "修复了导入数据后首页卡片不更新的问题"
# ============================================================

if [ $# -lt 1 ]; then
  echo "用法: $0 <版本号> [\"发布说明\"]"
  echo "示例: $0 1.0.1 \"修复了XX问题\""
  exit 1
fi

VERSION="$1"
NOTES="${2:-}"
TAG="v${VERSION}"
APK_DIR="build/app/outputs/flutter-apk"
APK_PATHS=(
  "$APK_DIR/app-armeabi-v7a-release.apk"
  "$APK_DIR/app-arm64-v8a-release.apk"
  "$APK_DIR/app-x86_64-release.apk"
)

echo "========================================"
echo "  发布 v${VERSION}"
echo "========================================"

# --- 检查前提 ---
if ! command -v gh &> /dev/null; then
  echo "错误: 未找到 gh CLI，请先安装 https://cli.github.com/"
  exit 1
fi

if [ ! -f pubspec.yaml ]; then
  echo "错误: 请在项目根目录运行此脚本"
  exit 1
fi

# --- 更新 pubspec.yaml 版本号 ---
echo ">>> 更新版本号到 ${VERSION}"
# 提取当前 build number，+1
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | sed 's/version: *//' | cut -d'+' -f2)
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i "s/^version: .*/version: ${VERSION}+${NEW_BUILD}/" pubspec.yaml
echo "    新版本: ${VERSION}+${NEW_BUILD}"

# --- 提交 ---
echo ">>> 提交版本变更"
git add pubspec.yaml
git commit -m "chore: 发布 v${VERSION}"

# --- 构建 APK ---
echo ">>> 构建 Release APK"
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# --- 构建 Windows 桌面版与 MSIX 安装包（仅 Windows 环境） ---
RELEASE_FILES=("${APK_PATHS[@]}")
if [[ "$OS" == "Windows_NT" ]] || [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$(uname -s)" == MSYS* ]]; then
  echo ">>> 构建 Windows 桌面版"
  flutter build windows --release

  echo ">>> 创建 MSIX 安装包"
  MSIX_VERSION="${VERSION}.${NEW_BUILD}"
  MSIX_DIR="build/windows/msix"
  MSIX_NAME="my_assistant_${VERSION}_x64"
  mkdir -p "$MSIX_DIR"
  dart run msix:create --build-windows false --version "$MSIX_VERSION" --output-path "$MSIX_DIR" --output-name "$MSIX_NAME"
  MSIX_PATH="$MSIX_DIR/$MSIX_NAME.msix"
  RELEASE_FILES+=("$MSIX_PATH")
else
  echo ">>> 跳过 Windows 安装包（当前非 Windows 环境）"
fi

# --- 打 Tag ---
echo ">>> 打 Tag: ${TAG}"
for FILE in "${RELEASE_FILES[@]}"; do
  if [ ! -f "$FILE" ]; then
    echo "错误: 发布产物构建失败，路径: $FILE"
    exit 1
  fi
  echo "    $(basename "$FILE"): $(du -h "$FILE" | cut -f1)"
done

git tag "$TAG"

# --- 推送到远程 ---
echo ">>> 推送到远程"
git push
git push origin "$TAG"

# --- 创建 GitHub Release ---
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
