# 理解（my_assistant）

一个使用 Flutter 开发的轻量级个人工具箱，当前包含周期记账、生理期记录和密码保险箱。应用以本地使用为核心，业务数据保存在设备 SQLite 数据库中，不接入云端同步或遥测。

> 当前主要支持：Android、Windows；iOS 暂不支持发布。
> 版本号以 `pubspec.yaml` 为准。

## 功能概览

### 周期记账

以发薪周期或自定义周期为单位管理收支，而不是只按自然月记账。

- 创建、编辑和关闭记账周期
- 将一个周期拆分为多个阶段
- 记录本金、余额、追加金额与分类支出
- 单独管理不计入日常总本金和总支出的大额记录
- 查看历史周期和聚合统计
- 提供余额趋势、月度支出、支出分类等图表

### 生理期记录

通过日历记录经期，并根据历史数据提供周期参考。

- 记录经期开始日期、结束日期和备注
- 在日历中查看历史记录与预测日期
- 根据最近记录计算加权平均周期
- 展示下次经期、排卵日、易孕期和当前周期天数
- 查看周期统计信息

> 周期预测仅供个人记录和日常参考，不能替代专业医疗建议。

### 密码保险箱

在本地分类保存账号、密码与备注信息。

- 设置并验证主密码
- 创建、排序和管理密码分类
- 新增、查看、编辑和复制密码条目
- 支持结构化多条备注
- Windows 支持通过分类快捷方式直接进入指定分类
- 离开模块时自动锁定会话

密码保护采用：

- Argon2id：从主密码派生 256-bit 密钥
- AES-256-GCM：加密密码内容
- 随机盐与随机 IV

主密码不会以明文形式保存。请妥善保管主密码；遗忘后可能无法恢复保险箱中的数据。

### 数据管理与设备同步

- 将应用设置和各模块数据导出为 JSON 备份
- 导入前预览并校验备份文件
- 在事务中合并导入数据，降低部分写入风险
- 通过局域网自动发现设备
- 在同一局域网内点对点发送和接收数据
- 接收端确认后才执行导入

局域网同步不等同于云同步，设备需要处于可互相访问的同一网络环境。

### 个性化设置

- 启用或停用首页模块
- 调整模块展示顺序
- 切换应用主题
- 数据导入、导出与局域网同步
- 检查应用更新

## 技术栈

| 类别 | 技术 |
| --- | --- |
| UI | Flutter、Material |
| 路由 | GoRouter |
| 本地存储 | SQLite、sqflite、sqflite_common_ffi |
| 图表 | fl_chart |
| 文件处理 | file_picker、path_provider、open_filex |
| 局域网通信 | Dart HTTP Server、UDP、shelf、http、dio |
| 密码学 | Argon2id（pointycastle）、AES-256-GCM（encrypt） |
| 国际化基础 | flutter_localizations、intl |
| 测试 | flutter_test |

## 项目结构

```text
lib/
├── main.dart                    # 应用入口与初始化流程
├── core/
│   ├── module_system/           # ToolModule 接口、模块注册与模块上下文
│   ├── routing/                 # GoRouter 全局路由
│   ├── settings/                # 设置、导入导出与版本更新
│   ├── storage/                 # SQLite 初始化、表结构与迁移
│   ├── sync/                    # 局域网设备发现与数据收发
│   └── theme/                   # 主题定义与主题状态
├── modules/
│   ├── period_book/             # 周期记账
│   ├── period_tracker/          # 生理期记录与预测
│   └── vault/                   # 密码保险箱
├── pages/                       # 首页外壳与个人页
└── shared/                      # 通用样式、工具和组件

test/                            # 与 lib/ 结构对应的测试
scripts/                         # 发布、安装包、图标与诊断脚本
docs/                            # PRD、SPEC、UI 规范
```

应用启动时按照以下顺序初始化：

1. 初始化 SQLite 工厂
2. 打开数据库并执行必要迁移
3. 注册所有 `ToolModule`
4. 初始化模块设置
5. 加载设置与主题
6. 根据已注册模块构建路由并启动应用

## 开发环境

### 基础要求

- Flutter stable
- Dart SDK `>=3.0.0 <4.0.0`
- Git

建议先确认本机环境：

```bash
flutter doctor
flutter --version
```

### Android 额外要求

- Android Studio 或可用的 Android SDK
- Java 17
- 已连接的 Android 设备或已启动的模拟器

当前 Android 工程使用 `compileSdk 36`。Release 构建目前仍使用 debug signing，仅适合内部测试；正式分发前应配置独立的 release keystore，并修改应用包名。

### Windows 额外要求

- Windows 10/11 64 位
- Visual Studio 2022，并安装“使用 C++ 的桌面开发”工作负载
- CMake 和 Windows SDK
- `sqlite3.dll`

