#!/bin/bash
#
# Copyright (C) 2018-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE_COMMON=sdm660-common
VENDOR=asus

# Check host-OS before doing anything
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM='linux-x86'
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM='darwin-x86'
fi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

LINEAGE_ROOT="${MY_DIR}"/../../..

HELPER="${LINEAGE_ROOT}/vendor/lineage/build/tools/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Use prebuilts from tools-lineage
TOOLS_LINEAGE="$LINEAGE_ROOT"/prebuilts/tools-lineage/"$PLATFORM"/bin
PATCHELF="$TOOLS_LINEAGE"/patchelf

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

SECTION=
KANG=
ONLY_COMMON=
ONLY_DEVICE=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -o | --only-common )
                ONLY_COMMON=false
                ;;
        -d | --only-device )
                ONLY_DEVICE=false
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in

    # remove android.hidl.base dependency
    lib64/libfm-hci.so | lib64/libwfdnative.so | lib/libfm-hci.so | lib/libwfdnative.so)
        "$PATCHELF" --remove-needed "android.hidl.base@1.0.so" "${2}"
        ;;

    product/lib64/libdpmframework.so)
        "$PATCHELF" --replace-needed "libcutils.so" "libcutils-v29.so" "${2}"
        "$PATCHELF" --add-needed "libcutils.so" "${2}"
        ;;
    esac
}

# Initialize the helper for common device
setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${LINEAGE_ROOT}" true "${CLEAN_VENDOR}"

if [ -z "${ONLY_DEVICE}" ] && [ -s "${MY_DIR}/proprietary-files.txt" ]; then
extract "${MY_DIR}/proprietary-files.txt" "${SRC}" \
        "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${LINEAGE_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" \
            "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
