# Container Desk 1.0.0

[English](README.md) · [中文（繁體）](README.zh-Hant.md) · [中文（简体）](README.zh-Hans.md)

专为 Apple Silicon、macOS 26 及以上打造的 **Apple Container 原生 SwiftUI 管理工具**。独立开源项目，并非 Apple 官方 App。应用名称为 **Container Desk**，官网使用 **Apple Container Desk** 标题方便查找。

[下载 1.0.0 DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v1.0.0/Container-Desk-1.0.0-arm64.dmg) · [官网](https://container.emo-lab.com/zh-Hans/) · [版本说明](docs/RELEASE_NOTES_1.0.0.md) · [快速上手](docs/QUICK_START.zh-Hans.md)

1.0 整合现有容器管理、项目、AI／MCP 与镜像更新功能，安装包、Dock 和侧栏统一使用最新 **VM＋包裹 Logo**，并提供三语教程和官网源代码。

**发行方式：**仅 ad hoc 签名，没有 Developer ID 或 Apple 公证。需要 Apple Silicon、macOS 26 及以上；仅在开发者的 M4 Mac mini、macOS 26.7.1、Apple Container 1.5.0 上测试，第二台 Mac 测试仍推迟。版本号不代表所有引擎、Docker 项目或模型都兼容。[验证与限制](docs/RELEASE_1.0.0_VALIDATION.md)。

## 快速开始

1. 打开 DMG，退出旧版 Container Desk，再拖入“应用程序”并确认替换。若 macOS 阻止打开，请按[单个 App 安装教程](docs/QUICK_START.zh-Hans.md)处理，不要全局关闭安全保护。
2. 在“容器引擎”连接 Apple 官方 Container；引擎单独安装，来源为 Apple 官方发布页。
3. 在“镜像 → 下载与部署”搜索 Docker Hub 或填写镜像引用，选择合适的 ARM64 镜像并配置 CPU、内存和端口。
4. 新容器创建后保持停止；点击“启动”，双击查看详细信息和日志，点击已发布的 TCP 网页端口打开服务。
5. 本地 AI 参阅 [Hugging Face／llama.cpp／MCP 教程](docs/AI_QUICK_START.zh-Hans.md)。建议先用 SmolLM2 135M Q4_K_M（约 105 MB）；文字推理与工具调用是不同能力，该小模型未通过工具调用测试。

## 功能范围

| 类别 | 1.0 提供内容 |
| --- | --- |
| 容器 | 创建、启停、重启、删除、经确认的批量操作、选择性复制设置、实际主机规格与资源信息。 |
| 界面 | 原生 SwiftUI、英文／繁体／简体、侧栏排序、展开详情、80–150% 缩放和尊重减少动态效果的过渡。 |
| 镜像 | Docker Hub 搜索、架构检查、下载部署、Dockerfile 构建、标签、OCI 导入导出、镜像更新、经确认的容器替换与回滚。 |
| 存储与文件 | 网络、存储卷、选择性清理、文件浏览与传输、容器保存为镜像；不执行全局清理，快照不包含挂载数据。 |
| 仓库与项目 | Registry 登录／推送、HTTPS 目录与标签浏览、支持范围内的 Compose 导入及 Docker 项目转换，不支持字段明确提示。 |
| 本地 AI／MCP | 公开单文件 GGUF 搜索、固定版本与 SHA-256 下载验证、llama.cpp CPU 部署、能力测试和经确认的 MCP 工具执行。 |
| 引擎 | 官方来源安装；带工作负载检查的手动／自愿启用自动更新，仅 App 打开时运行。 |

## 快速测试

先下载并检查脚本，再执行：

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 只读；`--run` 创建、验证并清理专用 localhost HTTP 容器，不安装 AI 模型。[自动化说明](docs/AUTOMATED_QA.md)。

## 截图与教程

![主机信息总览](docs/images/overview-en.png)
![容器管理](docs/images/containers-en.jpg)
![创建容器](docs/images/create-en.png)

截图来自历史 0.2.0，主机名已遮蔽，并非本版新验收结果。[素材来源](docs/MEDIA.md)。[90 秒 AI 教程](docs/video/README.md)使用真实界面截图、旁白与操作说明，不是连续部署录像。

## 升级与限制

- 替换前退出旧 App；容器、镜像与存储卷仍位于引擎原有数据目录。
- 1.0 使用正式标识 `local.containerdesk.app`；0.3 预览版使用 `local.containerdesk.ai-development`。预览版的界面偏好和 AI 选择记录不会自动迁移，必要时重新选择已有 GGUF 或模型缓存，不需删除引擎数据。
- Compose 只支持已验证的子集，Docker 本地镜像和持久数据需分别迁移；架构选择不是二进制转换。尚无远程主机管理、内嵌终端或关闭 App 后的后台更新。
- 本地 AI 在 Linux VM 中使用 CPU，没有 Metal。公开搜索不处理受限或分割 GGUF；模型质量与 MCP 兼容性不同，连接及模型提出的工具调用都需要确认。
- 镜像替换改变容器名称／IP 并造成停机；保留原容器，但回滚不撤销挂载数据写入或数据库迁移。[更新指南](docs/IMAGE_UPDATES.md)。
- 全新引擎安装、真实引擎升级、外部私有 HTTPS 仓库成功流程及完整人工 VoiceOver 验收仍未验证。[功能状态](docs/FEATURE_ROADMAP.md)。

## 源码与打包

```sh
bash scripts/test.sh
bash scripts/build.sh
# 提交待发布源码后打包：
bash scripts/package.sh ../outputs
```

Release 附件**只有 DMG**；[Apache-2.0](LICENSE) 源码可通过 GitHub 自动生成的版本归档下载。安装包与标签对应同一提交，SHA-256 写入 Release 正文。另备 Developer ID／公证流程，不代表本次已公证。

[官网源码](website/README.md) · [文件、仓库和项目](docs/COMPOSE_AND_FILES.md) · [Docker 转换](docs/DOCKER_CONVERSION.md) · [Apple Container 官方来源](https://github.com/apple/container)
