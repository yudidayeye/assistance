# Windows 平台设置指南

## 问题描述

在 Windows 上运行 Flutter 应用时，可能会遇到以下错误：

```
Invalid argument(s): Couldn't resolve native function 'sqlite3_initialize'
Failed to load dynamic library 'sqlite3.dll'
```

这是因为 Windows 平台需要 SQLite 的原生动态链接库 (DLL) 文件。

## 解决方案

### 方法一：自动设置（推荐）

运行自动设置脚本：

```bash
# 在项目根目录下
windows\setup_sqlite3.bat
```

该脚本会自动下载并安装 `sqlite3.dll` 文件到正确位置。

### 方法二：手动设置

1. 访问 SQLite 官方下载页面：https://www.sqlite.org/download.html

2. 下载 "Precompiled Binaries for Windows" 部分的 `sqlite-dll-win-x64-*.zip` 文件

3. 解压下载的 ZIP 文件，找到 `sqlite3.dll` 文件

4. 将 `sqlite3.dll` 复制到以下目录之一：
   - `windows\runner\` （项目内，推荐）
   - 应用的构建输出目录
   - 系统 PATH 包含的目录

### 方法三：使用 vcpkg（高级用户）

如果已安装 vcpkg：

```bash
vcpkg install sqlite3:x64-windows
```

## 验证安装

设置完成后，重新构建并运行应用：

```bash
flutter clean
flutter pub get
flutter run -d windows
```

## 常见问题

### Q: 下载脚本失败怎么办？

A: 由于网络问题，自动下载可能失败。请使用方法二手动下载。

### Q: 放置 DLL 后仍然报错？

A: 确保：
1. DLL 文件名是 `sqlite3.dll`（区分大小写）
2. DLL 是 64 位版本（与你的 Dart/Flutter 版本匹配）
3. 重新运行 `flutter clean` 后再构建

### Q: 如何确认 DLL 是否正确加载？

A: 应用启动时，控制台会显示 SQLite 相关的初始化信息。如果没有错误信息，说明加载成功。

## 技术说明

本项目使用 `sqflite_common_ffi` 包在 Windows 上提供 SQLite 支持。该包通过 FFI (Foreign Function Interface) 调用 SQLite 的原生库，因此需要 `sqlite3.dll` 文件。

## 相关文件

- `lib/core/storage/database_service.dart` - 数据库服务初始化
- `windows/setup_sqlite3.bat` - 自动设置脚本
- `pubspec.yaml` - 依赖配置