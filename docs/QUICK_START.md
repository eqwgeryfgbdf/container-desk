# Container Desk 1.0 — Quick start

[English](QUICK_START.md) · [繁體中文](QUICK_START.zh-Hant.md) · [简体中文](QUICK_START.zh-Hans.md)

## 1. Requirements

Apple Silicon, macOS 26+, and the separate [official Apple Container engine](https://github.com/apple/container). Tested on the developer’s M4 Mac mini / macOS 26.7.1 / engine 1.5.0 only. See [validation](RELEASE_1.0.0_VALIDATION.md).

## 2. Install and connect

1. Download `Container-Desk-1.0.0-arm64.dmg` from [v1.0.0](https://github.com/eqwgeryfgbdf/container-desk/releases/tag/v1.0.0). The only uploaded attachment is the DMG; source archives are generated separately by GitHub.
2. Optionally run `shasum -a 256 Container-Desk-1.0.0-arm64.dmg` and compare the entire value with the release body.
3. Quit the existing app. Open the DMG, drag Container Desk into Applications and confirm replacement. Retain a backup of the old app if you want a simple downgrade. Do not remove engine storage or containers.
4. Open the app. This distribution is ad hoc signed and not notarized. If macOS blocks it, verify the source and use System Settings → Privacy & Security → Open Anyway for this app, then follow the system confirmation. Do not disable Gatekeeper globally.
5. Open **Container Engine**. Connect to an existing engine or install from the supported Apple official release. An administrator may need to authorize system installation. Running workloads defer engine updates; do not stop unrelated work to complete onboarding.

The 0.3 preview used a different preferences domain. Version 1.0 retains the stable app identity; preview UI preferences and AI selection must be reselected as necessary. Engine data is shared and is not migrated or deleted by replacing the app.

## 3. Create a web container

1. **Images → Download & Deploy → Search Docker Hub**: choose the official `nginx`, tag `alpine`, ARM64.
2. Download and configure: name `my-web`, 1 CPU, 256 MiB; publish free host port `18080` to container port `80` over TCP. Keep defaults otherwise.
3. Create, then Start. Click `127.0.0.1:18080` to open the service. If the port is occupied, choose another unused host port.
4. Double-click the container to expand details and logs. Use ⌘+ / ⌘− / ⌘0 for content zoom.
5. Stop and delete only this test container when finished. Removing a container is not a backup of mounted data.

## 4. Optional scripted test

Download `scripts/quick-test.sh` from the matching `v1.0.0` tag and read it first:

```sh
curl -fL https://raw.githubusercontent.com/eqwgeryfgbdf/container-desk/v1.0.0/scripts/quick-test.sh -o quick-test.sh
bash quick-test.sh --check
bash quick-test.sh --run
```

The check is read-only. The run creates a uniquely named, temporary loopback HTTP service and removes its own resources. `--keep` retains the test container for exploration and prints cleanup instructions. No extra test ZIP or AI download is needed.

## 5. More workflows

- [Hugging Face, llama.cpp and MCP](AI_QUICK_START.md): begin with a ~105 MB model; text inference does not guarantee tool calling.
- [Image updates and rollback](IMAGE_UPDATES.md): review downtime and mounted-data limitations before replacing a container.
- [Files, registry and Compose](COMPOSE_AND_FILES.md), [Docker migration](DOCKER_CONVERSION.md): supported subset only; migrate persistent data separately.
- [Report a problem](TEST_REPORT.md): include app/engine/macOS versions and the error, never passwords, tokens or private environment variables.
