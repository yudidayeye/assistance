# 视觉设计

优化 App 整体的 UI 展示，要求如下。

## 概述

Apple 的网页设计堪称典范：以近乎隐形的 UI 框架，衬托庄重而精致的产品摄影。每个页面都由一组铺满宽度的产品「区块」垂直堆叠而成，明亮与深色画布交替出现。每个区块以主视觉标题、一行标语、两个小巧的蓝色胶囊按钮和一张极其清晰的产品渲染图为中心。任何元素都不能抢夺产品本身的注意力。字体自信但克制；颜色只使用纯白、略带暖意的羊皮纸白或近黑色；所有交互元素统一使用一种安静的蓝色。

即使按照当代 SaaS 产品的标准，这套设计的信息密度也非常低。每个产品区块大约占据一个视口，没有装饰性界面框架：不使用边框、渐变、装饰画框，也不为标题添加阴影。只有当产品图片放置在某个表面上时才使用层次效果，即唯一的一组柔和投影 `rgba(0, 0, 0, 0.22) 3px 5px 30px`，用于赋予产品视觉重量。最终效果更像博物馆画廊而不是普通商品目录：墙面隐去，展品成为绝对主角。

商店与购买页面沿用同一套设计骨架，但切换为更偏工具型的表达方式。产品配置器（如 iPhone 17 Pro 购买页、配件网格）使用紧凑的白色功能卡片网格，圆角为 `{rounded.lg}`（18px），搭配细边框和持续显示的窄型次级导航栏。环境主题页面则更深沉、更具编辑感。在所有分析页面中，字体系统、间距节奏和唯一的蓝色强调色始终保持一致——这是同一种设计语言在不同场景下以不同音量呈现。

**核心特征：**

- 以摄影为先；UI 主动退后，让产品自己表达。
- 明亮与深色的全宽区块交替出现：白色或羊皮纸白 ↔ 近黑色，颜色变化本身就是分区线。
- 所有交互元素统一使用蓝色强调色（`{colors.primary}` — #0066cc），不存在第二品牌色。
- 仅使用两类按钮语法：小型蓝色胶囊 CTA（`{rounded.pill}`）与紧凑的功能型矩形按钮（`{rounded.sm}`）。
- 使用 SF Pro Display 与 SF Pro Text；大字号采用负字距，形成标志性的「Apple 紧凑感」标题。
- 极轻的层次效果只在产品图片需要从背景中浮现时使用；整个系统只有一组投影。
- 紧凑的双层导航：纤薄的 `{component.global-nav}`，加上产品专属的 `{component.sub-nav-frosted}`；主要 CTA 始终固定在右侧。
- 多页面共享稳定的区块节奏：明亮主视觉 → 深色产品区块 → 明亮功能区块 → 深色区块 → 羊皮纸白页脚。

## 颜色

> **分析来源页面：** 首页、环境主题页、商店页、iPhone 17 Pro 购买页、配件首页。五类页面使用完全相同的颜色系统，差异仅在于不同表面模式的组合比例。

### 品牌色与强调色

- **操作蓝**（`{colors.primary}` — #0066cc）：唯一的品牌级交互色。用于所有文本链接、蓝色胶囊 CTA（如「进一步了解」「购买」）以及焦点环的基础颜色。这是 Apple 安静而统一的「可点击」信号。按下状态不通过替换色值表现，而是通过缩放变换形成略深的视觉感受。
- **焦点蓝**（`{colors.primary-focus}` — #0071e3）：比操作蓝略亮，仅用于按钮的键盘焦点环（`outline: 2px solid`）。
- **深色背景链接蓝**（`{colors.primary-on-dark}` — #2997ff）：用于深色表面中的正文链接和行内提示。普通操作蓝在深色区块上对比度不足，因此使用更明亮的蓝色变体。

### 表面色

