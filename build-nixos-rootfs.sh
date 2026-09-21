#!/usr/bin/env bash

# ---
# Module: Build RootFS Script
# Description: Wrapper script to build NixOS root filesystem
# Scope: Script
# ---
set -euo pipefail

IMAGE_SIZE="${IMAGE_SIZE:-auto}"
ROOTFS_FLAKE_ATTR="${ROOTFS_FLAKE_ATTR:-mobileRootfsImage}"
FILESYSTEM_UUID="${FILESYSTEM_UUID:-ee8d3593-59b1-480e-a3b6-4fefb17ee7d8}"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
OUT_DIR="${OUT_DIR:-out}"
OUT_LINK="${OUT_DIR}/nixos-sheng-${ROOTFS_FLAKE_ATTR}"
if [ -n "${NIX_BUILD_FLAGS:-}" ]; then
    read -r -a NIX_BUILD_FLAGS_ARRAY <<< "${NIX_BUILD_FLAGS}"
else
    NIX_BUILD_FLAGS_ARRAY=(--fallback)
fi

if [ -n "${ROOTFS_BACKEND:-}" ] && [ "${ROOTFS_BACKEND}" != "mobile" ]; then
    echo "ROOTFS_BACKEND=${ROOTFS_BACKEND} is no longer supported."
    echo "This project now flashes the Mobile NixOS generated rootfs image."
    exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
    echo "nix is required. Install Nix with flakes enabled first."
    exit 1
fi

mkdir -p "${OUT_DIR}"

case "${ROOTFS_FLAKE_ATTR}" in
    mobileRootfsImage)
        ROOTFS_VARIANT="minimal"
        ;;
    mobileRootfsImageGnome)
        ROOTFS_VARIANT="gnome"
        ;;
    mobileRootfsImageNiri)
        ROOTFS_VARIANT="niri"
        ;;
    *)
        echo "Unsupported ROOTFS_FLAKE_ATTR=${ROOTFS_FLAKE_ATTR}"
        echo "Supported values: mobileRootfsImage, mobileRootfsImageGnome, mobileRootfsImageNiri"
        exit 1
        ;;
esac

ROOTFS_IMG="nixos-sheng-${ROOTFS_VARIANT}-${TIMESTAMP}.img"

echo "==> Building Mobile NixOS generated rootfs image: ${ROOTFS_FLAKE_ATTR}"
nix --extra-experimental-features "nix-command flakes" \
    build "./nixos#${ROOTFS_FLAKE_ATTR}" \
    --out-link "${OUT_LINK}" \
    "${NIX_BUILD_FLAGS_ARRAY[@]}"

ROOTFS_DIR="$(readlink -f "${OUT_LINK}")"
ROOTFS_SOURCE="$(
    find "${ROOTFS_DIR}" -type f \( -name "rootfs.img" -o -name "rootfs.img.zst" \) | head -n 1
)"

if [ -z "${ROOTFS_SOURCE}" ] || [ ! -f "${ROOTFS_SOURCE}" ]; then
    echo "Could not find rootfs.img or rootfs.img.zst in ${ROOTFS_DIR}"
    exit 1
fi

echo "==> Copying rootfs image to ${OUT_DIR}/${ROOTFS_IMG}"
case "${ROOTFS_SOURCE}" in
    *.zst)
        if ! command -v zstd >/dev/null 2>&1; then
            echo "zstd is required to decompress ${ROOTFS_SOURCE}"
            exit 1
        fi
        zstd -dc "${ROOTFS_SOURCE}" > "${OUT_DIR}/${ROOTFS_IMG}"
        ;;
    *)
        cp "${ROOTFS_SOURCE}" "${OUT_DIR}/${ROOTFS_IMG}"
        ;;
esac

chmod +w "${OUT_DIR}/${ROOTFS_IMG}"

if [ "${IMAGE_SIZE}" != "auto" ]; then
    echo "==> Resizing rootfs image to ${IMAGE_SIZE}"
    e2fsck -fy "${OUT_DIR}/${ROOTFS_IMG}"
    truncate -s "${IMAGE_SIZE}" "${OUT_DIR}/${ROOTFS_IMG}"
    resize2fs "${OUT_DIR}/${ROOTFS_IMG}"
fi

echo "==> Setting rootfs UUID ${FILESYSTEM_UUID}"
tune2fs -U "${FILESYSTEM_UUID}" "${OUT_DIR}/${ROOTFS_IMG}" >/dev/null

echo "==> Verifying rootfs integrity"
e2fsck -fn "${OUT_DIR}/${ROOTFS_IMG}"

features="$(dumpe2fs -h "${OUT_DIR}/${ROOTFS_IMG}" 2>/dev/null | awk -F: '/Filesystem features/ { print $2 }')"
echo "Filesystem features:${features}"
for feature in metadata_csum 64bit dir_index; do
    grep -qw "$feature" <<<"$features" || {
        echo "ERROR: rootfs is missing required ext4 feature: $feature" >&2
        exit 1
    }
done

if ! command -v img2simg >/dev/null 2>&1; then
    echo "ERROR: img2simg is required to produce a fastboot-flashable sparse image" >&2
    echo "Install android-tools-fsutils (or android-tools) and retry." >&2
    exit 1
fi

echo "==> Converting raw ext4 image to Android sparse image for fastboot"
RAW_IMG="${OUT_DIR}/${ROOTFS_IMG}.raw"
mv "${OUT_DIR}/${ROOTFS_IMG}" "${RAW_IMG}"
img2simg "${RAW_IMG}" "${OUT_DIR}/${ROOTFS_IMG}"
rm -f "${RAW_IMG}"

echo "Done: ${OUT_DIR}/${ROOTFS_IMG}"
echo "Note: a Mobile NixOS rootfs is expected to contain nix/store and nix-path-registration."
echo "The output .img is in Android sparse format and can be flashed directly with fastboot."
