# 我的工具箱 — UI 全面重设计方案

> 生成日期: 2026-06-30
> 基于: `docs/UI.md` 设计哲学 + UI/UX Pro Max 设计规则
> 状态: 待评审

---

## 目录

1. [设计总纲](#1-设计总纲)
2. [当前 UI 差距分析](#2-当前-ui-差距分析)
3. [新色彩系统](#3-新色彩系统)
4. [主题 Token 重构](#4-主题-token-重构)
5. [全局样式规范](#5-全局样式规范)
6. [页面级重设计](#6-页面级重设计)
7. [组件级重设计](#7-组件级重设计)
8. [动效与交互规范](#8-动效与交互规范)
9. [无障碍规范](#9-无障碍规范)
10. [实施路线图](#10-实施路线图)

---

## 1. 设计总纲

### 1.1 核心气质

```
安静的科技感 + 温和的健康陪伴 + 轻商业化引导
```

| 关键词 | 含义 | 设计表现 |
|--------|------|----------|
| **Calm** (平静) | 不制造焦虑，不催促 | 低对比、大留白、慢节奏动效 |
| **Soft Tech** (柔和科技) | 科技感但不冰冷 | 柔光渐变、半透明玻璃质感 |
| **Restorative** (恢复感) | 让人感到被修复、被关怀 | 温暖的色彩过渡、圆润的形态 |
| **Non-intrusive** (不打扰) | 信息存在但不压迫 | 低信息密度、层级清晰、安静通知 |

### 1.2 设计原则（5 条铁律）

1. **低对比优先** — 文字与背景对比度控制在 4.5:1–7:1 之间，不超过 10:1；禁止纯黑(#000)文字、禁止纯白(#FFF)大面积硬背景
2. **圆润即柔和** — 所有矩形元素最小圆角 16px，卡片圆角 24px，弹窗圆角 28px；禁止 <8px 的尖角
3. **留白即呼吸** — 卡片间距 ≥16px，段落间距 ≥12px，页面边距 20px；禁止一屏塞入超过 3 张完整卡片
4. **渐变替代纯色** — 背景使用柔光渐变替代纯色平铺；卡片底色使用半透明/微渐变
5. **叙事统一** — 所有页面（数据页、设置页、引导页）色调统一，禁止数据页冰冷 + 营销页花哨的割裂感

### 1.3 情绪曲线目标

```
打开 App → 看到柔和渐变背景 → 呼吸放缓
进入模块 → 核心信息居中呈现 → 专注但不紧张
浏览数据 → 卡片温柔浮现 → 信息被感知而非被轰炸
点击操作 → 微动效反馈 → 操作确认但不打断
```

---

## 2. 当前 UI 差距分析

### 2.1 与设计目标不符的问题

| 问题 | 现状 | 目标 |
|------|------|------|
| **对比度过高** | `_goldEarth = #2C1810`（接近纯黑）用于大段文字 | 正文应为深棕灰（#3D3D3D 级别），不超 #1A1A1A |
| **纯白硬背景** | `_white = #FFFFFF` 用于卡片底色 | 卡片底色应为微暖的浅灰/乳白 (#FAF9F7 级别)，或在 cream 背景上用半透明白色 |
| **阴影偏硬** | `BoxShadow(blurRadius: 16, offset: 0,4)` 在浅色背景上产生明显边界 | 阴影应更轻更散 — blurRadius 20-32，alpha ≤6% |
| **圆角不统一** | 卡片 20px, 按钮 14px, 输入框 14px, 设置图标 12-14px | 统一升级为卡片 24px, 按钮 16px, 输入框 16px, 图标容器 16px |
| **粉色主题过艳** | `_pinkPrimary = #E91E63`（Material Pink 500）过于高饱和 | 应降为柔粉 #D4879A 或淡玫红 #C97D7D |
| **模块卡片缺乏层次** | 首页卡片直接 `creamDark` 底色，与背景区分不够 | 卡片背景应为浅柔光渐变，增加漂浮感 |
| **缺少渐变背景** | 全页面纯色 `cream` 背景，无层次 | 应增加对角线柔光渐变，从左上到右下有微妙的色彩过渡 |
| **生理期模块色** | `#C97D7D` 虽然柔和但与文档描述的理想色系有偏差 | 见 §3 新色彩系统 |

### 2.2 已符合目标的部分（保留）

| 项目 | 说明 |
|------|------|
| Material 3 基础 | `useMaterial3: true` — 保留，M3 的柔和设计语言与目标一致 |
| AppBar 透明无分割线 | `elevation: 0, scrolledUnderElevation: 0` — 保留 |
| 卡片无边框设计 | `elevation: 0, 无 border` — 保留并加强 |
| 底部导航简洁 | 仅 2 个 tab（≤5），符合导航最佳实践 |
| Google Fonts | DM Sans + Roboto Slab + Playfair Display — 字体体系保留，调整使用场景 |

---

## 3. 新色彩系统

### 3.1 设计理念

```
主色：睡眠恢复感 — 深蓝紫调，暗示夜间修复
辅助色：薄荷绿（健康指标）+ 柔粉（情绪/女性关怀）
背景：大面积柔光渐变，从暖灰到微蓝
```

### 3.2 主题套系（4 套，保留现有框架）

#### 主题 1: 「柔夜」(Soft Night) — 默认主题（替代 gold）

品牌主色取"恢复的夜晚"意向 — 深蓝紫调，科技感但不冷。

| Token | 色值 | 语义 |
|-------|------|------|
| `primary` | `#7B8BAA` | 主色 — 蓝灰调，柔和科技感 |
| `primaryLight` | `#D8DFE8` | 浅主色 — 卡片底色、选中背景 |
| `primaryDark` | `#5A6B8A` | 深主色 — 渐变终点、强调文字 |
| `earth` | `#3D3D3D` | 正文 — 深灰，非纯黑 |
| `earthLight` | `#6B6B6B` | 次要文字 |
| `earthMedium` | `#9B9B9B` | 辅助文字/占位符 |
| `cream` | `#F5F3F0` | 页面背景 — 微暖灰白 |
| `creamDark` | `#EBE8E4` | 卡片底色 — 比背景略深 |
| `sage` | `#8CADA0` | 辅助色 — 薄荷绿（健康指标） |
| `sageLight` | `#CDE0D6` | 浅辅助色 |
| `rose` | `#D4879A` | 强调色 — 柔粉（女性关怀） |
| `roseLight` | `#EDCDD4` | 浅强调色 |

**渐变**: 
- 页面背景对角渐变: `cream → creamDark` (左上→右下, 轻微)
- 卡片柔光渐变: `creamDark → creamDark.withAlpha(180)` 
- 主色渐变: `primary → primaryDark`

#### 主题 2: 「晨雾」(Morning Mist) — 替代 blue

| Token | 色值 | 说明 |
|-------|------|------|
| `primary` | `#8AADB8` | 雾蓝 |
| `primaryLight` | `#D6E5EA` | |
| `primaryDark` | `#6A8E9A` | |
| `earth` | `#3D3D3D` | 同柔夜 |
| `earthLight` | `#6B6B6B` | |
| `earthMedium` | `#9B9B9B` | |
| `cream` | `#F4F6F7` | 偏冷灰白 |
| `creamDark` | `#E8EDEF` | |
| `sage` | `#8CADA0` | 同柔夜 |
| `sageLight` | `#CDE0D6` | |
| `rose` | `#D4879A` | |
| `roseLight` | `#EDCDD4` | |

#### 主题 3: 「叶语」(Leaf Whisper) — 替代 green

| Token | 色值 | 说明 |
|-------|------|------|
| `primary` | `#9CAD8A` | 橄榄绿灰 |
| `primaryLight` | `#DDE5D6` | |
| `primaryDark` | `#7A8D6A` | |
| `earth` | `#3D3D3D` | |
| `earthLight` | `#6B6B6B` | |
| `earthMedium` | `#9B9B9B` | |
| `cream` | `#F5F4F0` | 微暖 |
| `creamDark` | `#EBE9E4` | |
| `sage` | `#8CADA0` | |
| `sageLight` | `#CDE0D6` | |
| `rose` | `#D4879A` | |
| `roseLight` | `#EDCDD4` | |

#### 主题 4: 「花雾」(Flower Mist) — 替代 pink

| Token | 色值 | 说明 |
|-------|------|------|
| `primary` | `#C9A0AA` | 柔玫瑰灰 |
| `primaryLight` | `#EDD8DE` | |
| `primaryDark` | `#A8808A` | |
| `earth` | `#3D3D3D` | |
| `earthLight` | `#6B6B6B` | |
| `earthMedium` | `#9B9B9B` | |
| `cream` | `#F7F4F5` | 微粉暖 |
| `creamDark` | `#EFEAEB` | |
| `sage` | `#8CADA0` | |
| `sageLight` | `#CDE0D6` | |
| `rose` | `#C97D8A` | 花雾专属柔粉 |
| `roseLight` | `#E8C4CA` | |

### 3.3 关键变化

1. **所有主题共用 `earth/earthLight/earthMedium` 文字色系** — 统一阅读体验，避免主题切换后文字色突变
2. **所有主题共用 `sage/sageLight` 和 `rose/roseLight`** — 辅助色语义固定："薄荷绿=健康指标"、"柔粉=情绪/周期"
3. **主色统一为低饱和灰调** — 所有原高饱和色 (gold #D4AF37, blue #4A90D9, green #4CAF50, pink #E91E63) 均降为柔和灰调
4. **背景 cream 系列保持暖调微差** — 4 个主题的 cream 色调略有差异以传递不同的氛围

---

## 4. 主题 Token 重构

### 4.1 扩展 AppThemeExtension

当前 14 个 token 不足以支持新设计。需要扩展为：

```dart
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // 现有 - 保留
  final Color primary, primaryLight, primaryDark;
  final Color earth, earthLight, earthMedium;
  final Color cream, creamDark;
  final Color sage, sageLight;
  final Color rose, roseLight;
  final Gradient gradientPrimary, gradientEarth;
  
  // 新增 - 卡片系统
  final Color cardBackground;       // 卡片底色（半透明白/微渐变）
  final Color cardBorder;           // 卡片微弱边框（几乎不可见）
  final List<BoxShadow> cardShadow; // 卡片阴影（极轻）
  
  // 新增 - 背景系统
  final Gradient scaffoldGradient;  // 页面背景渐变
  final Color surfaceOverlay;       // 半透明覆盖层（弹窗遮罩）
  
  // 新增 - 圆角系统（定义半径 token）
  final double radiusSm;            // 12px — 小元素
  final double radiusMd;            // 16px — 按钮/输入框
  final double radiusLg;            // 24px — 卡片
  final double radiusXl;            // 28px — 弹窗/大卡片
  
  // 新增 - 间距系统
  final double spaceXs;             // 4px
  final double spaceSm;             // 8px
  final double spaceMd;             // 16px
  final double spaceLg;             // 24px
  final double spaceXl;             // 32px
}
```

### 4.2 主题类型枚举重命名

```dart
enum AppThemeType {
  softNight('柔夜', Color(0xFF7B8BAA)),     // 原 gold → 柔夜
  morningMist('晨雾', Color(0xFF8AADB8)),   // 原 blue → 晨雾
  leafWhisper('叶语', Color(0xFF9CAD8A)),   // 原 green → 叶语
  flowerMist('花雾', Color(0xFFC9A0AA)),    // 原 pink → 花雾
}
```

### 4.3 模块主题色更新

```dart
// accounting_module.dart
Color get themeColor => const Color(0xFF9CAD8A); // 叶语绿 — 记账用温和的绿

// period_module.dart  
Color get themeColor => const Color(0xFFD4879A); // 柔粉 — 生理期用关怀粉
```

### 4.4 ThemeData 关键参数调整

```dart
ThemeData _buildTheme({...}) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // 卡片 — 统一大圆角 + 无边框
    cardTheme: CardThemeData(
      color: Colors.transparent,          // 改：卡片用自定义 Container
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),  // 改：20→24
      ),
      margin: EdgeInsets.zero,
    ),
    
    // 输入框 — 放大圆角
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.7), // 改：半透明白
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),   // 改：14→16
        borderSide: BorderSide.none,               // 改：无边框
      ),
      // ... 保留 enabledBorder/focusedBorder 同样无边框
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    
    // 按钮 — 放大圆角
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),  // 改：14→16
        ),
      ),
    ),
    
    // 底部导航 — 添加毛玻璃效果
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.85), // 改：半透明
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
    
    // Chip — 放大圆角
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),      // 改：10→12
      ),
    ),
  );
}
```

---

## 5. 全局样式规范

### 5.1 圆角系统

| 级别 | 值 | 应用场景 |
|------|-----|----------|
| `radiusXs` | 8px | 极小元素（小标签、徽章） |
| `radiusSm` | 12px | Chip、小按钮、图标容器 |
| `radiusMd` | 16px | 输入框、按钮、列表项 |
| `radiusLg` | 24px | 卡片、面板 |
| `radiusXl` | 28px | 弹窗、大卡片、FeaturedCard |

### 5.2 间距系统（8dp 基准）

| 级别 | 值 | 应用场景 |
|------|-----|----------|
| `spaceXs` | 4px | 紧密关联元素（图标-文字） |
| `spaceSm` | 8px | 相关元素间距 |
| `spaceMd` | 16px | 卡片内边距、列表项间距 |
| `spaceLg` | 24px | 段落间距、卡片间距 |
| `spaceXl` | 32px | 大区块间距 |
| `space2xl` | 48px | 页面顶部/底部呼吸区 |

### 5.3 阴影系统（极轻）

| 级别 | 参数 | 应用 |
|------|------|------|
| `shadowNone` | 无 | 大多数卡片 |
| `shadowSubtle` | `blur: 20, offset: (0,2), alpha: 4` | 悬浮卡片（首页模块卡） |
| `shadowFloat` | `blur: 32, offset: (0,4), alpha: 6` | 弹窗/Modal |

原则：**优先用背景色分层代替阴影**。卡片与背景的区分通过 `creamDark` vs `cream` 的微小色差实现。

### 5.4 字体体系

| 角色 | 字体 | 权重 | 大小 |
|------|------|------|------|
| 页面标题 | Playfair Display | W700 | 28px |
| 模块标题 | Roboto Slab | W700 | 20-24px |
| 卡片标题 | DM Sans | W600 | 16px |
| 正文 | DM Sans | W400 | 14-15px |
| 辅助文字 | DM Sans | W400 | 12-13px |
| 数字/金额 | DM Sans | W600 | 28-36px（大数字） |
| 按钮文字 | DM Sans | W600 | 15px |

### 5.5 遮罩系统

```
弹窗遮罩: Colors.black.withOpacity(0.3)  // 减轻到 30%，不压迫
底部弹出遮罩: Colors.black.withOpacity(0.2)
```

---

## 6. 页面级重设计

### 6.1 首页 — MainShellPage / 工具箱 Tab

**页面对比**: UI.md §布局结构.1 "单焦点中心结构" + §布局结构.2 "模块化卡片流"

#### 当前问题
- 标题栏 `padding: (20,56,20,16)` — 顶部 56px 太紧贴状态栏
- GridView 2 列，`childAspectRatio: 0.82` — 卡片偏窄高
- `creamDark` 纯色卡片与背景对比不够

#### 新设计

```
┌─────────────────────────────────┐
│  (safe area top)                │
│                                 │
│  工具箱              ⚙️          │  ← 标题: Playfair Display 28px
│                                 │
│  ┌──────────┐  ┌──────────┐    │
│  │  ♡ 图标   │  │  ✨ 图标   │    │  ← 卡片: 大圆角 24px
│  │          │  │          │    │     cardBackground 渐变底
│  │ 生理期记录│  │   记账    │    │     阴影: shadowSubtle
│  │          │  │          │    │
│  │ 下次预测  │  │ 本月支出  │    │
│  │ 6月30日  │  │ ¥1,280   │    │
│  └──────────┘  └──────────┘    │
│                                 │
│  ┌──────────┐                  │  ← 后续模块同样排列
│  │  更多...  │                  │
│  └──────────┘                  │
│                                 │
│  (bottom nav area)              │
└─────────────────────────────────┘
```

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 标题 padding | `(20,56,20,16)` | `(24, safeTop+24, 24, 20)` |
| 标题字体 | Roboto Slab 24px | Playfair Display 28px |
| Grid 列数 | 2 | 2（保持不变） |
| cardAspectRatio | 0.82 | 0.88（更方正） |
| 卡片间距 | 16px | 20px |
| Grid padding | `(20,8,20,0)` | `(20,12,20,24)` |
| 卡片底色 | `creamDark` 纯色 | `cardBackground` 微渐变（半透明白 + subtle 渐变） |
| 卡片阴影 | `BoxShadow(alpha:8, blur:16)` | `shadowSubtle` (alpha:4, blur:20) |
| 设置按钮 | 白底+边框+圆角14 | 半透明底+无边框+圆角16 |

### 6.2 "我的"页面 — ProfilePageContent

**页面对比**: UI.md §整体气质 "温和的健康陪伴" + §卡片风格 "更像状态容器"

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 标题字体 | Playfair Display 28px | 保留 |
| 用户卡片底色 | `Colors.white` | `cardBackground` 微渐变 |
| 用户卡片阴影 | `BoxShadow(alpha:8, blur:16)` | `shadowSubtle` |
| 用户卡片圆角 | 24px | 保留 24px |
| 头像容器圆角 | 20px | 16px（统一 radiusMd） |
| 头像容器大小 | 64×64 | 56×56（略缩小，更精致） |
| 编辑弹窗圆角 | 24px | 28px (`radiusXl`) |
| 弹窗输入框 | `Colors.white` | 半透明白 |
| 弹窗按钮圆角 | 14px | 16px |
| 弹窗遮罩 | (默认) | `Colors.black.withOpacity(0.3)` |

#### 新增内容建议

在用户卡片下方增加：
- 当前主题选择指示器（小色块展示 4 个主题，当前选中高亮）
- 数据概览区（两个模块的小摘要卡片）

### 6.3 生理期日历页 — CalendarPage

**页面对比**: UI.md §整体气质（核心应用场景）

这是最能体现新设计理念的页面。当前已有较多优化（预测卡片等），需针对性调整：

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 页面背景 | 纯色 | `scaffoldGradient` 柔光渐变 |
| 预测卡片底色 | 白色/creamDark | `cardBackground` + 极微弱边框 |
| 预测卡片圆角 | 当前值 | 统一 24px |
| 日历网格月相图标 | 当前色 | 使用主题 `rose` 柔粉色 |
| 经期标记点 | 当前色 | 使用 `rose`/`roseLight` |
| 排卵期标记 | 当前色 | 使用 `sage`/`sageLight` 薄荷绿 |
| 日期详情面板 | 当前值 | 背景半透明 + backdropFilter 模糊 |

### 6.4 记账主页 — AccountingEntryPage

**页面对比**: UI.md §布局结构 "单焦点中心结构"

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 页面背景 | 纯色 | `scaffoldGradient` |
| 月度汇总卡片 | 白色/creamDark | `cardBackground` + shadowSubtle |
| 汇总卡片圆角 | 当前值 | 24px |
| 金额数字 | 当前值 | DM Sans W600, 更大字号(32-36px) |
| 交易列表项 | 分隔线分割 | 卡片式分隔（每项独立微卡片）+ 间距 |
| FAB 按钮 | 圆形 primary | 圆角 16px, 带微阴影 |
| 空状态插图 | 当前 | 柔和的 SVG 插图 + 引导文字 |

### 6.5 统计页 — AccountingStatsPage + PeriodStatsPage

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 图表配色 | fl_chart 默认 | 主题色系（pie: [primary, sage, rose, primaryLight]） |
| 图表卡片 | 当前 | `cardBackground` + 24px 圆角 |
| 图例 | 默认 | 圆点 + DM Sans 13px，颜色使用主题 token |
| 空数据 | 空图表 | 柔和的空状态（图标+文字引导） |

> 图表规则遵循 UI/UX Pro Max §10: 饼图≤5 分类、补充数据表格、图例可交互、触控区域≥44pt

### 6.6 设置页 — SettingsPage

#### 变更清单

| 项目 | 旧值 | 新值 |
|------|------|------|
| 主题选择 | 4 色块+文字标签 | 4 个微卡片：每卡片展示主题名+色块预览+勾选标记 |
| 开关组件 | 默认 Material | 自定义柔和色开关（track 用 sageLight, active 用 primary） |
| 列表项分隔 | 默认分割线 | 间距分隔（无分割线） |
| 隐私免责声明 | 默认文字 | 卡片内柔和呈现 |

---

## 7. 组件级重设计

### 7.1 FeaturedCard（首页模块卡片）

**目标**: 从"功能入口按钮" → "状态信息容器"

```dart
// 新设计关键参数
Container(
  padding: EdgeInsets.all(24),                     // 统一内边距
  decoration: BoxDecoration(
    gradient: LinearGradient(                       // 微渐变底色
      colors: [cardBackground, cardBackground.withOpacity(0.6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(24),        // 大圆角
    boxShadow: [shadowSubtle],                      // 极轻阴影
  ),
  child: Column(
    children: [
      // 图标容器
      Container(
        width: 56, height: 56,                     // 48→56, 更舒展
        decoration: BoxDecoration(
          color: moduleColor.withOpacity(0.12),    // 12% 透明度（20%→12%, 更柔和）
          borderRadius: BorderRadius.circular(16),
        ),
        child: module.icon.build(size: 28, color: moduleColor),
      ),
      SizedBox(height: 16),                         // 12→16
      // 标题
      Text(module.displayName, 
        style: DM Sans W600 16px),                  // Roboto Slab→DM Sans 统一
      SizedBox(height: 6),
      // 摘要
      Text(summary, 
        style: DM Sans W400 12px earthMedium),
    ],
  ),
)
```

### 7.2 ToolboxBottomNav（底部导航栏）

**目标**: 轻量化，融入背景

| 项目 | 旧值 | 新值 |
|------|------|------|
| 背景 | `Colors.white` | `Colors.white.withOpacity(0.85)` +  backdropFilter 模糊 |
| 选中图标色 | `primary` | `primary`（保留） |
| 未选中图标色 | `earthMedium` | `earthLight`（更淡） |
| 分割线 | 无 | 无（保留） |
| 高度 | 默认 | 60px（含 safe area） |
| 选中指示器 | 无 | 顶部微条 3×20px, `primary` 色, 圆角 |

### 7.3 MonthSelector（月份选择器）

| 项目 | 旧值 | 新值 |
|------|------|------|
| 箭头按钮 | 当前 | 圆形 40×40, 半透明底, 无边框 |
| 月份文字 | 当前 | DM Sans W600 16px |

### 7.4 自定义开关（生理期开关等）

```dart
// 柔和风格开关
Switch(
  activeColor: primary,                            // 使用主题主色
  activeTrackColor: primaryLight,
  inactiveThumbColor: earthLight,
  inactiveTrackColor: creamDark,
)
// 或使用 Flutter 自定义 Switch 实现柔和动画过渡
```

### 7.5 空状态组件

所有列表/数据页的空状态统一为：

```
┌─────────────────────────────┐
│                             │
│       (柔和 SVG 插图)        │  ← 使用主题色，线条轻柔
│                             │
│     还没有记录哦             │  ← DM Sans W500 16px earth
│   点击下方按钮开始记录吧     │  ← DM Sans W400 13px earthMedium
│                             │
└─────────────────────────────┘
```

---

## 8. 动效与交互规范

### 8.1 微交互

遵循 UI/UX Pro Max §7 规范：

| 交互 | 时长 | 缓动 | 说明 |
|------|------|------|------|
| 按钮按下 | 150ms | `easeOut` | 缩放 0.97 → 1.0 |
| 卡片点击 | 200ms | `easeOut` | 轻微 scale + 阴影变化 |
| 页面过渡 | 300ms | `easeInOut` | 水平滑动（前进左→，后退右→） |
| 弹窗出现 | 250ms | `easeOutBack` (轻微) | 缩放 0.92→1.0 + 淡入 |
| 弹窗消失 | 150ms | `easeIn` | 缩放 1.0→0.95 + 淡出 |
| 数字变化 | 400ms | `easeInOut` | 数字滚动动画 |
| 列表项进入 | stagger 40ms/项 | `easeOut` | 依次淡入+上移 |

### 8.2 页面背景渐变动画

切换到新主题时，背景渐变过渡使用 600ms `easeInOut`，让色彩变化"呼吸感"。

### 8.3 减少动画支持

```dart
// 检测 prefers-reduced-motion
final bool reduceMotion = MediaQuery.of(context).disableAnimations;
final duration = reduceMotion ? Duration.zero : Duration(milliseconds: 200);
```

### 8.4 触觉反馈

在关键操作（记录保存、删除确认）时使用 `HapticFeedback.lightImpact()`。

---

## 9. 无障碍规范

遵循 UI/UX Pro Max §1（CRITICAL）：

### 9.1 必做项

| 规范 | 实现方式 |
|------|----------|
| 色彩对比度 ≥4.5:1 | `earth (#3D3D3D)` on `cream (#F5F3F0)` = 约 7:1 ✅ |
| 触控目标 ≥44×44pt | 所有按钮、图标按钮、卡片均满足 |
| 触控间距 ≥8px | 列表项间距设置 |
| 图标按钮 aria-label | Flutter `Semantics(label: ...)` |
| 焦点环 | `FocusableActionDetector` 或 Material 默认 |
| 动态字体 | 使用 `MediaQuery.textScaler` 适配 |
| 减少动画 | `MediaQuery.disableAnimations` |

### 9.2 语义化颜色

- 错误/警告不仅用红色，同时显示图标+文字
- 图表数据点不仅靠颜色区分，同时使用形状/纹理

---

## 10. 实施路线图

### 阶段 1: 主题系统重构（基础）

**目标**: 新色彩系统落地，不改变页面逻辑

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| 1.1 | 更新 `AppThemeExtension` — 新增 card/system token | `theme_extension.dart` | P0 |
| 1.2 | 重写 4 套配色常量（柔夜/晨雾/叶语/花雾） | `app_theme.dart` | P0 |
| 1.3 | 更新 `AppThemeType` 枚举名称和标签 | `theme_provider.dart` | P0 |
| 1.4 | 更新 `_buildTheme()` — 圆角/阴影/渐变统一 | `app_theme.dart` | P0 |
| 1.5 | 更新模块主题色 | `accounting_module.dart`, `period_module.dart` | P1 |
| 1.6 | 数据库迁移：旧 theme 名称 → 新名称映射 | `theme_provider.dart` | P1 |

### 阶段 2: 全局组件重设计

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| 2.1 | 重写 `FeaturedCard` — 渐变底+新尺寸+柔阴影 | `featured_card.dart` | P0 |
| 2.2 | 重写 `ToolboxBottomNav` — 毛玻璃+选中指示器 | `toolbox_bottom_nav.dart` | P1 |
| 2.3 | 重写 `MonthSelector` — 柔和风格 | `month_selector.dart` | P2 |
| 2.4 | 创建 `EmptyStateWidget` 通用空状态组件 | `shared/widgets/` | P2 |
| 2.5 | 创建 `SoftGradientCard` 通用卡片组件 | `shared/widgets/` | P1 |

### 阶段 3: 页面逐个重设计

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| 3.1 | 首页（工具箱+我的）布局调整 | `main_shell_page.dart`, `profile_page.dart` | P1 |
| 3.2 | 生理期日历页背景渐变+卡片柔和化 | `calendar_page.dart` | P1 |
| 3.3 | 记账主页背景渐变+汇总卡片柔和化 | `entry_page.dart` | P2 |
| 3.4 | 统计页图表配色+卡片 | `stats_page.dart` (×2) | P2 |
| 3.5 | 设置页主题选择器重设计 | `settings_page.dart` | P2 |
| 3.6 | 新增交易页/记录页输入区域柔和化 | `add_page.dart`, `record_page.dart` | P3 |

### 阶段 4: 动效与细节打磨

| # | 任务 | 涉及文件 | 优先级 |
|---|------|----------|--------|
| 4.1 | 页面过渡动画（GoRouter 自定义 transition） | `app_router.dart` | P3 |
| 4.2 | 主题切换背景渐变过渡 | `theme_provider.dart` | P3 |
| 4.3 | 卡片微交互（onTap scale feedback） | 各卡片组件 | P3 |
| 4.4 | 无障碍标注 (Semantics) | 全局 | P3 |

---

## 附录

### A. 色值速查表

```
柔夜 (默认):
  primary:     #7B8BAA  ████████ 蓝灰
  primaryLight:#D8DFE8  ████████ 浅蓝灰
  cream:       #F5F3F0  ████████ 暖灰白
  creamDark:   #EBE8E4  ████████ 卡片底
  sage:        #8CADA0  ████████ 薄荷绿
  rose:        #D4879A  ████████ 柔粉
  earth:       #3D3D3D  ████████ 正文

晨雾:
  primary:     #8AADB8  ████████ 雾蓝
  cream:       #F4F6F7  ████████ 冷灰白

叶语:
  primary:     #9CAD8A  ████████ 橄榄绿灰
  cream:       #F5F4F0  ████████ 微暖

花雾:
  primary:     #C9A0AA  ████████ 柔玫瑰灰
  cream:       #F7F4F5  ████████ 微粉暖
```

### B. 设计决策记录

1. **为什么 4 套主题共用 earth/sage/rose 色系？** — UI.md 强调"品牌一致性"和"颜色不过多"。文字色统一保证阅读舒适度，辅助色语义固定避免了用户跨主题时的认知负担。

2. **为什么不直接删除旧主题加载逻辑？** — 实施路线图 §1.6 设计了迁移映射，确保用户已保存的主题设置平滑过渡。

3. **为什么保持 Material 3？** — M3 的柔和设计语言天然契合"Calm/Soft"目标，无需重造轮子。修改集中在 colorScheme 和组件 token 层面。

4. **为什么阴影极轻（alpha ≤6%）？** — UI.md 明确指出"几乎无阴影，更依赖分层+留白"。在 cream 底色上，`creamDark` 卡片通过色差已能清晰分层。

### C. 参考文件

- `docs/UI.md` — 设计哲学来源
- `lib/core/theme/app_theme.dart` — 当前主题实现
- `lib/core/theme/theme_extension.dart` — Token 定义
- `lib/core/theme/theme_provider.dart` — 主题管理
- `lib/shared/widgets/featured_card.dart` — 首页卡片
- `lib/pages/main_shell_page.dart` — 首页布局
- `lib/pages/profile_page.dart` — "我的"页面
