# SG2002 厂家SDK镜像分析报告

## 1. 分区布局 (Partition Layout)

厂家镜像采用传统的 MBR 分区结构：

- **扇区大小**: 512 Bytes
- **几何参数 (Geometry)**: Heads=2, Sectors per Track=32

### 分区表

| 分区 | 类型 | 起始 LBA | 大小 | 状态 | 文件系统 |
|------|------|----------|------|------|----------|
| Part 1 (Boot) | 0x0C (FAT32 LBA) | 1 | 16 MB | 0x80 (Active) | FAT16 |
| Part 2 (RootFS) | 0x83 (Linux) | - | 1.6 GB | - | ext4/squashfs |

**关键差异**:
- 分区1起始LBA = 1 (不是2048)
- 分区1大小 = 16MB (不是64MB)
- 使用FAT16而不是FAT32

## 2. 核心文件 (Boot Partition Contents)

第一个分区包含以下关键文件：

### fip.bin
- **作用**: 核心引导固件
- **内容**: 包含 FSBL/BL2, OpenSBI 和可能的微码
- **加载**: 由Mask ROM从SD卡扇区1直接加载

### boot.sd
- **作用**: 厂家引导逻辑的关键
- **格式**: FIT (Flattened Image Tree) 格式，不是原始内核镜像
- **内含组件**:
  - **Kernel**: 加载地址和入口点均为 0x80200000 (Uncompressed)
  - **Ramdisk**: 初始内存盘
  - **FDT**: 设备树文件
- **来源**: 由 boot.itb 重命名而来

### 其他文件
- logo.jpeg
- ver (版本信息)
- usb.* 标记文件 (用于U-Boot环境判断)

## 3. 镜像组成成分（打包前）

### A. 固件包：fip.bin
通过 fsbl 仓库生成，内部包含：
- **FSBL (BL2)**: 第一级启动引导程序（First Stage Bootloader）
- **OpenSBI (Monitor)**: 负责 RISC-V 运行时服务
- **U-Boot (Loader 2nd)**: 第二级启动引导程序，负责加载 Linux 内核
- **BLCP**: Coprocessor（如 MCU）的运行镜像
- **DDR_PARAM**: DDR 内存初始化参数

### B. 引导分区镜像：boot.sd
由 build/Makefile 中的 `make boot` 目标生成的 boot.itb 重命名而来。
FIT格式包含：
- Linux Kernel (Image): 压缩后的 Linux 内核
- 设备树 (dtb): 对应板卡的设备树文件
- Ramdisk (boot.cpio.gz): （可选）初始 RAM 盘

### C. 根文件系统镜像：rootfs.sd
包含 Linux 系统的所有根文件系统内容。

## 4. 打包脚本层次

### 顶层控制
- **build/Makefile**: 定义了 boot 和 rootfs 等目标

### 分区准备
- **build/common_functions.sh**: 
  - `pack_boot` 函数: 准备 boot.sd 镜像
  - `pack_rootfs` 函数: 准备 rootfs.sd 镜像

### 最终打包脚本
- **sd_gen_burn_image_rootless.sh**: 
  - 使用 genimage 工具
  - 根据 genimage_rootless.cfg 配置
  - 将 fip.bin、boot.sd 和 rootfs.sd 合并成完整 .img 文件

## 5. 启动顺序

SG2002 的启动过程遵循多级引导机制：

```
1. Mask ROM
   ↓ (从SD卡加载)
2. FSBL (BL2) [在 fip.bin 中]
   ↓ (初始化DDR)
3. OpenSBI [在 fip.bin 中]
   ↓ (RISC-V M-Mode初始化)
4. U-Boot [在 fip.bin 中]
   ↓ (从boot分区读取boot.sd)
5. boot.sd (FIT格式)
   ↓ (解析出内核和设备树)
6. Linux Kernel
   ↓ (挂载rootfs)
7. Init 进程
```

**关键差异**:
- U-Boot不直接加载内核，而是加载FIT格式的boot.sd
- boot.sd包含内核+设备树+ramdisk的完整包

## 6. 与我们当前方案的差异

| 项目 | 我们的方案 | 厂家SDK方案 |
|------|------------|-------------|
| Boot镜像 | boot.img (简单连接) | boot.sd (FIT格式) |
| 分区起始 | LBA 2048 | LBA 1 |
| 分区大小 | 64MB | 16MB |
| 文件系统 | FAT32 | FAT16 |
| 启动流程 | U-Boot → 内核 | U-Boot → FIT → 内核 |
| 包含文件 | 仅内核 | fip.bin + boot.sd |

## 7. 修复方案

### 需要获取的文件
1. **fip.bin**: 从厂家SDK获取
2. **设备树dtb**: SG2002特定的设备树
3. **mkimage**: 用于创建FIT镜像的工具
4. **its文件**: 描述FIT镜像结构的配置文件

### 需要修改的内容
1. 分区表: 起始LBA=1, 大小16MB
2. 创建FIT格式的boot.itb而不是boot.img
3. 在boot分区中添加fip.bin
4. 重命名boot.itb为boot.sd
5. 使用genimage工具进行最终打包

## 8. 参考文件

- LicheeRV-Nano-Build/build/common_functions.sh
- LicheeRV-Nano-Build/build/sd_gen_burn_image_rootless.sh
- LicheeRV-Nano-Build/build/genimage_rootless.cfg
- LicheeRV-Nano-Build/fsbl/ (fip.bin来源)
