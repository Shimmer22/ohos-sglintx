# SG2002 OpenHarmony Kernel Patches

## 说明

本目录包含SG2002内核移植所需的补丁文件。

## 补丁文件说明

- `hdf.patch`: HDF (Hardware Driver Foundation) 补丁，从ARM适配到RISC-V架构
- `sg2002.patch`: SG2002硬件驱动补丁（如有修改）
- `README_zh.md`: 本文件

## HDF补丁修改要点

HDF补丁针对RISC-V架构进行了适配：

1. **链接脚本修改**：`arch/riscv/kernel/vmlinux.lds.S`
   - 添加HDF段定义：`.init.hdf_table`
   - 定义HDF驱动符号：`_hdf_drivers_start` 和 `_hdf_drivers_end`

2. **驱动配置**：
   - `drivers/Kconfig`: 添加HDF配置项
   - `drivers/Makefile`: 添加HDF编译入口
   - `drivers/hdf/`: 创建HDF目录和软链接

3. **依赖**：
   - HDF框架源码位于：`drivers/hdf_core/`
   - HDF适配代码位于：`drivers/hdf_core/adapter/khdf/linux/`

## 参考资源

- ARM版本HDF补丁：`kernel/linux/patches/linux-5.10/hi3516dv300_patch/hdf.patch`
- Allwinner D1 RISC-V移植：`reference/Allwinner D1/`
- LicheeRV-Nano-Build内核: `LicheeRV-Nano-Build/linux_5.10/`

## 使用方法

编译时通过`build_kernel.sh`脚本自动应用：
```bash
cd ${KERNEL_SRC_TMP_PATH}
patch -p1 < hdf.patch
patch -p1 < sg2002.patch
```
