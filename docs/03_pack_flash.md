# 打包与烧录

本文档说明如何从构建产物生成 SG2002 单镜像并进行基础验证。

## 1. 前置条件

- 用户态构建完成：`./build.sh --product-name sg2002_nano --ccache`
- 内核构建完成：`make -f kernel-5.10.mk`
- 准备真实 `fip.bin`

## 2. 固定 DTB 准备

内核重建后需重新放置固定 DTB：

```bash
mkdir -p /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/thead
cp /home/openharmony/ohos-sglintx/sg2002_fixed.dtb \
  /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/thead/sg2002_fixed.dtb
```

## 3. 打包命令

```bash
cd /home/openharmony
./device/sophgo/build/pack -t ext4 -f /home/openharmony/fip.bin
```

说明：

- `-f` 必须是真实可启动 `fip.bin`
- 推荐 `-t ext4`（当前脚本稳定路径）

## 4. 产物位置

- 最终镜像：`out/licheerv_nano/sg2002_licheerv_nano_ohos.img`
- 中间文件：
  - `out/licheerv_nano/boot.vfat`
  - `out/licheerv_nano/genimage_input/boot.sd`
  - `out/licheerv_nano/genimage_input/rootfs.ext4`

## 5. 快速组成验证

```bash
fdisk -l /home/openharmony/out/licheerv_nano/sg2002_licheerv_nano_ohos.img
mdir -i /home/openharmony/out/licheerv_nano/boot.vfat ::
```

期望结果：

- 分区1：16MB FAT32（bootable）
- 分区2：Linux rootfs
- boot 分区至少包含 `fip.bin` 与 `boot.sd`

## 6. 烧录示例

```bash
sudo dd if=/home/openharmony/out/licheerv_nano/sg2002_licheerv_nano_ohos.img \
  of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

