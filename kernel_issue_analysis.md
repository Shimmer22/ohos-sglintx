# 为什么没有Kernel？ - 问题分析

## 问题描述

在成功构建OpenHarmony标准系统后（生成system.img, vendor.img等），发现没有生成Linux内核镜像（Image）。

## 根本原因分析

### 1. OpenHarmony构建系统的分工

OpenHarmony的构建系统分为两部分：

| 部分 | 构建工具 | 输出 | 说明 |
|------|----------|------|------|
| **用户态组件** | GN + Ninja | system.img, vendor.img, userdata.img | 通过 `./build.sh` 构建 |
| **内核** | Make + GCC | Image (Linux内核) | 需要单独构建 |

### 2. 标准系统构建流程

标准系统构建 (`./build.sh --product-name sg2002_nano`) 只构建：
- 第三方库 (third_party)
- 系统服务 (startup, hiviewdfx等)
- 应用框架 (ace, aafwk等)
- 驱动框架 (hdf)
- 生成rootfs镜像

**不构建内核！**

### 3. 内核构建的正确流程

参考Allwinner D1的做法：

```
1. 构建OH用户态: ./build.sh --product-name sunxi_d1
2. 单独构建内核: 通过 kernel/linux/patches/ 下的脚本
3. 打包固件: ./device/sunxi/build/pack
```

### 4. 我们的配置现状

虽然我们配置了：
- `device/sophgo/sg2002_nano/kernel/BUILD.gn` - 定义了kernel action
- `device/sophgo/sg2002_nano/BUILD.gn` - 依赖 kernel:kernel
- `kernel/linux/patches/kernel-5.10.mk` - 内核Makefile
- `kernel/linux/patches/kernel_module_build.sh` - 构建脚本

**但是**：标准系统的 `ohos-riscv64` 产品继承的 `_ohos_riscv64_parts.json` 中**没有kernel子系统**！

```json
// _ohos_riscv64_parts.json 中没有kernel组件
{
  "parts": {
    "ace:ace_engine_standard": {},
    "startup:init": {},
    // ... 其他组件
    // 注意：没有 "kernel:linux_5_10" 或类似组件
  }
}
```

### 5. 为什么D1能构建内核？

查看D1的产品配置：
```json
// sunxi_d1.json
{
  "product_name": "sunxi_d1",
  "parts": {
    "sunxi_products:sunxi_products": {}  // 包含内核构建
  }
}
```

D1的 `sunxi_products` 子系统中包含了内核构建。而 `_ohos_riscv64_parts.json` 是通用RISC-V配置，**不包含内核**。

## 解决方案

### 方案1: 单独构建内核 (推荐)

与D1类似，内核单独构建：

```bash
# 1. 构建OH用户态
cd /home/openharmony
./build.sh --product-name sg2002_nano --ccache

# 2. 单独构建内核
cd kernel/linux/patches
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN_PREFIX/gcc

# 构建内核
export TARGET_PRODUCT=sg2002_nano
export OUT_DIR=/home/openharmony/out/KERNEL_OBJ
export OHOS_ROOT_PATH=/home/openharmony

make -f kernel-5.10.mk

# 3. 打包
# 需要创建 device/sophgo/build/pack 脚本
```

### 方案2: 将内核添加到产品配置

修改产品配置，添加kernel子系统：

```json
// vendor/sophgo/sg2002_nano/config.json
{
  "subsystems": [
    {
      "subsystem": "kernel",
      "components": [
        { "component": "linux_5_10", "features": [] }
      ]
    }
  ]
}
```

然后需要在 `device/sophgo/sg2002_nano/BUILD.gn` 中确保kernel action被调用。

### 方案3: 使用pack脚本集成

参考D1创建pack脚本：

```bash
# device/sophgo/build/pack
# 1. 调用内核构建
# 2. 打包boot.img (kernel + ramdisk)
# 3. 生成完整固件
```

## 当前构建结果

已完成的构建：
- ✅ system.img (1.5GB) - 系统分区
- ✅ vendor.img (256MB) - 厂商分区
- ✅ userdata.img (1.4GB) - 用户数据分区
- ✅ updater.img (20MB) - 升级程序

缺失的：
- ❌ Image (Linux内核) - 需要单独构建
- ❌ boot.img (内核+ramdisk) - 需要打包

## 下一步行动

1. **验证内核单独构建** - 测试kernel-5.10.mk是否能正常工作
2. **创建pack脚本** - 参考D1创建固件打包工具
3. **集成到构建流程** - 决定是单独构建还是集成到标准构建

## 相关文件

- `kernel/linux/patches/kernel-5.10.mk` - 内核Makefile
- `kernel/linux/patches/kernel_module_build.sh` - 构建脚本
- `device/sophgo/sg2002_nano/kernel/` - 内核构建配置
- `device/sunxi/build/pack` - D1打包脚本参考
