# 仓库结构与职责

本文档说明 `ohos-sglintx` 中各目录/文件的用途，帮助后续移植时快速定位修改点。

## 1. 目录结构

- `device/sophgo/sg2002_nano/`
  - 设备构建入口、内核构建桥接、rootfs 相关构建定义。
- `vendor/sophgo/sg2002_nano/`
  - 产品配置、HDF 配置与板级资源。
- `productdefine/common/`
  - `sg2002_nano` 的产品和设备定义 JSON。
- `kernel/linux/patches/`
  - Linux 5.10 构建规则与补丁（核心是 `kernel-5.10.mk`）。
- `device/sophgo/build/pack`
  - 单镜像打包脚本（依赖厂商 SDK 的 `mkimage`、`genimage`）。
- `sg2002_fixed.dtb`
  - 打包时使用的固定 DTB。

## 2. 关键文件

- `kernel/linux/patches/kernel-5.10.mk`
  - 使用厂商 GCC 工具链构建 Linux 5.10。
  - 在 defconfig 后强制校准 Binder 关键选项，避免配置回写。
- `kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch`
  - OpenHarmony 必需内核配置补丁（包括 Binder、文件系统等）。
- `device/sophgo/build/pack`
  - 产出 `out/licheerv_nano/sg2002_licheerv_nano_ohos.img`。

## 3. 最小复现需要同步的内容

从本仓库同步到 OH 主源码树时，至少包含：

- `device/sophgo`
- `vendor/sophgo`
- `productdefine/common/products/sg2002_nano.json`
- `productdefine/common/device/sg2002_nano.json`
- `drivers/peripheral/camera/hal/adapter/chipset/gni/camera.sg2002_nano.gni`
- `kernel/linux/patches/kernel-5.10.mk`
- `kernel/linux/patches/kernel_module_build.sh`
- `kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch`