- **纯白**（`{colors.canvas}` — #ffffff）：主画布颜色，用于内容区、功能卡片、商店区块和配置器网格。
- **羊皮纸白**（`{colors.canvas-parchment}` — #f5f5f7）：Apple 标志性的灰白色。用于交替出现的明亮区块、页脚，以及商店功能区的默认页面背景。它与纯白只有轻微差异，但足以形成节奏。
- **珍珠白按钮色**（`{colors.surface-pearl}` — #fafafc）：用于次要「幽灵」按钮的近白色填充。它比羊皮纸白画布更亮，因此按钮在 `{colors.canvas-parchment}` 上仍能被识别。
- **近黑区块 1**（`{colors.surface-tile-1}` — #272729）：首页产品网格中的主要深色区块表面。
- **近黑区块 2**（`{colors.surface-tile-2}` — #2a2a2c）：比区块 1 稍亮。当两个深色区块上下相邻时使用，以最轻微的亮度差形成分隔。
- **近黑区块 3**（`{colors.surface-tile-3}` — #252527）：比区块 1 稍暗，用于页面堆叠底部以及嵌入式视频或播放器框架。
- **纯黑**（`{colors.surface-black}` — #000000）：只用于真正的视觉空洞，例如视频播放器背景、铺满边缘的摄影遮罩和全局导航栏背景。
- **半透明控件灰**（`{colors.surface-chip-translucent}` — #d2d2d7）：覆盖在摄影图片上的圆形控制按钮基础色。实际使用时约为 64% 不透明度，即 `rgba(210, 210, 215, 0.64)`。

### 文本色

- **近黑墨色**（`{colors.ink}` — #1d1d1f）：用于所有明亮表面上的标题、正文，以及深色功能按钮的填充。使用近黑而不是纯黑，可使页面更具摄影感，避免产生印刷品般的生硬效果。
- **正文色**（`{colors.body}` — #1d1d1f）：与墨色使用相同色值。Apple 在明亮表面上统一使用一种近黑色承载文本。
- **深色背景正文色**（`{colors.body-on-dark}` — #ffffff）：用于深色区块和全局导航栏上的所有文本。
- **弱化正文色**（`{colors.body-muted}` — #cccccc）：用于深色区块上的次要文本，避免纯白显得过于响亮。
- **80% 弱化墨色**（`{colors.ink-muted-80}` — #333333）：用于珍珠白按钮表面上的正文，比纯黑更柔和。
- **48% 弱化墨色**（`{colors.ink-muted-48}` — #7a7a7a）：用于禁用按钮文本和法律细则。

### 发丝线与边框

- **柔和分隔色**（`{colors.divider-soft}` — #f0f0f0）：用于次要按钮的「边框」，实际效果更接近环形柔光，而不是清晰硬边。生产环境中通常以 `rgba(0, 0, 0, 0.04)` 使用。
- **发丝线色**（`{colors.hairline}` — #e0e0e0）：用于商店功能卡片和配置器选项的 1px 细边框。

### 品牌渐变

**禁止使用装饰性渐变。** 产品摄影中的氛围深度，例如 iPhone 17 Pro 相机区域、Apple Watch 表带和 AirPods 反光，应来自图片本身，而不是 CSS 渐变遮罩。环境主题页的主视觉通过晨曦山景等摄影内容营造氛围，但不定义任何渐变 Token。Apple 是少数完全不依赖渐变设计 Token 的高端品牌网站之一。

## 字体排印

### 字体族

- **展示字体：** `SF Pro Display, system-ui, -apple-system, sans-serif`。SF Pro Display 是 Apple 的专有展示字体，针对不小于 19px 的字号优化，定义所有标题的视觉语气。
- **正文与 UI 字体：** `SF Pro Text, system-ui, -apple-system, sans-serif`。这是针对文本阅读优化的版本，用于 20px 以下的正文、说明、按钮和链接。
- **OpenType 特性：** 数字链接（如价格表和规格表）启用 `font-variant-numeric: numerator`。大字号主要依赖紧凑字距，而不是上下文连字塑造视觉效果。

### 字体层级

