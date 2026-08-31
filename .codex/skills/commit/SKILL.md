---
name: commit
description: 按 Conventional Commits(约定式提交)规范执行 git 提交。每次需要提交代码变更时必须使用本 skill。
---

# Commit Skill —— 规范化代码提交

## 触发时机

- **触发**:完成一个小需求、修复一个 bug、完成一项重构后,执行提交。
- **不触发**:纯样式/间距/颜色调整不单独提交(可随下次需求一起提交)。

## 执行步骤

1. **检查变更**:`git status` 和 `git diff --stat`,确认变更范围完整、无遗漏文件、无调试代码或临时文件;同时确认暂存区中没有他人预先暂存的无关变更(有则只 `git add` 自己的文件,不动他人暂存内容)。
2. **运行检查**:涉及 Dart 代码变更时,先执行 `flutter analyze`,并**只运行与本次改动相关的测试**(对应测试文件或模块测试目录,如 `flutter test test/modules/accounting/`);禁止默认全量 `flutter test`。仅当改动 `lib/core/`、`lib/shared/` 等共享层且影响多个模块时,才全量回归。
3. **生成提交信息**:严格按下方规范构造 message。
4. **执行提交**:`git add <具体文件>`(避免无差别 `git add -A`)+ `git commit -m "<message>"`。
5. **验证结果**:`git log -1 --stat` 确认提交内容与信息匹配。

## 提交信息格式

```
<type>(<可选 scope>): <简体中文描述>
```

### type 取值

| type | 含义 |
| :--- | :--- |
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 仅文档变更 |
| `style` | 代码格式调整(不影响逻辑) |
| `refactor` | 重构(既不修 bug 也不加功能) |
| `perf` | 性能优化 |
| `test` | 新增或修改测试 |
| `chore` | 构建流程、依赖、杂项;版本发布统一用 `chore: 发布 vX.Y.Z` |

### 书写规则

- **scope**:使用模块名,如 `accounting`、`period_tracker`、`core`、`settings`;跨模块可省略。
- **描述**:简体中文祈使句,首行不超过 72 字符,结尾不加句号。
- **正文(可选)**:复杂变更在空行后补充"为什么改",而非"改了什么"。

### 示例

```
feat(accounting): 新增月度消费统计图表
fix(period_tracker): 修复编辑阶段日期不回显的问题
refactor(core): 抽离数据库升级为独立迁移类
docs: 更新贡献指南中的提交规范
chore: 发布 v1.2.7
```
