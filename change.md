# SGLinTx 移植变更汇总

## 1. 概述
本文档记录了为支持 **SGLinTx (LicheeRV Nano)** 开发板在 OpenHarmony (3.2 Release) 上进行移植所做的所有文件修改和配置变更。

## 2. 目录结构变更

### 2.1 板级配置 (Device Configuration)
**路径:** `device/board/Humpback/SGLinTx`

*   **[新建] `BUILD.gn`**
    *   **作用:** 板级编译入口。
    *   **内容:** 定义了一个空的 `group("sglintx_group")`。
    *   **原因:** 替换原始复制来的 D1 相关配置，消除无效引用错误。

*   **[新建] `ohos.build`**
    *   **作用:** OHOS 组件子系统定义。
    *   **内容:** 注册子系统 `device_sglintx` 和部件 `sglintx_group`。
    *   **原因:** 让 `hb` 构建系统能识别该板级组件。

*   **[新建] `linux_5.10/` (目录)**
    *   **作用:** (已废弃) 原计划用于修复 Small System 错误，切换 Standard 后不再需要。

### 2.2 产品配置 (Vendor Configuration)
**路径:** `vendor/Humpback/SGLinTx`

*   **[新建] `config.json`**
    *   **作用:** 核心产品定义文件。
    *   **关键配置:**
        *   `product_name`: "SGLinTx"
        *   `ohos_version`: "OpenHarmony 3.2"
        *   `device_company`: "Humpback"
        *   `board`: "SGLinTx"
        *   `kernel_type`: "linux"
        *   `kernel_version`: "5.10"
        *   **`target_cpu`: "riscv64"** (修复默认 ARM 架构问题)
        *   **`target_os`: "linux"**
        *   **`component_name`: "linux"** (尝试修复 linux_5.10 匹配问题)

## 3. 构建环境与脚本修复 (Build System Fixes)

针对 Docker 环境和 RISC-V 架构的适配修改。

### 3.1 工具链配置 (Toolchain)
*   **问题:** 构建脚本默认检查并依赖 `gcc-arm-linux-gnueabi`，但当前环境为 RISC-V 且缺少该工具链。
*   **修复 1 (依赖检查):** 修改 `build/scripts/build_package_list.json`，删除了 `gcc-arm-linux-gnueabi` 和 `gcc-arm-none-eabi` 的依赖检查。
*   **修复 2 (编译配置):** 修改 `kernel/linux/build/kernel.mk` (注意：需要确保此修改存在)：
    *   为 `riscv64` 架构添加分支。
    *   指定使用 **LLVM/Clang** (`llvm-`) 作为工具链，直接复用 OpenHarmony 预编译工具，无需安装额外 GCC。

### 3.2 内核构建适配 (Kernel Setup)
*   **构建脚本:** 修改 `kernel/linux/build/kernel_module_build.sh`，在架构判断中添加 `riscv64` 支持 (对应 `Image` 镜像)。
*   **Defconfig:** 将 `lichee_sdk` 中的配置复制为 `kernel/linux/config/linux-5.10/SGLinTx_small_defconfig`。
*   **补丁文件:** 在 `kernel/linux/patches/linux-5.10/SGLinTx_patch/` 下创建了空的 `SGLinTx.patch` 和 `SGLinTx_small.patch` 以满足构建脚本对 Patch 文件的强制检查。


## 4. 架构变更 (Standard System Pivot)

用户要求切换到 **Standard System (L2)** 以对齐 D1 开发板体验。

*   **配置变更 (`vendor/Humpback/SGLinTx/config.json`)**:
    *   **Type**: 从 `small` 改为 `standard`。
    *   **inherit**: 继承 `productdefine/common/base/standard_system.json`。
    *   **Components**:
        *   移除 `init_lite`, `hilog_lite` 等 Lite 组件。
        *   添加 Standard 组件: `init`, `hiviewdfx_hilog_native`, `hidumper`, `hdc`。
    *   **注意**: 必须使用 `hiviewdfx_hilog_native` (在 `base/hiviewdfx/hilog/interfaces/native/bundle.json` 中定义) 以满足 `huks` 和 `hidumper` 的依赖。

## 5. 当前状态

*   **构建状态**: `./build.sh --product-name SGLinTx --build-only-gn` **成功**。
*   **遗留问题**: 需要进一步验证完整的内核编译和镜像打包 (Image generation)。

## 6. 代码管理与内核集成 (Git & Kernel)

