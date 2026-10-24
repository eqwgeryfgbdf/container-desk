# Local AI and MCP — 0.3.0 development preview

[繁體中文](AI_QUICK_START.zh-Hant.md) · [简体中文](AI_QUICK_START.zh-Hans.md)

Download the [0.3.0 preview DMG](https://github.com/eqwgeryfgbdf/container-desk/releases/download/v0.3.0-preview/Container-Desk-0.3.0-arm64-preview.dmg). Native search UI automation passed on the developer’s Mac; see [validation and limits](AI_VALIDATION.md). This is an ad hoc signed preview, not Apple-notarized or a stable release. Public 0.2.0 does not contain these features.

## Start a model

1. Start the Apple Container engine, then open **Local AI** in the sidebar (the label follows the selected language).
2. Select the smallest catalog model, **Qwen2.5 0.5B Instruct Q4_K_M**, and download it, or choose your own single-file `.gguf`. The catalog download is 491,400,032 bytes (~491 MB). Downloads verify an exact pinned revision, file size and SHA-256. Models are not included in the DMG.
3. Use 2 CPUs, 2 GiB memory, a 2,048-token context and an unused host port (default 18090). Create/start the model container, then test the model. The official pinned llama.cpp Linux ARM64 image is downloaded separately.
4. Send a message. To replace a deployment, stop/delete its container from Containers first. A canceled or failed deployment may leave a container there for inspection; the app does not delete workloads automatically.

Inference runs on **CPU inside the Linux VM**; it does not use Apple Metal. Only the selected model file is mounted read-only. The service is published on `127.0.0.1`. Normal downloads are cached in `~/Library/Application Support/Container Desk/Models`; they remain until you remove them. Small models are suitable for connectivity testing, not a promise of reliable reasoning or arbitrary tool use.

## Search Hugging Face models

In **Local AI → Search Hugging Face**, enter a model name or publisher, or select a small-model shortcut. Results are ordered by download count. Choose a repository, then a single GGUF quantization file (smallest first). Review its size, license/model card and estimated memory, then click **Select & Download**. An empty search lists popular GGUF candidates.

For a lightweight trial, search `SmolLM2-135M-Instruct`, choose `bartowski/SmolLM2-135M-Instruct-GGUF`, then `SmolLM2-135M-Instruct-Q4_K_M.gguf` (105,454,432 bytes at the tested revision). Use 2 CPUs, 1 GiB and 1,024 context for a basic text test. Tool calling is a separate compatibility test; a small model may fail it.

Downloads pin the repository commit and verify the exact size, GGUF header and SHA-256. Different contents use separate cache folders, preserving old same-named models. Downloading never deploys or executes repository code. GGUF is a format filter, not proof that the pinned llama.cpp engine supports every architecture. Use **Test Model** after deployment; memory estimates vary with context and do not guarantee successful startup.

Only public, single-file text-model candidates are offered. Split GGUFs, projectors, adapters and files without complete checksum metadata are omitted. Access-controlled models require manual authorization on Hugging Face and local-file selection. Unknown licenses are displayed explicitly; check the model card before use. Search sends your search text to Hugging Face, not your chat or local files.

Scripted checks (normal regression makes no network requests):

```sh
bash scripts/test-huggingface.sh
bash scripts/test-huggingface.sh --live                      # metadata only
bash scripts/test-huggingface.sh --live --download           # model below 128 MiB, cleaned up
bash scripts/test-huggingface.sh --live --download --inference --allow-image-pull
```

The inference test uses port 19893 and a temporary 2 CPU / 1 GiB container. The optional official ARM64 server image is about 296 MB compressed; newly downloaded test images are removed after the test. Existing containers are preserved. A forcibly killed script may leave `cd-hf-test-*` resources for manual inspection.

## Download troubleshooting

| Symptom | What to do |
| --- | --- |
| No matching model | Search a shorter name or publisher. Results show at most 40 popular public GGUF candidates; clear the query for popular models. |
| Too many quantizations | In the file filter enter `Q4_K_M`. File sizes are sorted smallest-first; choose one complete GGUF, not an adapter or projector. |
| Access approval / sign-in required | Use the model-card link, obtain permission on Hugging Face, download a single GGUF manually, then choose **Choose local GGUF…**. The app does not collect a Hugging Face token. |
| Rate limit / network error | Wait and retry the search. An error is not a successful download or a compatibility result. |
| Insufficient storage / checksum failure | Free space or retry. The app does not select a failed download. Do not rename or edit a corrupt file to bypass verification. |
| Container does not become ready | Check its logs and memory allocation. Try the tested small model; the pinned engine may not support a newer model architecture. |
| Tool calling warning | A text response does not prove MCP support. The tested SmolLM2 135M failed the tool probe. Use a suitable instruct model and rerun the test before enabling tools. |

To cancel a download, use **Cancel** beside its progress. Completed downloads remain in `~/Library/Application Support/Container Desk/Models`. Models downloaded by the live test are temporary and cleaned up separately. Stop/delete a model container before removing a file it mounts.

## Connect installed MCP tools

Import a JSON file containing `mcpServers`, select one server, review the command or URL, then connect. For example, adapt these placeholders to an already installed server:

```json
{"mcpServers":{"local-tools":{"command":"/absolute/path/to/server","args":["--stdio"],"env":{}}}}
```

Or add a Streamable HTTP endpoint such as `http://127.0.0.1:3000/mcp`; remote endpoints require HTTPS. An optional Bearer token is supported. Imported HTTP configuration can use `url` and an `Authorization: Bearer …` header. Configurations, credentials and chat stay in memory; reconnect after restarting the app. Do not commit credentials.

Connecting lists tools; it does not invoke them. Stdio starts a local program **as your Mac user**, so review imported commands and arguments. The app does not automatically install packages. No tools are selected initially. Select only the tools you want, then run the model compatibility test. That test uses a synthetic echo declaration and executes no MCP tool.

For real requests, review each proposed tool name and its complete JSON arguments before approving. Declining executes nothing. Approval executes that batch and asks the model to summarize the results. It does not loop into additional tool calls. A failed call may already have had effects; inspect the server before retrying.

A failed structured tool-call probe displays a compatibility warning. Connection/authentication errors are reported separately. Passing the probe is not certification of all tool schemas or model accuracy.

Supported scope: stdio, Streamable HTTP JSON/SSE responses, modern discovery and legacy initialization, paginated tool lists and tool calls, one server per conversation. OAuth, legacy HTTP+SSE transport, sampling, tasks, input requests and schema-to-header projection are not implemented. Unsupported paths fail explicitly.

## Reproduce checks

From the repository with Xcode/Command Line Tools 26, Python 3 and Apple Container:

```sh
bash scripts/test.sh                 # fixtures and regression; no model download
bash scripts/test-ai.sh --live       # small real model, temporary image/container/files
CONTAINERDESK_BUNDLE_ID=local.containerdesk.ai-development bash scripts/build.sh ../work/ai-build
open '../work/ai-build/Container Desk.app'
# Choose English + Light in this isolated candidate, unlock the Mac, grant Accessibility:
python3 scripts/test-ai-ui.py
```

The live test needs network access and free port 19891. It uses unique test resources, preserves pre-existing workloads, and removes its temporary model/container and newly downloaded image on normal completion. If the process is forcibly killed, inspect `cd-ai-test-*` and the system temporary directory before manual cleanup. Logs/reports are local under `../work/ai-tests`. UI captures remain private under `../work/ai-ui-tests`; inspect/redact host identity before publication. `--generate-only` only creates a scenario, never reports a UI pass.

See [acceptance results](AI_VALIDATION.md). GitHub Releases will attach only `.dmg`; tests and guides remain in the repository. GitHub provides source archives for the release tag automatically.

## Upstream references

[Apple Container](https://github.com/apple/container) · [llama.cpp containers](https://github.com/ggml-org/llama.cpp/blob/master/docs/docker.md) · [function calling](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md) · [Qwen model](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) · [MCP specification](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
