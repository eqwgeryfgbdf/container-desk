# Quick start — Container Desk 0.1.3 preview

[English](QUICK_START.md) · [中文（繁體）](QUICK_START.zh-Hant.md) · [中文（简体）](QUICK_START.zh-Hans.md)

Try a real local service without compiling the app. The repository is currently private: testers need repository access and must sign in to GitHub. A 404 usually means the account lacks access, not that the download has disappeared.

## 1. Choose your download

Open [v0.1.3-preview](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v0.1.3-preview).

| Asset | Use |
|---|---|
| `Container-Desk-0.1.3-arm64-preview.dmg` | Install the Mac app; no Xcode needed. |
| `Container-Desk-0.1.3-Quick-Start.zip` | Optional small bundle: this guide in three languages, `quick-test.sh`, read-only `Check-Mac.command`, opt-in `Run-Quick-Test.command` and example project. No duplicate DMG. |
| `Container-Desk-0.1.3-preview-source.zip` | Matching Apache-2.0 source, build scripts and complete automated QA. |
| `Container-Desk-0.1.3-preview-manifest.json` | Exact source commit/tree and primary artifact hashes. |
| `SHA256SUMS.txt` | SHA-256 for all attached deliverables except this checksum file. |
| `Container-Desk-Overview-zh-Hant.mp4` | 58.5-second actual walkthrough with Traditional Chinese captions. Recorded from the preceding QA build; it is not an install/upgrade acceptance video. |

Requirements: Apple Silicon, macOS 26+, Internet for image downloads, and Apple Container **1.5.0**. Intel Macs are unsupported. Only source builds/full QA require Xcode or Command Line Tools 26 and Python 3; the quick test uses built-in Bash/curl and the installed engine.

If you download all listed assets into one folder, run `shasum -a 256 -c SHA256SUMS.txt` there. If you only download the DMG, run `shasum -a 256 Container-Desk-0.1.3-arm64-preview.dmg` and compare its full digest with the matching checksum line; missing optional files are not DMG corruption.

## 2. Install and connect

1. Open the DMG, drag **Container Desk** to **Applications**, then launch it from Applications. When replacing an old app, quit that app first. Eject the DMG afterward.
2. This preview is ad hoc signed, without Developer ID or Apple notarization. macOS may block first launch. If you trust this exact download, review Apple's [per-app opening instructions](https://support.apple.com/en-nz/102445); the relevant control may appear under System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper globally. If no per-app option is available, report the exact alert.
3. Open **Container Engine**. If the engine is missing, use the app's official-source installation flow, or install the supported release from [Apple Container](https://github.com/apple/container). Review any macOS administrator prompt yourself. The app and engine are separate installations.
4. Start the engine if needed. Wait for **Connected**, then verify Overview shows your real CPU/memory/system version. Do not reinstall over an unrecognized custom setup; follow the displayed explanation.
5. In Settings choose English, Traditional Chinese or Simplified Chinese. CPU counts/memory limits come from the actual host.

## 3. Five-minute engine check, without compilation

Unzip the optional Quick Start bundle and open Terminal in that folder. Read the script before running it.

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

`--check` is read-only. `--run` downloads official `busybox:1.37` **only if absent**, creates a UUID-named container with 1 CPU/256 MiB, exposes HTTP only on `127.0.0.1:18080`, verifies the response, exec/log access and stop/start file persistence, then removes its container and only the image reference it newly downloaded. Existing images and unrelated containers are retained. It never installs/upgrades the engine, invokes sudo, mounts host folders, prunes resources or uploads reports.

Expected result: lines starting `PASS:` and exit status 0. A nonzero status or `BLOCKED`/`FAIL` is a failed or unmet check, not success. `--port 18081` selects another port if 18080 is busy.

To leave the service running for exploring the app:

```sh
bash quick-test.sh --run --keep
```

The script prints the exact container name, URL and cleanup commands. In Container Desk, refresh Containers, select that `cd-quick-…` container, double-click it for full details, open its port link, view Logs and use More Actions → Files to inspect `/www/index.html`. When finished, run the printed stop/delete commands; delete the image only if it is no longer used. `--keep` intentionally leaves test resources running.