首次进行 Windows 开发时，可在项目根目录执行：

```powershell
windows\setup_sqlite3.bat
```

该脚本会将 `sqlite3.dll` 安装到 Windows Runner 所需目录。

## 获取并运行项目

```bash
git clone https://github.com/yudidayeye/assistance.git
cd assistance
flutter pub get
```

查看可用设备：

```bash
flutter devices
```

运行 Android：

```bash
flutter run -d android
```

运行 Windows：

```bash
flutter run -d windows
```

也可以将 `android` 或 `windows` 替换为 `flutter devices` 输出的具体设备 ID。

## 数据存储与隐私

业务数据默认保存在本地 SQLite 数据库 `toolbox.db` 中：

- Android：应用私有数据库目录
- Windows：应用支持目录下的 `my_assistant/toolbox.db`

项目不提供云端同步，也不应引入遥测。局域网同步只在用户主动进入同步页面并操作时使用本地网络。

需要迁移设备或重装应用时，请先通过应用内的导出功能创建 JSON 备份。备份中包含应用业务数据；密码保险箱字段保持数据库中的加密形式，但备份文件仍应作为敏感文件妥善保管。

## 开发与质量检查

格式化代码：

```bash
dart format lib test
```

执行静态分析：

```bash
flutter analyze
```

测试应按改动范围运行，不默认执行全量测试：

```bash
# 单个测试文件
flutter test test/modules/vault/vault_crypto_service_test.dart

# 单个模块
flutter test test/modules/vault

# 精确筛选测试名称
flutter test test/modules/vault/vault_service_test.dart --name "关键字"
```

只有修改 `lib/core/`、`lib/shared/` 且影响多个模块时，才运行全量测试：

```bash
flutter test
```

## 新增模块

每个功能模块应实现 `ToolModule`，并提供模块标识、展示信息、入口页面、生命周期、摘要以及可选子路由。

基本步骤：

1. 在 `lib/modules/<module_id>/` 下创建 `models/`、`services/`、`pages/` 和 `widgets/`
2. 创建 `<module_id>_module.dart` 并实现 `ToolModule`
3. 数据表使用 `mod_<module_id>_...` 前缀
4. 在 `lib/main.dart` 的 `ModuleRegistry.registerAll()` 中注册模块
5. 通过模块的 `buildSubRoutes()` 声明子路由
6. 在 `test/modules/<module_id>/` 中补充 unit 或 widget 测试

根路由由 `AppRouter` 根据已注册模块动态生成，无需为每个模块重复添加顶层 `GoRoute`。

## 构建

构建分 ABI Android APK：

```bash
flutter build apk --release --split-per-abi
```

构建 Android App Bundle：

```bash
flutter build appbundle --release
```

构建 Windows Release：

```bash
flutter build windows --release
```

常见输出目录：

```text
build/app/outputs/flutter-apk/
build/app/outputs/bundle/release/
build/windows/x64/runner/Release/
```

## 发布版本

发布必须通过仓库脚本完成，脚本会更新 `pubspec.yaml`、提交版本变更、构建产物、创建 Git Tag、推送远程并创建 GitHub Release。

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/release.ps1 1.2.7 "本次发布说明"
```

其他 Shell：

```bash
bash scripts/release.sh 1.2.7 "本次发布说明"
```

发布前需要：

- 安装并登录 GitHub CLI：`gh auth login`
- 确认当前位于正确分支
- 确认工作区没有无关改动
- Windows 安装包构建需要安装 Inno Setup 6
- 先运行 `flutter analyze` 和相关测试

版本规则：

- 未明确指定版本号时，只递增修订号（patch），例如 `1.2.6` → `1.2.7`
- 构建号由发布脚本自动递增
- 只有明确指定目标版本号时，才修改主版本号（major）或次版本号（minor）
- 不要用手动修改版本号、打 Tag 或创建 Release 的方式替代脚本

## 相关文档

- [`AGENTS.md`](AGENTS.md)：仓库开发与 Agent 协作规范
- [`docs/PRD.md`](docs/PRD.md)：产品需求文档
- [`docs/SPEC.md`](docs/SPEC.md)：功能与技术规格
- [`docs/UI.md`](docs/UI.md)：界面设计规范，调整视觉样式前必读

## 注意事项

- 项目定位为本地个人工具集，不应引入云端同步或遥测
- 密码保险箱的安全性仍依赖用户主密码强度、设备安全和备份文件保管方式
- 生理期预测为基于历史记录的估算，不构成医疗建议
- 当前 Android Application ID 仍为 `com.example.my_assistant`，正式发布前需要替换
- 当前仓库未声明开源许可证；未经许可，请勿默认将代码视为可自由分发的软件
