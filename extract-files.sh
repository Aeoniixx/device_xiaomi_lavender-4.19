#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

export DEVICE=lavender
export VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export TARGET_ENABLE_CHECKELF=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
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
        vendor/etc/sensors/hals.conf)
            sed -i '/sensors.elliptic.so/d' "${2}"
            ;;
        vendor/lib/lib_lowlight.so)
            "${PATCHELF}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;
        vendor/lib64/libwvhidl.so) 
            [ "$2" = "" ] && return 0 
            grep -q "libcrypto_shim.so" "${2}" || "${PATCHELF}" --add-needed "libcrypto_shim.so" "${2}"
            ;;
        vendor/lib64/libvendor.goodix.hardware.interfaces.biometrics.fingerprint@2.1.so)
            "${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${2}"
	    ;;
	vendor/lib/libts_face_beautify_hal.so)
            "${PATCHELF}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;  
	vendor/lib/libts_detected_face_hal.so)
            "${PATCHELF}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${2}"
            ;;  
	vendor/lib/libmmcamera_faceproc.so)
            [ "$2" = "" ] && return 0
           "${PATCHELF}" --clear-symbol-version "__aeabi_memcpy" "${2}"
           "${PATCHELF}" --clear-symbol-version "__aeabi_memset" "${2}"
           "${PATCHELF}" --clear-symbol-version "__gnu_Unwind_Find_exidx" "${2}"
            ;;
        vendor/lib64/hw/consumerir.default.so)
            [ "$2" = "" ] && return 0
           "${PATCHELF}" --set-soname "consumerir.lirc.sdm660.so" "consumerir.default.so" "${2}"
            ;;
        vendor/lib64/hw/consumerir.default.so)
            [ "$2" = "" ] && return 0
           "${PATCHELF}" --set-soname "consumerir.spi.sdm660.so" "consumerir.default.so" "${2}"
            ;;
	system_ext/lib64/libqxrsplitauxservice.qti.so)
            [ "$2" = "" ] && return 0
           "${PATCHELF}" --replace-needed "android.media.audio.common.types-V3-cpp.so" "android.media.audio.common.types-V4-cpp.so" "${2}"
           "${PATCHELF}" --add-needed "libaudioclient_shim.so" "${2}"
            ;;
    esac
}


# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
