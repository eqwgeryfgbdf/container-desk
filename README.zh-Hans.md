# Container Desk 0.2.0 — 公开版

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

使用 macOS 26 SDK 制作的原生 SwiftUI **本机 Apple Container** 管理工具。需要 Apple Silicon、macOS 26 以上，以及已测试的引擎 **1.5.0**。这是独立开发的应用，并非 Apple 产品。

[下载 0.2.0 公开版](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.2.0) · [完整快速上手教程](docs/QUICK_START.zh-Hans.md) · [三语版本说明](RELEASE_NOTES.md)

**公开版 0.2.0。** 仅在开发者自己的 M4 Mac mini（16 GiB、macOS 26.7.1、Apple Container 1.5.0）测试。按所有者决定暂不进行第二台 Mac 测试。本版只有 ad hoc 签名，没有 Developer ID／Apple 公证；请先阅读[验证范围及已知限制](docs/RELEASE_0.2.0_VALIDATION.md)。

## 五分钟开始体验

1. 从 Release 下载 DMG 和可选的 `Container-Desk-0.2.0-Quick-Start.zip`，使用 `SHA256SUMS.txt` 核对文件。
2. 将 **Container Desk.app** 拖入“应用程序”。本版仅有 ad hoc 签名，没有 Developer ID 或 Apple 公证；遇到 macOS 阻止时，参照[安装教程](docs/QUICK_START.zh-Hans.md)。
3. 在“容器引擎”连接或安装受支持的官方 Apple Container。App 与引擎分别下载，管理员授权由 macOS 处理。
4. 解压入门包，在该文件夹打开终端：

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

第一个命令只读。第二个使用专用 BusyBox 容器在 `127.0.0.1:18080` 提供网页，验证 HTTP、exec／日志访问、停止重启和文件保留，再清理自己创建的资源。不需要 Xcode、Python 或 sudo。使用 `--run --keep` 可保留容器，在 App 中体验后按输出命令清理。教程还提供纯界面的 Python 网页服务及简单项目导入示例；快速测试不代表全部界面或安装流程已验收。

## 常用界面与操作视频

### 总览

![真实 Mac 规格与实时容器统计](docs/images/overview-en.png)

### 容器管理

![容器搜索、状态与资源配置](docs/images/containers-en.jpg)

### 创建容器

![CPU / Memory / Image](docs/images/create-en.png)

[观看实机操作视频](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.2.0/Container-Desk-Overview-zh-Hant.mp4)（繁体字幕）。截图与视频均为 **0.2.0 在开发者自己的 Mac** 上操作真实测试容器，主机名已遮挡，没有模拟数据；可能显示 macOS 录屏指示。媒体不代表全新安装／升级验收。[来源说明](docs/MEDIA.md)。

## 0.2.0 包含的功能

- **安全复制容器：** 从实际配置创建独立副本，清除端口；环境变量与挂载需选择加入，挂载默认只读，可写共享需源容器已停止。保留原容器。
- **磁盘用量与清理：** 读取真实用量，逐项确认可删除的镜像／网络／卷，不做全局 prune。
- **镜像默认信息与仓库浏览：** 创建前查看启动命令、用户、工作目录与声明端口；浏览 HTTPS Registry V2 项目／标签后部署。目录浏览采用独立临时 Basic 认证，不保证支持所有 Bearer 认证服务。
- **容器管理：** 创建、启动、停止、重启、检查与删除；批量选择和操作确认；CPU 下拉菜单、内存滑块／数字输入、已下载镜像选择。新容器先创建为停止状态。
- **完整信息：** 双击展开、实时 CPU／内存／进程／网络摘要、会话图表、日志搜索和导出、可点击的 TCP 地址与复制网址。不模拟缺失数据；网络数字为累计流量。
- **镜像与部署：** Docker Hub 搜索、仓库镜像引用、架构检查、下载并配置、ARM64 或 AMD64／Rosetta 选择、Dockerfile 构建、标签／删除、OCI 导入导出。切换架构不等于转换二进制文件。
- **文件与快照：** 浏览容器文件、不覆盖的传输、将容器保存为镜像。快照不包含挂载数据，环境变量需要主动选择纳入。[范围说明](docs/CONTAINER_SNAPSHOTS.md)。
- **仓库、网络与存储卷：** 登录／退出、推送镜像、搜索、创建、引用保护与批量删除确认。[使用说明](docs/COMPOSE_AND_FILES.md)。
- **项目与 Docker 迁移：** 检查并导入受支持的 Compose 配置，将 Docker 项目转换为独立配置文件，可选用已安装的官方 Compose CLI 解析覆盖配置，再启动／停止／移除服务。不支持的字段会阻止导入；Docker 本地镜像和存储卷数据需要单独迁移。[转换教程](docs/DOCKER_CONVERSION.md)。
- **原生界面：** 保存侧栏顺序、80–150% 内容缩放（⌘+、⌘−、⌘0）、遵循减少动态效果、真实主机规格、英文／繁中／简中，没有演示模式。
- **引擎：** 官方来源安装、手动及选择启用的自动更新，含工作负载检查。安装仅限已测试版本并需要系统授权；App 打开时才进行更新。

## 测试范围

自动化覆盖容器生命周期、数据保留、文件、镜像、项目与转换、仓库失败／本地推送及资源保护。新增容器复制、镜像信息、仓库目录与三项中度安全修复回归测试。完整结果、跳过项目及长时间运行数据见[本版验证记录](docs/RELEASE_0.2.0_VALIDATION.md)；跳过不代表通过。

仅在自己的设备上测试。全新引擎安装、真实旧版升级、外部私有 HTTPS 仓库成功流程及完整 VoiceOver 人工验收仍未验证。AI 延后；Docker 数据与本地镜像仍需单独迁移，尚无自动重启监督、切换／回滚、远程主机、内嵌终端或 App 关闭后更新。[功能状态](docs/FEATURE_ROADMAP.md) · [反馈模板](docs/TEST_REPORT.md)。

## 源码、打包与许可

DMG、`source.zip` 及 manifest 对应同一个版本提交。源码包含 **Apache-2.0** 许可、资源、脚本和测试。`SHA256SUMS.txt` 覆盖上传附件，入门包中的 `BUILD.json` 记录来源提交。入门包不重复包含 DMG；0.1.2 历史附件保留以便追溯。

开发者需要 Command Line Tools／Xcode 26 和 Python 3：

```sh
bash scripts/test.sh
bash scripts/build.sh
# 先提交所有源码变更，再生成同版产物：
bash scripts/package.sh ../outputs
python3 scripts/make-quick-start.py --output ../outputs
```

打包要求干净的 Git 工作目录，Release 标签必须对应 manifest 的提交。可选的 Developer ID／公证流程已准备，本次公开版仅有 ad hoc 签名。[Apache-2.0 许可](LICENSE) · [公开门槛](docs/PUBLIC_RELEASE_GATE.md)。

## 官方依赖

[Apple Container](https://github.com/apple/container) 为独立依赖，有自己的许可。官方安装包按需下载，未内嵌在 App 中。
