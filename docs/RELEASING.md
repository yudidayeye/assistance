# 发布与签名排障手册

发布规则以 [`AGENTS.md`](../AGENTS.md) 与 [`README.md`](../README.md) 为准：GitHub
Actions 工作流是唯一发布通道，本地脚本不作为发布手段。本文只记录发布、签名和
更新检查出问题时需要查阅的资料与恢复步骤。

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

## 单独补发与失败恢复

统一工作流的 `mode=existing` 和两个补发工作流都用于恢复已有 Release，区别是
`existing` 重建该 Release 的全部四个安装包，补发只替换单个平台。

补发时在 Actions 选择“Android 安装包补充发布”或“Windows 安装包补充发布”，
点击 **Run workflow**：

- 工作流分支：`master`。
- `tag`：要替换安装包的正式 Release 标签，例如 `v1.2.13`。
- `source`：默认 `master`，使用最新已提交代码，适合修复小功能后补发；`tag`
  使用原标签源码，适合重建原包。
- `notes`：本次安装包更新说明，建议填写；留空时应用展示原 Release 说明。

例如修改小功能并推送 master 后，运行 Android 补发，填写 `v1.2.13`、选择
`master`。应用显示版本仍是 `1.2.13`，内部构建号从 `42` 递增到 `43`；只替换
三个 APK 和 `update-android.json`，Windows 安装包和其更新信息保持不变。
Windows 补发同理，只替换 `.exe` 和 `update-windows.json`，不需要 Android 密钥。

`source=master` 要求目标标签的版本与 master 当前版本一致；重建旧版本请选择
`tag`。两种方式都递增 master 的全局构建号，不改变其对外版本，也不移动原标签。
实际构建的源码提交记录在平台更新 JSON 中，可能晚于原 Release 标签。

三个工作流共用发布队列，避免构建号冲突。构建期间 master 有新提交时停止发布，
重新点击 Run workflow 即可。上传失败后也应新建一次运行，以分配新的构建号；
不要仅重跑旧运行的失败 job。统一发布先创建草稿 Release，发布校验按 Release
数字 ID 读取草稿，已上传且哈希、大小一致的附件直接复用，最后才公开发布。

## 同版本安装包的更新检查

统一发布会上传 `update-android.json` 和 `update-windows.json`；补发只更新当前
平台的 JSON。应用比较版本号和当前平台的构建号，因此只更新 Android 不会让
Windows 用户收到更新提示。JSON 包含源码提交、构建号、文件大小、SHA-256 和
本次说明；上传时先校验安装包，最后更新 JSON。检查时若二者不一致，会提示
安装包正在更新，请稍后重试。下载缓存也按文件标识和哈希校验，避免复用旧包。

旧 Release 没有这些 JSON 时，继续按版本号检查。**已安装的旧版应用需要先安装
一次包含新检查逻辑的安装包，之后才能识别同版本补发**；原来的检查逻辑无法仅
靠修改远端附件升级。内部构建号仍受现有 Android ABI 编码限制，范围为 1..999。

版本信息弹窗展示本机版本和构建号、当前平台最新安装包、更新时间、更新状态和
说明，可直接重试检查或查看更新。不同平台的构建号可以不同。

## 发布脚本职责（仅供工作流与本地调试）

统一 Actions 通过 Bash 脚本的 `--ci-build` / `--ci-publish` / `--ci-single-publish` 和 PowerShell 脚本的
`-BuildOnly -BuildNumber` 分离构建与发布；`scripts/ci_release.py` 负责版本规划、
签名验证、产物清单及统一发布校验。这些模式由工作流传入参数，不需要用户手动调用。

`scripts/release.sh`（Linux）与 `scripts/release.ps1`（Windows）只为维护发布流程本身
保留，用于本地验证打包逻辑，不作为发布手段；本地完整构建需要 Android 与 Windows
工具链，Windows 安装包还需要 Inno Setup 6。

发布工具修改的 Python 校验测试：
`python3 -m unittest discover -s test/scripts -p '*_test.py' -v`。

## 历史备注

原 `work` 已合入 master；一次性的 `release/1.2.10-recovery` 不用于常规发布。
两个任务分支已删除，清理前的完整历史保存在云工作区的 Git bundle 归档中。
