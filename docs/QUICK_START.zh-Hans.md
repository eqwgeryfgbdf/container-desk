# Container Desk 1.0 — 快速上手

[English](QUICK_START.md) · [繁體中文](QUICK_START.zh-Hant.md) · [简体中文](QUICK_START.zh-Hans.md)

## 1. 系统要求

Apple Silicon、macOS 26 及以上，另外安装 [Apple 官方 Container](https://github.com/apple/container)。仅在开发者的 M4 Mac mini／macOS 26.7.1／引擎 1.5.0 测试。[验证范围](RELEASE_1.0.0_VALIDATION.md)。

## 2. 安装与连接

1. 从 [v1.0.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v1.0.0) 下载 `Container-Desk-1.0.0-arm64.dmg`。手动上传附件只有 DMG，源码归档由 GitHub 自动生成。
2. 可运行 `shasum -a 256 Container-Desk-1.0.0-arm64.dmg`，与 Release 正文中的完整校验码比较。
3. 退出旧 App，打开 DMG、拖入“应用程序”并确认替换；需要降版选项可先备份旧 App。不要删除引擎数据或容器。
4. 本版仅 ad hoc 签名，尚未公证。若被 macOS 阻止，确认来源后打开“系统设置 → 隐私与安全性 → 仍要打开”，按单个 App 的提示确认。不要全局关闭 Gatekeeper。
5. 在“容器引擎”连接已有引擎，或从支持的 Apple 官方来源安装；系统安装可能需要管理员授权。运行中的工作负载会推迟引擎更新，不要为安装 App 停止其他服务。

0.3 预览版使用不同的偏好设置标识，1.0 回到正式 App 标识。必要时重新选择界面偏好和已有 AI 模型；替换 App 不迁移或删除引擎数据。

## 3. 创建网页容器

1. “镜像 → 下载与部署 → 搜索 Docker Hub”，选择官方 `nginx`、`alpine` 标签、ARM64。
2. 下载后填写 `my-web`、1 CPU、256 MiB；将空闲主机端口 `18080` 映射至容器 `80`，TCP，其余保留默认值。
3. 创建后点击“启动”，点击 `127.0.0.1:18080` 打开服务；端口占用时换一个空闲主机端口。
4. 双击容器展开信息与日志，使用 ⌘+／⌘−／⌘0 缩放与还原。
5. 完成后仅停止并删除自己的测试容器；删除容器不等于备份挂载数据。

## 4. 可选脚本测试

先下载并阅读相同版本的脚本：

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` 只读；`--run` 创建唯一命名的 localhost HTTP 服务，验证后清理自身资源。加上 `--keep` 可保留测试容器并查看清理方法。不需额外测试 ZIP，也不下载 AI 模型。

## 5. 更多操作

- [Hugging Face／llama.cpp／MCP](AI_QUICK_START.zh-Hans.md)：先用约 105 MB 小模型，文字推理不等于支持工具调用。
- [镜像更新与回滚](IMAGE_UPDATES.md)：先了解停机和挂载数据限制。
- [文件、仓库与 Compose](COMPOSE_AND_FILES.md)、[Docker 转换](DOCKER_CONVERSION.md)：仅支持列明范围，持久数据单独迁移。
- [问题反馈](TEST_REPORT.md)：提供 App／引擎／macOS 版本和错误，不要提供密码、Token 或私密环境变量。
