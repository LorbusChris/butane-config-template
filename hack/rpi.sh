#!/bin/bash
set -euo pipefail

if [[ $OS_ARCH != "aarch64" ]]; then
    echo "OS_ARCH is not aarch64"
    exit 1
fi

RPI_FW_VERSION=v1.32  # use latest one from https://github.com/pftf/RPi4/releases

OS_EFI_PARTITION=$(lsblk $OS_DISK -J -oLABEL,PATH  | jq -r '.blockdevices[] | select(.label == "EFI-SYSTEM")'.path)

if [[ -z $OS_EFI_PARTITION ]]; then
  echo "No EFI partition found"
  exit 1
fi

TMP_DIR=$(mktemp -d)

if [[ ! $TMP_DIR || ! -d $TMP_DIR ]]; then
  echo "Could not create temp dir"
  exit 1
fi

mount $OS_EFI_PARTITION $TMP_DIR
pushd $TMP_DIR
curl -LO https://github.com/pftf/RPi4/releases/download/${RPI_FW_VERSION}/RPi4_UEFI_Firmware_${RPI_FW_VERSION}.zip
unzip RPi4_UEFI_Firmware_${RPI_FW_VERSION}.zip
rm RPi4_UEFI_Firmware_${RPI_FW_VERSION}.zip
popd
umount $TMP_DIR
