#!/usr/bin/env bash
# Build (and optionally push) the isannai/llama image.
#
# Usage:
#   ./build.sh                          # build only
#   ./build.sh --push                   # build + push
#   LLAMA_REF=b3000 ./build.sh          # pin llama.cpp version (tag/branch/commit)
#   IMAGE_TAG=v0.1.0 ./build.sh         # custom image tag
#   CUDA_ARCHS=86 ./build.sh            # build for single CUDA arch (faster)
#
# Can be run from anywhere — uses its own location to find the Dockerfile.

set -euo pipefail

# --- Locate self --------------------------------------------------------------
# Script lives in engines/llama/scripts/. Engine dir (with Dockerfile,
# .env, docker-compose.yml) is the parent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Config (env overridable) -------------------------------------------------
IMAGE_NAME="${IMAGE_NAME:-isannai/llama}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
LLAMA_REF="${LLAMA_REF:-master}"
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
echo "    llama.cpp ref: ${LLAMA_REF}"
echo "    dockerfile:    ${DOCKERFILE}"
echo

BUILD_ARGS=(--build-arg "LLAMA_REF=${LLAMA_REF}")
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
