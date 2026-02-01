# OpenHarmony SGLinTx 移植项目 - 下一步行动指南

**最后更新**: 2026-02-01  
**当前状态**: U-Boot 成功启动，FIT 配置节点待修复

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
- ✅ 内核构建成功
- ✅ 镜像打包完成
- ✅ BootROM → FSBL → U-Boot 启动链成功
- ⚠️ **FIT 内核加载失败** (配置节点不匹配)

---

## 🔍 问题背景

### 已解决的问题

1. **内核编译问题**
   - Clang 不支持 RISC-V `-mmedany` 代码模型
   - **解决**: 使用 GCC 工具链编译内核

2. **内核链接问题**
   - `CONFIG_KALLSYMS` 导致符号地址超出 32 位范围
   - **解决**: 禁用 KALLSYMS

3. **启动黑屏问题**
   - Boot 分区缺少 vendor marker 文件
   - FAT 文件系统被手动修改破坏
   - **解决**: 提取 vendor 的 9 个 marker 文件，使用 genimage 正确参数

### 当前问题

**现象**:
```
## Loading kernel from FIT Image at 81800000 ...
Could not find configuration node
ERROR: can't get kernel image!
```

**原因**: FIT 配置节点命名不匹配
- 官方 boot.sd 使用: `config@1`
- OHOS boot.sd 使用: `config-1`

---

## 🎯 需要的修改

### 文件位置
```
/home/shimmer/ohos_source/SGLinTx_Port/device/board/Humpback/SGLinTx/kernel/package_ohos.sh
```

### 具体修改

**第 84-92 行**，当前代码:
```bash
configurations {
    default = "config-1";
    config-1 {
        description = "Boot Configuration";
        kernel = "kernel";
        ramdisk = "ramdisk";
        fdt = "fdt";
    };
};
```

**改为**:
```bash
configurations {
    default = "config@1";
    config@1 {
        description = "Boot Configuration";
        kernel = "kernel";
        ramdisk = "ramdisk";
        fdt = "fdt";
    };
};
```

**关键点**: 将连字符 `-` 改为 `@` 符号

---

## 🔧 操作步骤

### 1. 修改配置节点

```bash
cd /home/shimmer/ohos_source/SGLinTx_Port
vim device/board/Humpback/SGLinTx/kernel/package_ohos.sh
# 修改第 84 和 86 行，将 config-1 改为 config@1
```

### 2. 同步到 Docker

```bash
cd /home/shimmer/ohos_source
./deploy_to_docker.sh
```

### 3. 重新打包镜像

```bash
docker exec -it ohos_build_env bash
cd /home/openharmony
rm -rf /home/openharmony/out/SGLinTx/pack/output/*
bash device/board/Humpback/SGLinTx/kernel/package_ohos.sh
```

### 4. 验证修改

```bash
# 在 Docker 中
dd if=/home/openharmony/out/SGLinTx/pack/output/ohos_sglintx.img bs=512 skip=1 count=32768 of=/tmp/check_boot.vfat 2>/dev/null
mcopy -i /tmp/check_boot.vfat ::boot.sd /tmp/boot_new.sd
mkimage -l /tmp/boot_new.sd | grep -A3 "Configuration"
# 应该看到 "Config 0 (config@1)"
```

### 5. 烧录测试

```bash
# 复制到主机
docker cp ohos_build_env:/home/openharmony/out/SGLinTx/pack/output/ohos_sglintx.img /home/shimmer/ohos_source/out/SGLinTx/pack/output/

# Windows 使用 Rufus, Linux 使用 dd
sudo dd if=ohos_sglintx.img of=/dev/sdX bs=4M status=progress
```

### 6. 串口监控

```bash
# 波特率: 115200, 8N1
sudo picocom /dev/ttyUSB0 -b 115200
# 或
sudo minicom -D /dev/ttyUSB0 -b 115200
```

---

## 📁 重要文件说明

### 项目结构
```
SGLinTx_Port/
├── device/board/Humpback/SGLinTx/
│   └── kernel/
│       ├── build_kernel.sh          # 内核编译脚本
│       ├── package_ohos.sh          # 镜像打包脚本 ⭐ 需要修改
│       ├── BUILD.gn                 # GN 构建配置
│       └── configs/
│           └── sg2002_licheervnano_sd_defconfig  # 内核配置
├── vendor/Humpback/SGLinTx/
│   └── config.json                  # 产品配置
├── change.md                        # 完整的修改记录 ⭐ 必读
├── README.md                        # 项目说明
└── verify_ohos_image.sh             # 镜像验证工具
```

### 必读文档
1. **`change.md`** - 记录了所有技术细节和修改历史
2. **`device/board/Humpback/SGLinTx/kernel/package_ohos.sh`** - 核心打包脚本

### 关键代码段

