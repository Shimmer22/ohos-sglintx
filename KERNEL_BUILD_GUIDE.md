# SG2002 Linux内核构建指南

## 概述

使用混合模式构建OpenHarmony内核：
- 基于LicheeRV-Nano-Build SDK的Linux 5.10源码
- 添加OpenHarmony必需配置（主要是Android Binder）
- 使用SDK自带的GCC工具链

### ✅ 编译成功验证

**时间**: 2026-02-05  
**内核版本**: Linux 5.10.4  
**镜像大小**: 9.2MB  
**输出位置**: `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image`

**关键配置已启用**:
```
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_SQUASHFS=y
CONFIG_DEBUG_FS=y
```

## 快速构建（一键命令）

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

**输出**:
- 内核镜像: `/home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image` (9.2MB)

## 关键发现

### 1. OH对内核的特殊要求

OpenHarmony 3.0 LTS（标准系统）只需要：

```
CONFIG_ANDROID=y                    # 已存在
CONFIG_ANDROID_BINDER_IPC=y         # SDK缺失！
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
```

**不需要**HDF补丁（OH 3.0 LTS内核不包含hilog/hievent驱动）。

### 2. 构建方式

参考Allwinner D1的方式：
- 不修改内核源码
- 只修改内核配置（.config）
- 添加OH必需的Android Binder支持

## 构建步骤

### 方法一：命令行直接构建

```bash
# 1. 进入OpenHarmony目录
cd /home/openharmony

# 2. 设置工具链环境
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN_PREFIX/gcc

# 3. 准备内核源码
export KERNEL_SRC_TMP_PATH=/home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10
mkdir -p $KERNEL_SRC_TMP_PATH
cp -arfL /home/openharmony/kernel/linux_5.10/* $KERNEL_SRC_TMP_PATH/

# 4. 复制SDK配置并添加OH补丁
cp $LICHEERV_SDK_PATH/linux_5.10/.config \
   $KERNEL_SRC_TMP_PATH/arch/riscv/configs/sg2002_nano_defconfig

# 5. 应用OH配置补丁
cat /home/openharmony/kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch \
    >> $KERNEL_SRC_TMP_PATH/arch/riscv/configs/sg2002_nano_defconfig

# 6. 编译内核
cd $KERNEL_SRC_TMP_PATH
make ARCH=riscv CROSS_COMPILE=$KERNEL_TARGET_TOOLCHAIN_PREFIX \
     CC=$GNU_CC sg2002_nano_defconfig

make ARCH=riscv CROSS_COMPILE=$KERNEL_TARGET_TOOLCHAIN_PREFIX \
     CC=$GNU_CC -j$(nproc) Image dtbs

# 7. 输出文件
# $KERNEL_SRC_TMP_PATH/arch/riscv/boot/Image
```

### 方法二：使用Makefile

```bash
# 使用kernel-5.10.mk
cd /home/openharmony/kernel/linux/patches

export TARGET_PRODUCT=sg2002_nano
export OUT_DIR=/home/openharmony/out/KERNEL_OBJ
export OHOS_ROOT_PATH=/home/openharmony
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN_PREFIX/gcc
export KERNEL_ARCH=riscv

make -f kernel-5.10.mk
```

### 方法三：完整OH构建（包括内核）

```bash
# 构建OH用户态 + 内核
cd /home/openharmony
./build.sh --product-name sg2002_nano --ccache

# 注意：需要确保内核action被正确添加到构建系统
```

## 配置补丁说明

**文件**: `kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch`

**关键修改**:
```bash
# Android Binder (必需)
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"

# BPF (推荐)
CONFIG_BPF_SYSCALL=y

# 文件系统支持
CONFIG_SQUASHFS_FILE_DIRECT=y
CONFIG_SQUASHFS_XATTR=y
CONFIG_SQUASHFS_ZLIB=y
CONFIG_SQUASHFS_LZO=y
CONFIG_SQUASHFS_LZ4=y
CONFIG_SQUASHFS_ZSTD=y

# Debug支持
CONFIG_DEBUG_FS=y

# 容器支持 (cgroup和namespace)
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_PIDS=y
CONFIG_MEMCG=y
CONFIG_NAMESPACES=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_NET_NS=y

# 安全
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_SECURITY=y
CONFIG_SECURITYFS=y
```

## 输出文件

构建完成后生成：

```
out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image
```

文件大小约：9-10MB

## 验证内核

```bash
# 检查内核镜像
file out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image

# 检查配置
zgrep CONFIG_ANDROID_BINDER_IPC out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/.config
```

## 注意事项

1. **不要修改SDK内核源码**：保持LicheeRV-Nano-Build/linux_5.10不变
2. **使用GCC而非Clang**：内核使用SDK的GCC 10.2.0
3. **配置追加方式**：将OH配置追加到SDK默认配置
4. **工具链路径**：`LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/bin/`

## 下一步

内核构建完成后：
1. 打包boot.img（内核 + ramdisk）
2. 打包完整固件
3. 烧录测试

## 参考

- D1参考: `device/sunxi/config/chips/d1/configs/nezha/linux-5.4/config-5.4`
- SDK: `LicheeRV-Nano-Build/linux_5.10/`
- 移植文档: `reference/移植方法.md`
