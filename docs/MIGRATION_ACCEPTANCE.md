> 0.2.0 publication does not mean this full-migration target has passed. The owner deferred second-Mac testing; all current tests run only on the developer’s own Mac. Local-image/data bridging, supervision and cutover/rollback remain future work.

# Migration and quick-deployment acceptance

The product target is a practical migration workflow for ordinary Web/API/database projects. **The current source has not met the complete migration target.** Passing configuration conversion or one fixture must not be called painless migration.

## Two distinct entry points

- **Docker Hub / OCI registry:** an image reference or Docker Hub repository URL downloads/verifies a Linux arm64 image, then opens container configuration. An image alone does not specify required credentials, application-specific ports, persistence, companion services or readiness checks. Private image access uses the official Apple Container CLI's saved credentials.
- **Existing Compose project:** select local source files. Installed official Docker Compose resolves overrides, YAML anchors/templates, `.env` and `env_file`; Container Desk checks and translates the supported runtime settings. A future repository/template import can feed this same review stage. GitHub URL cloning/catalog browsing is not implemented yet.

## Definition of done for painless migration

A supported project must complete all of these without hand-editing YAML:

1. Discover/import the source project, preserve the exact selected file order and relevant environment, and display the target service/resource plan.
2. Preserve command, environment, network connectivity/aliases, startup readiness and supported restart behavior. Detect architecture/runtime differences before cutover; do not silently turn automatic restart into manual control.
3. Transfer local-only images or reproducibly build/pull the required variant, verifying the result against the reviewed source.
4. Back up and migrate named-volume data with application-appropriate consistency, ownership/modes and integrity checks. Account for Docker volume initialization from image contents. Never replace a nonempty destination implicitly.
5. Detect host-port conflicts and evaluate existing bind mounts. Start the target separately where possible and verify application-level health.
6. Review the exact downtime/cutover scope, stop only the selected source writers, perform final synchronization and verify the target. Keep the source and backups intact.
7. On failure, show the failed step and a recoverable checkpoint; restore the selected source service when safe. Retry must not duplicate resources or overwrite data.
8. Pass on a second Apple Silicon Mac and report both success and failure clearly in English, Simplified Chinese and Traditional Chinese.

## Required acceptance fixtures

| Project | Required evidence | Current status |
| --- | --- | --- |
| Static HTTP image | Docker Hub URL/reference, arm64 image, explicit port, HTTP response | Reference parsing and image preparation implemented; deployment still requires configuration |
| Web + API | Multi-file Compose, env values, build args/target, network aliases, HTTP request | Config resolution and multi-network execution covered by focused fixtures; real framework fixture pending |
| API + PostgreSQL | Consistent backup/restore, row counts/checksums, ownership, restart, rollback | Pending |
| API + Redis persistence | Persistence across restart/cutover, no lost writes, rollback | Pending |
| Local-only image | Export/import, digest/variant verification, unchanged source tags | Pending |
| Interrupted migration | Cancellation at every write stage; retry/rollback with preserved original data | Pending |
| Unsupported project | Precise report for Docker socket/API, GPU, privileged/host-network or unsupported semantics | Unsupported configuration rejection implemented; cannot be labelled migrated |

Current increments are documented in [the conversion guide](DOCKER_CONVERSION.md) and [test report](TEST_REPORT.md). Automatic restart supervision, consistent volume migration, image-store bridging, cutover/rollback and a deployment-template catalog remain release-blocking work for this migration target. The repository must remain private until the broader [public-release gates](PUBLIC_RELEASE_GATE.md) also pass.
