# Image search and download

In **Images → Download & Deploy…**, choose **Search Docker Hub**. Enter a keyword and press Return or Search. Select a repository, inspect its description and available version tags, then choose **Use this image**, then **Download Only** or **Download & Configure**. Downloading does not start a container.

- Search covers public Docker Hub repositories. Descriptions, official-image badges, pull counts and stars are supplied by Docker Hub. The badge identifies Docker Official Images, not Apple endorsement or a security review.
- Search and version pages load 25 entries at a time. More Results and More Versions fetch subsequent pages. Duplicate results are omitted. Changing the query or leaving the page cancels the active request; late replies cannot replace newer results.
- Version metadata now displays all reported OS/architecture/variant combinations (attestation entries marked `unknown/unknown` are omitted). Supported deployment targets are Linux ARM64 and AMD64. ARM64 is preferred. Tags reporting only other platforms are blocked; missing metadata and manually entered tags require download-time verification.
- Changing architecture selects a published variant; it does not convert binaries. An AMD64 image runs through Rosetta in an ARM64 Linux VM. For a native ARM64 rebuild, use **Build Image** with the source project and Dockerfile. See Apple's [multiplatform documentation](https://github.com/apple/container/blob/main/docs/multiplatform-images.md).
- Rosetta availability is read from macOS Virtualization.framework. If unavailable, AMD64 download remains available while the unified workflow disables configuration. No Rosetta installation or license acceptance occurs automatically.
- Download explicitly requests `linux/arm64` or `linux/amd64`, verifies actual image configuration, and downloads a missing architecture even when another variant of the same reference exists locally. Configuration preserves the selected architecture and enables Rosetta for AMD64. The create operation rechecks the local architecture before invoking the CLI.
- Download Only ends with Done or Configure Container. Download & Configure continues in the same sheet after verification; it does not create or start a container until the user completes configuration. Tags are mutable and metadata is informational.
- Search is anonymous, without Docker credentials or session cookies. Private images and other registries remain available through **Image name or URL** and existing CLI credentials. They are not included in global search.
- Empty results, unavailable service, malformed responses and HTTP 429 rate limits produce localized messages. Requests have time and response-size bounds. Pagination is constructed locally against Docker Hub, not followed from returned URLs.
- Images still require appropriate ports, environment variables and persistent storage. This feature does not clone GitHub projects, import Compose recipes or migrate existing data.

## Service contract and verification

Docker Hub public search currently uses `/v2/search/repositories/`; this discovery endpoint is not listed in the stable Hub API reference and may change. Keep direct image input available if discovery becomes unavailable. Tag listing uses the [Docker Hub tag API](https://docs.docker.com/reference/api/hub/latest/operations/ListRepositoryTags/).

`bash scripts/test-platform.sh --hub-search` checks live public search and repository/tag pagination without downloading. `--hub-download` additionally selects a small official BusyBox ARM64 tag, downloads and inspects it through the app's operation path, removes only a reference introduced by the test, and checks existing image references and container states. It does not create or start containers.

The new search UI is included in the local development build and source. Existing Release DMGs are unchanged until a new paired release is packaged. Interactive UI acceptance is tracked separately from API and operation tests.

`bash scripts/test-platform.sh --architecture-deploy` additionally verifies ARM64 then AMD64 download of the same unused BusyBox reference, creates a uniquely named AMD64 test container when Rosetta is installed, checks `uname -m` reports `x86_64`, removes its own resources and verifies the original inventory.
