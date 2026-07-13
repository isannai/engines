#!/usr/bin/env bash
# Build (and optionally push) the isannai/sd image.
#
# Usage:
#   ./deploy/engines/sd/build.sh                    # build only
#   ./deploy/engines/sd/build.sh --push             # build + push
#   SDCPP_REF=v1.0.0 ./deploy/engines/sd/build.sh   # pin sd.cpp version
#   IMAGE_TAG=v0.1.0 ./deploy/engines/sd/build.sh   # custom image tag
#
# Can be run from anywhere -uses its own location to find the Dockerfile.

set -euo pipefail

# --- Locate self --------------------------------------------------------------
# Script lives in deploy/engines/sd/scripts/. Engine dir (with Dockerfile,
# .env.example, docker-compose.yml) is the parent. Going up one level is
# what build cares about — the Dockerfile / context live there, not next
# to this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Config (env overridable) -------------------------------------------------
IMAGE_NAME="${IMAGE_NAME:-isannai/sd}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
SDCPP_REF="${SDCPP_REF:-dd75372}"
DOCKERFILE="${DOCKERFILE:-${ENGINE_DIR}/Dockerfile}"
BUILD_CONTEXT="${BUILD_CONTEXT:-${ENGINE_DIR}}"

PUSH=0
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "==> Building ${IMAGE}"
echo "    sd.cpp ref: ${SDCPP_REF}"
echo "    dockerfile: ${DOCKERFILE}"
echo

BUILD_ARGS=(--build-arg "SDCPP_REF=${SDCPP_REF}")
if [ -n "${CUDA_ARCHS:-}" ]; then
  BUILD_ARGS+=(--build-arg "CUDA_ARCHS=${CUDA_ARCHS}")
fi

docker build \
  "${BUILD_ARGS[@]}" \
  -t "${IMAGE}" \
  -f "${DOCKERFILE}" \
  "${BUILD_CONTEXT}"

echo
echo "==> Build done: ${IMAGE}"

if [ "${PUSH}" -eq 1 ]; then
  echo "==> Pushing ${IMAGE}"
  docker push "${IMAGE}"
  echo "==> Push done"
fi
