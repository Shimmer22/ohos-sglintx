# SG2002 启动修复指南

## 问题分析

根据用户提供的厂家SDK分析，我们之前的打包方案存在以下关键问题：

### ❌ 错误的做法
1. **分区布局错误**: 起始LBA=2048，大小64MB
2. **boot镜像错误**: 使用简单连接而不是FIT格式
3. **缺少fip.bin**: 没有包含启动必需的固件包

### ✅ 正确的做法（厂家SDK）
1. **分区布局**: 起始LBA=1，大小16MB，FAT16
2. **boot镜像**: FIT格式（boot.itb/boot.sd），包含内核+ramdisk+设备树
3. **包含fip.bin**: 必需的启动固件（FSBL + OpenSBI + U-Boot）

## 启动流程（厂家SDK）

```
┌─────────────────────────────────────────────────────────────┐
│  Mask ROM (芯片内部)                                         │
│  ↓ 从SD卡扇区1加载                                          │
├─────────────────────────────────────────────────────────────┤
│  FSBL (BL2) - 在 fip.bin 中                                  │
│  ↓ 初始化DDR                                                │
├─────────────────────────────────────────────────────────────┤
│  OpenSBI - 在 fip.bin 中                                     │
│  ↓ RISC-V M-Mode初始化                                      │
├─────────────────────────────────────────────────────────────┤
│  U-Boot - 在 fip.bin 中                                      │
│  ↓ 从SD卡boot分区读取boot.sd                                │
├─────────────────────────────────────────────────────────────┤
│  boot.sd (FIT格式)                                           │
│  ├─ Kernel (Image.gz)                                       │
│  ├─ Ramdisk (boot.cpio.gz)                                  │
│  └─ FDT (设备树)                                            │
│  ↓ 解压并启动                                                │
├─────────────────────────────────────────────────────────────┤
│  Linux Kernel                                                │
│  ↓ 挂载rootfs                                                │
├─────────────────────────────────────────────────────────────┤
│  OpenHarmony Init                                            │
└─────────────────────────────────────────────────────────────┘
```

## 解决方案

### 步骤1: 获取fip.bin

fip.bin是启动必需的固件，包含FSBL、OpenSBI和U-Boot。

**方法A: 从现有SD卡提取（推荐）**
```bash
# 将厂家提供的可启动SD卡插入电脑
# 查看SD卡设备
lsblk

# 提取fip.bin（从扇区1开始，大小约16MB）
sudo dd if=/dev/sdX of=/path/to/fip.bin bs=512 skip=1 count=32768

# 验证
ls -lh /path/to/fip.bin
file /path/to/fip.bin
```

**方法B: 从厂家SDK编译**
```bash
cd /home/openharmony/LicheeRV-Nano-Build

# 加载环境
source build/envsetup_soc.sh

# 选择你的板子
lunch sg2002_licheervnano_sd

# 编译fip.bin
make_fsbl

# 输出位置
ls out/sg2002_licheervnano_sd/fip.bin
```

### 步骤2: 使用新的打包脚本

我们创建了新的打包脚本 `pack_v2`，支持正确的分区布局和FIT镜像：

```bash
cd /home/openharmony

# 使用新的打包脚本
./device/sophgo/build/pack_v2 -f /path/to/fip.bin

# 或者使用squashfs（推荐，更小）
./device/sophgo/build/pack_v2 -t squashfs -f /path/to/fip.bin

# 查看帮助
./device/sophgo/build/pack_v2 -h
```

### 步骤3: 烧录镜像

```bash
cd /home/openharmony/out/licheerv_nano

# 方法1: 使用自动脚本（推荐）
sudo ./flash.sh /dev/sdX

# 方法2: 使用dd
sudo dd if=sg2002_licheerv_nano_ohos.img of=/dev/sdX bs=4M status=progress conv=fsync

# 同步
sync
```

### 步骤4: 验证分区

烧录后，检查分区是否正确：

```bash
sudo fdisk -l /dev/sdX

# 应该显示：
# Device       Boot Start     End Sectors Size Id Type
# /dev/sdX1    *       1   32768   32768  16M  c W95 FAT32 (LBA)
# /dev/sdX2         32769  ...     ...    ...  83 Linux
```

### 步骤5: 检查boot分区内容

```bash
# 挂载boot分区
sudo mount /dev/sdX1 /mnt

# 检查文件
ls -la /mnt/

# 应该包含：
# - fip.bin
# - boot.sd (或 boot.itb)
# 可选:
# - Image (内核，供参考)
# - sg2002.dtb (设备树)
# - logo.jpeg
# - ver

sudo umount /mnt
```

## 如果仍然无法启动

### 问题1: 卡在Mask ROM
**现象**: 串口无任何输出
**原因**: 
- fip.bin不存在或损坏
- 分区起始位置不对
- 文件系统格式不对

**排查**:
```bash
# 检查fip.bin是否存在
sudo mount /dev/sdX1 /mnt
ls -la /mnt/fip.bin
sudo umount /mnt

# 检查分区起始位置
sudo fdisk -l /dev/sdX
# 确认Part 1从扇区1开始
```

### 问题2: U-Boot无法找到boot.sd
**现象**: U-Boot启动但提示找不到kernel
**原因**:
- boot.sd文件名不对
- boot.sd格式不对

**排查**:
```bash
# 检查boot.sd是否存在
sudo mount /dev/sdX1 /mnt
ls -la /mnt/boot.sd

# 检查FIT格式
file /mnt/boot.sd
# 应该显示: "Flattened Image Tree"
```

### 问题3: 内核panic
**现象**: 内核启动但panic
**原因**:
- 根文件系统无法挂载
- root参数错误

**排查**:
- 在U-Boot中断启动，修改bootargs
```
setenv bootargs 'console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=squashfs rw rootwait init=/sbin/init'
saveenv
boot
```

## 调试技巧

### 查看串口输出
```bash
# 连接USB转串口，通常参数:
# - 波特率: 115200
# - 数据位: 8
# - 停止位: 1
# - 校验: None
screen /dev/ttyUSB0 115200
# 或
minicom -D /dev/ttyUSB0 -b 115200
```

### U-Boot调试
在U-Boot启动时按任意键中断，可以执行：
```
# 查看环境变量
printenv

# 查看分区
mmc part

# 手动加载FIT镜像
fatload mmc 0:1 ${kernel_addr_r} boot.sd
bootm ${kernel_addr_r}

# 设置启动参数
setenv bootargs 'console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=squashfs rw rootwait'
boot
```

## 参考文件

- **厂家SDK分析**: `VENDOR_SDK_ANALYSIS.md`
- **FIT镜像模板**: `LicheeRV-Nano-Build/ramdisk/configs/sg200x/multi.its`
- **打包脚本**: `device/sophgo/build/pack_v2`
- **fip.bin来源**: `LicheeRV-Nano-Build/fsbl/`

## 总结

要使OpenHarmony在SG2002上启动，必须：

1. ✅ 使用正确的分区布局（LBA 1开始，16MB boot）
2. ✅ 包含fip.bin（FSBL + OpenSBI + U-Boot）
3. ✅ 使用FIT格式的boot.sd（而不是简单的boot.img）
4. ✅ 根文件系统使用squashfs或ext4

新的打包脚本 `pack_v2` 已经实现了以上所有要求，只需要提供fip.bin即可生成可启动的镜像。