### 6.1 Git 初始化
已为 SGLinTx 的板级和厂商目录初始化了 Git 仓库并提交了初始状态，方便后续管理。
*   `device/board/Humpback/SGLinTx`
*   `vendor/Humpback/SGLinTx`

### 6.2 内核编译集成
为了在标准系统中编译内核，参照 RK3568 创建了以下文件：
*   **[新建] `device/board/Humpback/SGLinTx/kernel/BUILD.gn`**: 定义内核编译目标 `action("kernel")`。
*   **[新建] `device/board/Humpback/SGLinTx/kernel/build_kernel.sh`**: 内核编译脚本，负责：
    *   复制内核源码 (`kernel/linux/linux-5.10`)
    *   打 Patch (HDF + Board)
    *   配置 (`SGLinTx_small_defconfig` -> `sglintx_defconfig`)
    *   **注入 `Hybrid Bypass` 策略**: 剥离 Clang 的 `v0p7` 标志，通过 `-Wa` 传递给汇编器汇编器，解决向量扩展版本冲突。
    *   **禁用了 Linker Relaxation**: 通过 `-Wa,-mno-relax` 解决 `ld.lld` 不支持 GCC 产生的 relocation 问题。
    *   执行 LLVM 交叉编译 (`make ARCH=riscv LLVM=1 ...`)
*   **[新建] `device/board/Humpback/SGLinTx/kernel/package_ohos.sh`**: 镜像打包脚本，负责：
    *   收集 `fip.bin`, `Image`, `dtb`, `system.img` 等组件。
    *   使用 SDK 里的 `genimage` 工具将分散的分区镜像打包成一个完整的 `ohos_sglintx.img` (SD卡全盘镜像)。
*   **[修改] `device/board/Humpback/SGLinTx/BUILD.gn`**:
    *   添加了 `kernel:kernel` 到 `deps`，确保构建系统自动触发内核编译。

## 7. 内核编译关键修复 (Kernel Build Fixes)

针对内核编译过程中出现的链接和指令集错误，实施了以下关键修复：

### 7.1 汇编器指令集冲突 (RISC-V Vector 0.7)
*   **现象**: Clang 汇编器严格执行 V1.0 标准，拒绝内核中的 V0.7 指令。
*   **修复**: 在 `build_kernel.sh` 中剥离 Clang 看到的 `v0p7` 标志，并通过 `-Wa,-march=rv64imafdcv0p7` 直接透传给 GCC 汇编器。

### 7.2 链接器重定位错误 (Linker Relaxation)
*   **现象**: `ld.lld: error: ... relocation R_RISCV_ALIGN requires unimplemented linker relaxation`.
*   **修复**: 在 `arch/riscv/Makefile` 中全局注入 `-Wa,-mno-relax`，强制汇编器不产生需要 relaxation 的对齐指令。

### 7.3 内存模型与寻址范围 (PC-relative out of range)
*   **现象**: `relocation R_RISCV_PCREL_HI20 out of range`。
*   **修复**: 在 `defconfig` 中启用 `CONFIG_CMODEL_MEDANY=y`，将内核内存模型从 `medlow` (2GB) 切换到 `medany` (支撑更大范围的地址跳转)。

### 7.4 KALLSYMS 链接异常
*   **现象**: 即使开启 `medany`，`kallsyms` 相关符号仍报寻址超限。
*   **修复**: 在 `defconfig` 中通过 `CONFIG_KALLSYMS=n` 暂时禁用该功能以绕过链接死锁，优先产出可引导镜像。

## 8. 启动修复 (Boot Fixes)

### 8.1 问题诊断

**初始现象**：OHOS 镜像烧录后无串口输出，无法启动

#### 诊断过程

1. **对比分析**
   - 官方镜像：BootROM 乱码 → U-Boot (115200 baud) → 内核启动
   - OHOS 镜像：BootROM 乱码较短 → 无输出 → Watchdog 重启循环

2. **定位问题**
   - fip.bin 版本正确（SHA256 与官方完全一致）
   - Boot 分区文件缺失（缺少 U-Boot 环境检测所需的标记文件）
   - 手动修改 FAT BPB 破坏文件系统导致 fip.bin 无法加载

### 8.2 修复措施

#### A. 添加 Vendor Boot Marker 文件

**修改文件**: `device/board/Humpback/SGLinTx/kernel/package_ohos.sh`

