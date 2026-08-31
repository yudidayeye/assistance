# 技术规格文档（SPEC）

## 1. 文档信息

| 项目 | 内容 |
| --- | --- |
| 项目名称 | `my_assistant` |
| 应用名称 | 理解 |
| 当前版本 | `1.2.6+31` |
| SQLite schema version | `17` |
| Dart SDK | `>=3.0.0 <4.0.0` |
| 文档更新时间 | 2026-08-31 |
| 相关文档 | [产品需求文档](./PRD.md)、[UI 设计规范](./UI.md) |

本文档描述当前源码对应的技术架构、数据模型、算法、路由、导入导出、局域网同步、安全实现、测试和发布要求。视觉 Token 与组件样式以 `docs/UI.md` 为准，本文件不重复定义。

## 2. 技术栈与平台

### 2.1 基础技术

- Flutter / Dart。
- GoRouter：应用路由和模块子路由。
- SQLite：核心业务数据和设置持久化。
- `sqflite`：Android 等移动平台数据库实现。
- `sqflite_common_ffi`：Windows、Linux 数据库实现。
- `ChangeNotifier`、`AnimatedBuilder`、`StatefulWidget`：当前主要状态更新方式。
- 静态单例服务：数据库、设置、主题、导入导出、同步、更新和模块服务。

`flutter_riverpod` 已声明为依赖，但当前并非应用主要状态管理架构。新增代码应先与现有服务和通知机制保持一致，除非执行经过评审的整体迁移。

### 2.2 主要依赖

| 依赖 | 用途 |
| --- | --- |
| `go_router` | 声明式路由 |
| `sqflite` | 移动端 SQLite |
| `sqflite_common_ffi` | Windows、Linux SQLite |
| `fl_chart` | 图表展示 |
| `intl` | 日期和数字格式化 |
| `uuid` | UUID 生成 |
| `path_provider`、`path` | 应用目录与路径处理 |
| `file_picker` | 选择导入、导出文件 |
| `shelf` | 局域网同步 HTTP 服务 |
| `http`、`dio` | HTTP 请求与下载 |
| `url_launcher` | 打开外部发布页面 |
| `package_info_plus` | 获取应用版本 |
| `open_filex` | 调用系统打开安装包 |
| `permission_handler`、`device_info_plus` | Android 安装权限和设备信息 |
| `encrypt`、`pointycastle` | Vault 加密、认证与密钥派生 |
| `flutter_markdown` | Markdown 内容展示 |

### 2.3 平台范围

- **Android**：当前主要移动发布平台。
- **Windows**：支持桌面运行、安装程序和 Vault 分类快捷方式。
- **Linux**：数据库层包含 FFI 路径，但不是当前明确发布目标。
- **iOS**：暂不支持发布。

Android 工程当前使用 `compileSdk = 36`、Java 17，`applicationId` 为 `com.example.my_assistant`。当前 Release 构建仍使用 debug signing，正式对外分发前应配置独立发布签名。

## 3. 项目结构

```text
lib/
├── main.dart
├── core/
│   ├── module_system/    # ToolModule、模块注册和运行期管理
│   ├── routing/          # GoRouter 配置和模块动态路由
│   ├── settings/         # 设置、导入导出、更新等能力
│   ├── storage/          # SQLite 初始化、建表和迁移
│   ├── sync/             # 局域网发现、发送和接收
│   └── theme/            # 主题定义、持久化和控制器
├── modules/
│   ├── period_book/      # 周期记账
│   ├── period_tracker/   # 生理期记录
│   └── vault/            # 密码保险箱
├── pages/                # 首页、设置、同步等应用级页面
└── shared/               # 跨模块复用组件和工具

test/
├── core/
├── modules/
├── shared/
└── widget_test.dart

docs/
├── PRD.md
├── SPEC.md
└── UI.md
```

模块内部通常按 `models/`、`services/`、`pages/`、`widgets/` 和 `*_module.dart` 组织。测试目录应尽量镜像源码结构。

## 4. 应用启动流程

`lib/main.dart` 按固定顺序执行初始化：

1. 初始化 Flutter binding 和 SQLite 工厂。
2. 打开 `toolbox.db`，创建或迁移数据库。
3. 向模块管理器注册内置模块。
4. 初始化模块默认设置。
5. 加载应用设置和主题。
6. 初始化 GoRouter。
7. 启动应用；Windows 若从 Vault 分类快捷方式进入，则使用相应分类路由作为初始位置。

