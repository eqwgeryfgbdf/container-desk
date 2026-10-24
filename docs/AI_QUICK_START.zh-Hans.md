# 本地 AI 与 MCP：0.3.0 开发预览版

[English](AI_QUICK_START.md) · [繁體中文](AI_QUICK_START.zh-Hant.md)

下载 [0.3.0 预览版 DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.3.0-preview/Container-Desk-0.3.0-arm64-preview.dmg)。本机已通过原生搜索界面自动化测试，详见[验证范围](AI_VALIDATION.md)。本版只有 ad hoc 签名，没有 Apple 公证，仍为预览版；0.2.0 不包含这些功能。

## 启动模型

1. 启动 Apple Container 引擎，打开左侧 AI 页面。
2. 选择目录中最小的 **Qwen2.5 0.5B Instruct Q4_K_M** 并下载，或选择自己的单文件 `.gguf`。下载量为 491,400,032 bytes（约 491 MB），会检查固定版本、大小与 SHA-256；DMG 不包含模型。
3. 建议测试使用 2 CPU、2 GiB 内存、2,048 token 上下文及空闲主机端口（默认 18090）。创建并启动后测试模型。官方 llama.cpp Linux ARM64 镜像另行下载，固定 digest。
4. 输入消息即可测试。更换部署前，先到容器页停止并删除原部署。取消或失败可能留下容器供检查，不会自动删除工作负载。

推理使用 Linux VM 的 **CPU，不支持 Apple Metal**。仅挂载选中的单个模型文件，且为只读；服务仅发布到 `127.0.0.1`。常规下载保留在 `~/Library/Application Support/Container Desk/Models`，可自行删除。小模型适合验证连接，不代表具备可靠推理或任意工具使用能力。

## 搜索 Hugging Face 模型

在 **本地 AI → 搜索 Hugging Face** 输入模型名称或发布者，也可点击轻量模型快捷键。结果按下载量排序；选择仓库后，挑选单文件 GGUF 量化版本（从小到大），查看容量、授权／模型说明及估计内存，再点击 **选择并下载**。空白搜索会显示热门 GGUF 候选模型。

轻量试用可搜索 `SmolLM2-135M-Instruct`，选择 `bartowski/SmolLM2-135M-Instruct-GGUF` 的 `SmolLM2-135M-Instruct-Q4_K_M.gguf`（测试版本为 105,454,432 bytes）。基本文字测试可用 2 CPU、1 GiB、1,024 上下文。工具调用需单独测试兼容性，小模型可能无法通过。

下载固定到仓库 commit，验证文件大小、GGUF 标头与 SHA-256。不同内容分开缓存，不覆盖原有同名模型。下载不会部署或执行仓库代码。GGUF 只是格式筛选，不代表当前 llama.cpp 引擎支持每种架构；部署后请点击“测试模型”。内存估计会随上下文变化，不保证能启动。

目前提供公开、单文件的文字模型候选；隐藏分割文件、投影器、适配器与缺少校验信息的文件。受限制模型需自行在 Hugging Face 取得权限、下载后选择本地文件。未知授权会明确标示，使用前请查看模型说明。搜索只会发送搜索文字到 Hugging Face，不会发送对话或本地文件。

脚本测试：`bash scripts/test-huggingface.sh`；加 `--live` 查询真实 API，加 `--download` 下载小于 128 MiB 的测试模型并清除。加 `--inference --allow-image-pull` 进行实机推理，使用端口 19893、2 CPU／1 GiB 临时容器；另需约 296 MB 压缩的官方 ARM64 服务器镜像，测试后删除本次新增的镜像与容器。现有容器保持原状；强制终止脚本时请检查 `cd-hf-test-*` 残留资源。

## 下载故障排查

