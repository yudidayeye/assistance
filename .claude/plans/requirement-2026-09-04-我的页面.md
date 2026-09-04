# 需求：我的页面功能化（2026-09-04）

## 背景
「我的」Tab（`lib/pages/profile_page.dart` `ProfilePageContent`）目前为空壳：仅头像/昵称用户卡 + 右上齿轮跳 `/settings` + 底部 120px 空占位，无业务作用。

## 目标
基于现有功能，把「我的」页重做为**偏纯功能操作中心**，让该 Tab 承载实际作用。

## 需求点
1. 保留顶部头像/昵称用户卡，昵称可编辑。
2. **头像支持从相册选择**（现仅默认 person 图标）；可移除头像恢复默认。
3. **三模块指标快照**「我的工具」：period_book（周期记账）/ period_tracker（生理期）/ vault（保险箱）三行入口，复用各模块 `getSummary()` 摘要，点击直达模块。
4. **快捷操作按钮组**：高频动作。
5. **功能与设置分区列表**：轻量入口（统计/历史/同步 + 主题/隐私/版本），重型与危险操作仍保留在 `/settings`。
6. 保留右上齿轮 → `/settings`；数据随模块 service 自动刷新；头像随导入导出一致。

## 约束
- 只改动 `lib/pages/profile_page.dart`；不加新 pub 依赖；不改原生配置（仓库仅 android/ + windows/）。
- 样式遵循现有设计系统（AppThemeExtension token、SectionCard/SettingsListItem/AppSnackBar）。
