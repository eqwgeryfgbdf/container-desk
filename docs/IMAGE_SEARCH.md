# Image search and download

In **Images → Quick Deploy…**, choose **Search Docker Hub**. Enter a keyword and press Return or Search. Select a repository, inspect its description and available version tags, then choose **Use this image → Download and Verify → Configure Container…**. Downloading does not start a container.

- Search covers public Docker Hub repositories. Descriptions, official-image badges, pull counts and stars are supplied by Docker Hub. The badge identifies Docker Official Images, not Apple endorsement or a security review.
- Search and version pages load 25 entries at a time. More Results and More Versions fetch subsequent pages. Duplicate results are omitted. Changing the query or leaving the page cancels the active request; late replies cannot replace newer results.
- Version metadata lists Linux ARM64 compatibility. Listed incompatible/unknown tags cannot be selected for download; enter a different tag or load more versions. A manually entered tag is checked again by the existing Apple Container download/inspection workflow. Tags are mutable and metadata is informational.
- Search is anonymous, without Docker credentials or session cookies. Private images and other registries remain available through **Image name or URL** and existing CLI credentials. They are not included in global search.
- Empty results, unavailable service, malformed responses and HTTP 429 rate limits produce localized messages. Requests have time and response-size bounds. Pagination is constructed locally against Docker Hub, not followed from returned URLs.
- Images still require appropriate ports, environment variables and persistent storage. This feature does not clone GitHub projects, import Compose recipes or migrate existing data.

## Service contract and verification

Docker Hub public search currently uses `/v2/search/repositories/`; this discovery endpoint is not listed in the stable Hub API reference and may change. Keep direct image input available if discovery becomes unavailable. Tag listing uses the [Docker Hub tag API](https://docs.docker.com/reference/api/hub/latest/operations/ListRepositoryTags/).

`bash scripts/test-platform.sh --hub-search` checks live public search and repository/tag pagination without downloading. `--hub-download` additionally selects a small official BusyBox ARM64 tag, downloads and inspects it through the app's operation path, removes only a reference introduced by the test, and checks existing image references and container states. It does not create or start containers.

The new search UI is included in the local development build and source. Existing Release DMGs are unchanged until a new paired release is packaged. Interactive UI acceptance is tracked separately from API and operation tests.
