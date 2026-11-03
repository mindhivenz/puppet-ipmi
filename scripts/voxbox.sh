#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

readonly image=$(sed -n 's/^  VOXBOX_IMAGE: //p' .github/workflows/ci.yml)

# Private mindhivenz fixtures are cloned with your gh token, as CI does with its App token
exec docker run --rm -v "$PWD:/repo" -e SPEC \
  -e GIT_CONFIG_COUNT=1 \
  -e GIT_CONFIG_KEY_0="url.https://x-access-token:$(gh auth token)@github.com/mindhivenz/.insteadOf" \
  -e GIT_CONFIG_VALUE_0=https://github.com/mindhivenz/ \
  "$image" "$@"
