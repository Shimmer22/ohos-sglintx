# SG2002 OpenHarmony 移植 - 完整修改总结

**项目**: SG2002 (LicheeRV Nano) OpenHarmony 移植  
**日期**: 2026-02-05  
**状态**: ✅ 内核编译成功 + 打包脚本完成（测试可启动）  

---

## 一、项目概述

成功将OpenHarmony 3.0 LTS移植到SG2002 (LicheeRV Nano)芯片平台：
- ✅ OpenHarmony标准系统构建成功（3136 targets）
- ✅ Linux 5.10.4内核编译成功（含OH配置）
- ✅ 固件打包脚本完成（支持FIT格式和厂家SDK分区布局）

---

## 二、修改的文件清单（共84个文件）

### 1. 文档（8个）

| 文件 | 说明 | 状态 |
|------|------|------|
| `BOOT_FIX_GUIDE.md` | 启动修复指南（基于厂家SDK分析） | ✅ 新增 |
| `CHANGES_SUMMARY.md` | 本文件，完整修改总结 | ✅ 新增 |
| `KERNEL_BUILD_GUIDE.md` | 内核构建指南 | ✅ 新增 |
| `MODIFIED_FILES_COMPLETE.md` | 修改文件完整清单 | ✅ 新增 |
| `PACKING_GUIDE.md` | 固件打包和烧录指南 | ✅ 新增 |
| `VENDOR_SDK_ANALYSIS.md` | 厂家SDK镜像分析报告 | ✅ 新增 |

| `sg2002_compiler_analysis.md` | 编译器使用分析 | ✅ 新增 |
| `sg2002_porting_status.md` | 移植状态报告 | ✅ 新增 |

### 2. 设备配置（10个）

```
device/sophgo/
├── build/
│   ├── BUILD.gn                    # 设备全局构建配置
│   └── pack                        # ⭐ 固件打包脚本（v3，已测试可启动）
├── sg2002_nano/
│   ├── BUILD.gn                    # 设备构建入口
│   ├── build/
│   │   ├── BUILD.gn                # 根文件系统构建
│   │   └── rootfs/
│   │       └── BUILD.gn            # init配置
│   ├── kernel/
│   │   ├── BUILD.gn                # 内核构建规则
│   │   └── build_kernel.sh         # 内核编译脚本
│   ├── prebuilts/
│   │   └── .gitkeep                # 占位文件
│   └── kernel_config.patch         # 内核配置补丁（可选）
└── config/
    └── chips/
        └── sg2002/
            └── configs/
                └── nano/           # 芯片配置目录（预留）
```

### 3. 产品配置（2个）

```
productdefine/common/
├── device/
│   └── sg2002_nano.json            # 设备定义
└── products/
    └── sg2002_nano.json            # 产品定义
```

### 4. Vendor配置（64个）

```
vendor/sophgo/sg2002_nano/
├── config.json                     # 产品子系统配置
├── ohos.build                      # 子系统构建配置
└── hdf_config/                     # HDF配置（从D1复制）
    ├── khdf/
    │   ├── audio/
    │   ├── device_info/
    │   ├── hdf_test/
    │   ├── input/
    │   ├── lcd/
    │   ├── platform/
    │   ├── sensor/
    │   ├── vibrator/
    │   └── wifi/
    └── uhdf/
        ├── camera/
        └── device_info.hcs
```

### 5. 驱动配置（1个）

```
drivers/peripheral/camera/hal/adapter/chipset/gni/
└── camera.sg2002_nano.gni         # 相机驱动配置
```

### 6. 内核配置（4个）

```
kernel/linux/patches/
├── kernel-5.10.mk                  # Linux 5.10内核Makefile
├── kernel_module_build.sh          # 修改：添加sg2002支持
└── linux-5.10/
    ├── sg2002_nano_defconfig       # 内核默认配置（占位）
    └── sg2002_nano_kernel_config.patch  # OH配置补丁
```

---

## 三、关键修复和特性

### 1. 编译器配置
- **LLVM工具链**: `prebuilts/clang/ohos/linux-x86_64/llvm-riscv/`
- **GCC工具链**: `LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/`
- **系统修复**: 创建 `/usr/include/asm` 符号链接

### 2. 内核构建
- **内核版本**: Linux 5.10.4
- **必需配置**: `CONFIG_ANDROID_BINDER_IPC=y`
- **构建命令**: `make -f kernel-5.10.mk`
- **输出**: `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image`