| Token | 字号 | 字重 | 行高 | 字距 | 用途 |
|---|---:|---:|---:|---:|---|
| `{typography.hero-display}` | 56px | 600 | 1.07 | -0.28px | 主视觉标题；标志性的「Apple 紧凑感」字距 |
| `{typography.display-lg}` | 40px | 600 | 1.10 | 0 | 每个产品区块顶部的标题 |
| `{typography.display-md}` | 34px | 600 | 1.47 | -0.374px | 章节标题，以展示比例使用 SF Pro Text |
| `{typography.lead}` | 28px | 400 | 1.14 | 0.196px | 产品区块副文案 |
| `{typography.lead-airy}` | 24px | 300 | 1.5 | 0 | 环境主题页引导段落，少见的 300 字重 |
| `{typography.tagline}` | 21px | 600 | 1.19 | 0.231px | 区块标语、次级导航分类名 |
| `{typography.body-strong}` | 17px | 600 | 1.24 | -0.374px | 行内重点文本 |
| `{typography.body}` | 17px | 400 | 1.47 | -0.374px | 默认正文段落 |
| `{typography.dense-link}` | 17px | 400 | 2.41 | 0 | 页脚或商店功能链接列表，使用宽松行距 |
| `{typography.caption}` | 14px | 400 | 1.43 | -0.224px | 次要说明与按钮文本 |
| `{typography.caption-strong}` | 14px | 600 | 1.29 | -0.224px | 强调说明文本 |
| `{typography.button-large}` | 18px | 300 | 1.0 | 0 | 商店主视觉 CTA，少见的 300 字重 |
| `{typography.button-utility}` | 14px | 400 | 1.29 | -0.224px | 功能按钮和导航按钮标签 |
| `{typography.fine-print}` | 12px | 400 | 1.0 | -0.12px | 细则和页脚正文 |
| `{typography.micro-legal}` | 10px | 400 | 1.3 | -0.08px | 极小字号法律声明 |
| `{typography.nav-link}` | 12px | 400 | 1.0 | -0.12px | 全局导航菜单项 |

### 排印原则

- **大字号使用负字距。** 所有 17px 及以上标题均略微收紧字距（`-0.12 → -0.374px`），形成标志性的「Apple 紧凑感」节奏。12px 及以下字号禁止使用这一规则。
- **正文使用 17px，而不是 16px。** Apple 打破常见 SaaS 规范，将段落正文设为 17px。多出的 1px 让页面更偏向「阅读」，而不是快速「扫描」。
- **300 字重真实存在，但极少使用。** 仅有少数大字号内容采用 300，例如 18px/300 的 `{typography.button-large}` 和 24px/300 的 `{typography.lead-airy}`。它用于需要轻盈氛围的时刻，不应被泛用。
- **标题使用 600，而不是 700。** Apple 的标题通常为 600。只有在 `{typography.tagline}`（21px）等需要略强表达的少数位置，才谨慎使用 700。
- **行高必须依据上下文设置。** 展示字号使用 1.07–1.19 的紧凑行高；正文使用 1.47；页脚和商店的功能链接列表则使用非常宽松的 2.41（`{typography.dense-link}`）。2.41 不是错误，它让高密度链接列仍能保持呼吸感。
- **有意不使用 500 字重。** 字重阶梯固定为 300 / 400 / 600 / 700。任何中等强调场景都使用 600。

### 字体替代说明

SF Pro 是 Apple 的专有系统字体。在非 Apple 系统上构建时：

- 字体栈优先使用 `system-ui, -apple-system, BlinkMacSystemFont`；在 macOS、iOS 和 Safari 上会解析为真正的 SF Pro。
- 对于非 Apple 平台，**Inter**（Google Fonts，可变字体）是最接近的开源替代方案。Inter 使用 600 字重并设置 `font-feature-settings: "ss03"`，可近似 SF Pro 更圆润的字母「a」。
- 展示字号的 `letter-spacing` 再减少 `-0.01em`，以重现 Apple 的紧凑感；Inter 默认字距略宽于 SF Pro。
- 正文使用 Inter 时，将行高从 1.47 略微收紧至 1.44。Inter 的 x-height 较高，不需要同样宽松的行距。

## 布局

### 间距系统

