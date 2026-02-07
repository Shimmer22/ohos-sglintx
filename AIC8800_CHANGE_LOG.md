# AIC8800 Wi-Fi 驱动移植变更记录

本文档总结了将 AIC8800 Wi-Fi 驱动移植到 OpenHarmony SG2002 LicheeRV Nano 平台所做的更改。

## 修改的文件

### 1. `device/sophgo/build/pack`
*   **原文件**: 标准打包脚本（基于 `pack_v3`）。
*   **变更内容**:
    *   添加了将 AIC8800 固件从 `temp_firmware` 复制到 `/usr/lib/firmware/aic8800_sdio/` 的逻辑。
    *   添加了将编译好的驱动模块 (`aic8800_bsp.ko`, `aic8800_fdrv.ko`) 复制到 `/vendor/lib/modules/` 的逻辑。
    *   注入了 `/vendor/etc/init/aic8800.cfg` 的生成逻辑，以便在启动时自动加载模块。
    *   增加了 `genext2fs` 的 inode 计数 (`-N 150000`) 以防止文件系统耗尽。
    *   默认文件系统类型设置为 `ext4`（隐含使用）。

### 2. `device/sophgo/sg2002_nano/drivers/wifi/build_aic8800.sh` (新文件)
*   **用途**: 用于编译树外 AIC8800 驱动的脚本。
*   **主要操作**:
    *   设置交叉编译环境变量。
    *   在内核源码上运行 `make modules_prepare`。
    *   针对内核头文件编译 `aic8800_bsp` 和 `aic8800_fdrv` 模块。

### 3. `build_kernel_fixed.sh`
*   **变更内容**:
    *   在编译前添加 `sed` 命令，强制在内核 `.config` 中设置 `CONFIG_CFG80211=y` 和 `CONFIG_RFKILL=y`。
    *   这确保了 Wi-Fi 栈支持是内置的，从而解决了驱动模块的符号依赖问题。

### 4. `kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch`
*   **变更内容**:
    *   追加了 `CONFIG_CFG80211=y` 和 `CONFIG_RFKILL=y`。
    *   注意: `build_kernel_fixed.sh` 也会在编译过程中强制执行这些设置，以保证它们被应用。

## 使用方法

1.  **编译内核**:
    ```bash
    ./build_kernel_fixed.sh
    ```
2.  **编译驱动**:
    ```bash
    ./device/sophgo/sg2002_nano/drivers/wifi/build_aic8800.sh
    ```
3.  **打包镜像**:
    ```bash
    ./device/sophgo/build/pack -t ext4 -f /path/to/fip.bin
    ```