**添加内容**:
```bash
# 从厂家镜像提取标记文件
VENDOR_IMG="${VENDOR_BOOT_FILES}/images/2026-01-21-18-59-f3639b.img"
dd if=${VENDOR_IMG} bs=512 skip=1 count=32768 of=${PACK_DIR}/tmp_extract/boot.vfat
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.dev ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.ncm ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.rndis ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::wifi.sta ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::gt9xx ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::logo.jpeg ${PACK_DIR}/input/
mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::ver ${PACK_DIR}/input/
```

**Boot 分区文件清单** (共 9 个文件):
1. `fip.bin` - 引导固件 (FSBL/BL2 + OpenSBI + U-Boot SPL)
2. `boot.sd` - FIT 格式内核镜像包
3. `usb.dev` - USB 设备模式标记
4. `usb.ncm` - USB NCM 模式标记
5. `usb.rndis` - USB RNDIS 模式标记
6. `wifi.sta` - WiFi 站点模式标记
7. `gt9xx` - 触摸屏驱动标记
8. `logo.jpeg` - 启动 Logo (3621 bytes)
9. `ver` - 版本信息

**作用**: U-Boot 通过这些标记文件检测硬件配置和启动模式

#### B. 修正 FAT 分区几何参数配置

**修改**: `genimage.cfg` 的 FAT 分区配置

```bash
vfat {
    label = "boot"
    files = { ... }
    # Match vendor FAT geometry: Heads=2, Sectors=32, FAT16
    extraargs = "-F 16 -h 2 -s 32"
}
```

**重要教训**: 
- ✅ genimage 的 `-h 2 -s 32` 参数有效
- ❌ **不要事后手动修改 FAT BPB**，会破坏文件系统内部一致性
- ✅ 现代 SD 卡启动对 Heads 参数不敏感，BootROM 更关注文件系统有效性

#### C. FIT 镜像生成

**修改**: 添加 FIT (Flattened Image Tree) 镜像生成逻辑

```bash
# 生成 ITS (Image Tree Source) 文件
cat <<EOF > ${PACK_DIR}/input/ohos_boot.its
/dts-v1/;
/ {
    description = "OpenHarmony SGLinTx Boot Image";
    #address-cells = <1>;
    
    images {
        kernel {
            description = "RISC-V OpenHarmony Kernel";
            data = /incbin/("Image");
            type = "kernel";
            arch = "riscv";
            os = "linux";
            compression = "none";
            load = <0x80200000>;
            entry = <0x80200000>;
            hash { algo = "crc32"; };
            hash { algo = "sha256"; };
        };
        fdt {
            description = "SG2002 LicheeRV Nano Device Tree";
            data = /incbin/("sg2002_licheervnano_sd.dtb");
            type = "flat_dt";
            arch = "riscv";
            compression = "none";
            hash { algo = "crc32"; };
            hash { algo = "sha256"; };
        };
        ramdisk {
            description = "OpenHarmony Initial Ramdisk";
            data = /incbin/("ramdisk.img");
            type = "ramdisk";
            arch = "riscv";
            os = "linux";
            compression = "none";
            hash { algo = "crc32"; };
            hash { algo = "sha256"; };
        };
    };
    
    configurations {
        default = "config-1";
        config-1 {
            description = "Boot Configuration";
            kernel = "kernel";
            ramdisk = "ramdisk";
            fdt = "fdt";
        };
    };
};
EOF

# 编译 FIT 镜像
mkimage -f ohos_boot.its boot.sd
```

### 8.3 当前状态

✅ **已解决**:
- BootROM 阶段: fip.bin 正常加载
- FSBL/OpenSBI: DDR 初始化成功
- U-Boot 启动: `DRAM: 254 MiB` 检测正常
- SD 卡识别: MMC 驱动工作正常
- Boot Logo: logo.jpeg 解码并显示成功
- FIT 文件读取: `12079500 bytes read` 成功

❌ **待解决** (FIT 配置节点不匹配):
```
## Loading kernel from FIT Image at 81800000 ...
Could not find configuration node
ERROR: can't get kernel image!
```

**问题分析**:
- 官方 boot.sd 使用 `config@1` 节点名
- OHOS boot.sd 使用 `config-1` 节点名
- U-Boot 的 distro boot 脚本硬编码查找 `config@1` 格式

**修复** (2026-02-01):
修改 `package_ohos.sh` 第 85-86 行，将配置节点命名改为 `@` 格式：
```bash
configurations {
    default = "config@1";
    config@1 {
        description = "Boot Configuration";
        kernel = "kernel";
        fdt = "fdt";
        ramdisk = "ramdisk";
    };
};
```

