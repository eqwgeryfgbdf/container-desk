#!/bin/bash
# No Xcode, Swift, Python, sudo, or global cleanup required.
set -euo pipefail
MODE=check
KEEP=0
PORT=18080
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --run) MODE=run; shift ;;
    --keep) KEEP=1; shift ;;
    --port) [[ $# -ge 2 ]] || { echo 'Missing port' >&2; exit 2; }; PORT="$2"; shift 2 ;;
    --help|-h) echo 'Usage: bash quick-test.sh [--check | --run] [--keep] [--port 18080]'; echo 'Default: read-only preflight. --run uses one disposable BusyBox HTTP container.'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
[[ "$PORT" =~ ^[0-9]+$ && ${#PORT} -le 5 ]] || { echo 'Invalid port' >&2; exit 2; }
PORT=$((10#$PORT))
(( PORT>=1024 && PORT<=65535 )) || { echo 'Port must be 1024–65535' >&2; exit 2; }
[[ "$MODE" == run || "$KEEP" == 0 ]] || { echo '--keep requires --run' >&2; exit 2; }
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { echo 'BLOCKED: an Apple Silicon Mac is required.' >&2; exit 1; }
OS="$(sw_vers -productVersion)"
(( ${OS%%.*} >= 26 )) || { echo 'BLOCKED: macOS 26 or later is required.' >&2; exit 1; }
CLI=''
for candidate in "$(command -v container || true)" /usr/local/bin/container "$HOME/.local/bin/container" /opt/homebrew/bin/container; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then CLI="$candidate"; break; fi
done
[[ -n "$CLI" ]] || { echo 'BLOCKED: install Apple Container from the official source in the Container Engine page first.' >&2; exit 1; }
VERSION="$("$CLI" --version)"
[[ "$VERSION" == 'container CLI version 1.5.0 '* || "$VERSION" == 'container CLI version 1.5.0' ]] || { echo "BLOCKED: this release was tested with Apple Container 1.5.0; found $VERSION" >&2; exit 1; }
"$CLI" list --all --quiet >/dev/null
printf 'PASS: Apple Silicon, macOS %s, engine 1.5.0 reachable\n' "$OS"
if [[ "$MODE" == check ]]; then
  echo 'Read-only check complete. Run with --run to exercise a disposable local HTTP service.'
  exit 0
fi
if /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "BLOCKED: port $PORT is in use. Choose another with --port 18081." >&2; exit 1
fi
NAME="cd-quick-$(uuidgen | tr '[:upper:]' '[:lower:]')"
IMAGE='docker.io/library/busybox:1.37'
MARKER="$NAME-ok"
CREATED=0
OWN_IMAGE=0
SUCCESS=0
cleanup() {
  result=$?
  trap - EXIT INT TERM
  if [[ "$KEEP" == 1 && "$SUCCESS" == 1 ]]; then
    printf 'KEPT: %s\nURL: http://127.0.0.1:%s\n' "$NAME" "$PORT"
    echo 'Remove only this fixture when finished:'
    printf '%q stop -- %q\n%q delete -- %q\n' "$CLI" "$NAME" "$CLI" "$NAME"
    if [[ "$OWN_IMAGE" == 1 ]]; then printf '%q image delete -- %q\n' "$CLI" "$IMAGE"; fi
  else
    if [[ "$CREATED" == 1 ]]; then
      "$CLI" stop -- "$NAME" >/dev/null 2>&1 || true
      if ! "$CLI" delete -- "$NAME" >/dev/null; then echo "Cleanup failed: inspect $NAME" >&2; result=1; fi
    fi
    if [[ "$OWN_IMAGE" == 1 ]] && "$CLI" image inspect -- "$IMAGE" >/dev/null 2>&1; then
      if ! "$CLI" image delete -- "$IMAGE" >/dev/null; then echo "Image is retained; inspect its references: $IMAGE" >&2; result=1; fi
    fi
    [[ "$result" != 0 ]] || echo 'PASS: disposable container and newly downloaded image cleaned up'
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! "$CLI" image inspect -- "$IMAGE" >/dev/null 2>&1; then
  OWN_IMAGE=1
  "$CLI" image pull --arch arm64 --progress plain "$IMAGE"
fi
# The command is a fixed test payload, not interpolated user input.
"$CLI" create --name "$NAME" --cpus 1 --memory 256M --publish "127.0.0.1:$PORT:8080" -- "$IMAGE" /bin/sh -c 'mkdir -p /www; printf "%s" "$1" > /www/index.html; exec httpd -f -p 8080 -h /www' sh "$MARKER" >/dev/null
CREATED=1
"$CLI" start -- "$NAME" >/dev/null
check_http() {
  for ((attempt=0; attempt<30; attempt++)); do
    response="$(/usr/bin/curl --noproxy '*' --fail --silent --max-time 2 "http://127.0.0.1:$PORT/" || true)"
    [[ "$response" != "$MARKER" ]] || return 0
    sleep 1
  done
  echo "FAIL: HTTP endpoint did not return the expected fixture marker: $NAME" >&2; return 1
}
check_http
echo 'PASS: container started and loopback HTTP response verified'
actual="$("$CLI" exec -- "$NAME" /bin/cat /www/index.html)"
[[ "$actual" == "$MARKER" ]] || { echo 'FAIL: container exec/file readback' >&2; exit 1; }
"$CLI" logs -- "$NAME" >/dev/null
"$CLI" stop -- "$NAME" >/dev/null
"$CLI" start -- "$NAME" >/dev/null
check_http
echo 'PASS: exec/log access and stop/start with writable-layer file persistence'
SUCCESS=1