- **基础单位：** 8px。2、4、5、6、7px 等小于基础单位的数值只用于紧凑的排印微调；结构布局应对齐到 8/12/16/20/24px。
- **Token：** `{spacing.xxs}` 4px · `{spacing.xs}` 8px · `{spacing.sm}` 12px · `{spacing.md}` 17px · `{spacing.lg}` 24px · `{spacing.xl}` 32px · `{spacing.xxl}` 48px · `{spacing.section}` 80px。
- **区块垂直内边距：** 产品区块内部使用 `{spacing.section}`（80px）；相邻区块之间间距为 0，由背景颜色变化形成分隔。
- **卡片内边距：** 功能网格卡片内部使用 `{spacing.lg}`（24px）。
- **按钮内边距：** 垂直 8–11px，水平 15–22px。
- **通用节奏常量：** 17px 正文配合约 25px 行高，以及 21px 标语字号，在所有分析页面中反复出现。

### 网格与容器

- **最大内容宽度：** 文字密集区（如环境主题页）约 980px；产品网格（商店、配件页）约 1440px；首页产品区块铺满宽度。
- **列布局：** 商店和配件页采用 3–5 列功能卡片网格；首页部分区域使用左右并排的双列区块；产品主视觉采用单列居中堆叠。
- **网格间距：** 功能卡片之间保持 20–24px。

### 留白理念

Apple 的留白是产品的展台。每个区块在标题上方至少保留 64px 空间，在标题下方保留 48–64px。产品渲染图周围不得拥挤，图片与最近内容之间至少相距 40px。页脚是唯一例外：页脚刻意提高密度，以便用户一眼看到完整的信息架构。

## 层次与深度

| 层级 | 表现方式 | 用途 |
|---|---|---|
| 平面 | 无阴影、无边框 | 全宽区块、全局导航、页脚和正文区域 |
| 柔和发丝线 | 1px `rgba(0, 0, 0, 0.08)` 边框 | 功能卡片、磨砂次级导航分隔线 |
| 背景模糊 | 在 80% 不透明度羊皮纸白表面使用 `backdrop-filter: blur(N)` | 次级导航和 iPhone 购买页悬浮吸底栏 |
| 产品投影 | `rgba(0, 0, 0, 0.22) 3px 5px 30px 0` | 放置于表面上的产品渲染图，是系统中唯一真正的「阴影」 |

**投影理念：** Apple 只使用**一组**投影，并且仅应用于产品摄影图——绝不用于卡片、按钮或文本。UI 的层次来自两种方式：（a）表面颜色切换，即明亮区块 ↔ 深色区块；（b）吸附栏的背景模糊。唯一的投影用于赋予产品重量，而不是构建 UI 层级。

### 装饰性深度

- 环境主题页使用**氛围摄影**（如山景）营造情绪，不使用 CSS 渐变。
- **全宽区块交替**在不使用边框和阴影的情况下形成节奏，颜色变化本身就是分隔线。
- `{component.sub-nav-frosted}` 和 `{component.floating-sticky-bar}` 使用 **`backdrop-filter` 模糊**，营造「悬浮在内容之上」的效果；这是功能性的，而不是装饰性的。

## 形状

### 圆角等级

| Token | 数值 | 用途 |
|---|---:|---|
| `{rounded.none}` | 0px | 全宽产品区块，不使用圆角 |
| `{rounded.xs}` | 5px | 行内链接作为弱化标签时使用，较少出现 |
| `{rounded.sm}` | 8px | 深色功能按钮（登录、购物袋）、卡片内嵌图片 |
| `{rounded.md}` | 11px | 珍珠白胶囊按钮 |
| `{rounded.lg}` | 18px | 商店功能卡片、配件网格卡片 |
| `{rounded.pill}` | 9999px | 蓝色主 CTA、次级导航购买按钮、配置器选项、搜索框；这是标志性的 Apple 胶囊形状 |
| `{rounded.full}` | 9999px / 50% | 覆盖在摄影图片上的圆形控制按钮 |

### 摄影图片几何规则

- **主视觉图片：** 首页使用铺满宽度的 21:9 或更高画幅；环境主题页和商店页使用 16:9。产品渲染图应具备写实摄影质感，通常放置在带有色调的表面上，并让该表面自然延伸为区块背景。
- **产品渲染图：** 使用透明背景 PNG/WebP，放置在表面区块上，并应用系统唯一的产品投影。
- **配件网格：** 使用 1:1 方形裁切和 `{rounded.lg}`（18px）圆角，背景为浅色中性色，产品居中并保留 20–40px 内边距。
- **主视觉区块中的图片不得使用圆角。** 图片应铺满并保持矩形。只有卡片内嵌图片才使用 `{rounded.sm}` 或 `{rounded.lg}`。
- 所有断点均使用响应式 `srcset` 和 `sizes`，默认启用懒加载，并通过 CDN 提供优化后的 WebP。

