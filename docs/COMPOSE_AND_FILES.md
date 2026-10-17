# Files, registries and Compose projects

Current source only. The existing `v0.1.2-preview` download does not contain this increment.

## Files

Select a running container and choose **Files** from its actions. Browse directories, search names, upload a file/folder, download a selection, create a directory, rename, copy a path or remove a file/empty directory. The container needs `/bin/sh` and ordinary Unix `tar`, `mkdir`, `mv`, `rm` and `rmdir` commands. Distroless images without those tools cannot use this browser.

Transfers stream uncompressed tar archives through Apple Container `exec`, so bind mounts and named volumes use the filesystem actually visible to the container. Apple Container 1.5.0 `copy` was found to bypass the named-volume mount in a live test; it is not used for transfers. Archives are limited to 4 GiB and temporarily occupy disk space. Download extraction uses macOS BSD tar's default traversal/symlink protections plus safe writes. Uploads extract into a private staging directory and move the selected file/folder to a new destination; downloads stage in a private local directory before moving to a new destination. Existing destinations are refused. Interrupted uploads can leave the staging path shown in the operation output; inspect that path before removing it. Symlinks are displayed, but the UI does not open or download a selected symlink. Remote paths containing `:` are not accepted by this file browser. Listings require UTF-8 names. Deleting a mounted file affects its underlying host/volume data; directories must be empty and there is no recursive delete action.

## Registries

**Registries** lists the official CLI's saved account metadata. Log in with a hostname (no URL scheme), username and token/password. Credentials travel over stdin to the official CLI and are stored by that CLI in macOS Keychain. The app does not put passwords in command arguments, operation output, preferences or project files. Login requires HTTPS; authentication failures display a generic error to avoid reflecting a secret. Logout removes the shared CLI credential for the selected server.

From **Images**, choose **Push Image**, supply a fully qualified `registry/namespace/image:tag`, then confirm the push. HTTPS is the default. Optional HTTP is limited to loopback anonymous test registries; it is not an insecure remote-registry login mode. A new local target tag is retained if push fails. Existing different local target tags are refused; a successful remote push can replace the remote tag. Pull and push use the CLI's saved credentials. Remote registry catalog/tag browsing is not yet implemented.

## Compose

Choose **Compose Projects → Import Compose…**, select a local YAML file and review the services, actual container names, networks, volumes, mounts, commands and startup order. Import and validation do not execute the project. **Create & Start** asks for confirmation before pulling/building images or starting containers. Relative paths resolve beside the selected Compose file.

| Supported | Scope |
| --- | --- |
| `image`, `build` | Local arm64 images reused; missing images pulled, or built from local `context`/`dockerfile`. No automatic rebuild of cached tags. |
| `command`, `entrypoint` | Literal argument lists or shell-style word splitting; no implicit host shell evaluation. Explicit shell commands still execute inside the container. |
| `environment`, `env_file` | Explicit values; adjacent `.env` supplies YAML `$VAR`, `${VAR}`, `${VAR:-default}` and `$$`. Host environment is not inherited. Env files use literal single-line `KEY=value`. |
| `ports` | Short form `host:container[/tcp\|udp]`, optionally prefixed with `127.0.0.1:`. Loopback only; no ranges. |
| `volumes` | Short form or long `type/source/target/read_only`; bind mounts and declared named volumes. New managed volumes use 8 GiB each. |
| `networks` | Exactly one declared network per service, default managed network if omitted. Existing external resources must already exist. |
| `depends_on` | Ordered starts, `service_started` or explicit `service_healthy`; missing services and cycles rejected. |
| `healthcheck` | Explicit `CMD`/`CMD-SHELL`, bounded retries/timeout/interval/start period; startup readiness only. Probe output suppressed. |
| Resource/process options | Whole `cpus`, `mem_limit`, `working_dir`, `user`, `read_only`, `platform: linux/arm64`, `restart: "no"`. |

The adapter rejects unsupported settings with their property path before mutating engine resources. Examples include `restart: always`, `deploy`, `profiles`, `secrets`, `configs`, privileged mode, network aliases, multiple networks, completed-job dependencies, YAML anchors/aliases/merge keys, duplicate keys and multi-document YAML. This is a deliberately limited Compose adapter, not full Docker Compose compatibility.

Each project has a persistent UUID and owns only resources carrying its label. Existing same-named foreign resources are refused. A changed service configuration is also refused: review, remove the old project containers, then create again. **Stop Project** and **Remove Project Containers** remain usable if the source YAML becomes invalid. Removal affects the reviewed project containers and their writable layers; named volumes, networks and images remain. Remove unused resources separately from their management pages after reviewing references.

Service names resolve through per-service read-only `/etc/hosts` files managed by the app, populated only with running peers on the same network. `/etc/hosts` is reserved. Project start refreshes addresses; after restarting services through another tool or the ordinary container restart action, run **Create & Start** again to refresh peers. This is not a continuously running DNS service and does not change Mac DNS. Applications that require dynamic DNS updates or custom host-file contents need another setup.

Startup failure/cancellation leaves already-created resources for inspection; it does not roll back data. There is no continuous restart supervisor, scaling or automatic source-file watch. Import only projects whose images, commands, build context and mounts you intend to run.

See [the example](examples/compose.yaml) and [feature roadmap](FEATURE_ROADMAP.md).

## Build and verification

The YAML parser is pinned to Yams 6.2.2 in `Package.swift` and `Package.resolved`. The first Swift Package Manager build needs network access to fetch it. Yams and its bundled LibYAML notices are included in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and in the app resources. Container Desk remains Apache-2.0.

```sh
bash scripts/test.sh                         # includes parser/file/credential unit suites
bash scripts/test-platform.sh --run          # disposable Compose services + file round trip
bash scripts/test-platform.sh --registry     # failed HTTPS login leaves saved accounts unchanged
bash scripts/test-platform.sh --push         # disposable loopback Distribution registry + OCI push
```

Run live suites sequentially on a suitable Apple Container 1.5.0 test host. `--run` needs an existing arm64 Python image. `--push` downloads `registry:3` when missing, imports a tiny empty OCI fixture and removes only its test resources afterward. Successful login/logout and authenticated pull/push against a trusted private registry still need real-account acceptance; the failure fixture does not certify that path.
