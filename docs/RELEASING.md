# 分支管理与发布流程

## 日常开发

`master` 保存已完成并验证的代码。从最新 `master` 创建任务分支，完成改动及相关
检查后，通过 Pull Request 合入 `master`，然后删除任务分支。标签和 Release 保留。

提交、推送、合并及创建标签均不会自动打包。所有打包工作流只支持手动运行。

## 一次操作打包 Android 和 Windows

在仓库 Actions 页面选择“Android 与 Windows 打包发布”，点击 **Run workflow**：

- 工作流分支：`master`。
- `version`：不带 `v` 的版本号，例如 `1.2.11`。
- `mode`：`new` 发布新版本；`existing` 重建已发布版本的全部四个安装包。
- `notes`：可选的新版本发布说明。

`new` 从 master 当前提交构建，要求版本号高于当前版本且标签不存在。构建号自动
加一。Android 和 Windows 使用同一个源码提交、版本和构建号，分别由 Linux、
Windows 运行器并行打包。两边全部成功后，发布脚本才提交版本号、创建标签，先
创建草稿 Release，上传并校验三个 APK 和一个 `.exe`，最后公开发布。

如果构建期间 master 被其他提交更新，发布会停止，避免覆盖他人的改动。
如果上传中断，可查看标签和草稿状态，使用 `existing` 恢复已有 Release 的附件。

`existing` 从指定版本的原标签构建，保留原版本和构建号，不移动标签、不提交
版本修改；全部构建成功后替换该 Release 的同名四个安装包。现有 Release
及标签必须存在。适用于用原密钥修复 1.2.10 的 Android 签名。

## Android 签名配置（首次使用前必须完成）

在仓库 **Settings → Secrets and variables → Actions → Secrets** 添加：

| Secret | 内容 |
| --- | --- |
| `ANDROID_SIGNING_KEYSTORE_BASE64` | 原签名文件的 Base64 编码 |
| `ANDROID_KEYSTORE_PASSWORD` | 密钥库密码 |
| `ANDROID_KEY_PASSWORD` | 签名密钥密码 |
| `ANDROID_KEY_ALIAS` | 签名密钥别名 |

原来一直使用 Android 默认调试密钥时，密码通常为 `android`，别名为
`androiddebugkey`。密钥来自原来构建 1.2.9 的电脑；不要使用其他机器新生成的文件。

工作流默认要求签名证书 SHA-256 与已发布的 1.2.9 一致：
`c82e8fdbb18885ba841914d22e5d8ede4b40f66ba78f29991db0e3ca0a4a923d`。
只有明确迁移签名、接受旧版不能直接覆盖升级时，才修改 Actions **Variables**
中的 `ANDROID_SIGNING_CERT_SHA256`。变量用于指定预期证书，不包含私钥。

签名缺失或证书不匹配时停止上传。密钥只在临时运行器中解码使用，完成后清理；
不会包含在构建产物中。Base64 同样属于敏感密钥，仅存入 Secrets，不提交到仓库。

## 只补 Windows 安装包

保留独立的“Windows 安装包补充发布”工作流。选择 `master`，在 `tag` 填写已正式
发布的标签（例如 `v1.2.10`）。它调用 `scripts/release.ps1 -WindowsOnly`，只替换
该 Release 的同名 `.exe`，不递增版本或修改 APK，且不要求 Android 密钥。

## 本地发布与脚本职责

常规本地发布仍使用 `scripts/release.sh`（Linux）或 `scripts/release.ps1`（Windows）。
Windows 完整本地发布需要 Android 与 Windows 工具链。

统一 Actions 通过 Bash 脚本的 `--ci-build` / `--ci-publish` 和 PowerShell 脚本的
`-BuildOnly -BuildNumber` 分离构建与发布；`scripts/ci_release.py` 负责版本规划、
签名验证、产物清单及统一发布校验。这些模式由工作流传入参数，不需要用户手动调用。

发布工具修改的 Python 校验测试：
`python3 -m unittest discover -s test/scripts -p '*_test.py' -v`。

## 已清理的临时分支

原 `work` 已合入 master；一次性的 `release/1.2.10-recovery` 不用于常规发布。
两个任务分支已删除，清理前的完整历史保存在云工作区的 Git bundle 归档中。