当前模块注册顺序为：

```dart
[
  PeriodTrackerModule(),
  PeriodBookModule(),
  VaultModule(),
]
```

不得随意调整初始化先后顺序。路由、首页模块列表和模块摘要依赖数据库、模块及设置已经完成初始化。

## 5. 模块系统

### 5.1 `ToolModule` 契约

每个工具模块实现 `ToolModule`，主要成员如下：

```text
moduleId
 displayName
 description
 icon
 themeColor
 buildEntryPage
 buildSettingsPage
 buildSubRoutes
 onRegister
 onOpen
 onClose
 getSummary
```

职责划分：

- 元数据用于首页入口和模块管理。
- `buildEntryPage()` 构建模块根页面。
- `buildSettingsPage()` 可提供模块级设置页面。
- `buildSubRoutes()` 声明模块子路由。
- 生命周期方法用于初始化、进入、离开和资源清理。
- `getSummary()` 返回首页卡片摘要。

### 5.2 模块注册与状态

- 所有内置模块首次默认启用。
- 启用状态和顺序由 `SettingsService` 持久化。
- `SettingsController` 继承 `ChangeNotifier`，负责通知首页和设置页面刷新。
- 停用模块只影响入口可见性，不卸载代码、不删除数据库记录。
- 模块根路由由 `AppRouter` 根据 `moduleId` 动态创建为 `/<moduleId>`。

### 5.3 新增模块流程

1. 实现 `ToolModule`。
2. 模块表使用 `mod_<moduleId>_...` 命名。
3. 在 `main()` 中注册模块。
4. 通过 `buildSubRoutes()` 声明子页面。
5. 将数据库最终结构加入新建流程，并提供旧版本迁移。
6. 为核心服务、算法和关键 Widget 补充测试。
7. 更新 `README.md`、`docs/PRD.md`、`docs/SPEC.md`，涉及视觉规则时同步更新 `docs/UI.md`。

## 6. 路由规格

### 6.1 系统路由

| 路由 | 页面 |
| --- | --- |
| `/` | 主页面，包含“工具箱”和“我的” |
| `/settings` | 设置页面 |
| `/sync` | 局域网同步页面 |

### 6.2 周期记账路由

模块根路由：`/period_book`

| 子路由 | 用途 |
| --- | --- |
| `/period_book/new` | 新建周期 |
| `/period_book/edit/:id` | 编辑周期 |
| `/period_book/stage_edit/:stageId` | 编辑阶段 |
| `/period_book/history` | 历史周期 |
| `/period_book/detail/:id` | 周期详情 |
| `/period_book/large_items/:periodId` | 周期级大额收支 |

### 6.3 生理期记录路由

模块根路由：`/period_tracker`

| 子路由 | 用途 |
| --- | --- |
| `/period_tracker/stats` | 周期统计与预测 |

### 6.4 Vault 路由

模块根路由：`/vault`

| 子路由 | 用途 |
| --- | --- |
| `/vault/setup` | 设置主密码 |
| `/vault/unlock` | 验证主密码并解锁 |
| `/vault/category/:id` | 分类详情 |
| `/vault/add?categoryId=...` | 新建条目 |
| `/vault/edit/:id` | 编辑条目 |
| `/vault/view/:id` | 查看条目 |

Windows 分类快捷方式使用以下启动参数：

```text
--vault-category=<id>
```

参数只改变初始导航目标，不改变 Vault 的认证和锁定规则。

## 7. 状态与服务组织

### 7.1 应用级状态

- 设置和模块顺序：`SettingsService` + `SettingsController`。
- 主题：主题服务或控制器加载 `app_settings.theme_type` 并通知 `MaterialApp` 刷新。
- 首页模块摘要：模块服务提供数据，业务变化或导入后触发重新获取。
- 页面局部状态：主要由 `StatefulWidget` 管理。

### 7.2 服务约定

核心服务通常采用静态单例：

```dart
static final instance = ClassName._();
```

服务负责数据库访问、业务计算和跨页面共享状态。UI 不应自行拼接 SQL 或复制核心算法。

### 7.3 设置项

通用设置存入 `app_settings` 键值表。已知重要设置包括：

- 模块启用状态。
- 模块顺序。
- 本地用户名。
- 当前主题 `theme_type`。
- 模块自己的持久化配置，例如周期记账发薪日。

