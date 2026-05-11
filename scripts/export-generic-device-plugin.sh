#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF='docker.io/squat/generic-device-plugin@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff'
PROXY_REF='dockerproxy.net/squat/generic-device-plugin@sha256:66c8d5c270eb2b721f1064c549b9b7898152a6d2f0163380a5d37dc7636c20ff'
IMAGE_TAG_REF='docker.io/squat/generic-device-plugin:0.2.0'
OUT_TAR="${1:-/tmp/generic-device-plugin.multiarch.oci.tar}"
COMPRESS_ZSTD="${2:-false}" # true/false

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

echo "[1/2] Export multi-arch image as OCI archive..."
skopeo copy --insecure-policy --multi-arch all \
  "docker://${PROXY_REF}" \
  "oci-archive:${OUT_TAR}:${IMAGE_TAG_REF}"

if [[ "${COMPRESS_ZSTD}" == "true" ]]; then
  echo "[2/2] Compress with zstd..."
  zstd -T0 -10 -f "${OUT_TAR}" -o "${OUT_TAR}.zst"
  echo "Done: ${OUT_TAR}.zst"
else
  echo "[2/2] Skip compression."
  echo "Done: ${OUT_TAR}"
fi