### 8.4 FAT 文件系统参数修复 (2026-02-01)

**问题 1**: Boot 分区从 128MB 缩减为 16MB 后 U-Boot 仍无法启动

**诊断**:
- Block number 溢出: `MMC: block number 0x100000041 exceeds max`
- 原因：mkdosfs参数理解错误

**关键发现**:
```bash
# ❌ 错误理解
-h 2    # 以为是 Heads=2
-s 32   # 以为是 Sectors per track=32

# ✅ 实际含义  
-h 2    # Hidden sectors = 2
-s 32   # Sectors per CLUSTER = 32  ← 这导致簇太大，地址溢出
```

**Vendor 实际参数**:
```
Boot 分区大小: 16MB
Sectors per cluster: 4
Reserved sectors: 4
FAT 类型: FAT16
```

**最终修复**:
```bash
# package_ohos.sh 第 147 行
extraargs = "-F 16 -s 4 -R 4"
size = 16M
```

**技术要点**:
1. mkdosfs `-s` 设置的是**簇大小**，不是磁盘几何参数
2. 磁盘 geometry (heads, sectors per track) 由 FAT 自动计算
3. Boot 分区大小必须与 vendor 完全一致（16MB），否则 FAT 参数不匹配

---

## 9. 当前状态 (2026-02-01 更新)

### 系统构建: ✅ **成功**
- 内核编译: 通过 (RISC-V 64位, v5.10.4)
- 系统镜像: 生成完整 (system.img, vendor.img, userdata.img, ramdisk.img)
- Boot 镜像: FIT 格式正确，配置节点匹配

### 启动进度: 🟡 **内核加载成功，Console 待修复**
- ✅ BootROM → FSBL → OpenSBI
- ✅ U-Boot 启动并初始化 (DRAM: 254 MiB)
- ✅ Boot 分区识别和文件读取
- ✅ FIT 内核加载成功 (`Using 'config@1' configuration`)
- ✅ 内核、Ramdisk、DTB Hash 校验通过
- ✅ **"Starting kernel ..."** - 内核已跳转
- ❌ **内核 console 无输出** - bootargs/chosen 节点配置问题

### 镜像信息
- **路径**: `out/SGLinTx/pack/output/ohos_sglintx.img`
- **大小**: 3.14 GB
- **分区**:
  - Boot: **16 MB** (FAT16, 包含 9 个文件, Sectors/cluster=4)
  - System: 1.5 GB (EXT4)
  - Vendor: 256 MB (EXT4)
  - Userdata: 1.4 GB (EXT4)

### 待解决问题

#### 内核 Console 静默
**现象**: 
- 内核成功跳转 ("Starting kernel ...")
- 之后无任何串口输出
- 设置 U-Boot bootargs 无效

**可能原因**:
1. DTB chosen 节点为空，覆盖了 U-Boot 的 bootargs
2. DTB 编译流程问题 - 设备树源文件修改未生效
3. 内核 console 驱动相关配置缺失

**尝试过的方案**:
- ✗ U-Boot 手动设置 `console=ttyS0,115200 root=/dev/mmcblk0p2`
- ✗ 修改设备树源文件添加 chosen/bootargs (编译未生效)

**下一步调查**:
1. 研究 OHOS 内核构建系统的 DTB 编译流程
2. 对比 vendor DTB 和 OHOS DTB 的 chosen 节点
3. 考虑通过 U-Boot 脚本传递 bootargs

### 技术要点总结

1. **RISC-V 编译链**: 使用 LLVM/Clang，需处理 Vector v0p7 和 Linker Relaxation
2. **Kernel 链接**: 关闭 `CONFIG_KALLSYMS` 避免超限，使用 `CMODEL_MEDANY`
3. **FIT 镜像**: 
   - 配置节点必须使用 `config@N` 格式（不是 `config-N`）
   - 必须匹配 U-Boot 的 distro boot 脚本预期
4. **Boot 分区配置**:
   - 大小：16MB (与 vendor 完全一致)
   - FAT16: sectors per cluster = 4, reserved = 4
   - ⚠️ mkdosfs `-s` 参数设置**簇大小**，不是 sectors per track
5. **Boot 标记文件**: U-Boot 环境检测必需（9个文件）
6. **FAT 文件系统**: 使用 genimage extraargs 正确配置，不要事后手动修改
7. **波特率**: BootROM 乱码正常，U-Boot/Linux 使用 115200 baud

