#!/bin/bash
set -e

# Configuration
export OHOS_ROOT=/home/openharmony
export KERNEL_SRC=$OHOS_ROOT/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10
export LICHEERV_SDK_PATH=$OHOS_ROOT/LicheeRV-Nano-Build

# Toolchain setup (Same as kernel build)
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN_PREFIX/gcc

# AIC8800 Driver Source
DRIVER_SRC=$LICHEERV_SDK_PATH/osdrv/extdrv/wireless/aic8800
OUTPUT_DIR=$OHOS_ROOT/out/aic8800_modules

mkdir -p $OUTPUT_DIR

echo "Preparing kernel for module build..."
make -C $KERNEL_SRC ARCH=riscv CROSS_COMPILE=$KERNEL_TARGET_TOOLCHAIN_PREFIX modules_prepare

echo "Building aic8800_bsp..."
make -C $KERNEL_SRC M=$DRIVER_SRC/aic8800_bsp \
    ARCH=riscv CROSS_COMPILE=$KERNEL_TARGET_TOOLCHAIN_PREFIX \
    CONFIG_AIC8800_BSP_SUPPORT=m modules

echo "Building aic8800_fdrv..."
# Need to ensure aic8800_bsp symbols are available? usually not needed for compilation if not exported via Module.symvers, checking...
# Actually aic8800_fdrv depends on aic8800_bsp, so might need KBUILD_EXTRA_SYMBOLS
make -C $KERNEL_SRC M=$DRIVER_SRC/aic8800_fdrv \
    ARCH=riscv CROSS_COMPILE=$KERNEL_TARGET_TOOLCHAIN_PREFIX \
    CONFIG_AIC8800_WLAN_SUPPORT=m \
    KBUILD_EXTRA_SYMBOLS=$DRIVER_SRC/aic8800_bsp/Module.symvers \
    modules

echo "Build complete. Copying modules..."
cp $DRIVER_SRC/aic8800_bsp/aic8800_bsp.ko $OUTPUT_DIR/
cp $DRIVER_SRC/aic8800_fdrv/aic8800_fdrv.ko $OUTPUT_DIR/

echo "Modules available at $OUTPUT_DIR"