## 组件

### 顶部导航

**`global-nav`（全局导航）**：固定在每个页面顶部的超薄黑色导航栏。背景使用 `{colors.surface-black}`，高度 44px；文字使用 `{colors.on-dark}` 和 `{typography.nav-link}`（12px / 400 / -0.12px 字距）。链接保持克制，间距约 20px，并横向分布在顶部。右侧始终显示搜索与购物袋图标。移动端在约 834px 时折叠为菜单按钮，Apple Logo 居中。

**`sub-nav-frosted`（磨砂次级导航）**：吸附在全局导航下方、针对当前页面或产品的导航栏。背景为 80% 不透明度的 `{colors.canvas-parchment}`，并使用 `backdrop-filter` 模糊形成磨砂玻璃效果。高度 52px。左侧显示产品分类名（如「iPhone」「商店」「配件」），使用 `{typography.tagline}`（21px / 600）；右侧显示 `{typography.button-utility}`（14px）行内导航链接，并以持续显示的 `{component.button-primary}`（如「购买」）或功能链接结束。

### 按钮

**`button-primary`（主要按钮）**：Apple 标志性的操作按钮。背景使用 `{colors.primary}`（操作蓝 #0066cc）；文字使用 `{colors.on-primary}` 和 `{typography.body}`（SF Pro Text 17px / 400）；圆角使用 `{rounded.pill}`，形成完整胶囊形；内边距为 11px × 22px。完整胶囊形本身就是品牌的主要操作信号。

- 按下状态：`{component.button-primary-active}`，使用 `transform: scale(0.95)`，这是全系统统一的微交互。
- 焦点状态：`{component.button-primary-focus}`，使用 2px 实线 `{colors.primary-focus}` 外轮廓。

**`button-secondary-pill`（次要胶囊按钮）**：当两个蓝色 CTA 并列出现时（如「进一步了解」与「购买」），用作第二按钮。背景透明，文字和 1px 边框均使用 `{colors.primary}`，圆角使用 `{rounded.pill}`，内边距为 11px × 22px，视觉上属于「幽灵胶囊按钮」。

**`button-dark-utility`（深色功能按钮）**：用于全局导航操作，如登录、购物袋和语言选择。背景为 `{colors.ink}`（#1d1d1f）；文字使用 `{colors.on-dark}` 和 `{typography.button-utility}`（14px / 400 / -0.224px 字距）；圆角为 `{rounded.sm}`（8px）；内边距为 8px × 15px。按下状态使用 `transform: scale(0.95)`。

**`button-pearl-capsule`（珍珠白胶囊按钮）**：产品卡片中的次要按钮。背景使用 `{colors.surface-pearl}`（#fafafc）；文字使用 `{colors.ink-muted-80}` 和 `{typography.caption}`（14px）；边框为 3px 实线 `{colors.divider-soft}`，其作用是形成柔和光环，而不是明显边线；圆角使用 `{rounded.md}`（11px）；内边距为 8px × 14px。

**`button-store-hero`（商店主视觉按钮）**：用于商店主视觉区域的较大主要 CTA。颜色与 `{component.button-primary}` 相同，使用操作蓝背景和纸白文字，但字体改为 `{typography.button-large}`（18px / 300，注意这里少见地使用 300 字重），内边距略增至 14px × 28px。仅在商店首页等少数位置使用。

**`button-icon-circular`（圆形图标按钮）**：覆盖在摄影图片上。尺寸固定为 44 × 44px；背景使用约 64% 不透明度的 `{colors.surface-chip-translucent}`；图标使用 `{colors.ink}`；圆角为 `{rounded.full}`。用于轮播控制、关闭按钮和图片内部控制，例如 iPhone 购买页的产品缩略图按钮。

**`text-link`（文本链接）**：正文中的行内链接使用 `{colors.primary}`。是否显示下划线由具体上下文决定。

