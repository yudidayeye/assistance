# 发布流程

## 前提条件

- 已安装 [GitHub CLI](https://cli.github.com/) (`gh`)
- 已登录：`gh auth login`
- 当前在 `master` 分支，工作区干净（`git status` 无未提交更改）

## 发布步骤

### 1. 更新版本号

编辑 `pubspec.yaml`，递增版本号：

```yaml
# 格式：主版本.次版本.修订号+构建号
version: 1.0.1+2
```

规则：
- 修 bug：`1.0.0+1` → `1.0.1+2`
- 加小功能：`1.0.0+1` → `1.1.0+2`
- 重大变更：`1.0.0+1` → `2.0.0+2`

### 2. 提交版本变更

```bash
git add pubspec.yaml
git commit -m "chore: 发布 v1.0.1"
git push
```

### 3. 构建 APK

```bash
flutter clean
flutter pub get
flutter build apk --release
```

输出：`build/app/outputs/flutter-apk/app-release.apk`

### 4. 打 Tag 并创建 Release

```bash
# 打 tag（必须和 pubspec.yaml 的 version 一致，去掉 build number）
git tag v1.0.1
git push origin v1.0.1

# 创建 Release 并上传 APK
gh release create v1.0.1 \
  --title "v1.0.1" \
  --notes-file /dev/stdin \
  build/app/outputs/flutter-apk/app-release.apk <<'EOF'
### 变更内容
- （填写本次更新的内容）

### 安装说明
1. 下载 `app-release.apk`
2. 在手机上打开安装（需要允许"未知来源"）
EOF
```

### 5. 验证

打开 `https://github.com/<你的用户名>/<仓库名>/releases` 确认 Release 已创建，APK 可正常下载。

---

## 快速发布脚本

将下面的脚本保存为 `scripts/release.sh`，以后发布只需一行：

```bash
bash scripts/release.sh 1.0.1 "修复了导入数据后首页卡片不更新的问题"
```
