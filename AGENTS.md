# SGLinTx OpenHarmony 移植项目 - AI Agent 上下文

## 项目概览
**目标**: 将 OpenHarmony Standard System 移植到 Sophgo SG2002 (LicheeRV Nano) 开发板

## 环境信息
- **OpenHarmony 版本**: 3.2 Release (Standard System / L2)
- **内核版本**: Linux 5.10.4
- **目标架构**: RISC-V 64 (`riscv64`)
- **芯片**: Sophgo SG2002 (双核 RISC-V C906@1GHz + ARM A53)
- **工作环境**: Docker 容器 `ohos_build_env`

## 参考资源
- **Vendor SDK**: `lichee_sdk` (LicheeRV 官方 Buildroot SDK)
  - 路径: `/path/to/lichee_sdk` (参考内核配置和设备树)
  - 作用: 提供已验证的硬件配置、defconfig、设备树
- **参考移植**: 全志 D1 OpenHarmony 仓库
  - 同为平头哥 C906 RISC-V 芯片
  - 可参考架构适配和编译配置

## 核心路径

### 产品与板级配置
- **产品定义**: `vendor/Humpback/SGLinTx/config.json`
  - 版本: `"version": "3.0"` (OpenHarmony 3.2)
  - 类型: `"type": "standard"` (标准系统)
  - 架构: `"target_cpu": "riscv64"`
- **板级目录**: `device/board/Humpback/SGLinTx/`
  - `BUILD.gn` - 板级编译入口
  - `ohos.build` - 子系统注册
  - `kernel/` - 内核构建脚本目录

### 内核相关路径
- **内核源码**: `lichee_sdk/linux_5.10/` (Vendor SDK)
  - 编译时复制到: `out/kernel/src_tmp/linux-5.10/`
- **内核配置**: `kernel/linux/config/linux-5.10/SGLinTx_small_defconfig`
  - 也位于: `device/board/Humpback/SGLinTx/kernel/SGLinTx_small_defconfig`
- **内核补丁**: `kernel/linux/patches/linux-5.10/SGLinTx_patch/`
- **构建脚本**: `device/board/Humpback/SGLinTx/kernel/build_kernel.sh`
- **打包脚本**: `device/board/Humpback/SGLinTx/kernel/package_ohos.sh`

### 设备树 (Device Tree)
- **源文件位置** (lichee_sdk):
  - 主板 DTS: `lichee_sdk/build/boards/sg200x/sg2002_licheervnano_sd/dts_riscv/sg2002_licheervnano_sd.dts`
  - 公共 DTSI: `lichee_sdk/build/boards/default/dts/sg200x/soph_*.dtsi`
- **编译时位置**: `out/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/cvitek/`
- **编译产物**: `out/kernel/OBJ/linux-5.10/arch/riscv/boot/dts/cvitek/*.dtb`
- **最终输出**: `out/SGLinTx/packages/phone/images/sg2002_licheervnano_sd.dtb`

### 输出镜像
- **组件镜像**: `out/SGLinTx/packages/phone/images/`
  - `Image` - 内核镜像
  - `sg2002_licheervnano_sd.dtb` - 设备树
  - `ramdisk.img`, `system.img`, `vendor.img`, `userdata.img`
- **打包目录**: `out/SGLinTx/pack/`
  - `input/` - 临时文件 (boot.sd, fip.bin)
  - `output/ohos_sglintx.img` - **最终 SD 卡镜像** (3.14 GB)

## 快速命令

### Docker 环境
```bash
# 一键进入并编译
docker start ohos_build_env && docker exec -it ohos_build_env bash

# 在容器内执行编译
cd /home/openharmony
./build.sh --product-name SGLinTx --ccache
```

### 编译命令
```bash
# 完整编译
./build.sh --product-name SGLinTx --ccache

# 仅 GN 配置检查
./build.sh --product-name SGLinTx --build-only-gn

# 单独编译内核 (在 board 目录)
./kernel/build_kernel.sh
```

## 技术配置详解

### FIT 镜像结构 (boot.sd)
由 `package_ohos.sh` 生成,包含:
- **kernel-1**: `Image` @ 0x80200000 (加载和入口地址)
- **fdt-sg2002_licheervnano_sd**: 设备树
- **ramdisk-1**: 初始 RAM 磁盘
- **配置节点**: `config-sg2002_licheervnano_sd`

### 启动流程
```
BootROM → FSBL (fip.bin) → OpenSBI → U-Boot
  → 读取 boot.sd → 加载 kernel/dtb/ramdisk → 跳转 0x80200000
```

### Boot 分区文件 (FAT16, 16MB)
1. `fip.bin` - 固件包 (FSBL+OpenSBI+U-Boot)
2. `boot.sd` - FIT 镜像
3-7. `usb.dev`, `usb.ncm`, `usb.rndis`, `wifi.sta`, `gt9xx` - 环境标记
8. `logo.jpeg` - 启动 Logo
9. `ver` - 版本信息

### 内核编译配置
- **工具链**: LLVM/Clang + GCC 汇编器
- **Vector 扩展**: `-Wa,-march=rv64imafdcv0p7`
- **禁用 Relaxation**: `-Wa,-mno-relax`
- **内存模型**: `CONFIG_CMODEL_MEDANY=y`
- **KALLSYMS**: 暂时禁用 (链接问题)

# 用户交互习惯

- 将用户的习惯写入文档中，包括`AGENTS.md`,`change.md`,`NEXT_SESSION.md`以及`README.md`
- 用户的Git仓库是SGLinTx_Port下的仓库。但是没有用户明确的指令不要提交与推送
- 在对话中回答用户问题的时候，请使用中文；编写文档的时候请使用中文
- 编写代码，进行逻辑思考的时候请使用英文