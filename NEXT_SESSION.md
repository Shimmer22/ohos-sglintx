# OpenHarmony SGLinTx 移植项目 - 下一步行动指南

**最后更新**: 2026-02-03  
**当前状态**: ✅ OHOS 内核编译成功，❌ 启动后 Console 静默

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
- ✅ **OHOS 内核编译成功** (使用 llvm-riscv-1124 + GCC ld)
- ✅ 镜像打包完成
- ✅ BootROM → FSBL → U-Boot 启动链成功
- ✅ **内核成功加载并跳转** ("Starting kernel ...")
- ❌ **内核启动后 Console 静默** - 深层问题待解决

---

## 🔄 2026-02-03 调试记录

### OHOS 内核编译调试全过程

#### 问题起源
使用 `SGLinTx_small_defconfig` 编译的内核无法启动（console 静默）

#### 调试尝试 1: 配置文件完整性验证
**发现**: small_defconfig 严重不足
- SGLinTx_small_defconfig: **1,021 项**
- Vendor .config: **4,830 项**
- **结论**: 缺少大量关键配置

**验证方案**: 使用 Vendor 预编译内核
- ✅ 成功启动并看到 console 输出
- ✅ OHOS userspace 组件开始运行（HiLogAdapter）
- **确认**: 问题在于配置不足，非 DTS/bootargs

#### 调试尝试 2: 创建 SGLinTx_vendor_defconfig
从 Vendor .config 提取 **1,126 个配置项**，创建 `SGLinTx_vendor_defconfig`

#### 调试尝试 3: 配置 llvm-riscv-1124 工具链

**工具链**: D1 项目推荐的 llvm-riscv-1124 (685MB)
- clang-12
- LLVM 12.0.1 完整工具集
- 专为 RISC-V 优化

**安装位置**: `/prebuilts/clang/ohos/linux-x86_64/llvm-riscv/`

#### 调试尝试 4: 解决编译错误

**错误 1: HOSTCC libc 问题**
```
/usr/bin/ld: cannot find /usr/lib/x86_64-linux-gnu/libc_nonshared.a
```
**解决**: 强制宿主工具使用系统 GCC
```bash
make HOSTCC=gcc HOSTCXX=g++ ...
```

**错误 2: V4L2 驱动 - copy_in_user 未定义**
```
v4l2-compat-ioctl32.c:163:6: error: implicit declaration of function 'copy_in_user'
```
**第一次解决**: 禁用所有 MEDIA/V4L2/VIDEO 配置（29 项）

**错误 3: Android ION - compat_alloc_user_space 未定义**
```
compat_ion.c:58:10: error: implicit declaration of function 'compat_alloc_user_space'
```
**第一次解决**: 禁用所有 ANDROID 和 STAGING 配置

**错误 4: KALLSYMS 链接器重定位错误**
```
ld.lld: error: relocation R_RISCV_PCREL_HI20 out of range: 33552792
```
**解决**: 
1. 禁用 `.config` 中的 KALLSYMS
2. **使用 GCC 链接器替代 LLVM ld.lld**
```bash
make ... LD=${CROSS_COMPILE}ld ...
```

#### 调试尝试 5: 第一次编译成功（过度精简）

**配置**: 禁用 KALLSYMS + MEDIA + ANDROID + STAGING (**67项**)
- ✅ 编译成功
- ✅ 生成 Image (17MB)
- ✅ 打包镜像成功
- **测试结果**: ❌ 内核静默启动（禁用太多配置）

#### 调试尝试 6: 使用完整配置重新编译

**更正策略**: **只禁用 2 项 KALLSYMS**，保留所有其他配置
- 重新从 Vendor .config 提取完整配置（4,537 行）
- 保留 MEDIA/V4L2/Android ION/Staging 驱动

**意外发现**: 之前担心的 copy_in_user/ION 错误**没有出现**！
- 可能原因：那些代码是模块（=m）或未触发条件编译

**编译结果**:
- ✅ 编译成功
- ✅ Image 生成 (10 MB)
- ✅ 打包成功

**测试结果**: ❌ **仍然静默启动**

---

## 📊 内核分析结果

### 使用工具: `SGLinTx_Port/analyze_kernel.py`

### 关键差异

| 项目 | OHOS 内核 | Vendor 内核 | 差异 |
|------|-----------|-------------|------|
| **大小** | 10.48 MB | 9.21 MB | **+1.27 MB (+13.83%)** |
| **Entry Code** | 0x00010760106f5a4d | 0x00010760106f5a4d | ✅ 相同 |
| **Flags** | 0x00a41000 | 0x0090a000 | ❌ 不同 |
| **Magic** | RISCV | RISCV | ✅ 相同 |
| **版本** | clang 12.0.1 | GCC 10.2.0 (Xuantie-900) | 编译器不同 |

### 配置字符串检查

Both kernels:
- ✅ 包含 "earlycon"
- ❌ 不包含 "CONFIG_CMDLINE"（被编译优化移除）
- ❌ 不包含 "console=ttyS0"
- ❌ 不包含 "keep_bootconsole"

---

## 🎓 技术总结

### 成功的工具链配置

| 组件 | 工具 | 来源 |
|------|------|------|
| **C 编译器** | clang-12 | llvm-riscv-1124 |
| **汇编器** | GAS | lichee_sdk GCC (支持 v0.7 vector) |
| **链接器** | ld | OHOS GCC（避免 ld.lld 问题）|
| **宿主工具** | gcc/g++ | 系统 GCC |

### 关键的 build_kernel.sh 配置

