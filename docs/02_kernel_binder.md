# 内核与 Binder 说明

本文档聚焦 Linux 5.10 构建路径与 Binder 关键配置，目标是避免重复踩坑。

## 1. 构建命令

```bash
cd /home/openharmony/kernel/linux/patches
export TARGET_PRODUCT=sg2002_nano
export OUT_DIR=/home/openharmony/out/KERNEL_OBJ
export OHOS_ROOT_PATH=/home/openharmony
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-gcc
make -f kernel-5.10.mk
```

产物：

- `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image`

## 2. Binder 目标配置（对齐 D1 传统模式）

必须满足：

- `CONFIG_ANDROID=y`
- `CONFIG_ANDROID_BINDER_IPC=y`
- `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
- `# CONFIG_ANDROID_BINDERFS is not set`

## 3. 防回写机制

`kernel/linux/patches/kernel-5.10.mk` 在 `defconfig` 后会：

- 删除旧 Binder 相关行。
- 追加目标配置。
- 执行 `olddefconfig`。

该机制用于防止 Kconfig 依赖把 Binder 选项回写到不期望状态。

## 4. 每次构建后必检

```bash
grep -E '^CONFIG_ANDROID=|^CONFIG_ANDROID_BINDER_IPC=|^CONFIG_ANDROID_BINDER_DEVICES=|^CONFIG_ANDROID_BINDERFS=|^# CONFIG_ANDROID_BINDERFS is not set' \
  /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/.config
```

未通过检查时，不应继续打包与烧录。

