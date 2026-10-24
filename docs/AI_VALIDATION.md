# AI / MCP development acceptance

The October 19 results below are historical. See the October 25 update for current Hugging Face search acceptance.

Scope: 0.3.0 development working tree, not public stable 0.2.0. Tested only on the developer's Apple M4 Mac mini (10 cores, 16 GiB), macOS 26.7.1, Apple Container 1.5.0. Second-device testing remains deferred by the owner.

| Gate | Result | Evidence / boundary |
| --- | --- | --- |
| Full scripted regression | PASS | `bash scripts/test.sh`: 51 core checks, 663 complete three-language keys, 13 simulated installer checks, 35 management checks, 34 workflow checks, 17 platform suites, convenience suite and 40 AI checks |
| Real small-model inference | PASS | `bash scripts/test-ai.sh --live`: 45 total checks (includes the 37 fixture checks at that run), actual ARM64 llama.cpp container and Qwen2.5 0.5B Q4_K_M |
| Real model → MCP → model | PASS | Exact echo argument proposed by the model, fixture MCP tool executed, final model answer includes returned value |
| Review boundary | PASS | Actual AIWorkspace state test: connect/selection does not execute; proposal waits for approval; approve executes once; decline and stale approval after disconnect execute nothing |
| Capability failure | PASS | Text-only model fixture returns failed structured tool-call probe; connection failures are distinct errors |
| Resource boundaries | PASS | Pinned model SHA-256/size, corrupted download rejected, loopback inference, one read-only model file, unknown tool alias rejection, bounded MCP output, cancellation cleanup, no redirect/auth retry |
| Legacy and modern MCP | PASS, fixtures | Stdio legacy/modern and HTTP legacy/modern/modern-SSE tested against local protocol fixtures; arbitrary third-party MCP servers remain unverified |
| Live cleanup | PASS | Test container, temporary GGUF and newly downloaded image removed; pre-existing inventory preserved |
| Release build | PASS | ARM64 SwiftUI app built and ad hoc signed; not Developer ID signed or notarized |
| Native UI matrix | PENDING | Locked desktop; owner deferred unlock. Standalone `test-ai-ui.py` generates 91 steps across 3 languages × 2 themes × 2 window sizes. Generation is not execution. Captures and visual review remain pending. |

## Measured lightweight run

- Model download: **491,400,032 bytes** (~491 MB); no 1.5B model downloaded.
- Container allocation: **2 CPUs, 2 GiB RAM**, context 2,048, CPU inference.
- Model download and verification: **16.15 s**.
- Health readiness: **1.01 s after the container start command returned**; excludes pull/create/start time.
- Single short text response: **0.29 s**; not a throughput benchmark.
- Memory observation: **878,448,640 bytes (~838 MiB)** at the stats sample; not peak memory.
- Full live test including download, image pull and cleanup: **57.08 s**.
- The 491 MB temporary model was deleted, not left in the user's model library.

Local detailed evidence: `../work/ai-tests/live-report.json`, `live-results.log`, `full-regression.log`. The final regression reran after state handling changes and added three checks for models proposing nonexistent tools (40 AI fixture checks total). The live run preceded minor test-harness cleanup/deadline improvements; its recorded runtime results are preserved rather than relabeled as a new run.

These checks validate the narrow supported path, not model quality, an exhaustive security audit, all model formats, all MCP providers or all installation paths. No OAuth, legacy HTTP+SSE transport, sampling, asynchronous tasks, input requests or schema-to-header projection. No Metal/GPU inference inside this Linux container. Native UI acceptance and third-party MCP compatibility remain release work.

## Release attachment policy

Future GitHub Releases attach **only the `.dmg` installer**. Source stays in Git and GitHub's automatic tag archives. Guides and executable tests stay in the repository. Build manifests/checksums are local audit files, not attachments. Historical published assets are not removed. Stable publication remains a separate release step; this document does not authorize or claim publication.

## Hugging Face search acceptance — 2026-10-25

Scope: development 0.3.0 build 7, same developer Mac only.

| Check | Result | Evidence / boundary |
| --- | --- | --- |
| Full regression | PASS | `bash scripts/test.sh`: core, install fixtures, management/workflow/platform/convenience, 40 AI checks, 16 new HF checks and image-update suite. Final localization check: 720 keys in all three languages. |
| HF metadata / cache integrity | PASS | Reject non-text pipelines, private/gated access, traversal, missing hash, invalid size/revision, split/projector/adapter files; preserve same-named old cache and reuse verified cache. |
| Real search → download → inference | PASS | `bash scripts/test-huggingface.sh --live --download --inference --allow-image-pull`: 23 checks. `bartowski/SmolLM2-135M-Instruct-GGUF`, `SmolLM2-135M-Instruct-Q4_K_M.gguf`, commit `09816acd5d99df7be770d85ea30822623dab342c`, 105,454,432 bytes. Actual GGUF header / size / SHA-256 verified. |
| Runtime | PASS | Pinned official ARM64 llama.cpp; 2 CPUs, 1 GiB, context 1,024; health and non-empty text response. This is connectivity acceptance, not a model-quality benchmark. |
| Tiny-model MCP capability | UNSUPPORTED | Real structured tool-call probe returned false. The app retains its capability gate; model format alone never enables MCP execution. |
| Cleanup | PASS | Temporary model and test container removed; newly pulled server image removed; pre-existing container IDs and running states preserved. |
| Native search UI | PASS | `python3 scripts/test-huggingface-ui.py`: 151 steps. English, Traditional Chinese, Simplified Chinese; 1320×860 light and 1100×692 dark per language. Search, repository selection, quantization filter, file selection, repeated selection, no results, disabled download state, close, screenshots. Public API queried; UI test itself does not download or deploy. |
| Visual inspection | PASS, scoped | English dark small-window and Traditional Chinese light large-window captures inspected for clipping, selection and action placement. Other combinations have scripted element checks and captures. |

Local evidence: `../work/huggingface-live.log`, `../work/huggingface-regression.log`, `../work/huggingface-ui/ui.log`, screenshots in `../work/huggingface-ui/`. Screenshots contain local host information and are not public marketing assets.

The native harness initially could not find a Q4 file below the lazy list's visible rows. A filename/quantization filter was added and the complete final scenario passed. The first live inference attempt required a missing server image; the final run explicitly allowed the approximately 296 MB compressed official image and cleaned it up. No large model was downloaded.

Remaining scope: architecture compatibility must be checked by deployment on the pinned engine; GGUF does not guarantee tool support. Gated/private download authentication, split models and exhaustive model/VoiceOver/second-Mac testing are not implemented or claimed. Preview remains ad hoc signed, without Developer ID notarization.
