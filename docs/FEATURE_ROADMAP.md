# Functional baseline and convenience roadmap

Updated 2026-10-17. User priority: finish the common container-management baseline first, then local AI, then cloud AI. Routine implementation decisions proceed without waiting for replies. Decisions about accounts, paid services, model licensing and optional providers stay deferred. This file tracks scope; it is not a claim of feature parity or public-release acceptance.

## Baseline A — implemented in current source

| Workflow | Implemented behavior | Evidence |
| --- | --- | --- |
| Container lifecycle | Create stopped, start, stop, restart (stop then start), delete stopped containers | Real disposable lifecycle including restart and retained volume data |
| Create configuration | Local-image picker; CPU menu; exact memory entry + slider; loopback port; network and named-volume pickers; bind mount; env; arm64/amd64; optional Rosetta; entrypoint, working directory and literal command arguments | CLI readback and native UI creation; Rosetta requires a separate runtime check |
| Container access | Browser links, inspect JSON/copy/export, Terminal running `/bin/sh` in a running container | Port tests; live exec/inspect; interactive Terminal acceptance still pending |
| Images | Pull with architecture, Dockerfile build, tag, delete, OCI tar import/export, create from selection | Actual scratch build, archive round trip, arm64 BusyBox pull, native tag dialog and native creation |
| Networks | Create with optional IPv4 subnet and host-only setting; list/search/inspect/delete | Actual create/readback/delete; built-in deletion refusal |
| Volumes | Create with capacity; list/search/inspect/delete; select in creation | Actual mount, restart persistence, refusal when referenced by a stopped container |
| Operations | Live CLI output; background continuation; last-operation view; cancellation; timeout; bounded output | Streaming/cancel/timeout tests; actual operation completion in the UI |
| Protection | Re-read references before deletion, protect built-in networks and image aliases; never use blanket or forced delete; prevent engine update during an active resource task | Parser fixtures plus actual engine refusal tests |
| Languages | English, Simplified Chinese, Traditional Chinese | Catalog validation |

The native creation hang UI-001 was traced to `Slider(step: 1)` generating thousands of macOS 26 step marks across the host's memory range. The slider now remains continuous and rounds its binding to whole MiB. The view uses a fixed-size scrollable sheet with reachable footer actions. Native layout checks cover 16 GiB and 1 TiB ranges, and native creation was read back through the CLI. Full multi-size/VoiceOver/second-Mac acceptance remains pending.

## Baseline B — delivered increment

- Multi-select containers (Command/Shift selection), review the exact list, then start/stop/restart/delete sequentially. Fresh per-target state checks reject changed, missing or ineligible targets; failures do not stop later targets. Results show each outcome and cancellation leaves already completed work intact. Deletes never implicitly stop running containers.
- Multiple loopback TCP/UDP ports and bind/named-volume mounts in creation; duplicate normalized destinations and duplicate host-port/protocol pairs are rejected. Added mount rows must be complete. Folder selection uses native panels; named volumes are rechecked before create.
- A shared log viewer for inspector and expanded details: case-insensitive line search, 150/500/2,000/10,000-line snapshots, application/boot source, refresh toggle, copy and native save-panel export. Copy/export uses the visible filtered snapshot, not the entire log history.
- Live evidence: two published HTTP endpoints, UDP configuration readback, three mounts including a read-only bind and a named volume; partial batch failure continues, changed state and running delete are refused, restart/stop/delete are read back. Both disposable containers and their volume were removed; all 8 original container states remained unchanged.

## Files, Registry and Compose — current source

- Container file browser with literal-path operations, staged file/folder transfers through `exec` + tar, no-overwrite behavior, rename/mkdir and confirmed file/empty-directory deletion. Mounted data is accessed in the container's actual filesystem namespace. Archive limit: 4 GiB; requires `/bin/sh`, tar and ordinary Unix file tools.
- Official CLI Registry account list/login/logout; HTTPS credentials on stdin, CLI-managed macOS Keychain, no password in app output or settings. Image push supports explicit fully qualified targets and optional anonymous loopback HTTP for local testing.
- Local Compose YAML import and preview, strict property-path diagnostics, dependency/health startup order, managed service-name mappings, labelled project start/stop/removal and retained named volumes. Invalid source YAML does not prevent stopping/removing previously imported project containers. This is a supported subset, not complete Docker Compose compatibility.
- See [usage, compatibility matrix and test commands](COMPOSE_AND_FILES.md). Private-registry successful authentication needs real-account acceptance; it is deferred rather than prompting for credentials in chat.

## Docker project conversion — current source

- Reviewed Dockerfile/Compose import with a separate, private YAML output; original files and Docker workloads remain unchanged. Common syntax/default-driver normalization, explicit manual-restart opt-in and strict compatibility blocking are implemented. Data, local-only images and application behavior still require migration/verification. See [conversion workflow and limits](DOCKER_CONVERSION.md).

## Baseline B — remaining, before AI

1. Image-metadata defaults; safe duplicate/recreate with a visible configuration diff and retained-volume policy.
2. Finish multi-selection interactive and accessibility acceptance across window sizes; expand cancellation and external-state-change coverage.
3. Finish file-browser interactive/accessibility acceptance and optional embedded terminal; finish boot-log and large-snapshot acceptance. The current Terminal action uses macOS Terminal and needs a shell inside the image.
4. Registry catalog/tag browsing and real authenticated pull/push/login/logout acceptance. Supply accounts only through an appropriate secure flow; do not send credentials in chat.
5. Extend Compose beyond the documented subset: continuous service discovery/restart supervision, scaling, recreate/diff, and additional Compose semantics only when their behavior is verified. Current unsupported settings are rejected.
6. Disk-usage view and selective cleanup preview. No one-click global prune without showing precisely what will be removed.
7. Complete UI, accessibility, clean-install, upgrade and second-Mac release gates; package app and Apache-2.0 source from the same version.

## After the baseline

- **Local AI first:** runtime detection, hardware/capacity checks, model selection/download/progress/cancel, health checks, chat/API verification and application templates. Evaluate native inference on Apple Silicon plus containerized applications; do not advertise GPU acceleration inside Linux containers without verified support.
- **Cloud AI second:** explicit provider/endpoint, secure credential storage, connectivity test and a clear indication of what is sent off-device. Providers, model list and paid subscriptions are deferred decisions.
- Kubernetes, remote machines, MCP, widgets/menu-bar conveniences and advanced registries follow the daily workflows rather than blocking them.

## Reproducible checks

```sh
bash scripts/test.sh
bash scripts/test-creation-ui.sh       # isolated native layout, no engine calls
bash scripts/test-management-live.sh --run
bash scripts/test-workflows-live.sh --run  # two disposable containers, no image download
bash scripts/test-images-live.sh --run
bash scripts/test-platform.sh --run --registry --push  # disposable projects, files and loopback registry
```

Live tests mutate only named disposable resources. The management test requires an existing arm64 Python image. The image test requires the existing builder to be stopped; it temporarily starts that builder for a tiny scratch build, restores it to stopped, downloads a small BusyBox image if absent, and cleans up its own images. It does not stop unrelated running containers. Run these on a suitable test host, never concurrently with another build.

Current source and local development build include Baseline A. Existing `v0.1.2-preview` GitHub assets have not been replaced. Keep the repository private until [the public-release gates](PUBLIC_RELEASE_GATE.md) pass.
