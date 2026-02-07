#!/bin/bash
set -e

# Setup environment
export OHOS_ROOT_PATH=/home/openharmony
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_SRC_TMP=/home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10

# Helper for cross-compile
export ARCH=riscv
export CROSS_COMPILE=${LICHEERV_SDK_PATH}/host-tools/gcc/riscv64-linux-x86_64/bin/riscv64-unknown-linux-gnu-

echo "Cleaning previous build artifacts..."
rm -f ${KERNEL_SRC_TMP}/arch/riscv/boot/Image

echo "Running make sg2002_nano_defconfig in kernel source..."
cd ${KERNEL_SRC_TMP}
make ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE sg2002_nano_defconfig

echo "Patching .config manually to enforce D1-compatible Binder/Ashmem..."
CONFIG_FILE=${KERNEL_SRC_TMP}/.config

# Force enable Staging (dependency for Android)
sed -i '/CONFIG_STAGING/d' $CONFIG_FILE
echo "CONFIG_STAGING=y" >> $CONFIG_FILE

# Force enable Android (dependency for Ashmem)
sed -i '/CONFIG_ANDROID/d' $CONFIG_FILE
echo "CONFIG_ANDROID=y" >> $CONFIG_FILE

# Force enable Ashmem
sed -i '/CONFIG_ASHMEM/d' $CONFIG_FILE
echo "CONFIG_ASHMEM=y" >> $CONFIG_FILE

# Force Binder IPC
sed -i '/CONFIG_ANDROID_BINDER_IPC/d' $CONFIG_FILE
echo "CONFIG_ANDROID_BINDER_IPC=y" >> $CONFIG_FILE

# Force Binder Devices
sed -i '/CONFIG_ANDROID_BINDER_DEVICES/d' $CONFIG_FILE
echo 'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"' >> $CONFIG_FILE

# Force DISABLE BinderFS (Legacy Mode)
sed -i '/CONFIG_ANDROID_BINDERFS/d' $CONFIG_FILE
echo "# CONFIG_ANDROID_BINDERFS is not set" >> $CONFIG_FILE

# Force Wi-Fi support to built-in
sed -i 's/CONFIG_CFG80211=m/CONFIG_CFG80211=y/' $CONFIG_FILE
sed -i 's/# CONFIG_CFG80211 is not set/CONFIG_CFG80211=y/' $CONFIG_FILE
sed -i 's/CONFIG_RFKILL=m/CONFIG_RFKILL=y/' $CONFIG_FILE
sed -i 's/# CONFIG_RFKILL is not set/CONFIG_RFKILL=y/' $CONFIG_FILE

echo "Configuration patching complete. Verifying..."
grep -E "CONFIG_ASHMEM|CONFIG_ANDROID_BINDER" $CONFIG_FILE

echo "Running make olddefconfig to resolve dependencies..."
make ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE olddefconfig

echo "Verifying again after olddefconfig..."
grep -E "CONFIG_ASHMEM|CONFIG_ANDROID_BINDER" $CONFIG_FILE

echo "Starting Kernel Build..."
make ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) Image dtbs

echo "Build complete."
