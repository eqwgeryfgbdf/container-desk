# Image and container updates

## Quick start

1. Open **Images**, select an image, then **Update → Check & Download Latest Image**. Apple Container pulls the same tag from its registry using your existing CLI registry login. This may download new layers. It does not discover newer version-number tags and does not change existing containers.
2. Review the result: the local digest and Linux architectures are verified after pulling. A changed digest means a new image was downloaded; an unchanged digest means the registry matches the local image. An authentication/network error is a failure, never “up to date”. Digest-pinned references cannot track tag updates. Local build-only images need rebuilding or publishing first.
3. Choose **Update → Apply Image to Container…**, choose an outdated container and review its replacement name. Optional: enter a read-only HTTP health endpoint on one of that container's published TCP addresses/ports.
4. Back up application data, read the impact notice, acknowledge it, then apply. The original stops; a replacement is created with the new image. Supported CPU, memory, command, user, environment, ports, network and mounts are retained. The original is not deleted.
5. Read the verification report. For a previously running container, the replacement must remain running across three observations. An optional HTTP check requires a 2xx response, retries startup failures and refuses redirects. Without an HTTP URL, application health is **not** claimed. A previously stopped container stays stopped; its startup is not tested.
6. Revert successive updates newest-first. Retained originals are excluded from new update selections while an update record exists. To return, use **Images → Revert Container Update** and select the replacement/original pair. The app verifies both configurations before stopping the replacement and restoring the original running/stopped state.

## Boundaries and recovery

- Apple Container has no in-place image replacement/rename operation in the tested 1.5.0 CLI. This workflow retains the original container and creates a replacement with an `-upd-…` name. Internal IP and container name change. Clients using the old internal name/IP need adjustment; host port bindings are preserved. This is not a rolling or zero-downtime update.
- Root filesystem changes made inside the old container are not copied into the replacement. The original filesystem remains in the retained original container.
- Mounted data is shared. **Neither automatic nor manual rollback reverses database migrations or changes to mounted files.** Back up data separately and verify application-specific compatibility before proceeding.
- The conservative planner refuses configurations it cannot reproduce, including managed/labelled workloads, custom DNS, multiple networks, unsupported mounts, capabilities and special runtime settings. Update those through their project/deployment configuration. No partial recreation is attempted.
- Configuration/digest/state are checked again immediately before mutation. Operation failure or cancellation attempts to stop only the generated replacement and restore the original state. If recovery cannot be verified, the UI reports that explicitly. Inspect both containers before starting either one.
- If the app or machine terminates during an update, no automatic background recovery runs. The original and retained image references are available for manual inspection; a partially created replacement may also exist. Ensure only one instance accesses writable mounts.
- Completed update pairs survive app restarts in `~/Library/Application Support/ContainerDesk/container-updates.json`. It stores identifiers and configuration hashes, not environment values. Images under `docker.io/container-desk-backup/…` are local retained tags; the app never pushes them. They may be deleted manually after recovery is no longer needed and no container uses them.
- A health URL is optional and must be an HTTP(S) address published by the selected container, without embedded credentials or a fragment. It sends a GET with no stored cookies/credentials. Choose a read-only endpoint that accurately represents readiness.

## Scripted verification

```sh
bash scripts/test-image-updates.sh          # deterministic failure-path tests, no downloads
bash scripts/test-image-updates.sh --live   # disposable BusyBox containers, about a few MB of image layers
```

The live script pulls ARM64 BusyBox 1.36.1 and 1.37.0, changes a disposable local tag, applies the update, verifies HTTP 2xx and retained port/environment/mount behavior, explicitly rolls back, then forces HTTP 404 to verify automatic rollback. It also checks a real registry refresh and verifies fixture cleanup and original container states. It never updates existing user containers. Tests have been run on this Mac only.

Reference: [Apple Container command reference](https://github.com/apple/container/blob/1.5.0/docs/command-reference.md).
