# OpenHarmony SGLinTx 移植项目 - 下一步行动指南

**最后更新**: 2026-02-01  
**当前状态**: ✅ 内核成功启动，❌ Console 输出待修复

---

## 📋 项目概述

### 目标
将 OpenHarmony Standard System 移植到 **Sophgo SG2002 (LicheeRV Nano)** 开发板

### 硬件规格
- **CPU**: SG2002 双核 RISC-V C906@1GHz + ARM A53@1GHz
- **内存**: 256MB DDR3
- **存储**: SD/eMMC
- **架构**: 本项目使用 RISC-V 核心

### 当前进度
- ✅ 系统编译成功
- ✅ 内核构建成功 (Linux 5.10.4)
- ✅ 镜像打包完成
- ✅ BootROM → FSBL → U-Boot 启动链成功
- ✅ **FIT 配置节点已修复** (`config-1` → `config@1`)
- ✅ **FAT BPB 参数已修复** (16MB, sectors/cluster=4)
- ✅ **内核成功加载并跳转** ("Starting kernel ...")
- ❌ **内核 Console 无输出** - 待调查 DTB 和 bootargs 传递

---

## 🎯 历史问题汇总

### 1. 汇编器指令集冲突 (✅ 已解决)
   - Clang 不支持 RISC-V Vector 0.7
   - **解决**: 使用 GCC 汇编器，透传 `-march=rv64imafdcv0p7`

### 2. 链接器重定位错误 (✅ 已解决)
   - ld.lld 不支持 relaxation
   - **解决**: 注入 `-Wa,-mno-relax`，禁用 `CONFIG_KALLSYMS`

### 3. 启动黑屏问题 (✅ 已解决)
   - Boot 分区缺少 vendor marker 文件
   - FAT 文件系统被手动修改破坏
   - **解决**: 提取 vendor 的 9 个 marker 文件，使用 genimage 正确参数

### 4. FIT 配置节点不匹配 (✅ 已解决 - 2026-02-01)
   - FIT 配置使用 `config-1`，但 U-Boot 查找 `config@1`
   - **解决**: 修改为 `config@1` 格式

### 5. FAT 文件系统参数错误 (✅ 已解决 - 2026-02-01)
   - mkdosfs 参数理解错误：`-s 32` 导致簇太大
   - Block number 溢出：`0x100000041 exceeds max`
   - **解决**: 改用 `-s 4 -R 4`，boot 分区改为 16MB

---

## 🎉 今日解决的关键问题 (2026-02-01)

### 问题 1: FIT 配置节点不匹配

**现象**:
```
## Loading kernel from FIT Image at 81800000 ...
Could not find configuration node
ERROR: can't get kernel image!
```

**根本原因**: 
- 官方 boot.sd 使用: `config@1`
- OHOS boot.sd 错误使用: `config-1`
- U-Boot distro boot 脚本硬编码查找 `@` 格式

**解决方案**: 
修改 `package_ohos.sh` 第 85-86 行：
```bash
configurations {
    default = "config@1";  # 从 config-1 改为 config@1
    config@1 {             # 从 config-1 改为 config@1
        kernel = "kernel";
        fdt = "fdt";
        ramdisk = "ramdisk";
    };
};
```

### 问题 2: FAT 文件系统参数导致 U-Boot 读取失败

**现象**:
```
MMC: block number 0x100000041 exceeds max(0x3b72400)
Invalid FAT entry
** Unable to read file boot.sd **
```

**诊断过程**:
1. 缩小 boot 分区从 128MB 到 16MB 后仍无法启动
2. U-Boot 计算文件位置时地址溢出（4GB+）
3. 发现 BPB 参数异常：sectors per cluster = 32

**根本原因**: mkdosfs 参数理解错误
```bash
# ❌ 错误理解
-h 2    # 以为是 Heads=2
-s 32   # 以为是 Sectors per track=32

# ✅ 实际含义  
-h 2    # Hidden sectors = 2
-s 32   # Sectors per CLUSTER = 32  ← 导致簇太大，地址计算溢出
```

**Vendor 实际配置**:
- Boot 分区：16MB
- Sectors per cluster: 4
- Reserved sectors: 4
- FAT type: FAT16

**解决方案**:
```bash
# package_ohos.sh 第 147-148 行
extraargs = "-F 16 -s 4 -R 4"  # 簇大小4，保留扇区4
size = 16M                      # 16MB (匹配 vendor)
```