The `.command` launchers offer the same choices when opened in Finder; they pause so you can read the result. macOS may require approval for downloaded scripts. Terminal commands above are the transparent alternative. These engine checks do not establish full UI, clean-install or upgrade acceptance.

## 4. Create a service entirely in the app

1. Images → **Download & Deploy…**. Search Docker Hub for `python`, choose the official `library/python` repository, tag `3.13-slim`, Linux ARM64. Alternatively enter `docker.io/library/python:3.13-slim` in **Image name or URL**.
2. Choose **Download & Configure**. Name: `my-python-web`; CPU: `1`; memory: `512 MiB`; host port: `18081`; container port: `8080`, TCP. Use a free port. Keep the default network and add no host mounts or secrets.
3. Under Advanced, set entrypoint to `python3`. Put each argument on a separate line (do not add shell quotes):

```text
-u
-m
http.server
8080
--bind
0.0.0.0
```

4. Create. The new container initially stays **stopped**. Select it and click Start.
5. Click the port link or open `http://127.0.0.1:18081/`. A directory listing proves the actual service is reachable. Logs should show the request. If it fails, inspect status/logs before retrying.
6. Double-click the row for full-window details; use Command `+`/`-` to change interface scale. Check CPU/memory, logs and files. Select checkboxes for batch actions and review the listed targets before confirming.
7. Stop `my-python-web`, then delete only this test container. Images are separate resources; remove the downloaded Python image only when unused.

## 5. Try Projects, Registry and files

- **Projects:** import the bundled `examples/quick-web.yaml` (or [repository example](examples/quick-web.yaml)). Review the validation/compatibility report, then start the project. It uses a loopback port (18082), no bind mounts and a small BusyBox web server. Open `http://127.0.0.1:18082/`; expected text: `Container Desk project works`. Stop/remove the project afterward and inspect retained resources. Docker conversion supports a documented subset; unsupported fields are reported, not silently discarded. See [conversion guide](DOCKER_CONVERSION.md).
- **Registry:** use your own authorized test repository. Login stores credentials through the official CLI; never paste tokens into bug reports. Tag/push are explicit actions. Public search does not grant push access to Docker Hub. Private HTTPS login success still needs account-specific acceptance.
- **Files:** browse a test container first. Transfers enforce a 4 GiB/10,000-entry limit and ordinary uncompressed tar formats; unusual compression/sparse/metadata extensions are refused. Test downloads in a new empty destination; existing destination files are protected. See [files/projects guide](COMPOSE_AND_FILES.md).

## Troubleshooting and reporting

| Symptom | Next step |
|---|---|
| GitHub 404 | Sign in with an account invited to this private repository. |
| Cannot launch app | Confirm Apple Silicon/macOS 26 and the full DMG checksum; capture the exact macOS alert. |
| Disconnected / CLI not found | Use Container Engine to inspect the installed official engine and start it; do not erase its data. |
| Port in use | Pick 18081/another unused port; do not stop an unrelated service. |
| Search/download failure | Check Internet/DNS, registry rate limits and credentials; retry after the cause is resolved. |
| AMD64-only image | Prefer ARM64. AMD64 requires supported Rosetta setup; changing a label does not convert a binary. |
| Unsupported project field | Review the validation report and [supported subset](COMPOSE_AND_FILES.md); do not assume all Docker projects migrate unchanged. |
| Quick test cleanup failed | Use the printed UUID/container reference to inspect only that fixture. Do not use a global prune. |

Report app version, macOS/chip, engine version, exact steps, expected/actual result and the `PASS`/`FAIL` output. Remove hostnames, private paths, environment values, passwords and tokens before sharing. Reports remain local unless you choose to send them.

For developers: build with `bash scripts/build.sh`, then run `python3 scripts/qa.py --live --ui`. Read [Automated QA](AUTOMATED_QA.md) first: it downloads fixtures and operates the foreground app, so leave the desktop idle. Current baseline: 17 groups passed/0 failed, 56 UI steps passed. This is a private preview; second-Mac installation/upgrade, full accessibility/visual review and the 60-minute stability gate remain pending. AI models are deferred.