**package_ohos.sh 结构**:
- **Line 25-103**: FIT 镜像生成（ITS 文件定义）
- **Line 106-135**: Vendor marker 文件提取
- **Line 137-187**: genimage 配置生成

---

## 🐛 已知问题和注意事项

### ⚠️ 绝对不要做的事

1. **不要手动修改 FAT BPB 参数**
   - 会破坏文件系统，导致 fip.bin 无法加载
   - 使用 genimage 的 `extraargs` 参数

2. **不要删除 Boot 分区的 marker 文件**
   ```
   usb.dev, usb.ncm, usb.rndis, wifi.sta, gt9xx, logo.jpeg, ver
   ```
   - U-Boot 依赖这些文件检测硬件配置

3. **不要使用 Clang 编译内核**
   - RISC-V 内核必须用 GCC

### ✅ 最佳实践

1. **每次修改后运行验证脚本**:
   ```bash
   cd /home/openharmony
   ./SGLinTx_Port/verify_ohos_image.sh
   ```

2. **保持 fip.bin 与 vendor 一致**:
   ```bash
   sha256sum lichee_sdk/install/soc_sg2002_licheervnano_sd/fip.bin
   # 应该是: ec515da1bed75915727e0126fc5ba9b62156425412d39fd900f5d93419b43633
   ```

3. **使用官方 vendor 镜像作为参考**:
   ```bash
   lichee_sdk/install/soc_sg2002_licheervnano_sd/images/2026-01-21-18-59-f3639b.img
   ```

---

## 📊 预期启动日志

### 成功启动应该看到

```
[乱码 - BootROM]
U-Boot 2021.10 (xxx) soph
DRAM:  254 MiB
MMC:   cv-sd@4310000: 0, wifi-sd@4320000: 1
Loading Environment from nowhere... OK
...
Boot from SD dev 0 ...
12079500 bytes read in 1068 ms
## Loading kernel from FIT Image at 81800000 ...
   Using 'config@1' configuration          ← 这里应该成功
   Trying 'kernel' kernel subimage
     Description:  RISC-V OpenHarmony Kernel
     Load Address: 0x80200000
     Entry Point:  0x80200000
   Verifying Hash Integrity ... crc32+ sha256+ OK
## Flattened Device Tree blob at 82000000
Starting kernel ...

[    0.000000] Linux version 5.10.x-ohos ...
[    0.000000] Machine model: Sophgo LicheeRV Nano
...
```

---

## 🔬 调试技巧

### 如果修改后还是失败

1. **检查 FIT 镜像内容**:
   ```bash
   mkimage -l /tmp/boot.sd | grep -i config
   ```

2. **对比官方 boot.sd**:
   ```bash
   mcopy -i /tmp/vendor_boot.vfat ::boot.sd /tmp/vendor_boot.sd
   mkimage -l /tmp/vendor_boot.sd > vendor.txt
   mkimage -l /tmp/ohos_boot.sd > ohos.txt
   diff -u vendor.txt ohos.txt
   ```

3. **U-Boot 手动加载测试**:
   ```
   # 在 U-Boot 提示符 soph#
   fatload mmc 0:1 0x81800000 boot.sd
   iminfo 0x81800000
   bootm 0x81800000
   ```

### 串口无输出排查

1. 检查波特率: **115200** baud
2. 检查连线: TX ↔ RX, GND ↔ GND
3. 检查 SD 卡: 重新烧录
4. 检查电源: 5V/2A 供电

---

## 📞 技术支持资源

### 参考文档
- OpenHarmony 官方文档: https://gitee.com/openharmony
- SG2002 数据手册: lichee_sdk/docs/
- U-Boot FIT 格式: https://u-boot.readthedocs.io/

### 相关仓库
- 芯片厂商 SDK: `lichee_sdk/`
- OHOS kernel: `kernel/linux/linux-5.10/`
- 设备配置: `SGLinTx_Port/device/`

---

## 🎓 技术要点总结

1. **SG2002 启动流程**: BootROM → FSBL → OpenSBI → U-Boot → Kernel
2. **FIT 镜像必需**: 包含 Kernel + FDT + Ramdisk，配置节点指定引导方式
3. **Boot marker 文件**: usb.*, wifi.sta, gt9xx 等用于硬件检测
4. **FAT 几何参数**: Heads=2, Sectors=32, FAT16
5. **波特率**: BootROM 乱码正常，U-Boot/Linux 使用 115200

---

## ✅ 成功标准

修复完成后，应该满足:
- ✅ U-Boot 找到 `config@1` 配置节点
- ✅ FIT 镜像 Hash 校验通过
- ✅ 内核成功加载到 0x80200000
- ✅ Linux 内核输出 boot log
- ✅ OpenHarmony init 系统启动

---

**祝移植成功！🚀**

如有问题，请查阅 `change.md` 获取详细的技术背景和历史修改记录。
