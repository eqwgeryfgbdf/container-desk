# 0.3.0 preview — release validation

Version: 0.3.0, build 7. Tag: `v0.3.0-preview`. This is a public pre-release, with ad hoc signing and no Apple notarization. Source changes since 0.2.0 include local AI/MCP, Hugging Face model discovery and image/container updates. Website deployment files are a separate working copy and are not part of this app release.

Validation on the owner's M4 Mac mini only (16 GiB, macOS 26.7.1; Apple Container 1.5.0). Second-Mac testing remains deferred.

| Check | Result / scope |
| --- | --- |
| Full regression | PASS: `bash scripts/test.sh`; core/install fixtures/management/workflow/platform/convenience, 40 AI checks, 16 Hugging Face checks and image-update cases. 720 localization keys complete in English, Traditional Chinese and Simplified Chinese. |
| Live Hugging Face metadata | PASS: search, pinned revision and complete size/SHA-256 metadata for SmolLM2 135M Q4_K_M. Rechecked for publication with `bash scripts/test-huggingface.sh --live` (18 checks). |
| Model download and inference | PASS on the same source: 105,454,432-byte model, exact size/GGUF/SHA-256 verification, real llama.cpp text response with 2 CPUs / 1 GiB / 1,024 context, test-resource cleanup. See [AI acceptance](AI_VALIDATION.md); 23 checks in the live download/inference run. No new large-model download was needed for documentation-only release preparation. |
| MCP capability | The 135M model did not pass the tool-call probe. Text inference works; MCP capability is not claimed for this model. Existing fixture/state checks verify the approval gate and unsupported-model handling. |
| Native search UI | PASS: publication rerun of 151 scripted steps, three languages, 1320×860 light and 1100×692 dark per language. Search/repository selection/filter/file selection/repeated selection/no results/disabled actions/dismissal. The initial rerun found the app window hidden; reopening the app restored the test surface. |
| Image updates | Deterministic replacement, preservation, digest, health-failure, cancellation and rollback cases rerun. Earlier disposable-container live and native update/rollback results remain scoped to the same source; [update guide](IMAGE_UPDATES.md). No user container was updated for publication. |
| Documentation | Three READMEs, three AI guides, troubleshooting, light-model example and multilingual Release notes. Relative links checked. Historical 0.2.0 installation/media documentation is labeled separately. |

## Artifact and publication procedure

Build the DMG from a clean checkout of the release commit, verify the ad hoc app signature and disk image, and keep the source-state manifest locally. Upload only `Container-Desk-0.3.0-arm64-preview.dmg`. Publish the full SHA-256 and source commit in the GitHub Release body; do not attach checksum/test/source/video files. Download the published DMG and compare its SHA-256 before reporting publication complete. GitHub-generated source archives are separate from manually uploaded assets. Historical releases remain untouched.

The preview uses `local.containerdesk.ai-development` for its app preferences; the existing Apple Container engine and workloads are shared. It does not migrate preferences from the stable app. Do not interpret the preview as a separate engine or isolated copy of your containers.

## Remaining limits

No Developer ID/notarization, second-Mac, clean-install/real-upgrade certification or full VoiceOver acceptance. GGUF format does not guarantee engine/architecture/tool compatibility. No Metal in the Linux VM, gated-model authentication or split-model loading. MCP stdio programs run as the Mac user after connection review; model-proposed tool calls require approval. Container replacement changes names/IPs and has downtime; rollback does not restore mounted data or database migrations.

Local release logs are stored outside Git in `../work/release-0.3.0-*`; native captures may show the local host name and are not published. These checks do not claim exhaustive security assurance or universal model quality.
