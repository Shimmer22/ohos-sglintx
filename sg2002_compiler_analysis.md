# SG2002芯片移植 - 编译器使用分析报告

## 一、概述

本文档详细分析SG2002 (LicheeRV Nano)芯片移植到OpenHarmony时各组件使用的编译器情况。

---

## 二、各组件编译器详细说明

### 2.1 Linux内核 (Linux 5.10.4)

**编译器**: `riscv64-unknown-linux-gnu-gcc` (GCC 10.2.0)

**详细信息**:
- **来源**: LicheeRV-Nano-Build SDK自带
- **路径**: `LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/bin/`
- **版本**: Xuantie-900 linux-5.10.4 glibc gcc Toolchain V2.6.1 B-20220906
- **内核配置验证**:
  ```
  CONFIG_CC_VERSION_TEXT="riscv64-unknown-linux-gnu-gcc (Xuantie-900 linux-5.10.4 glibc gcc Toolchain V2.6.1 B-20220906) 10.2.0"
  CONFIG_CC_IS_GCC=y
  CONFIG_GCC_VERSION=100200
  ```

**编译选项** (从`build/config/compiler/BUILD.gn:726-738`):
```gn
cflags += [
  "-march=rv64imafdc",
  "-mabi=lp64d",
  "-mno-relax",
]
```

---

### 2.2 OpenHarmony用户态组件

**编译器**: `clang` / `clang++` (LLVM 12.0.1)

**详细信息**:
- **路径**: `prebuilts/clang/ohos/linux-x86_64/llvm-riscv/`
- **目标三元组**: `riscv64-unknown-linux-gnu`
- **架构**: riscv64, current_os = "ohos"

**配置来源** (`build/config/clang/clang.gni:14-18`):
```gn
if (target_cpu == "riscv64") {
  clang_base_path = "//prebuilts/clang/ohos/${host_platform_dir}/llvm-riscv"
}
```

**工具链定义** (`build/toolchain/ohos/BUILD.gn:75-81`):
```gn
ohos_clang_toolchain("ohos_clang_riscv64") {
  sysroot = "${musl_sysroot}"
  lib_dir = "usr/lib/riscv64-linux-ohosmusl"
  toolchain_args = {
    current_cpu = "riscv64"
  }
}
```

**编译器组件**:
| 工具 | 路径 | 用途 |
|------|------|------|
| clang/clang++ | bin/clang | 主C/C++编译器 |
| llvm-ar | bin/llvm-ar | 静态库归档 |
| llvm-strip | bin/llvm-strip | 符号剥离 |
| lld | bin/lld | 链接器 |
| llvm-readobj | bin/llvm-readobj | 对象文件读取 |
| llvm-nm | bin/llvm-nm | 符号表查看 |

---

### 2.3 LLVM工具链内容 (llvm-riscv-1124.tar.gz)

**解压后目录结构**:
```
llvm-riscv/
├── bin/
│   ├── clang, clang++          # 编译器
│   ├── llvm-ar, llvm-strip     # 工具
│   └── lld                     # 链接器
├── lib/
│   ├── riscv64-linux-ohosmusl/c++/
│   │   ├── libc++.so.1         # C++标准库
│   │   ├── libc++abi.so.1      # C++ ABI
│   │   ├── libatomic.so.1      # 原子操作
│   │   └── libunwind.so.1      # 栈展开
│   └── clang/12.0.1/lib/riscv64-linux-ohosmusl/
│       └── libclang_rt.*       # compiler-rt运行时
└── include/                     # 头文件
```

**构建配置** (参考`BUILD_OH_LLVM_TOOLCHAIN.md`):
- 基于 LLVM 12.0.1
- 使用 musl libc 1.2.2
- 需要riscv-gnu-toolchain提供libatomic

---

### 2.4 musl libc 库

**编译器**: Clang (交叉编译)

**详细信息**:
- 使用上述llvm-riscv工具链
- 配置参数:
  ```bash
  ARCH=riscv \
  CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
  CC="clang" \
  CFLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -z separate-code"
  ```

**来源** (`build/common/musl/BUILD.gn`):
| 库文件 | 用途 |
|--------|------|
| ld-musl-riscv.so.1 | 动态链接器 |
| libc++.so.1 | C++标准库 |
| libc++abi.so.1 | C++ ABI库 |
| libatomic.so.1 | 原子库(从gcc复制) |
| libunwind.so.1 | 异常处理/栈展开 |

---

### 2.5 U-Boot / Bootloader

**编译器**: SDK自带GCC

**详细信息**:
- **来源**: `LicheeRV-Nano-Build/host-tools/gcc/`
- 可选工具链:
  - `riscv64-linux-x86_64` (glibc)
  - `riscv64-linux-musl-x86_64` (musl)
- 架构: RV64GC

---

## 三、与Allwinner D1的对比

| 组件 | D1 (参考平台) | SG2002 (目标平台) |
|------|---------------|-------------------|
| **内核GCC** | thead glibc 20200702 | Xuantie-900 V2.6.1 (GCC 10.2.0) |
| **内核版本** | Linux 5.4 | Linux 5.10.4 |
| **OH用户态** | llvm-riscv (clang 12) | llvm-riscv (clang 12) |
| **libc** | musl | musl |
| **目标三元组** | riscv64-unknown-linux-gnu | riscv64-unknown-linux-gnu |
| **芯片架构** | RV64GC | RV64 (C906/A53) |

---

## 四、关键配置文件

1. **工具链选择**: `build/config/clang/clang.gni`
2. **编译选项**: `build/config/compiler/BUILD.gn` (726-738行)
3. **工具链定义**: `build/toolchain/ohos/BUILD.gn`
4. **musl配置**: `build/common/musl/BUILD.gn`
5. **内核构建**: `kernel/linux/patches/kernel_module_build.sh`

---

## 五、部署步骤

### 5.1 解压LLVM工具链

```bash
cd /home/openharmony
mkdir -p prebuilts/clang/ohos/linux-x86_64/llvm-riscv
tar -xzf llvm-riscv-1124.tar.gz -C prebuilts/clang/ohos/linux-x86_64/llvm-riscv/ --strip-components=1
```

### 5.2 复制GCC工具链 (可选)

内核编译直接使用LicheeRV-Nano-Build中的工具链，如需在OH中统一使用:

```bash
cp -r LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64 \
  prebuilts/gcc/linux-x86/riscv/riscv64-sg2002-gcc
```

### 5.3 验证编译器

```bash
# LLVM
prebuilts/clang/ohos/linux-x86_64/llvm-riscv/bin/clang --version

# GCC (内核用)
LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/bin/riscv64-unknown-linux-gnu-gcc --version
```

---

## 六、注意事项

1. **工具链版本**: LLVM使用12.0.1，GCC使用10.2.0
2. **架构标志**: 必须使用`-march=rv64imafdc -mabi=lp64d`
3. **链接器**: 使用lld而非bfd/gold
4. **sysroot**: 指向musl库路径
5. **libatomic**: 需要从GCC工具链复制到LLVM目录

---

*文档生成时间: 2026-02-05*
*基于: OpenHarmony 3.0 LTS + LicheeRV-Nano-Build SDK*
