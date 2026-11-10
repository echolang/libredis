#!/usr/bin/env bash
#
# Run the live tests against a throwaway Redis in Docker.
#
#   scripts/test-live.sh                         # redis:7
#   IMAGE=redis:6.2.6 scripts/test-live.sh
#   scripts/test-live.sh --filter live           # extra echoc test arguments
#
# The server has a password for the default user (REDIS_ROOT_URL) and an ACL user `app`
# (REDIS_TEST_URL), see scripts/server.sh.

set -euo pipefail

IMAGE=${IMAGE:-redis:7}
NAME=libredis-live-$$
PORT=${PORT:-$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')}

cd "$(dirname "$0")/.."
source scripts/server.sh
start_server "$NAME" "$IMAGE" "$PORT"
# -v: the server's data volume goes with it, or every run leaves one behind
trap 'docker rm -f -v "$NAME" >/dev/null 2>&1 || true' EXIT

export REDIS_TEST_URL="redis://app:secret@127.0.0.1:$PORT"
export REDIS_ROOT_URL="redis://:rootpw@127.0.0.1:$PORT"
echoc test --define redis --timeout 120000 "$@"
