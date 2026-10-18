# 快速上手 — Container Desk 0.2.0 公开版

[English](QUICK_START.md) · [中文（繁體）](QUICK_START.zh-Hant.md) · **中文（简体）**

无需编译即可试用真实本地服务。0.2.0 将公开发行，仅在开发者自己的 M4 Mac mini（16 GiB、macOS 26.7.1、Apple Container 1.5.0）测试；按所有者决定暂不测试第二台 Mac。

## 1. 选择下载文件

前往 [v0.2.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.2.0)。

| 文件 | 用途 |
|---|---|
| `Container-Desk-0.2.0-arm64.dmg` | 安装 Mac App，无需 Xcode。 |
| `Container-Desk-0.2.0-Quick-Start.zip` | 可选入门包：三语教程、快速测试脚本、两个 `.command` 启动器及示例项目，不重复包含 DMG。 |
| `Container-Desk-0.2.0-source.zip` | 同版本 Apache-2.0 源代码、构建脚本及完整自动化测试。 |
| `Container-Desk-0.2.0-manifest.json` | 源代码提交、文件树与主要产物哈希。 |
| `SHA256SUMS.txt` | 全部附件的 SHA-256（不含校验文件自身）。 |
| `Container-Desk-Overview-zh-Hant.mp4` | Actual 0.2.0 app footage / 0.2.0 實機操作 / 0.2.0 实机操作；繁體字幕。 |

要求：Apple Silicon、macOS 26 以上、可下载镜像的网络，以及 **Apple Container 1.5.0**。不支持 Intel Mac。只有源代码构建／完整 QA 需要 Xcode 或 Command Line Tools 26 与 Python 3；快速测试只用内置 Bash、curl 和已安装的引擎。

全部附件放在同一文件夹后，运行 `shasum -a 256 -c SHA256SUMS.txt`。仅下载 DMG 时，运行 `shasum -a 256 Container-Desk-0.2.0-arm64.dmg`，对比校验文件中相应的完整哈希；缺少可选附件不代表 DMG 损坏。

## 2. 安装并连接

