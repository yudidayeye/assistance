# 分支管理与发布流程

## 日常开发

- `master` 保存已完成并验证的代码。
- 从最新 `master` 创建任务分支，例如 `fix/android-signing` 或 `feat/period-book`。
- 完成开发及相关检查后，推送任务分支，通过 Pull Request 合入 `master`。
- 合并后删除任务分支。标签和 Release 保留，删除分支不会删除已发布安装包。

提交、推送、合并和创建标签都不会自动触发当前的 Windows 打包工作流。

## 发布新版本

发布使用仓库现有脚本：Linux 使用 `scripts/release.sh`，Windows 使用
`scripts/release.ps1`。明确指定版本号，由脚本更新版本和构建号、构建校验产物、
提交、打标签并上传 Release。Windows 完整发布需要 Android 与 Windows 工具链。

发布前确认 Android 使用原有签名密钥，并核对旧安装包证书。更换密钥会导致已有
应用无法覆盖安装；不要将密钥或密码提交到代码仓库。

## 手动给已有版本补 Windows 安装包

1. 打开仓库 Actions 页面，选择“Windows 安装包补充发布”。
2. 点击“Run workflow”，工作流分支选择 `master`。
3. 在 `tag` 中填写已正式发布的版本标签，例如 `v1.2.10`，再点击运行。
4. 等待任务成功，在对应 Release 下载 `my_assistant_setup_<版本号>.exe`。

工作流使用 `master` 中的发布工具，检出所填标签的源码，通过
`scripts/release.ps1 -WindowsOnly` 构建安装包。它不递增版本、不移动标签，
也不替换 Android APK；同名 Windows 安装包会被重新构建的文件替换。
发布前校验程序与安装包版本，上传后校验大小和 SHA-256。

该工作流仅支持手动触发，没有定时、推送或标签触发规则。

## 已完成的临时分支

`work` 中的功能及 Windows 发布工具已合入 `master`。
`release/1.2.10-recovery` 是为恢复一次 APK 上传创建的临时分支，参数固定为
1.2.10，不纳入常规发布流程。清理前的分支历史已在云工作区归档。
