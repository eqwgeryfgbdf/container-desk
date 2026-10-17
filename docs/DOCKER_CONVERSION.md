# Convert a Docker project

Current source and local development build only; the existing `v0.1.2-preview` download is unchanged. This converts a supported configuration to the Container Desk Compose adapter. It does not provide a Docker daemon/API, full Docker Compose compatibility, image architecture conversion or automatic data migration.

## Workflow

1. Open **Compose Projects → Convert Docker Project…**.
2. Choose a project folder, Compose YAML file or `Dockerfile` / `Dockerfile.*`. A folder must contain one canonical Compose file (`compose.yaml`, `compose.yml`, `docker-compose.yaml`, `docker-compose.yml`) or a `Dockerfile`. If multiple Compose files exist, choose one explicitly.
3. Leave **Resolve with installed Docker Compose** enabled to use the official CLI for YAML templates/anchors, `.env`, `env_file` and override merging. A single adjacent default override is selected automatically; use **Add Override File…** to specify explicit overrides in order. A missing CLI shows an actionable error; turning this option off uses the limited standalone parser. Host shell variables and ambient `COMPOSE_*` settings are not inherited. Missing-variable warnings block conversion instead of silently substituting blank values.
4. Review each compatibility message and the generated YAML. Unsupported requirements block import. Automatic restart policies block by default; the optional manual-start/stop checkbox explicitly accepts losing crash recovery and automatic startup.
5. Check the review box, then **Save & Import**. A uniquely named `compose.container-desk-<id>.yaml` is created beside the source with mode `0600`. Original files remain unchanged; a changed source is refused until reviewed again. Adjacent `.env`, `env_file`, build and bind paths retain their location. The new YAML can contain original environment values: review it before sharing or committing it.
6. Review the normal Compose preview and use **Create & Start** when ready. Import alone does not pull/build images, start containers, contact Docker or copy data.

Folder scanning is deliberately shallow. Multiple candidate base files require an explicit selection. Official resolution receives the selected file list and first file's project directory; it does not start Docker workloads. Save reruns resolution and refuses a changed result, including changes to overrides and environment files. The generated YAML contains resolved values marked by `x-container-desk-resolved: true`, so later `.env` edits or literal dollar signs cannot silently change its meaning. Reconvert to update the snapshot. This file can contain secrets and is created with mode `0600`.

Without the official CLI, anchors/aliases, merge keys and adjacent default overrides remain blocked. The standalone path supports only the documented interpolation subset. This mode does not claim Docker's complete file-resolution behavior.

## Conversion scope

| Input | Result |
| --- | --- |
| Supported Compose fields | Preserve values and validate with the same strict planner used for execution. See [the adapter matrix](COMPOSE_AND_FILES.md#compose). |
| `Dockerfile` alone | Generate an `app` service with its parent folder as build context and the selected Dockerfile name. Image defaults remain. `EXPOSE` does not publish host ports automatically. Review the build context and `.dockerignore`. |
| Obsolete `version` | Remove metadata. |
| `container_name` | Replace fixed naming with project-scoped names; service keys remain. Scripts and hard-coded hostnames using the old names require review. |
| `restart: always`, `unless-stopped`, `on-failure[:N]` | Block unless the user explicitly opts into manual start/stop, then set `restart: "no"`. |
| Explicit long-form port mapping | Convert `target`, `published`, `protocol`, `host_ip` to supported short form. Published ports use `127.0.0.1`; LAN exposure is not preserved. Ranges, random host ports, IPv6 and other specific host addresses are rejected. |
| `expose` | Remove valid port metadata without publishing a host port. |
| Service networks and aliases | Up to 8 declared networks per service. Network-scoped aliases use managed host mappings; conflicting/reserved aliases and static-IP/network options are rejected. |
| Required `env_file: {path, required: true}` entries | Convert to short paths. Optional/raw-format variants remain unsupported. |
| Docker default network/volume drivers | Replace `bridge`/`local` declarations with Apple Container-managed resources. Driver options and custom drivers are rejected. This does not promise identical network or storage behavior. |
| Build settings | Local context/Dockerfile, explicit build args, multi-stage target, no-cache and pull. Missing context defaults to the source folder. |
| `init`, labels | Forward init and explicit label maps; internal ownership labels are reserved. |

In official resolution mode, Docker Compose applies its env-file/interpolation rules using project files; host shell values are not inherited. In standalone mode, only adjacent `.env` and literal single-line env files are supported. Image availability, base-image architecture, successful build and application health still require runtime verification. A known `linux/amd64`/`linux/386` Dockerfile `FROM --platform=` is blocked, but static inspection cannot prove the architecture of every base image or executable.

## What needs separate migration

- **Data:** Docker named-volume contents are not copied. New managed Apple Container volumes are separate. Back up and migrate application data using an application-appropriate procedure, then verify it before switching services. External resources must already exist in Apple Container. Existing host bind paths refer to the actual same host files; starting a converted application can modify those files.
- **Images:** Docker's local image store is separate. Publish/import local-only images or supply a build context. Registry credentials and image access must work with the official Apple Container CLI.
- **Unsupported requirements:** Docker socket/API integrations, privileged mode, GPU/device configuration, host networking, profiles/deploy, secrets/configs and unsupported network/volume options block conversion. x86-only applications are not automatically rebuilt for arm64. Continuous restart supervision and dynamic service discovery are not implemented by this adapter.
- **Cutover:** Conversion never stops or removes the Docker project. Check host-port conflicts, back up data, verify the converted application and decide the cutover separately. Do not run two writers against the same database files.

## Verification

```sh
bash scripts/test.sh
bash scripts/test-platform.sh --convert-run
bash scripts/test-platform.sh --resolved-run # installed Docker Compose; merged multi-network fixture
```

The first command includes migration fixtures for explicit restart consent, preserved input/env/bind paths, private unique output, source-change refusal and unsupported settings. The live command needs an existing arm64 Python image and Apple Container 1.5.0. It converts a disposable two-service Docker-style configuration, then checks dependency/health startup, service-name access, mounted binary/directory transfer, volume retention, cleanup and original container-state preservation. Run on a suitable test host, sequentially with other live suites. This fixture does not certify arbitrary third-party Docker projects.

Official references: [Apple Container](https://github.com/apple/container) and the [Docker Compose service specification](https://docs.docker.com/reference/compose-file/services/).

## Quick deployment from Docker Hub

Open **Images → Quick Deploy…** and paste a Docker Hub repository link (for example `https://hub.docker.com/_/nginx`) or an OCI registry reference. Choose a tag when the reference does not already include one. **Download & Verify** uses the official Apple Container CLI, checks for an arm64 variant, and prepares **Configure Container…**. Review ports, environment and persistent storage against the image documentation. This does not start an image automatically or infer a complete application recipe. Cached local images are reused; private registries use saved CLI credentials. Arbitrary webpage URLs are rejected.

This is an incremental deployment workflow. The full data-preserving migration target and remaining release gates are tracked in [migration acceptance](MIGRATION_ACCEPTANCE.md).