1. 打开 DMG，把 **Container Desk** 拖到 **应用程序**，再从应用程序启动。替换旧版前先退出旧 App，完成后推出 DMG。
2. 此版本只有 ad hoc 签名，没有 Developer ID 或 Apple 公证，首次启动可能被 macOS 阻止。确认信任该下载后，参照 [Apple 的单个 App 打开说明](https://support.apple.com/en-nz/102445)，检查「系统设置 → 隐私与安全性 → 仍要打开」。不要全局关闭 Gatekeeper；如果没有单个 App 允许选项，请记录完整提示。
3. 打开左侧 **容器引擎**。引擎尚未安装时，使用 App 的官方来源安装流程，或从 [Apple Container](https://github.com/apple/container)安装受支持版本。macOS 管理员授权由你本人确认；App 与引擎是分别安装的。
4. 按需启动引擎，等待「已连接」。在概览核对真实 CPU、内存和系统版本。遇到未识别的自定义安装，请先阅读提示，不要覆盖已有设置。
5. 在设置中选择英文／繁体／简体；资源配额范围来自真实主机规格。

## 3. 五分钟快速测试，无需编译

解压入门包，在该文件夹打开终端。先阅读脚本，再运行：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 只读取环境。`--run` 仅在镜像不存在时下载官方 `busybox:1.37`，创建 UUID 命名的测试容器（1 CPU／256 MiB），仅把 HTTP 发布到 `127.0.0.1:18080`，验证网页响应、exec／日志访问、停止再启动及文件保留，然后删除该容器与本次新下载的镜像引用。原有镜像及其他容器会保留；不安装／升级引擎、不使用 sudo、不挂载主机文件夹、不全局清理、不上传报告。

预期出现 `PASS:` 且退出码为 0；`BLOCKED`／`FAIL` 或非零退出码表示条件未满足或失败。18080 被占用时可加 `--port 18081`。

若希望保留服务，继续在 App 中体验：

```sh
bash quick-test.sh --run --keep
```

脚本会打印精确容器名称、网址与清理命令。回到 Container Desk 刷新容器，选择 `cd-quick-…`，双击展开信息、点击端口链接、查看日志，再从「更多操作 → 文件」查看 `/www/index.html`。完成后运行打印的停止／删除命令；镜像不再被其他容器使用时才删除。`--keep` 会有意保留运行中的测试服务。

也可在 Finder 打开 `Check-Mac.command`（只读）或 `Run-Quick-Test.command`（实际测试）。启动器会停留以便阅读结果。下载的脚本可能需要 macOS 允许，也可使用上述明确的终端命令。此测试验证引擎基础流程，不等于完整 UI、全新安装或升级验收。

## 4. 完全通过 App 创建网页服务

1. **镜像 → 下载与快速部署**。搜索 `python`，选择官方 `library/python`、标签 `3.13-slim`、Linux ARM64；或在「镜像名称或网址」输入 `docker.io/library/python:3.13-slim`。
2. 选择「下载并配置」。名称 `my-python-web`、CPU `1`、内存 `512 MiB`、主机端口 `18081`、容器端口 `8080`、TCP。确保主机端口空闲，保留默认网络，不添加主机挂载或密钥。
3. 高级设置的入口程序填写 `python3`。命令参数**每行一个**，不加 Shell 引号：

```text
-u
-m
http.server
8080
--bind
0.0.0.0
```

4. 创建后容器保持**已停止**；选中并启动。
5. 点击端口链接或打开 `http://127.0.0.1:18081/`。出现目录列表代表真实服务可访问，日志应包含请求；失败时先检查状态与日志。
6. 双击进入完整信息，Command `+`／`-` 调整界面大小；查看 CPU／内存、日志和文件。复选框支持批量选择，操作前核对目标列表。
7. 完成后停止并删除 **my-python-web**。镜像是独立资源，确认无其他容器使用后再删除 Python 镜像。

## 5. 项目、Registry 与文件

- **项目**：导入入门包的 `docs/examples/quick-web.yaml`（或[这份示例](examples/quick-web.yaml)），阅读验证／兼容性报告，再启动。使用本机 `18082` 端口、小型 BusyBox 网页服务，无主机挂载。访问 `http://127.0.0.1:18082/` 应显示 `Container Desk project works`。完成后停止／移除项目，检查保留资源。Docker 转换只涵盖已支持的配置，其他字段会明确列出；详见[转换指南](DOCKER_CONVERSION.md)。
- **镜像仓库**：使用自己有权限的测试仓库；通过官方 CLI 保存登录凭据，标记／推送都是明确操作。可搜索公开镜像不代表拥有 Docker Hub 推送权限。私有 HTTPS 仓库登录成功仍需按账号环境验收。
- **文件**：先使用测试容器及空白目的地。限制为 4 GiB／10,000 个条目及普通未压缩 tar；特殊压缩、稀疏文件或不支持的元数据会拒绝。已有目的地文件受保护。详见[文件与项目指南](COMPOSE_AND_FILES.md)。
## 6. 新增便利功能

- **复制：** 容器 → 更多操作 → 复制／单独重建，检查源配置后设置新容器。原容器保留；端口清除，挂载默认只读，环境变量需选择加入。卷是共享而非复制；需要可写层更改时先保存为镜像。
- **磁盘用量：** 镜像／网络／卷 → 磁盘用量与清理，刷新后选择并确认单个项目。删除前重查引用，不删除容器，也不全局 prune。
- **浏览仓库：** 输入 HTTPS 主机，必要时直接指定项目，再选标签部署。目录 Basic 认证只保存在当前窗口；拉取／推送另用 CLI 登录。部分服务不支持目录或需要尚未支持的 Bearer 流程。简短主机名会显式添加 `:443`，认证拉取请使用相同名称登录。
- **镜像信息：** 创建时选择本地镜像与架构，展开默认信息查看启动命令、用户、工作目录与端口；不会自动发布端口。


## 排查问题与反馈

| 情况 | 下一步 |
|---|---|
| GitHub 404 | 核对 Release 链接及网络连接，仓库公开后不需要邀请权限。 |
| App 无法打开 | 检查 Apple Silicon、macOS 26、DMG 完整校验值，记录系统提示。 |
| 未连接／CLI 不存在 | 在容器引擎页检查官方引擎安装及启动状态，不要删除引擎数据。 |
| 端口被占用 | 换用 18081 或其他空闲端口，不要停止无关服务。 |
| 搜索／下载失败 | 检查网络、DNS、仓库限制及认证，排除原因后重试。 |
| 只有 AMD64 镜像 | 优先 ARM64；AMD64 需要兼容的 Rosetta 设置，改标签不等于转换二进制程序。 |
| 项目字段不支持 | 阅读验证报告与[支持范围](COMPOSE_AND_FILES.md)，不要假设所有 Docker 项目均可原样运行。 |
| 测试清理失败 | 只检查脚本打印的 UUID 资源，不要全局 prune。 |

反馈 App 版本、macOS／芯片、引擎版本、操作步骤、预期／实际结果及 `PASS`／`FAIL` 输出即可。分享前去掉主机名、私人路径、环境变量值、密码和 Token；脚本不会自动发送报告。

开发者先运行 `bash scripts/build.sh`，再运行 `python3 scripts/qa.py --live --ui`；请先阅读[自动化说明](AUTOMATED_QA.md)。界面测试期间保持 Mac 解锁，暂停操作桌面。[本版验证记录](RELEASE_0.2.0_VALIDATION.md)列出实际结果。全新安装、真实引擎升级、外部私有 HTTPS 仓库成功流程及完整人工无障碍验收仍未验证；AI 延后。