| 情况 | 处理方法 |
| --- | --- |
| 找不到模型 | 用较短名称或发布者搜索。最多显示 40 个热门公开 GGUF 候选；清空搜索可查看热门模型。 |
| 量化版本太多 | 在文件筛选输入 `Q4_K_M`。列表从小到大排序，选择完整单文件 GGUF，不要选适配器或投影器。 |
| 要求授权或登录 | 点击模型说明链接，在 Hugging Face 取得权限，手动下载单文件 GGUF，再点击“选择本地 GGUF…”。App 不收集 Hugging Face Token。 |
| 请求限制／网络错误 | 稍后重新搜索。错误不代表下载成功或兼容性通过。 |
| 空间不足／校验失败 | 清理空间或重新下载。失败文件不会设为已选模型，不要改名或修改损坏文件来绕过验证。 |
| 容器未就绪 | 检查容器日志与内存配置，先使用测试过的小模型；固定版本引擎可能不支持较新的模型架构。 |
| 工具调用不兼容 | 能回答文字不代表支持 MCP。测试的 SmolLM2 135M 未通过工具测试；改用合适的指令模型并重新测试。 |

下载中可点击进度旁的“取消”。完成的模型保留在 `~/Library/Application Support/Container Desk/Models`；脚本实机测试使用临时模型并自行清理。删除模型文件前，请先停止／删除挂载它的容器。

## 连接已安装的 MCP 工具

导入含 `mcpServers` 的 JSON，选择服务器、检查命令或网址后连接。例如将以下占位路径改成已安装的服务器：

```json
{"mcpServers":{"local-tools":{"command":"/absolute/path/to/server","args":["--stdio"],"env":{}}}}
```

也可手动添加 Streamable HTTP 地址，例如 `http://127.0.0.1:3000/mcp`；远程必须使用 HTTPS，可填写 Bearer token。导入 HTTP 配置可使用 `url` 与 `Authorization: Bearer …` 请求头。配置、凭证与对话仅保留在内存，重启 App 后需重新连接；不要把凭证提交至 Git。

连接仅列出工具，不会调用工具。Stdio 会以你的 Mac 账户启动程序，请检查命令和参数；App 不会自动安装软件包。默认不选择工具，请自行勾选并测试模型兼容性。兼容性测试使用虚构 echo 工具声明，不执行 MCP 工具。

实际使用时，先检查模型提出的工具名称与完整 JSON 参数，再批准该批次。拒绝不会执行；批准后将结果交回模型整理，不会自动继续调用其他工具。调用失败仍可能已经产生效果，重试前请确认服务器状态。

未通过结构化工具调用测试会显示兼容性提示；连接和认证错误单独显示。通过一次测试不代表支持所有工具结构，也不保证模型回答正确。

支持 stdio、Streamable HTTP JSON/SSE 响应、现代 discovery 与旧版初始化、分页工具列表及工具调用，每段对话连接一个服务器。目前不支持 OAuth、旧式 HTTP+SSE transport、sampling、tasks、input requests 或 schema-to-header projection；这些路径会明确报错。

## 脚本测试

需要 Xcode／Command Line Tools 26、Python 3 和 Apple Container，在仓库中执行：

```sh
bash scripts/test.sh
bash scripts/test-ai.sh --live
CONTAINERDESK_BUNDLE_ID=local.containerdesk.ai-development bash scripts/build.sh ../work/ai-build
open '../work/ai-build/Container Desk.app'
# 候选版选择 English、Light；Mac 解锁并授予测试程序辅助功能权限后：
python3 scripts/test-ai-ui.py
```

常规回归不下载模型。`--live` 需要网络和空闲的 19891 端口，仅使用上述小模型；正常结束会清理临时模型、容器及本次新增镜像，保留既有工作负载。若强制终止，请检查 `cd-ai-test-*` 与系统临时目录再清理。结果在 `../work/ai-tests`。界面脚本不下载、不连接 MCP、不改动容器；三语 × 深浅色 × 两种尺寸共 12 组，截图保留在 `../work/ai-ui-tests`，公开前需检查并遮蔽主机信息。`--generate-only` 仅生成脚本，不能算测试通过。

[验收记录](AI_VALIDATION.md)。后续 Releases 仅附 `.dmg`；教程与测试脚本保留在仓库，源码使用 GitHub 为 release tag 自动提供的下载。上游文档及许可见 [英文版](AI_QUICK_START.md#upstream-references)。
