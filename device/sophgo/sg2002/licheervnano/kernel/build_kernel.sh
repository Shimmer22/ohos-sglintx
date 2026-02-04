#!/bin/bash
# Copyright (c) 2025 SGLinTx. All rights reserved.

set -e

KERNEL_BUILD_SCRIPT_DIR=$1
KERNEL_SRC_TMP_DIR=$2
OUTPUT_DIR=$3
BUILD_TYPE=$4
CLANG_BASE_PATH=$5
PRODUCT_PATH=$6
DEVICE_NAME=$7
KERNEL_VERSION=$8

OHOS_ROOT_PATH=$(pwd)/../..

KERNEL_PATCH_PATH=${OHOS_ROOT_PATH}/kernel/linux/patches/${KERNEL_VERSION}
KERNEL_CONFIG_PATH=${OHOS_ROOT_PATH}/kernel/linux/config/${KERNEL_VERSION}
DEVICE_PATCH_DIR=${KERNEL_PATCH_PATH}/${DEVICE_NAME}_patch
DEVICE_PATCH_FILE=${DEVICE_PATCH_DIR}/${DEVICE_NAME}.patch
HDF_PATCH_FILE=${DEVICE_PATCH_DIR}/hdf.patch

LINUX_KERNEL_SRC_PATH=${OHOS_ROOT_PATH}/kernel/linux/${KERNEL_VERSION}
KERNEL_SRC_TMP_PATH=${KERNEL_SRC_TMP_DIR}/kernel/src_tmp/${KERNEL_VERSION}

KERNEL_ARCH=riscv
KERNEL_TARGET_TOOLCHAIN=${OHOS_ROOT_PATH}/prebuilts/gcc/linux-x86/riscv/riscv64-unknown-elf/bin
KERNEL_TARGET_TOOLCHAIN_PREFIX=${KERNEL_TARGET_TOOLCHAIN}/riscv64-unknown-elf-
CLANG_HOST_TOOLCHAIN=${CLANG_BASE_PATH}/bin
KERNEL_HOSTCC=${CLANG_HOST_TOOLCHAIN}/clang
KERNEL_PERL=/usr/bin/perl

KERNEL_CROSS_COMPILE="CC=${CLANG_HOST_TOOLCHAIN}/clang"
KERNEL_CROSS_COMPILE+=" HOSTCC=${KERNEL_HOSTCC}"
KERNEL_CROSS_COMPILE+=" PERL=${KERNEL_PERL}"
KERNEL_CROSS_COMPILE+=" CROSS_COMPILE=${KERNEL_TARGET_TOOLCHAIN_PREFIX}"

echo "==================== Build Linux Kernel ===================="
echo "KERNEL_VERSION: ${KERNEL_VERSION}"
echo "DEVICE_NAME: ${DEVICE_NAME}"
echo "BUILD_TYPE: ${BUILD_TYPE}"
echo "KERNEL_ARCH: ${KERNEL_ARCH}"
echo "KERNEL_SRC_TMP_PATH: ${KERNEL_SRC_TMP_PATH}"

export HDF_PROJECT_ROOT=${OHOS_ROOT_PATH}/
DEFCONFIG_FILE="${DEVICE_NAME}_${BUILD_TYPE}_defconfig"

echo "Cleaning and preparing kernel source..."
rm -rf ${KERNEL_SRC_TMP_PATH}
mkdir -p ${KERNEL_SRC_TMP_PATH}

echo "Copying kernel source..."
cp -arfL ${LINUX_KERNEL_SRC_PATH}/* ${KERNEL_SRC_TMP_PATH}/

echo "Applying patches..."
if [ -f "${HDF_PATCH_FILE}" ]; then
    cd ${KERNEL_SRC_TMP_PATH}
    patch -p1 < ${HDF_PATCH_FILE}
    cd - > /dev/null
else
    echo "Warning: HDF patch not found at ${HDF_PATCH_FILE}"
fi

if [ -f "${DEVICE_PATCH_FILE}" ]; then
    cd ${KERNEL_SRC_TMP_PATH}
    patch -p1 < ${DEVICE_PATCH_FILE}
    cd - > /dev/null
else
    echo "Info: Device patch not found at ${DEVICE_PATCH_FILE}"
fi

echo "Copying kernel config..."
cp -rf ${KERNEL_CONFIG_PATH}/. ${KERNEL_SRC_TMP_PATH}/ 2>/dev/null || true

echo "Building kernel..."
cd ${KERNEL_SRC_TMP_PATH}
make ARCH=${KERNEL_ARCH} ${KERNEL_CROSS_COMPILE} distclean
make ARCH=${KERNEL_ARCH} ${KERNEL_CROSS_COMPILE} ${DEFCONFIG_FILE}
make ARCH=${KERNEL_ARCH} ${KERNEL_CROSS_COMPILE} -j64 Image modules
cd - > /dev/null

KERNEL_IMAGE_FILE=${KERNEL_SRC_TMP_PATH}/arch/riscv/boot/Image
if [ -f "${KERNEL_IMAGE_FILE}" ]; then
    echo "Kernel build success: ${KERNEL_IMAGE_FILE}"
    cp ${KERNEL_IMAGE_FILE} ${OUTPUT_DIR}/Image
else
    echo "Error: Kernel build failed"
    exit 1
fi

echo "==================== Kernel Build Complete ===================="
