# SG2002 OpenHarmony 固件打包指南

## 概述

本文档说明如何将OpenHarmony构建产物和Linux内核打包成可烧录的固件。

## 前提条件

### 1. 编译完成

确保以下组件已编译完成：

```bash
# 1. OpenHarmony用户态系统
./build.sh --product-name sg2002_nano --ccache
# 输出: out/ohos-riscv64-release/packages/phone/{root,system,vendor}

# 2. Linux内核
cd kernel/linux/patches
export TARGET_PRODUCT=sg2002_nano
export OUT_DIR=/home/openharmony/out/KERNEL_OBJ
export OHOS_ROOT_PATH=/home/openharmony
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-gcc
make -f kernel-5.10.mk
# 输出: out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image
```

### 2. Docker 环境构建 (可选)

如果是在 WSL 或其他非标准 Linux 环境下，建议使用 Docker 进行构建。

```bash
# 1. 启动 Docker 容器 (假设镜像名为 ohos-build)
docker run -it -v $(pwd):/home/openharmony -w /home/openharmony ohos_build_env bash

# 2. 在容器内执行构建命令
./build.sh --product-name sg2002_nano --ccache

# 3. 如果需要修改文件但容器内没有编辑器
# 可以将文件复制到 /tmp 进行编辑，然后复制回源码目录
# 或者在宿主机编辑，因为目录是挂载的
```

## 打包脚本

### 基本用法

```bash
# 使用默认配置打包
cd /home/openharmony
./device/sophgo/build/pack

# 使用squashfs根文件系统
./device/sophgo/build/pack -t squashfs

# 指定输出目录
./device/sophgo/build/pack -o /path/to/output

# 使用自定义内核
./device/sophgo/build/pack -k /path/to/Image -d /path/to/dtb

# 显示帮助
./device/sophgo/build/pack -h
```

### 输出文件

打包完成后，在 `out/licheerv_nano/` 目录下生成：

| 文件 | 说明 | 大小 |
|------|------|------|
| `Image` | Linux内核镜像 | ~9MB |
| `boot.img` | 启动镜像（内核+ramdisk） | ~10MB |
| `rootfs.img` | 根文件系统（ext4/squashfs） | ~400MB |
| `ramdisk.img` | 初始ramdisk | ~1MB |
| `sg2002_licheerv_nano.img` | 完整SD卡镜像（root时） | ~500MB |
| `flash.sh` | 烧录脚本 | - |

## 烧录方法

### 方法1: 使用完整镜像（推荐）

如果使用root权限运行打包脚本：

```bash
# 查看SD卡设备
lsblk

# 烧录（替换/dev/sdX为你的SD卡）
sudo dd if=out/licheerv_nano/sg2002_licheerv_nano.img of=/dev/sdX bs=4M status=progress conv=fsync

# 或者使用脚本
sudo ./device/sophgo/build/pack
cd out/licheerv_nano
sudo ./flash.sh /dev/sdX
```

### 方法2: 分步烧录

如果运行打包脚本时没有root权限：

```bash
# 1. 手动分区
sudo fdisk /dev/sdX << EOF
o
n
p
1

+64M
t
c
n
p
2


w
EOF

# 2. 格式化分区
sudo mkfs.vfat -F 32 /dev/sdX1
sudo mkfs.ext4 /dev/sdX2

# 3. 烧录boot分区
mkdir -p /tmp/boot
sudo mount /dev/sdX1 /tmp/boot
sudo cp out/licheerv_nano/Image /tmp/boot/
sudo cp out/licheerv_nano/boot.img /tmp/boot/
sudo umount /tmp/boot

# 4. 烧录rootfs分区
sudo dd if=out/licheerv_nano/rootfs.img of=/dev/sdX2 bs=4M status=progress
```

## 启动流程

SG2002的启动顺序：

1. **ROM Boot** (芯片内部)
   - 从SPI NOR/NAND Flash或SD卡启动
   - 加载SPL/FSBL (First Stage Bootloader)

2. **SPL/FSBL** (Secondary Program Loader)
   - 初始化DDR内存
   - 加载OpenSBI + U-Boot

3. **OpenSBI** (RISC-V Supervisor Binary Interface)
   - 提供SBI调用接口
   - 跳转到U-Boot

4. **U-Boot** (Bootloader)
   - 初始化外设
   - 从SD卡/FAT32分区加载内核和设备树
   - 启动Linux内核

5. **Linux Kernel**
   - 挂载ramdisk
   - 切换根文件系统到SD卡分区2
   - 启动init进程

6. **OpenHarmony**
   - init启动系统服务
   - 加载HDF驱动
   - 启动应用框架

## 分区表

| 分区 | 大小 | 类型 | 内容 |
|------|------|------|------|
| p1 (boot) | 64MB | FAT32 (0x0C) | Image, boot.img, dtb |
| p2 (rootfs) | 剩余空间 | Linux (0x83) | ext4/squashfs rootfs |

## U-Boot启动参数

```bash
# 从SD卡启动
setenv bootcmd 'fatload mmc 0:1 ${kernel_addr_r} Image; fatload mmc 0:1 ${fdt_addr_r} sg2002.dtb; booti ${kernel_addr_r} - ${fdt_addr_r}'

# 设置启动参数
setenv bootargs 'console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rw rootwait init=/sbin/init'

saveenv
boot
```

## 故障排查

### 问题1: 内核无法启动

**现象**: U-Boot能加载内核但启动失败

**检查**:
1. 确认内核配置了正确的架构：`CONFIG_ARCH_RV64I=y`
2. 确认启用了Android Binder：`grep CONFIG_ANDROID_BINDER_IPC .config`
3. 检查设备树是否匹配硬件

### 问题2: 根文件系统无法挂载

**现象**: Kernel panic - not syncing: VFS: Unable to mount root fs

**检查**:
1. 确认分区正确创建：`fdisk -l /dev/sdX`
2. 确认文件系统格式正确：`file /dev/sdX2`
3. 检查bootargs中的root参数是否正确

### 问题3: OpenHarmony服务无法启动

**现象**: 内核启动成功，但系统服务无法运行

**检查**:
1. 确认根文件系统包含/sbin/init
2. 检查是否有正确的权限：init需要可执行权限
3. 确认Binder设备节点存在：`ls -la /dev/binder*`

## 参考资料

- [OpenHarmony内核移植指南](./reference/移植方法.md)
- [D1打包脚本参考](./device/sunxi/build/pack)
- [Buildroot打包配置](./LicheeRV-Nano-Build/build/tools/common/sd_tools/genimage.cfg)
- [U-Boot文档](./LicheeRV-Nano-Build/u-boot-2021.10/doc/)

## 文件位置

```
device/sophgo/build/pack                    # 打包脚本
out/licheerv_nano/                          # 打包输出目录
├── Image                                   # 内核镜像
├── boot.img                                # 启动镜像
├── rootfs.img                              # 根文件系统
└── flash.sh                                # 烧录脚本
```

## 更新记录

- 2026-02-05: 初始版本，支持ext4和squashfs
