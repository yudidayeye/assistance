# 开发计划：密码保险箱分类 Windows 桌面快捷方式

日期：2026-08-28

1. 利用 Flutter Windows runner 已透传的启动参数实现分类深度跳转。
2. 在 Windows runner 中注册 MethodChannel，使用 `IShellLinkW` 与 `IPersistFile` 创建桌面 `.lnk` 文件。
3. 在密码保险箱分类长按操作菜单提供「创建桌面快捷方式」入口，仅限 Windows 显示。
4. 补充启动参数解析单元测试，执行 Flutter 分析、测试和 Windows Release 构建验证。
