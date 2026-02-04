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
- **Vendor SDK**: `LicheeRV-Nano-Build` (LicheeRV 官方 Buildroot SDK)
  - 路径: `./LicheeRV-Nano-Build` (参考内核配置和设备树)
  - 作用: 提供已验证的硬件配置、defconfig、设备树
- **参考移植**: 全志 D1 OpenHarmony 仓库
  - 路径：`./reference/Allwinner D1`
  - https://gitee.com/allwinnertech-d1/device_sunxi
  - https://gitee.com/allwinnertech-d1/manifest-sunxi-d1
  - 同为平头哥 C906 RISC-V 架构
  - 可参考架构适配和编译配置

## 核心路径

### 产品与板级配置
> todo

### 内核相关路径
> todo 

### 设备树 (Device Tree)
- **源文件位置** (LicheeRV-Nano-Build):
  - 主板 DTS: `LicheeRV-Nano-Build/build/boards/sg200x/sg2002_licheervnano_sd/dts_riscv/sg2002_licheervnano_sd.dts`
  - 公共 DTSI: `LicheeRV-Nano-Build/build/boards/default/dts/sg200x/soph_*.dtsi`
- **编译时位置**: `out/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/cvitek/`
- **编译产物**: `out/kernel/OBJ/linux-5.10/arch/riscv/boot/dts/cvitek/*.dtb`
- **最终输出**: `out/SGLinTx/packages/phone/images/sg2002_licheervnano_sd.dtb`

### 输出镜像
> todo

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
> todo

# 用户交互习惯

- 将用户的习惯写入文档中，包括`AGENTS.md`,`change.md`,`NEXT_SESSION.md`以及`README.md`
- 用户的Git仓库是SGLinTx_Port下的仓库。但是没有用户明确的指令不要提交与推送
- 在对话中回答用户问题的时候，请使用中文；编写文档的时候请使用中文
- 编写代码，进行逻辑思考的时候请使用英文