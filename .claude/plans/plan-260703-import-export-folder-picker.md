# 开发计划：设置页导入导出手动选择文件夹

> 日期：2026-07-03
> 状态：待确认

---

## 一、需求背景

### 当前实现

| 功能 | 现状 | 痛点 |
|------|------|------|
| 导出 | 直接写入系统下载目录，路径自动返回 | 用户无法指定保存位置 |
| 导入 | 弹出手动输入路径的文本对话框 | 输入路径麻烦、易出错，移动端体验差 |

### 目标

- **导出**：用户可以选择保存目录，文件名自动生成（保持现有命名规则）
- **导入**：用户通过系统文件选择器选取备份文件，替代手动输入路径

---

## 二、技术方案

### 依赖：添加 `file_picker` 包

```yaml
# pubspec.yaml
dependencies:
  file_picker: ^9.0.0   # 系统文件/目录选择器
```

选择 `file_picker` 的原因：
- 支持文件选择（`FileType.custom` 限定 `.json`）和目录选择
- Android 上使用 Storage Access Framework（SAF），无需额外权限配置
- iOS 上调用系统文档选择器
- 维护活跃，API 简洁

---

## 三、改动清单

### 3.1 `pubspec.yaml`

新增依赖：

```yaml
file_picker: ^9.0.0
```

---

### 3.2 `lib/core/settings/import_export_service.dart`

**改动：** `exportData()` 新增可选参数 `directory`

```dart
// 现有签名
Future<ExportResult> exportData() async { ... }

// 新签名
Future<ExportResult> exportData({String? directory}) async { ... }
```

逻辑：
- 若 `directory` 不为空，直接写入该目录
- 若为空，保持现有逻辑（写入下载/文档目录）

```dart
final dir = directory ?? (await _getExportDirectory()).path;
final file = File('$dir${Platform.pathSeparator}$fileName');
```

---

### 3.3 `lib/core/settings/settings_page.dart`

#### 3.3.1 `_handleExport()` — 改为先选目录再导出

```dart
Future<void> _handleExport() async {
  // 1. 弹出目录选择器
  final selectedDir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: '选择导出保存目录',
  );
  if (selectedDir == null) return; // 用户取消

  _showSnackBar('正在导出数据...');
  final result = await _importExport.exportData(directory: selectedDir);
  // ... 处理结果（保持现有逻辑）
}
```

#### 3.3.2 `_handleImport()` — 改为用文件选择器选取 `.json` 文件

```dart
Future<void> _handleImport() async {
  // 1. 弹出文件选择器，限定 .json
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    allowMultiple: false,
  );
  if (picked == null || picked.files.isEmpty) return;

  final filePath = picked.files.single.path;
  if (filePath == null) {
    _showErrorDialog('导入失败', '无法获取文件路径');
    return;
  }

  // 2. 预览校验
  final preview = _importExport.previewImportFromPath(filePath);
  if (!preview.isReady) {
    _showErrorDialog('导入失败', preview.error ?? '文件格式无效');
    return;
  }

  // 3. 确认弹窗（保持现有逻辑）
  // 4. 执行导入（保持现有逻辑）
}
```

#### 3.3.3 删除 `_showPathInputDialog()` 方法

手动输入路径对话框不再使用，删除该方法。

---

## 四、UI 交互设计

### 导出流程

```
设置页 → 点击"导出数据"
  → 系统目录选择器弹出（Android: SAF 界面；iOS: 文件 app）
  → 用户选择/确认目录
  → 显示 SnackBar"正在导出..."
  → 成功：显示"已导出到：/path/to/file.json"
  → 失败：显示错误弹窗
```

### 导入流程

```
设置页 → 点击"导入数据"
  → 系统文件选择器弹出（仅显示 .json 文件）
  → 用户选取备份文件
  → 显示预览确认弹窗（设置数、记录数）
  → 用户确认 → 执行导入 → 显示成功 SnackBar
```

---

## 五、平台兼容性

| 平台 | 目录选择 | 文件选择 | 备注 |
|------|----------|----------|------|
| Android | ✅ SAF 界面 | ✅ SAF 文件选择 | 无需额外权限 |
| iOS | ✅ UIDocumentPicker | ✅ UIDocumentPicker | 需 Info.plist 配置 |
| Windows | ✅ 系统对话框 | ✅ 系统对话框 | 已支持 |

---

## 六、任务拆分

| # | 任务 | 文件 | 说明 |
|---|------|------|------|
| 1 | 添加 `file_picker` 依赖 | `pubspec.yaml` | `flutter pub get` |
| 2 | 修改 `exportData` 支持指定目录 | `import_export_service.dart` | 新增可选参数 `directory` |
| 3 | 修改 `_handleExport` 使用目录选择器 | `settings_page.dart` | 先选目录再导出 |
| 4 | 修改 `_handleImport` 使用文件选择器 | `settings_page.dart` | 选取 `.json` 文件，删除手动输入弹窗 |
| 5 | 删除 `_showPathInputDialog` 方法 | `settings_page.dart` | 已无用 |
| 6 | 运行测试验证 | — | 移动端真机/模拟器测试 |

---

## 七、风险与注意事项

1. **Android SAF 目录路径**：`getDirectoryPath()` 在 Android 上返回的是 SAF URI 映射的临时路径，可能存在权限持久化问题。若出现，可改为导出到固定目录 + 分享功能（作为备选方案）。
2. **iOS 文件选择器**：需在 `ios/Runner/Info.plist` 中确认 `LSSupportsOpeningDocumentsInPlace` 已设置为 `YES`。
3. **`file_picker` 版本**：需确认 `^9.0.0` 与当前 Flutter 版本兼容，必要时降级。

---

## 八、确认事项

- [ ] 是否接受添加 `file_picker` 依赖？
- [ ] 导出手动选择目录还是固定目录 + 分享？
- [ ] 是否需要对 Windows 平台做桌面端适配？