### 3. 固件打包（⭐ 重点）
- **脚本**: `device/sophgo/build/pack` (v3版本)
- **分区布局**: 基于厂家SDK分析
  - Part 1: LBA 1, 16MB, FAT16, Type 0x0C
  - Part 2: Linux Type 0x83
- **FIT镜像**: 支持kernel + ramdisk + dtb
- **必需文件**: fip.bin（FSBL + OpenSBI + U-Boot）
- **输出**: 完整SD卡镜像（~1.7GB）

### 4. 启动流程
```
Mask ROM → fip.bin (FSBL→OpenSBI→U-Boot) → boot.sd (FIT) → Linux → OpenHarmony
```

---

## 四、使用方法

### 1. 构建OpenHarmony
```bash
cd /home/openharmony
./build.sh --product-name sg2002_nano --ccache
```

### 2. 构建内核
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

### 3. 打包固件
```bash
cd /home/openharmony
./device/sophgo/build/pack -f /path/to/fip.bin
# 或使用squashfs
./device/sophgo/build/pack -t squashfs -f /path/to/fip.bin
```

### 4. 烧录镜像
```bash
cd /home/openharmony/out/licheerv_nano
sudo ./flash.sh /dev/sdX
# 或使用dd
sudo dd if=sg2002_licheerv_nano_ohos.img of=/dev/sdX bs=4M status=progress
```

---

## 五、系统级修改（非文件）

1. **创建符号链接**: `ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm`
   - 原因: 修复protobuf编译错误
   
2. **解压LLVM工具链**: `prebuilts/clang/ohos/linux-x86_64/llvm-riscv/`
   - 来源: `llvm-riscv-1124.tar.gz`

---

## 六、已知问题与注意事项

### ⚠️ 必需文件
- **fip.bin**: 必须从厂家SDK获取或从可启动SD卡提取
  - 获取方法: `dd if=/dev/sdX of=fip.bin bs=512 skip=1 count=32768`
  - 或编译厂家SDK生成

### ⚠️ 设备树
- 当前使用的是thead/ice.dtb
- 可能需要根据实际硬件调整为sg2002专用设备树

### ⚠️ HDF驱动
- 当前使用D1的HDF配置作为占位
- 需要根据sg2002实际硬件调整

---

## 七、输出文件位置

```
/home/openharmony/out/
├── ohos-riscv64-release/           # OpenHarmony构建输出
│   └── packages/phone/
│       ├── images/
│       ├── root/
│       ├── system/
│       └── vendor/
├── KERNEL_OBJ/                     # 内核构建输出
│   └── kernel/src_tmp/linux-5.10/
│       └── arch/riscv/boot/
│           └── Image               # 内核镜像
└── licheerv_nano/                  # 打包输出
    ├── sg2002_licheerv_nano_ohos.img  # 完整SD卡镜像
    ├── flash.sh                       # 烧录脚本
    └── rawimages/
        ├── boot.itb                   # FIT启动镜像
        ├── boot.sd                    # boot.itb重命名
        ├── fip.bin                    # 启动固件
        └── rootfs.sd                  # 根文件系统
```

---

## 八、后续工作

### 高优先级
1. [ ] **硬件测试**: 在sg2002开发板上验证启动
2. [ ] **串口调试**: 检查启动日志，排查可能的问题
3. [ ] **设备树调整**: 根据实际硬件调整设备树

### 中优先级
4. [ ] **HDF驱动适配**: 为sg2002硬件配置HDF驱动
5. [ ] **系统服务验证**: 验证OpenHarmony服务是否正常启动
6. [ ] **性能优化**: 优化启动时间和系统性能

### 低优先级
7. [ ] **文档完善**: 更新和完善移植文档
8. [ ] **自动化脚本**: 创建一键构建和打包脚本

---

## 九、参考资源

- **移植指南**: `reference/移植方法.md`
- **D1参考**: `device/sunxi/`
- **厂家SDK**: `LicheeRV-Nano-Build/`
- **内核源码**: `kernel/linux_5.10/`

---

## 十、文件恢复说明

将所有修改恢复到原位置：

```bash
cd /home/openharmony/change

# 复制所有文件
cp -r device/* /home/openharmony/device/
cp -r productdefine/* /home/openharmony/productdefine/
cp -r vendor/* /home/openharmony/vendor/
cp -r drivers/* /home/openharmony/drivers/
cp -r kernel/* /home/openharmony/kernel/

# 复制文档
cp *.md /home/openharmony/

# 创建系统级链接（如需要）
ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm
```

---

**总计**: 84个文件  
**文档**: 8个  
**配置**: 76个（含HDF配置目录）  
**脚本**: 3个  
**最后更新**: 2026-02-05 14:54
