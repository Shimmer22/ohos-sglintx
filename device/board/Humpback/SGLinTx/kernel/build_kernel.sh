#!/bin/bash
set -e

SCRIPT_DIR=${1}
OUTPUT_DIR=${2}
BOARD_DIR=${3}
PRODUCT_PATH=${4}
ROOT_DIR=${5}
DEVICE_COMPANY=${6}
DEVICE_NAME=${7}
PRODUCT_COMPANY=${8}

KERNEL_SRC_TMP_PATH=${ROOT_DIR}/out/kernel/src_tmp/linux-5.10
KERNEL_OBJ_TMP_PATH=${ROOT_DIR}/out/kernel/OBJ/linux-5.10
KERNEL_SOURCE=${ROOT_DIR}/kernel/linux/linux-5.10
KERNEL_PATCH_PATH=${ROOT_DIR}/kernel/linux/patches/linux-5.10
# SGLinTx specific patch directory (ensure this exists or use logic to check)
BOARD_PATCH_DIR=${KERNEL_PATCH_PATH}/SGLinTx_patch
KERNEL_CONFIG_FILE=${ROOT_DIR}/kernel/linux/config/linux-5.10/SGLinTx_small_defconfig

# 1. Clean and Prepare
rm -rf ${KERNEL_SRC_TMP_PATH}
mkdir -p ${KERNEL_SRC_TMP_PATH}
rm -rf ${KERNEL_OBJ_TMP_PATH}
mkdir -p ${KERNEL_OBJ_TMP_PATH}

export KBUILD_OUTPUT=${KERNEL_OBJ_TMP_PATH}

echo "Copying kernel source..."
cp -arf ${KERNEL_SOURCE}/* ${KERNEL_SRC_TMP_PATH}/

cd ${KERNEL_SRC_TMP_PATH}

# 2. HDF Patch
echo "Applying HDF patch..."
bash ${ROOT_DIR}/drivers/hdf_core/adapter/khdf/linux/patch_hdf.sh ${ROOT_DIR} ${KERNEL_SRC_TMP_PATH} ${KERNEL_PATCH_PATH} ${DEVICE_NAME}

# 3. Board Patch (Optional)
if [ -d "${BOARD_PATCH_DIR}" ]; then
    echo "Applying Board patches from ${BOARD_PATCH_DIR}..."
    for patch in ${BOARD_PATCH_DIR}/*.patch; do
        if [ -f "$patch" ]; then
            patch -p1 < "$patch"
        fi
    done
fi

# 4. Config
echo "Configuring kernel..."
# Copy defconfig to arch/riscv/configs/ to be safe
mkdir -p arch/riscv/configs
cp ${KERNEL_CONFIG_FILE} arch/riscv/configs/sglintx_defconfig

# Use LLVM toolchain from OHOS prebuilts
CLANG_BASE=${ROOT_DIR}/prebuilts/clang/ohos/linux-x86_64/llvm
export PATH=${CLANG_BASE}/bin:$PATH

# Make defconfig
make ARCH=riscv LLVM=1 LLVM_IAS=1 O=${KERNEL_OBJ_TMP_PATH} sglintx_defconfig

# 5. Build
echo "Building Image..."
make ARCH=riscv LLVM=1 LLVM_IAS=1 O=${KERNEL_OBJ_TMP_PATH} -j$(nproc) Image dtbs

# 6. Install
mkdir -p ${OUTPUT_DIR}
cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/Image ${OUTPUT_DIR}/Image
# Copy DTB if needed, assume single dtb or copy all
cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/sophgo/*.dtb ${OUTPUT_DIR}/ || echo "No DTB found in sophgo, checking dts/"
# Check common locations
if ls ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/*.dtb 1> /dev/null 2>&1; then
    cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/*.dtb ${OUTPUT_DIR}/
fi

echo "Kernel build finished. Output: ${OUTPUT_DIR}/Image"