**`text-link-on-dark`（深色背景文本链接）**：深色区块上的行内链接使用 `{colors.primary-on-dark}`（#2997ff）。普通操作蓝在 `{colors.surface-tile-1}` 上对比度不足。

### 卡片与容器

**`product-tile-light`（明亮产品区块）**：铺满宽度的明亮区块。背景为 `{colors.canvas}`，文字为 `{colors.ink}`，圆角为 `{rounded.none}`，上下内边距为 `{spacing.section}`（80px）。内容居中垂直堆叠：使用 `{typography.display-lg}`（40px / 600）的产品名 → 使用 `{typography.lead}`（28px / 400）的一行标语 → 两个 CTA（「进一步了解」「购买」）→ 带系统产品投影的产品渲染图。

**`product-tile-parchment`（羊皮纸白产品区块）**：结构与 `{component.product-tile-light}` 相同，但背景使用 `{colors.canvas-parchment}`（#f5f5f7）。用于避免连续出现两个纯白区块。

**`product-tile-dark`（深色产品区块）**：铺满宽度的深色区块。背景使用 `{colors.surface-tile-1}`（#272729），文字使用 `{colors.on-dark}`，圆角为 `{rounded.none}`，上下内边距为 `{spacing.section}`（80px）。内容结构与明亮区块相同，但行内文案使用 `{component.text-link-on-dark}`；主要按钮仍使用 `{component.button-primary}`，操作蓝在深色表面上仍然有效。用于首页产品网格中的交替深色带。

**`product-tile-dark-2`（深色产品区块 2）**：背景使用 `{colors.surface-tile-2}`（#2a2a2c）。当深色区块直接相邻时，通过极轻微的亮度变化与 `{component.product-tile-dark}` 形成分隔。

**`product-tile-dark-3`（深色产品区块 3）**：背景使用 `{colors.surface-tile-3}`（#252527）。用于页面堆叠底部和嵌入式视频或播放器框架。

**`store-utility-card`（商店功能卡片）**：用于商店网格和配件网格。背景使用 `{colors.canvas}`；边框为 1px 实线 `{colors.hairline}`；圆角为 `{rounded.lg}`（18px）；内边距为 `{spacing.lg}`（24px）。顶部为产品图片，使用 1:1 裁切和 `{rounded.sm}`（8px）内层图片圆角；下方依次为 `{typography.body-strong}`（17px / 600）的产品名、`{typography.body}`（17px / 400）的价格，以及 `{component.text-link}`（如「购买」或「进一步了解」）。卡片默认不使用阴影，只有产品渲染图本身使用系统产品投影。

**`configurator-option-chip`（配置器选项）**：iPhone 17 Pro 购买页使用的胶囊形可点击单元格。背景使用 `{colors.canvas}`；文字使用 `{colors.ink}` 和 `{typography.caption}`；圆角为 `{rounded.pill}`；内边距为 12px × 16px。内部包含小型产品缩略图、标签和差价，每行排列 4–5 个选项。

**`configurator-option-chip-selected`（已选配置器选项）**：选中状态将边框升级为 2px 实线 `{colors.primary-focus}`，形状和内容保持不变。

**`environment-quote-card`（环境主题引言卡片）**：环境主题页专用的摄影画布主视觉。背景为黎明山景等深色摄影图，加载失败时使用 `{colors.surface-tile-1}`；中央标题使用白色 `{typography.display-lg}`（40px）；标题上方放置小型绿色「Apple 2030」图形 Logo；下方仅放置一个 `{component.button-primary}`。内边距使用 `{spacing.section}`（80px）。

**`floating-sticky-bar`（悬浮吸底栏）**：在 iPhone 17 Pro 购买页滚动时悬浮于视口底部。背景为 80% 不透明度的 `{colors.canvas-parchment}`，配合 `backdrop-filter: blur(N)`；高度 64px；内边距为 12px × 32px。左侧使用 `{typography.body}` 显示当前总价，右侧放置 `{component.button-primary}`（「加入购物袋」）。

### 输入框与表单

