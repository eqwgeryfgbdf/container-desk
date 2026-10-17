# Container snapshots and personal registries

Open a container's action menu and choose **Save Container as Image…**. Supply a new local image name, review the filesystem and environment choices, then **Save Locally**. After success, either finish or enter a fully qualified registry destination and choose **Push Image**. Registry credentials come from the existing Apple Container CLI login. The app does not create a cloud account or change repository visibility.

The current implementation requires Apple Container 1.5+ with `container export`. It exports the current root filesystem, packages it as a new, single-layer OCI image, and loads that image locally. This preserves files added, modified or deleted since the original image, rather than just tagging the original image. The existing local tag must be unused. Network publishing is a separate, explicit action after the local snapshot is ready.

## What is included

- Root filesystem contents, including changes inside the container.
- Linux architecture, resolved startup executable/arguments, working directory and user.
- Environment variables only if explicitly enabled. They are omitted by default because they may contain credentials. Required variables must then be supplied during deployment.

## What is not included

- Mounted host folders, named volumes and their contents.
- Process memory, open connections, host ports, network definitions, automatic restart behavior, capabilities, resource limits, extra groups and other runtime configuration.
- Database/application transaction guarantees. The official running-container export snapshots the filesystem, but applications may still need their own backup/checkpoint procedure. The app does not stop the source container. Exporting a running source requires acknowledging this limitation.

The snapshot can contain private files and credentials even when environment variables are excluded. Review its contents before pushing to a registry. Registry access policies and repository visibility remain under the registry's control.

## Implementation and failure behavior

- Fresh inspect before export; configuration and running/stopped state are compared after export. If they changed, no image is loaded.
- The engine-produced filesystem tar stays opaque. Container files are never unpacked onto the Mac. A streaming SHA-256 digest produces OCI layer/config/manifest references; the host tar command only packages the private staging directory.
- Temporary staging is removed after success, failure or cancellation. A load interrupted after the engine begins importing may leave a local reference; inspect the local image list before retrying. Completed local snapshots remain available if a later push fails.
- Local tag collisions are rejected before export and again before import. The engine has no atomic create-if-absent tag API, so external CLI mutations must not concurrently assign the same target name.
- The image's architecture is verified after load. Snapshotting does not convert CPU architectures.

See the [official export command](https://github.com/apple/container/blob/main/docs/command-reference.md#container-export) for the underlying engine operation.