设置键应保持稳定。更名时必须提供兼容读取或迁移，避免重置用户配置。

## 8. SQLite 架构

### 8.1 数据库位置与初始化

数据库文件名为 `toolbox.db`。

- Windows、Linux：

  ```text
  getApplicationSupportDirectory()/my_assistant/toolbox.db
  ```

- 移动端：

  ```text
  getDatabasesPath()/toolbox.db
  ```

Windows、Linux 使用 `sqflite_common_ffi`，移动端使用 `sqflite`。数据库连接应启用外键约束。当前 schema version 为 `17`。

### 8.2 `app_settings`

```sql
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

### 8.3 生理期记录表

```sql
CREATE TABLE mod_period_tracker_records (
  id TEXT PRIMARY KEY,
  start_date TEXT NOT NULL,
  end_date TEXT,
  cycle_length INTEGER,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);

CREATE INDEX idx_period_start_date
ON mod_period_tracker_records(start_date);
```

约定：

- 日期和时间以字符串存储，由模型层统一序列化和解析。
- `end_date IS NULL` 表示当前记录仍在进行。
- `cycle_length` 根据相邻开始日期重新计算，不作为独立人工输入。

### 8.4 周期记账表

#### 周期

```sql
CREATE TABLE mod_period_book_periods (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  base_amount REAL NOT NULL,
  is_closed INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

#### 阶段

```sql
CREATE TABLE mod_period_book_stages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_id INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT NOT NULL,
  current_date TEXT,
  balance REAL,
  sort_order INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (period_id)
    REFERENCES mod_period_book_periods(id)
    ON DELETE CASCADE
);
```

#### 普通追加

```sql
CREATE TABLE mod_period_book_additions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id INTEGER NOT NULL,
  amount REAL NOT NULL,
  reason TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (stage_id)
    REFERENCES mod_period_book_stages(id)
    ON DELETE CASCADE
);
```

#### 普通支出

```sql
CREATE TABLE mod_period_book_expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stage_id INTEGER NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  description TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (stage_id)
    REFERENCES mod_period_book_stages(id)
    ON DELETE CASCADE
);
```

#### 大额追加

```sql
CREATE TABLE mod_period_book_large_additions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_id INTEGER NOT NULL,
  amount REAL NOT NULL,
  reason TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (period_id)
    REFERENCES mod_period_book_periods(id)
    ON DELETE CASCADE
);
```

#### 大额支出

```sql
CREATE TABLE mod_period_book_large_expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  period_id INTEGER NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL,
  description TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (period_id)
    REFERENCES mod_period_book_periods(id)
    ON DELETE CASCADE
);
```

#### 索引

```sql
CREATE INDEX idx_pb_periods_start_date
ON mod_period_book_periods(start_date);

CREATE INDEX idx_pb_stages_period
ON mod_period_book_stages(period_id);

CREATE INDEX idx_pb_expenses_stage
ON mod_period_book_expenses(stage_id);

CREATE INDEX idx_pb_additions_stage
ON mod_period_book_additions(stage_id);

CREATE INDEX idx_pb_large_additions_period
ON mod_period_book_large_additions(period_id);

CREATE INDEX idx_pb_large_expenses_period
ON mod_period_book_large_expenses(period_id);
```

### 8.5 Vault 表

#### 主密码验证信息

```sql
CREATE TABLE mod_vault_master (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  salt TEXT NOT NULL,
  verify_cipher TEXT NOT NULL,
  verify_iv TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

该表只保留验证和密钥派生所需数据，不保存主密码明文或派生主密钥。

#### 分类

```sql
CREATE TABLE mod_vault_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'folder',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_encrypted INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

#### 条目

```sql
CREATE TABLE mod_vault_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  username TEXT,
  encrypted_password TEXT NOT NULL,
  password_iv TEXT NOT NULL,
  salt TEXT,
  note TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (category_id)
    REFERENCES mod_vault_categories(id)
    ON DELETE CASCADE
);

CREATE INDEX idx_vault_entries_category
ON mod_vault_entries(category_id);
```

字段名 `encrypted_password` 为历史命名：当分类设置为不加密时，该字段存放密码明文。调用方必须结合分类的 `is_encrypted` 判断其语义，不能仅依据字段名推断密文状态。

`note` 当前保存多条结构化备注编码后的 JSON 字符串；旧版普通文本在模型层兼容转换为“其他”备注项。

### 8.6 数据库迁移历史

| 版本 | 变更 |
| --- | --- |
| v1 | 创建 `app_settings` 和生理期记录基础表 |
| v2 | 增加生理期开始日期索引 |
| v3 | 生理期记录增加 `note` |
| v4 | 创建周期记账初始表 |
| v5 | 删除旧 `accounting` 模块表 |
| v6 | 周期记账引入阶段并迁移旧数据 |
| v7 | 普通支出增加 `sort_order` |
| v8 | 阶段增加 `current_date` |
| v9 | 增加大额追加和大额支出表 |
| v10 | 普通追加增加 `sort_order` |
| v11 | 大额追加增加 `sort_order` |
| v12 | 无数据库结构变化 |
| v13 | 增加 Vault 主表、分类表、条目表和分类索引 |
| v14 | Vault 条目增加 `username` |
| v15 | Vault 分类增加 `is_encrypted` |
| v16 | Vault 条目增加 `sort_order` |
| v17 | Vault 条目增加独立 `salt`，旧条目回填主盐 |

全新安装由 `_onCreate()` 直接创建最终结构，不逐版执行迁移。旧安装升级时按版本差异执行兼容迁移。修改 schema 时必须同时维护最终建表 SQL、版本号和升级路径。

## 9. 周期记账实现规格

### 9.1 模块元数据

| 属性 | 值 |
| --- | --- |
| `moduleId` | `period_book` |
| 名称 | 周期记账 |
| 描述 | 以发薪周期为单位的轻量记账工具 |
| 主题色 | `#7B8BAA` |

### 9.2 周期日期计算

- 发薪日取值范围为 1 至 31，默认值为 10。
- 指定日期超过目标月份天数时，使用该月最后一天。
- 自动周期开始日为本次发薪日，结束日为下一次发薪日前一天。
- 自定义周期直接使用用户选择的开始和结束日期。
- 保存前查询已有周期，不允许日期区间重叠。
- 当未关闭周期的 `end_date` 早于当天时，服务自动更新 `is_closed = 1`。

日期区间重叠判断应采用闭区间语义：任意一天同时属于两个周期即视为重叠。

### 9.3 阶段拆分

创建周期时自动生成阶段：

1. 第一阶段从周期开始日到所在自然周的周日，若周期更早结束则截止周期结束日。
2. 后续阶段从周一开始，到周日结束。
3. 最后一阶段截止周期结束日。
4. `sort_order` 按日期顺序递增。

生成结果必须完整覆盖 `[period.start_date, period.end_date]`，阶段之间连续且不重叠。

### 9.4 阶段金额口径

阶段包含：

- 周期初始本金在阶段间形成的资金基础。
- 普通追加合计。
- 分类支出合计。
- 用户录入余额。
- `current_date` 指示该阶段当前记录推进到的日期。

生活支出倒推规则：

```text
生活支出 = 阶段本金 - 分类支出 - 其他支出 - 余额
```

其中参与倒推的已有支出不应再次计入生活支出。生活日均支出使用阶段有效记录天数作为分母；实现必须处理零天数，避免除零。

当前分类兼容关系包括：

- `shopping` → 购物。
- `other` → 其他。
- 当前分类还包括生活、工作、娱乐和大餐。

历史值不得因显示名称调整而无法读取。

### 9.5 大额收支

- 大额追加和大额支出关联 `period_id`，不关联阶段。
- 两类记录独立排序和展示。
- 大额收支不计入日常总本金和日常总支出。
- 周期总览可以单独展示大额收支结果，但必须保持统计口径可辨识。

### 9.6 聚合与摘要

服务层负责计算余额趋势、分类支出占比和月度支出等聚合结果。图表层只消费结果，不复制 SQL 聚合规则。

模块摘要：

- 无周期：`暂无周期，点击创建`。
- 有周期：显示日期范围，并根据当前数据显示余额或支出概览。

## 10. 生理期预测实现规格

### 10.1 模块元数据

| 属性 | 值 |
| --- | --- |
| `moduleId` | `period_tracker` |
| 名称 | 生理期记录 |
| 描述 | 女性生理周期记录与预测工具 |
| 主题色 | `#D4879A` |

### 10.2 基础计算

- `endDate == null` 表示进行中的经期。
- 经期持续天数：

  ```text
  end_date - start_date + 1
  ```

- 周期长度按相邻两条记录的开始日期差计算。
- 新增、编辑、删除或导入后，按开始日期重新排序并重算相关记录的 `cycle_length`。

### 10.3 预测常量

```dart
defaultCycleLength = 28;
minRecordsForWeighted = 3;
maxRecordsForWeight = 6;
ovulationOffset = 14;
fertileWindowBefore = 5;
fertileWindowAfter = 1;
defaultPeriodDuration = 5;
weights = [3, 2, 1, 1, 1, 1];
```

### 10.4 预测算法

1. 无历史记录时返回无预测结果。
2. 收集有效历史周期长度。
3. 有效周期长度少于 3 条时，使用默认 28 天。
4. 达到 3 条后，取最近最多 6 条有效周期长度。
5. 按 `[3, 2, 1, 1, 1, 1]` 从近期到远期进行加权平均。
6. 从最近一次经期开始日期加预测周期长度，得到候选下次经期。
7. 如果候选日期早于今天，则持续按预测周期向后推进，直到日期为今天或未来。
8. 排卵日为下次经期前 14 天。
9. 易孕期为排卵日前 5 天至排卵日后 1 天。
10. 预测经期默认持续 5 天。

预测属于统计估算。UI 和文档不得把结果表述为医学诊断或准确的避孕依据。

### 10.5 模块摘要

摘要展示：

- 预测的下次经期日期。
- 当前周期已进行天数。

无有效预测时应显示中性占位信息，不生成伪造日期。

## 11. Vault 安全实现规格

### 11.1 模块元数据

| 属性 | 值 |
| --- | --- |
| `moduleId` | `vault` |
| 名称 | 密码保险箱 |
| 描述 | 安全存储和管理常用密码 |
| 主题色 | `#6B8E7B` |

### 11.2 密钥派生与加密参数

主密码使用 Argon2id 派生 256-bit 密钥：

| 参数 | 值 |
| --- | --- |
| memory | 64 MB |
| iterations | 3 |
| parallelism | 1 |
| key length | 32 bytes |
| 默认盐长度 | 32 bytes |

密码字段使用 AES-256-GCM：

- 随机 IV 长度：12 bytes。
- 新建加密条目使用独立随机盐。
- 密文、IV 和盐分别持久化。
- GCM 负责机密性与完整性认证，解密认证失败不得返回部分明文。

### 11.3 主密码验证

`mod_vault_master` 保存：

- 主盐 `salt`。
- 验证密文 `verify_cipher`。
- 验证 IV `verify_iv`。

验证流程：

1. 使用用户输入主密码和主盐派生密钥。
2. 尝试解密验证密文。
3. 验证成功后，将当前主密码和派生密钥放入内存会话。
4. 验证失败时清理临时数据，并返回通用错误，避免泄露内部认证细节。

主密码本身和派生密钥不得写入数据库、设置或日志。

### 11.4 分类加密策略

- `is_encrypted = 1`：条目的密码字段使用 AES-256-GCM 密文保存。
- `is_encrypted = 0`：条目的密码字段以明文写入 `encrypted_password` 字段。
- 新分类默认 `is_encrypted = 1`。
- 切换加密状态时，在事务或等效的一致性边界内迁移分类全部条目。
- 从加密切换到不加密时先解密；从不加密切换到加密时为每个条目生成盐和 IV。
- 如果分类有条目且当前操作需要解密密钥，会话锁定时必须先解锁。

### 11.5 条目数据与备注

条目字段包括标题、用户名、密码、多条结构化备注和排序值。

- 只有密码字段根据分类状态加密。
- 标题、用户名、备注、分类信息为明文字段。
- 多条备注编码为 JSON 字符串写入 `note`。
- 读取非 JSON 旧备注时，将完整文本映射为“其他”类型的一条备注。
- 复制操作必须由用户主动触发；UI 应避免在锁定状态复制或展示加密密码。

### 11.6 会话锁定

`lock()` 必须：

- 清除内存中的主密码。
- 覆盖缓存派生密钥的字节后释放引用。
- 通知依赖会话状态的页面刷新。

以下事件触发锁定：

- 退出分类详情页。
- 应用生命周期进入 `inactive` 或后台。
- Vault 模块执行 `onClose()`。

桌面快捷方式不保留解锁状态，不得通过路由参数绕过验证。

### 11.7 安全边界

不得宣称“整个 Vault”或“整个数据库”均已加密。当前明确未加密的内容包括：

- 分类名称、图标、排序和加密标记。
- 条目标题、用户名、备注、排序和时间字段。
- 不加密分类中的密码。

备份文件包含 Vault 验证信息、密文、盐、IV 和明文元数据，应按敏感文件处理。主密码遗忘后，应用没有恢复加密密码的后门。

## 12. 导入导出规格

### 12.1 格式与 schema

当前备份格式为 UTF-8 JSON，schema version 为 `4`。当前实现不提供纯文本备份。

顶层数据包括：

```text
app_settings
period_tracker_records
period_book_periods
period_book_stages
period_book_additions
period_book_expenses
period_book_large_additions
period_book_large_expenses
vault_master
vault_categories
vault_entries
```

备份格式调整时必须增加 schema version，并保持对已发布旧版本的兼容读取或给出明确拒绝原因。

### 12.2 导出流程

1. 查询设置和各模块表。
2. 组装包含 schema version 的 JSON 对象。
3. 使用 UTF-8 写入用户选择的位置。
4. 返回明确的成功或错误结果。

导出不得删除、转换或重写当前数据库内容。

### 12.3 预览与校验

导入执行前必须：

- 解析 JSON。
- 验证顶层结构和版本字段。
- 统计可导入的数据类型和记录数量。
- 拒绝高于当前 schema version 的备份。
- 对不支持或结构损坏的数据给出错误，不进入写入事务。

### 12.4 导入事务

- 所有实际数据库写入在单个 SQLite 事务中执行。
- 设置和业务记录使用 `INSERT OR REPLACE` 合并。
- 相同主键由备份记录覆盖；未冲突的本地数据保留。
- 默认行为不是先清空数据库。
- 任一不可恢复写入错误应回滚整个事务。
- 生理期记录导入后在事务内重算周期长度。

导入成功后：

1. 重新加载应用设置。
2. 重新加载当前主题。
3. 通知周期记账、生理期记录和 Vault 刷新摘要或页面状态。

### 12.5 Vault 导入兼容规则

- 本地已经存在 `vault_master` 时，不覆盖本地主密码验证信息。
- 本地不存在主密码时，可以写入备份中的 `vault_master`。
- 带独立 `salt` 的新格式条目可以按记录合并。
- 如果本地主盐与备份主盐不同，并且备份中存在没有独立 `salt`、依赖备份主盐的旧格式条目，则跳过整个 Vault 数据导入。
- 跳过 Vault 不影响其他模块继续导入。
- 导入结果必须明确说明 Vault 是否因兼容保护被跳过。

该规则避免写入无法用本地主密码解密的旧条目，但也意味着并非所有备份都能在任意已有 Vault 环境中直接合并。

## 13. 局域网同步规格

### 13.1 架构

局域网同步传输完整 JSON 备份，包含：

- UDP 设备发现。
- 接收端 HTTP Server。
- 发送端 HTTP POST。
- UI 确认与导入。

它不是增量同步或云同步，不维护设备间长期一致性。

### 13.2 设备发现

- UDP 固定端口：`12346`。
- 在线设备每 2 秒广播一次。
- 超过 10 秒未再次出现的设备从发现列表移除。
- 接收端 HTTP 端口由系统动态分配。

在线广播内容：

```json
{
  "magic": "my_assistant_sync",
  "name": "<hostname>",
  "ip": "<lan-ip>",
  "port": "<dynamic-http-port>"
}
```

服务停止时发送附带以下字段的离线广播：

```json
{
  "offline": true
}
```

接收方必须校验 `magic` 和必要字段，忽略不属于本应用的 UDP 数据包。

### 13.3 数据发送

请求格式：

```text
POST http://<ip>:<port>/sync/upload
Content-Type: application/json
```

超时：

- 连接超时：10 秒。
- 响应超时：30 秒。

发送内容为当前应用生成的完整 JSON 备份。发送端应展示发现、连接、等待确认、完成或失败状态。

### 13.4 接收与确认

1. HTTP Server 接收请求。
2. 将请求内容写入系统临时 JSON 文件。
3. 调用普通导入预览逻辑校验文件。
4. 通过 `SyncRequest` 通知 UI 显示发送设备和数据摘要。
5. 用户确认后执行导入；拒绝时不修改数据库。
6. 确认等待最长 5 分钟，超时按拒绝处理。
7. 导入、拒绝或失败后删除临时文件。

不得在收到 HTTP 请求后未经用户确认自动导入。

### 13.5 安全限制

当前协议没有：

- 设备身份认证。
- 配对码。
- 请求签名。
- TLS 或应用层传输加密。

因此只能在可信局域网使用。公共 Wi-Fi 或其他不可信网络中的攻击者可能观察数据、伪装设备或发起请求。未来增加认证或加密时，应同步升级协议版本、兼容策略和 UI 风险提示。

## 14. 设置、主题与更新

### 14.1 设置页面

当前已接入：

- 模块管理。
- 主题设置。
- JSON 数据导入、导出。
- 局域网同步入口。
- 清除业务数据。
- 版本信息和检查更新。
- 隐私声明、免责声明静态条目。

当前占位、尚未实现：

- 通知管理。
- 帮助与反馈。

设置页面没有暴露数据库 `factoryReset()`。文档和 UI 不得把恢复出厂描述为当前可用入口。

### 14.2 清除业务数据

`clearAllBusinessData()` 删除所有名称匹配 `mod_%` 的业务表内容，包括 Vault。该操作：

- 不等同于仅删除周期记账和生理期记录。
- 不应删除 `app_settings`。
- 完成后刷新模块摘要和相关状态。
- 必须锁定 Vault。
- 必须在执行前明确提示实际影响范围。

### 14.3 主题

| 枚举 | 中文名称 | 主色 |
| --- | --- | --- |
| `softNight` | 柔夜 | `#0A82FD` |
| `morningMist` | 晨雾 | `#8AADB8` |
| `leafWhisper` | 叶语 | `#9CAD8A` |
| `flowerMist` | 花雾 | `#C9A0AA` |

主题标识写入 `app_settings.theme_type`。主题切换后应立即通知应用重建。具体颜色、字号、间距、圆角和组件行为以 `docs/UI.md` 为唯一视觉规范。

### 14.4 更新检查

`UpdateService` 请求：

```text
https://api.github.com/repos/yudidayeye/assistance/releases/latest
```

处理流程：

1. 读取本地 package version。
2. 获取 GitHub 最新 Release。
3. 对版本号各数字段进行语义比较。
4. 远端版本更高时展示更新信息。
5. 根据平台选择安装资产并下载。
6. 调用系统安装器，或在无法可信匹配时打开 Release 页面。

Android 资产选择顺序：

1. 与设备 ABI 精确匹配的 split APK。
2. `universal` APK。
3. 文件名中没有 ABI 标识的 APK。
4. 均无法可信匹配时打开 GitHub Release 页面。

Android 8 及以上需要处理“安装未知应用”权限。

Windows 选择 `.exe`，并优先文件名包含 `setup` 或 `installer` 的安装程序。

更新检查和安装包下载是明确联网行为，但不得上传 SQLite 数据、JSON 备份或模块业务内容。

## 15. 平台差异

### 15.1 Windows SQLite

Windows 首次开发或缺少原生 SQLite 库时执行：

```powershell
windows\setup_sqlite3.bat
```

### 15.2 Windows Vault 快捷方式

- 仅 Windows 提供分类桌面快捷方式。
- 快捷方式携带 `--vault-category=<id>` 参数。
- 启动时解析参数并导航到目标分类。
- 目标分类不存在时应回退到安全页面，而非崩溃。
- 加密分类仍需正常解锁。

### 15.3 Android 安装更新

- 根据 ABI 选择安装包。
- 下载完成后通过系统能力打开 APK。
- 权限被拒绝或安装器不可用时，应给出可恢复提示。

## 16. 测试策略

### 16.1 当前测试分布

仓库已有测试包括：

```text
test/widget_test.dart
test/core/settings/import_export_vault_sort_test.dart
test/core/settings/module_order_test.dart
test/core/settings/update_service_test.dart
test/modules/vault/vault_category_dialog_test.dart
test/modules/vault/vault_crypto_service_test.dart
test/modules/vault/vault_note_item_test.dart
test/modules/vault/vault_service_test.dart
test/modules/vault/vault_shortcut_service_test.dart
test/shared/date_utils_test.dart
test/shared/format_utils_test.dart
```

该列表表示当前已有测试，不代表所有 PRD 功能已完整覆盖。

### 16.2 按需运行规则

- 修改单个文件：运行对应测试文件。
- 修改整个模块：运行该模块测试目录。
- 使用 `--name "关键字"` 精确过滤测试。
- 只有修改 `lib/core/`、`lib/shared/` 且影响多个模块时，才默认运行全量 `flutter test`。
- 新增模块核心逻辑时，补充 unit 或 widget 测试。

示例：

```bash
flutter test test/modules/vault/vault_crypto_service_test.dart
flutter test test/modules/vault/
flutter test test/core/settings/update_service_test.dart --name "关键字"
```

提交前必须执行：

```bash
flutter analyze
flutter test <相关测试路径>
```

纯文档修改无需运行 Flutter 测试，但应进行 Markdown、链接和差异检查。

## 17. 构建与发布

### 17.1 常用命令

```bash
flutter run
flutter analyze
flutter test <路径>
flutter build apk
flutter build appbundle
flutter build windows
```

### 17.2 发布脚本

发布版本必须执行仓库脚本，不应手动替代完整发布流程：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/release.ps1 <版本号> "<发布说明>"
```

或：

```bash
bash scripts/release.sh <版本号> "<发布说明>"
```

脚本负责：

1. 更新 `pubspec.yaml` 版本。
2. 自动递增 build number。
3. 提交版本变更。
4. 构建 split APK。
5. 在 Windows 环境构建 Windows 应用和 Inno Setup 安装包。
6. 创建 Git tag。
7. 推送提交和 tag。
8. 创建 GitHub Release。

版本规则：

- 默认发布只递增最小版本号，即 SemVer 的 patch。
- 只有用户明确指定目标版本号时，才允许改变 major 或 minor。
- 不得因为功能规模推断并自动升级 major/minor。

提交行为还必须遵循仓库 `.codex/skills/commit/SKILL.md`。

## 18. 编码与文档约定

- 文件名使用 `snake_case`。
- 类名使用 `PascalCase`。
- 成员和函数使用 `camelCase`。
- 标识符、日志和 commit message 使用英文。
- 注释、文档和用户可见文本使用简体中文。
- 专有技术名词可保留英文，例如 Flutter、GoRouter、SQLite、Argon2id、AES-GCM。
- Dart 代码使用 `dart format`，静态分析遵循 `analysis_options.yaml`。
- PowerShell 读取文本使用 `Get-Content -Raw -Encoding UTF8`。
- PowerShell 写入文本使用 `Out-File -Encoding UTF8`，禁止使用 `Set-Content` 和 `Add-Content`。

## 19. 已知限制与风险

- iOS 当前不支持发布。
- Android Release 仍使用 debug signing，不适合作为正式生产签名方案。
- 通知管理、帮助与反馈仍为占位入口。
- 局域网同步没有认证和传输加密。
- Vault 不是全数据库加密，标题、用户名和备注等字段为明文。
- 不加密分类的密码直接以明文保存在数据库中。
- 主密码没有找回机制。
- 导入旧 Vault 数据可能因主盐不兼容而跳过整个 Vault 部分。
- 更新检查依赖 GitHub API 和 Release 资产的可访问性。
- `factoryReset()` 虽存在于数据库服务，但当前没有设置页入口。
- 现有测试集中在 Vault、设置与共享工具，其他模块仍需逐步补足关键业务测试。

## 20. 变更检查清单

### 20.1 数据库变更

- [ ] 增加 schema version。
- [ ] 更新最终建表结构。
- [ ] 添加旧版本升级路径。
- [ ] 验证外键、索引和级联删除。
- [ ] 更新导入导出 schema 与兼容逻辑。
- [ ] 增加迁移或服务测试。

### 20.2 模块变更

- [ ] 保持 `moduleId` 和表前缀稳定。
- [ ] 注册模块并声明路由。
- [ ] 更新模块摘要刷新逻辑。
- [ ] 检查停用模块时数据仍保留。
- [ ] 补充相关测试和文档。

### 20.3 安全相关变更

- [ ] 不在日志中输出主密码、密钥、明文密码或完整备份。
- [ ] 明确新增字段是否加密。
- [ ] 检查锁定、后台切换和异常路径是否清理密钥。
- [ ] 检查导入导出和局域网同步的兼容与风险提示。
- [ ] 对密码学参数或格式变更提供迁移设计，不直接破坏旧数据。

### 20.4 发布前检查

- [ ] 执行 `flutter analyze`。
- [ ] 执行与改动范围对应的测试。
- [ ] 按 `.codex/skills/commit/SKILL.md` 完成提交。
- [ ] 使用 `scripts/release.ps1` 或 `scripts/release.sh` 发布。
- [ ] 未明确指定版本号时只递增 patch。
