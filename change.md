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

## 8. 最终状态

*   **内核构建**: **成功**。
*   **镜像打包**: **成功**。产出了包含所有分区的全盘镜像 `ohos_sglintx.img`。
*   **产物验证**:
    *   分区镜像: `out/SGLinTx/packages/phone/images/`
    *   全盘镜像: `out/SGLinTx/pack/output/ohos_sglintx.img` (约 3.3GB)。
*   **系统构建**: **成功**。完整生成了 `system.img`, `vendor.img`, `userdata.img` 等镜像文件。
