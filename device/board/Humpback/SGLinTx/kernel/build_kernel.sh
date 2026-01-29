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
KERNEL_SOURCE=${ROOT_DIR}/lichee_sdk/linux_5.10
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

# --- Fix broken DTS symlinks (Absolute paths from SDK are invalid) ---
echo "Fixing DTS symlinks..."
DTS_CVITEK_DIR=arch/riscv/boot/dts/cvitek
SDK_BUILD_DIR=${ROOT_DIR}/lichee_sdk/build

# 1. Copy common dtsi files
if [ -d "${SDK_BUILD_DIR}/boards/default/dts/sg200x" ]; then
    # Delete broken symlinks first (cp fails otherwise)
    find ${DTS_CVITEK_DIR} -type l -name "soph_*.dtsi" -delete
    cp -f ${SDK_BUILD_DIR}/boards/default/dts/sg200x/soph_*.dtsi ${DTS_CVITEK_DIR}/
fi

# 2. Copy the specific board DTS we need
TARGET_DTS_SRC=${SDK_BUILD_DIR}/boards/sg200x/sg2002_licheervnano_sd/dts_riscv/sg2002_licheervnano_sd.dts
if [ -f "${TARGET_DTS_SRC}" ]; then
    # Delete broken symlink first
    rm -f ${DTS_CVITEK_DIR}/sg2002_licheervnano_sd.dts
    cp -f ${TARGET_DTS_SRC} ${DTS_CVITEK_DIR}/
else
    echo "Error: Could not find source DTS: ${TARGET_DTS_SRC}"
    exit 1
fi

# 2.1 Copy required header for DTS
HEADER_SRC=${ROOT_DIR}/lichee_sdk/linux_5.10/scripts/dtc/include-prefixes/cvi_board_memmap.h
# Fallback location
if [ ! -f "${HEADER_SRC}" ]; then
    HEADER_SRC=${ROOT_DIR}/lichee_sdk/u-boot-2021.10/include/cvi_board_memmap.h
fi

if [ -f "${HEADER_SRC}" ]; then
    cp -f ${HEADER_SRC} ${DTS_CVITEK_DIR}/
    # Also copy to standard include paths where DTC looks
    mkdir -p scripts/dtc/include-prefixes
    rm -f scripts/dtc/include-prefixes/cvi_board_memmap.h
    cp -f ${HEADER_SRC} scripts/dtc/include-prefixes/
    cp -f ${HEADER_SRC} include/
    # Also copy to parent dts directory as fallback
    cp -f ${HEADER_SRC} arch/riscv/boot/dts/
else
     echo "Error: cvi_board_memmap.h not found!"
fi

# 3. Remove other broken symlinks to prevent build errors
# (The makefile builds all *.dts it finds)
find ${DTS_CVITEK_DIR} -type l -name "*.dts" -delete

# 4. Remove incompatible DTS (thead/ice.dts causes DTC warning treated as error)
# and remove it from Makefile to prevent "No rule to make target" error
rm -rf arch/riscv/boot/dts/thead
sed -i '/subdir-y += thead/d' arch/riscv/boot/dts/Makefile

# 5. Remove GCC-specific flag -mno-ldd not supported by Clang
sed -i 's/-mno-ldd//g' arch/riscv/Makefile

# 6. Inject --target=riscv64-linux-ohos for Clang C Compiler
sed -i 's/KBUILD_CFLAGS += -mabi=lp64/KBUILD_CFLAGS += --target=riscv64-linux-ohos -mabi=lp64/g' arch/riscv/Makefile
sed -i 's/KBUILD_AFLAGS += -mabi=lp64/KBUILD_AFLAGS += --target=riscv64-linux-ohos -mabi=lp64/g' arch/riscv/Makefile

# 8. Replace v0p7 with v (Clang accepts v with experimental, GCC-10 interprets v as v0.7)
sed -i 's/v0p7/v/g' arch/riscv/Makefile

# 9. Disable linker relaxation (Use -Wa,-mno-relax to ensure it enters Assembler)
sed -i 's/KBUILD_CFLAGS += -mabi=lp64/KBUILD_CFLAGS += -Wa,-mno-relax -mabi=lp64/g' arch/riscv/Makefile
sed -i 's/KBUILD_AFLAGS += -mabi=lp64/KBUILD_AFLAGS += -Wa,-mno-relax -mabi=lp64/g' arch/riscv/Makefile

# 10. Force disable linker relaxation in VDSO Makefile (Critical for ld.lld)
sed -i 's/ccflags-y := -fno-stack-protector/ccflags-y := -fno-stack-protector -Wa,-mno-relax/g' arch/riscv/kernel/vdso/Makefile
# asflags-y doesn't exist, so append it
echo "asflags-y += -Wa,-mno-relax" >> arch/riscv/kernel/vdso/Makefile
# -------------------------------------------------------------------
# -------------------------------------------------------------------
# -------------------------------------------------------------------

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

# Use LLVM toolchain from OHOS prebuilts for C
CLANG_BASE=${ROOT_DIR}/prebuilts/clang/ohos/linux-x86_64/llvm
export PATH=${CLANG_BASE}/bin:$PATH

# Use SDK Toolchain for Assembler (LLVM_IAS=0) to support v0.7 vector and legacy syntax
export CROSS_COMPILE=${ROOT_DIR}/lichee_sdk/host-tools/gcc/riscv64-linux-x86_64/bin/riscv64-unknown-linux-gnu-

# Make defconfig
# Use LLVM_IAS=0 to force using external GAS assembler
make ARCH=riscv LLVM=1 LLVM_IAS=0 O=${KERNEL_OBJ_TMP_PATH} sglintx_defconfig

# 5. Build
echo "Building Image..."
make ARCH=riscv LLVM=1 LLVM_IAS=0 O=${KERNEL_OBJ_TMP_PATH} -j$(nproc) Image dtbs

# 6. Install
mkdir -p ${OUTPUT_DIR}
cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/Image ${OUTPUT_DIR}/Image
# Copy DTB if needed, assume single dtb or copy all
cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/cvitek/*.dtb ${OUTPUT_DIR}/ || echo "No DTB found in cvitek, checking dts/"
# Check common locations
if ls ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/*.dtb 1> /dev/null 2>&1; then
    cp ${KERNEL_OBJ_TMP_PATH}/arch/riscv/boot/dts/*.dtb ${OUTPUT_DIR}/
fi

echo "Kernel build finished. Output: ${OUTPUT_DIR}/Image"