**`search-input`（搜索框）**：用于配件页搜索。背景使用 `{colors.canvas}`；文字使用 `{colors.ink}` 和 `{typography.body}`（17px）；边框为 1px 实线 `rgba(0, 0, 0, 0.08)`；圆角使用 `{rounded.pill}`，搜索框同样采用完整胶囊形，与 CTA 语法保持一致；内边距为 12px × 20px；高度 44px。前置搜索图标为 14px，并使用弱化色调。

已分析页面中没有出现错误和表单校验状态，因此本文档暂不定义相关规范。

### 页脚

**`footer`（页脚）**：背景使用 `{colors.canvas-parchment}`（#f5f5f7），文字使用 `{colors.ink-muted-80}`。链接列使用 `{typography.dense-link}`（17px / 400 / 2.41 行高），宽松行距使高密度链接仍易于扫描。列标题使用 `{typography.caption-strong}`（14px / 600）。最底部的法律信息行使用 `{typography.fine-print}`（12px / 400）和 `{colors.ink-muted-48}`。上下内边距为 64px。

## 应做与不应做

### 应做

- 所有交互元素——链接、胶囊 CTA、焦点信号——统一使用 `{colors.primary}`（操作蓝 #0066cc），不得引入其他交互强调色。单一强调色是不可妥协的规则。
- 标题使用 `{typography.hero-display}` 或 `{typography.display-lg}`，并设置负字距（`-0.28 → -0.374px`），形成标志性的「Apple 紧凑感」节奏。
- 正文使用 `{typography.body}`（17px / 400 / 1.47 / -0.374px），不要使用 16px。多出的 1px 定义了品牌的阅读节奏。
- 交替使用 `{component.product-tile-light}`（或羊皮纸白变体）和 `{component.product-tile-dark}`，构建铺满宽度的章节节奏。颜色变化本身就是分隔线。
- `{rounded.pill}` 只用于蓝色主要 CTA，以及其他需要明确表达「操作」的元素，例如配置器选项、搜索框和吸底栏 CTA。
- 唯一的产品投影 `rgba(0, 0, 0, 0.22) 3px 5px 30px` 只应用于放置在表面上的产品渲染图，绝不应用于卡片、按钮或文本。
- 所有按钮的按下状态统一使用 `transform: scale(0.95)`，作为系统级微交互。
- 全局导航始终使用 `{colors.surface-black}`（纯黑）；在大多数页面中，这是唯一使用纯黑的区域。

### 不应做

- 不得引入第二强调色；所有「可点击」信号都必须使用 `{colors.primary}`。
- 不得为卡片、按钮或文本添加阴影；投影只属于产品图片。
- 不得使用渐变作为装饰背景；氛围应由摄影内容提供。
- 正文不得使用 500 字重。Apple 的字重阶梯是 300 / 400 / 600 / 700，并有意排除 500。正文始终为 400，行内强调为 600，展示标题为 600。
- 不得为铺满宽度的产品区块添加圆角；区块必须保持矩形并贴合边缘，由背景颜色变化形成分隔。
- 正文行高不得低于 1.47；编辑式的宽松行距是品牌感的一部分。
- 不得混用圆角语法：紧凑功能元素使用 `{rounded.sm}`，功能卡片使用 `{rounded.lg}`，胶囊元素使用 `{rounded.pill}`，不要添加中间值；唯一例外是少量珍珠白按钮使用 `{rounded.md}`。
- 不得在明亮表面使用 `{colors.primary-on-dark}`；该颜色仅用于深色区块。明亮表面应使用操作蓝 `{colors.primary}`。

## 响应式行为

### 断点

| 名称 | 宽度 | 主要变化 |
|---|---:|---|
| 小型手机 | ≤ 419px | 产品区块改为单列；次级导航仅保留分类名和主要 CTA；主视觉标题降至 28px |
| 手机 | 420–640px | 使用单列堆叠；产品渲染图缩放至区块宽度的 80%；主视觉 H1 降至 34px |
| 大屏手机 | 641–735px | 区块改用更紧凑的垂直内边距（48px，而不是 80px）；细则允许换行 |
| 竖屏平板 | 736–833px | 全局导航折叠为菜单；次级导航隐藏分类选项，仅保留主要 CTA |
| 横屏平板 | 834–1023px | 全局导航恢复完整显示；三列功能网格改为两列 |
| 小型桌面 | 1024–1068px | 产品区块使用约 2/3 宽度并保留两侧边距；主视觉 H1 保持 40px |
| 桌面 | 1069–1440px | 使用完整布局；商店网格为 4–5 列；内容最大宽度为 1440px |
| 宽屏桌面 | ≥ 1441px | 内容锁定在 1440px，多余宽度由两侧外边距吸收 |