```bash
# 使用 llvm-riscv 工具链
CLANG_BASE=${ROOT_DIR}/prebuilts/clang/ohos/linux-x86_64/llvm-riscv
export PATH=${CLANG_BASE}/bin:$PATH

# 使用 Vendor SDK 的 GCC 汇编器
export CROSS_COMPILE=${ROOT_DIR}/lichee_sdk/host-tools/gcc/.../riscv64-unknown-linux-gnu-

# 编译参数
make ARCH=riscv \
     LLVM=1 \
     LLVM_IAS=0 \
     HOSTCC=gcc \
     HOSTCXX=g++ \
     LD=${CROSS_COMPILE}ld \
     -j$(nproc) Image dtbs
```

### Defconfig 配置

**最终版本**: `SGLinTx_vendor_defconfig` (4,537 行)
- ✅ 基于 Vendor .config 完整提取
- ✅ 保留所有 MEDIA/V4L2/Android ION/Staging 驱动
- ❌ **只禁用 2 项**: CONFIG_KALLSYMS, CONFIG_KALLSYMS_BASE_RELATIVE

---

## ❌ 未解决的核心问题

### 内核静默启动

**现象**:
```
Starting kernel ...
← 完全静默，无任何输出
```

**已验证不是以下问题**:
- ✅ FIT 配置正确 (config@1)
- ✅ DTB 校验通过 (sha256)
- ✅ 内核 CRC32 校验通过
- ✅ 加载地址正确 (0x80200000)
- ✅ Entry point 正确
- ✅ 内核大小合理（略大于 Vendor）

**可能的原因分析**:

1. **编译器差异导致的二进制不兼容**
   - OHOS: clang-12 + LLVM
   - Vendor: GCC 10.2.0 (Xuantie-900)
   - Flags 值不同：0x00a41000 vs 0x0090a000

2. **缺少关键的早期初始化代码**
   - 可能某些汇编代码在 LLVM 下有差异
   - 可能某些内联汇编语法不兼容

3. **DTB/Bootargs 传递问题**
   - chosen 节点可能被覆盖
   - earlycon 参数可能未正确解析

4. **CONFIG 配置的微妙差异**
   - 虽然大部分配置相同，但可能某些关键配置的组合有问题
   - 需要逐项对比 OHOS .config 和 Vendor .config

---

## 📝 Next Steps - 调试方向

### 方案 A: 深入对比配置文件 ⭐ 推荐

1. **提取并对比实际的 .config**
   ```bash
   # OHOS kernel .config
   /home/openharmony/out/kernel/OBJ/linux-5.10/.config
   
   # Vendor kernel .config  
   /home/openharmony/lichee_sdk/linux_5.10/build/sg2002_licheervnano_sd/.config
   ```

2. **关注的配置项**:
   - EARLY_PRINTK
   - SERIAL_8250_CONSOLE 
   - CMDLINE / CMDLINE_FORCE
   - RISC-V 特定的启动选项
   - SBI console 相关

3. **工具**: 创建自动化对比脚本

### 方案 B: 尝试使用 Vendor 的 GCC 工具链

**理由**: Vendor 使用 Xuantie-900 GCC 10.2.0
**可行性**: lichee_sdk 中已包含完整 GCC 工具链

**步骤**:
1. 修改 build_kernel.sh 使用 GCC 而非 LLVM
2. 处理可能的 Vector v0.7 汇编问题
3. 对比编译结果

### 方案 C: 调试 DTB 和 chosen 节点

1. **提取 DTB**:
   ```bash
   # 从 FIT 镜像提取
   dumpimage -T flat_dt -p 2 -o ohos.dtb boot.sd
   dumpimage -T flat_dt -p 2 -o vendor.dtb vendor_boot.sd
   ```

2. **反编译并对比**:
   ```bash
   dtc -I dtb -O dts -o ohos.dts ohos.dtb
   dtc -I dtb -O dts -o vendor.dts vendor.dtb
   diff -u vendor.dts ohos.dts
   ```

3. **重点检查**:
   - chosen/bootargs
   - chosen/stdout-path
   - serial@04140000 节点配置

### 方案 D: 内核启动日志捕获

**尝试**:
1. 配置 CONFIG_EARLY_PRINTK_RISC_V_SBI
2. 检查是否有 SBI console 重定向
3. 尝试通过 JTAG 调试器捕获早期输出

---

## 🔗 相关文件

### 工具脚本
- **`SGLinTx_Port/analyze_kernel.py`** - 内核镜像分析工具

### 核心配置
- **`kernel/linux/config/linux-5.10/SGLinTx_vendor_defconfig`** - 当前使用的 defconfig (4,537 行)
- **`device/board/Humpback/SGLinTx/kernel/build_kernel.sh`** - 构建脚本
- **`device/board/Humpback/SGLinTx/kernel/package_ohos.sh`** - 打包脚本

### 日志和输出
- **`walkthrough.md`** - 完整的编译成功记录
- **Docker 内**: `/tmp/rebuild.log` - 最新编译日志

---

## 💡 重要发现

1. **LLVM 可以编译 RISC-V 内核**，只要正确配置（clang + GCC as + GCC ld）
2. **KALLSYMS 必须禁用**，否则 LLVM ld.lld 会有重定位错误
3. **大部分 Vendor 配置可以在 LLVM 下工作**（MEDIA/ION 没有真正的编译错误）
4. **内核大小差异 13.83%** 是编译器优化级别和代码生成策略不同导致
5. **真正的问题可能不在配置层面**，而在二进制兼容性或早期启动代码

---

## 联系与支持

内核分析工具: `python3 SGLinTx_Port/analyze_kernel.py`