**关键教训**:
1. mkdosfs `-s` 设置的是**簇大小** (sectors per cluster)，不是磁盘 geometry
2. Geometry 参数 (heads, sectors per track) 由 FAT 根据分区大小自动计算
3. Boot 分区大小必须严格匹配 vendor (16MB)

---

## ❌ 当前待解决问题

### 内核 Console 静默

**启动日志**:
```
## Loading kernel from FIT Image at 81800000 ...
   Using 'config@1' configuration          ✅ 配置正确
   Verifying Hash Integrity ... crc32+ OK  ✅ 内核校验通过
## Loading ramdisk from FIT Image ...
   Verifying Hash Integrity ... crc32+ OK  ✅ Ramdisk 校验通过
## Loading fdt from FIT Image ...
   Verifying Hash Integrity ... sha256+ OK ✅ DTB 校验通过

Starting kernel ...
← 卡在这里，无任何输出
```

**已尝试的方案**:
1. ✗ U-Boot 手动设置 bootargs: `console=ttyS0,115200 root=/dev/mmcblk0p2`
2. ✗ 修改设备树源文件添加 chosen/bootargs (编译未生效)

**可能原因分析**:
1. **DTB chosen 节点为空**: 覆盖了 U-Boot 传递的 bootargs
2. **DTB 编译流程问题**: 修改的 DTS 文件未被实际编译使用
3. **Console 驱动配置**: 内核 defconfig 中可能缺少必要配置

**下一步调查方向**:
1. 提取并对比 OHOS DTB vs Vendor DTB 的 chosen 节点
2. 研究 OHOS 内核构建系统的 DTB 编译路径
3. 检查 Vendor 如何传递 bootargs（U-Boot 环境变量？FIT 镜像？）
4. 考虑通过 U-Boot boot 脚本注入 bootargs

---

## 📝 镜像信息

### 当前镜像
- **路径**: `/home/openharmony/out/SGLinTx/pack/output/ohos_sglintx.img` (Docker 内)
- **大小**: 3.14 GB
- **日期**: 2026-02-01

### 分区布局
| 分区 | 大小 | 类型 | 说明 |
|------|------|------|------|
| boot | 16 MB | FAT16 | fip.bin + boot.sd + 7个marker文件 |
| system | 1.5 GB | EXT4 | OpenHarmony 系统分区 |
| vendor | 256 MB | EXT4 | Vendor 组件 |
| userdata | 1.4 GB | EXT4 | 用户数据 |

### Boot 分区文件清单
1. `fip.bin` (431 KB) - FSBL + OpenSBI + U-Boot SPL
2. `boot.sd` (11.5 MB) - FIT 镜像（kernel + ramdisk + dtb）
3. `usb.dev`, `usb.ncm`, `usb.rndis` - USB 模式标记
4. `wifi.sta` - WiFi 配置
5. `gt9xx` - 触摸屏标记
6. `logo.jpeg` (3.5 KB) - 启动 Logo
7. `ver` - 版本信息

---

## 📚 技术要点总结

### RISC-V 编译链
- 使用 LLVM/Clang 主编译器
- GCC 汇编器处理 Vector v0.7 指令
- 关闭 Linker Relaxation (`-mno-relax`)
- 使用 `CMODEL_MEDANY` 支持大地址空间

### FIT 镜像关键点
- 配置节点必须使用 `config@N` 格式（不是 `config-N`）
- 必须匹配 U-Boot distro boot 脚本预期
- 包含 kernel、ramdisk、dtb 三个组件

### Boot 分区配置
- **大小**: 16MB (严格匹配 vendor)
- **FAT 类型**: FAT16
- **Sectors per cluster**: 4
- **Reserved sectors**: 4
- ⚠️ mkdosfs `-s` 参数设置**簇大小**，不是 sectors per track

### 启动流程
1. BootROM (乱码正常，内部 loader)
2. FSBL (fip.bin，DDR 初始化)
3. OpenSBI (RISC-V supervisor binary interface)
4. U-Boot SPL → U-Boot proper
5. 加载 FIT 镜像 (boot.sd)
6. 跳转到 Linux kernel @ 0x80200000

---

## 🔗 相关文档

- **`change.md`** - 完整的修改记录和技术细节 (必读)
- **`NEXT_SESSION_CONTEXT.md`** - 详细的问题诊断过程
- **`device/board/Humpback/SGLinTx/kernel/`** - 核心构建脚本目录
  - `build_kernel.sh` - 内核编译
  - `package_ohos.sh` - 镜像打包

---

## 联系与支持

如有问题，请参考 `change.md` 中的详细技术说明。