对实现者最重要的结构断点为：1440px（内容锁定）、1068px（小型桌面）、833px（横屏平板切换）、734px（竖屏平板）、640px（手机）、480px（小型手机）。

### 触控目标

- 最小触控区域为 44 × 44px。`{component.button-primary}` 约为 44 × 100px；完整胶囊圆角使可感知的点击区域比文字标签更宽裕。
- `{component.button-icon-circular}` 固定为 44 × 44px。
- 全局导航功能链接略小，约为 32 × 80px。这些是需要精确操作的桌面端入口；在宽度不超过 833px 时会由移动端菜单替代。

### 折叠策略

- **全局导航：** 桌面端完整横向链接 → 宽度不超过 834px 时折叠为 Apple Logo、菜单按钮和购物袋图标。
- **次级导航：** 分类名、行内链接和主要 CTA → 移动端只保留分类名和主要 CTA，行内链接移入菜单抽屉。
- **产品区块：** 在 834px 时从双列改为单列；小型手机的垂直内边距从 80px 收紧至 48px。
- **功能网格**（商店、配件）：5 列 → 1440px 时 4 列 → 1068px 时 3 列 → 834px 时 2 列 → 640px 时 1 列。
- **主视觉字体：** `{typography.hero-display}`（56px）→ 1068px 时切换为 `{typography.display-lg}`（40px）→ 640px 时 34px → 419px 时 28px。

### 图片行为

- 所有产品图片使用响应式 `srcset`，并为不同断点提供匹配的裁切版本。
- 移动端主视觉摄影可以切换构图方向。例如环境主题页的远景在移动端可改为更高的画幅，用不同方式突出主体。
- 产品渲染图在各断点保持 1:1 或 4:3 宽高比，只调整缩放比例。
- 默认使用懒加载；首屏主视觉图片应立即加载。

## 迭代指南

1. 每次只聚焦一个组件，并直接引用它的 YAML 键，例如 `{component.product-tile-dark}`、`{component.search-input}`。
2. 现有组件的变体（`-active`、`-focus`、`-2`、`-3`）应作为 `components:` 下的独立条目维护。
3. 所有实现都使用 `{token.refs}`，禁止直接内联十六进制色值。
4. 不记录 hover 状态，只记录默认状态和 Active/Pressed 状态。
5. 展示标题始终使用 SF Pro Display 600 和负字距；正文始终使用 17px 的 SF Pro Text 400。二者边界不可打破。
6. 唯一的投影 `rgba(0, 0, 0, 0.22) 3px 5px 30px` 只用于产品摄影图。
7. 不确定如何强化层级时，应优先切换表面颜色（明亮 → 深色区块），而不是添加额外装饰框架。

## 已知缺口

- 已分析页面没有呈现表单校验和错误状态，因此目前只记录中性的搜索输入框。
- 首页嵌入式视频或播放器框架使用 `{colors.surface-black}`；内部播放器控件不在本文档范围内，因为它们属于平台组件，而不是网页设计 Token。
- 部分组件图片是动态的，例如轮播产品主视觉，其具体文案随页面变化。组件规范只描述结构，不约束动态内容本身。
- 已分析页面没有展示商店与配件功能卡片的深色模式版本；本文记录的是 Apple 默认发布的日间、明亮表面为主的设计系统。
- 环境主题页的山景等氛围摄影属于内容资产，不是设计 Token；`{component.environment-quote-card}` 只描述其结构表面。
- `{component.sub-nav-frosted}` 和 `{component.floating-sticky-bar}` 的精确 `backdrop-filter` 模糊半径与平台相关。生产 CSS 通常使用 `saturate(180%) blur(20px)` 作为基准，但该值尚未正式定义为 Token。
