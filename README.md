# ohos-sglintx

SG2002（LicheeRV Nano）移植 OpenHarmony 标准系统（riscv64）的复现仓库。  
本仓库目标是提供一套可重复执行的流程：从全新源码环境出发，完成移植文件注入、用户态构建、内核构建、单镜像打包与结果验证。

## 文档索引（docs）

- `docs/01_repository_layout.md`：仓库结构与关键文件职责
- `docs/02_kernel_binder.md`：内核构建与 Binder 防错要求
- `docs/03_pack_flash.md`：打包、镜像组成验证与烧录
- `docs/04_troubleshooting.md`：常见问题排查
- `docs/05_repo_sync_recovery.md`：`repo sync` 损坏仓库自动修复流程

## 1. 仓库作用

- 提供 SG2002 对应的 `device/vendor/productdefine/kernel` 移植文件。
- 提供 Linux 5.10 内核构建规则（含 Binder 防回退修复）。
- 提供单镜像打包脚本（生成 `sg2002_licheerv_nano_ohos.img`）。
- 提供固定 DTB 与配套配置，减少环境漂移导致的失败。

## 2. 快速复现（从零环境）

### 2.1 拉取官方 Docker 镜像

```bash
docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2
```

### 2.2 创建新容器并挂载新目录

```bash
docker run -it --name ohos_new \
  -v ~/ohos_new:/home/openharmony \
  swr.cn-south-1.myhuaweicloud.com/openharmony-docker/docker_oh_standard:3.2 \
  /bin/bash
```

### 2.3 准备 repo 工具

```bash
curl https://gitee.com/oschina/repo/raw/fork_flow/repo-py3 -o /bin/repo
chmod a+x /bin/repo
pip3 install -i https://repo.huaweicloud.com/repository/pypi/simple requests
```

### 2.4 下载 riscv manifest（D1 基线）

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
repo init -u https://gitee.com/allwinnertech-d1/manifest-sunxi-d1.git -b master -m sunxi_d1.xml --no-repo-verify
repo sync -c
repo forall -c 'git lfs pull'
```

### 2.5 获取本移植仓库

```bash
cd /home/openharmony
git clone https://github.com/Shimmer22/ohos-sglintx.git
```

### 2.6 获取厂商 SDK

```bash
cd /home/openharmony
git clone https://github.com/sipeed/LicheeRV-Nano-Build --depth=1
cd LicheeRV-Nano-Build
git clone https://github.com/sophgo/host-tools --depth=1
```

说明：网络不稳定时可能失败，建议重试并优先保证 `LicheeRV-Nano-Build/host-tools` 完整可用。

## 3. 仓库文件如何使用

本仓库不是直接在仓库内编译，而是将文件同步到 OH 主源码树后构建。

在 `/home/openharmony` 执行：

```bash
cp -a ohos-sglintx/device/sophgo device/
cp -a ohos-sglintx/vendor/sophgo vendor/
cp -a ohos-sglintx/productdefine/common/products/sg2002_nano.json productdefine/common/products/
cp -a ohos-sglintx/productdefine/common/device/sg2002_nano.json productdefine/common/device/
cp -a ohos-sglintx/drivers/peripheral/camera/hal/adapter/chipset/gni/camera.sg2002_nano.gni \
  drivers/peripheral/camera/hal/adapter/chipset/gni/

mkdir -p kernel/linux/patches/linux-5.10
cp -a ohos-sglintx/kernel/linux/patches/kernel-5.10.mk kernel/linux/patches/
cp -a ohos-sglintx/kernel/linux/patches/kernel_module_build.sh kernel/linux/patches/
cp -a ohos-sglintx/kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch \
  kernel/linux/patches/linux-5.10/

cp -a ohos-sglintx/device/sophgo/build/pack device/sophgo/build/
```

## 4. 编译步骤

### 4.1 构建 OpenHarmony 用户态

```bash
cd /home/openharmony
./build.sh --product-name sg2002_nano --ccache
```

用户态产物目录：

- `out/ohos-riscv64-release/packages/phone/`
- `out/ohos-riscv64-release/packages/phone/images/`（system/vendor/userdata/updater）

### 4.2 构建 Linux 5.10 内核

```bash
cd /home/openharmony/kernel/linux/patches
export TARGET_PRODUCT=sg2002_nano
export OUT_DIR=/home/openharmony/out/KERNEL_OBJ
export OHOS_ROOT_PATH=/home/openharmony
export LICHEERV_SDK_PATH=/home/openharmony/LicheeRV-Nano-Build
export KERNEL_TARGET_TOOLCHAIN=$LICHEERV_SDK_PATH/host-tools/gcc/riscv64-linux-x86_64/bin
export KERNEL_TARGET_TOOLCHAIN_PREFIX=riscv64-unknown-linux-gnu-
export GNU_CC=$KERNEL_TARGET_TOOLCHAIN/riscv64-unknown-linux-gnu-gcc
make -f kernel-5.10.mk
```

内核产物：

- `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image`

## 5. Binder 错误（已知问题）

由于binder的一些配置问题，如果出现构建后cpu占用满，`hilog`日志中binder刷屏：

```
01-01 00:00:25.156   101   101 E 01510/BinderInvoker: TransactWithDriver: Binder Driver died
```

则需要确保修改的内核配置生效，见下面步骤：
### 5.1 已内置修复

本仓库已内置以下策略，避免再次出现 Binder 兼容问题：

- 目标模式对齐 D1：传统 `/dev/binder`，禁用 binderfs
- `sg2002_nano_kernel_config.patch` 中显式设置：
  - `CONFIG_ANDROID_BINDER_IPC=y`
  - `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
  - `# CONFIG_ANDROID_BINDERFS is not set`
- `kernel-5.10.mk` 在 `defconfig` 后进行强制校准并执行 `olddefconfig`，防止 Kconfig 依赖把配置回写。

### 5.2 每次构建后必检（不要跳过）

```bash
grep -E '^CONFIG_ANDROID=|^CONFIG_ANDROID_BINDER_IPC=|^CONFIG_ANDROID_BINDER_DEVICES=|^CONFIG_ANDROID_BINDERFS=|^# CONFIG_ANDROID_BINDERFS is not set' \
  /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/.config
```

必须看到：

- `CONFIG_ANDROID_BINDER_IPC=y`
- `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
- `# CONFIG_ANDROID_BINDERFS is not set`

若不满足，请不要继续打包，先检查是否使用了本仓库提供的 `kernel-5.10.mk` 与补丁文件。

## 6. 打包单镜像

### 6.1 准备固定 DTB

内核重新构建后，需放置固定 DTB：

```bash
mkdir -p /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/thead
cp /home/openharmony/ohos-sglintx/sg2002_fixed.dtb \
  /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/thead/sg2002_fixed.dtb
```

### 6.2 使用打包脚本

```bash
cd /home/openharmony
./device/sophgo/build/pack -t ext4 -f /home/openharmony/fip.bin
```

说明：

- `-f` 必须提供真实 `fip.bin`
- 当前建议使用 `-t ext4`（稳定路径）

## 7. 最终结果与验证

最终镜像：

- `out/licheerv_nano/sg2002_licheerv_nano_ohos.img`

打包中间产物：

- `out/licheerv_nano/boot.vfat`
- `out/licheerv_nano/genimage_input/boot.sd`
- `out/licheerv_nano/genimage_input/rootfs.ext4`

镜像结构快速验证：

```bash
fdisk -l /home/openharmony/out/licheerv_nano/sg2002_licheerv_nano_ohos.img
mdir -i /home/openharmony/out/licheerv_nano/boot.vfat ::
```

期望：

- 分区1：FAT32，16MB，bootable
- 分区2：Linux rootfs
- boot 分区至少包含：`fip.bin`、`boot.sd`

## 8. 常见问题

### 8.1 `repo sync` 或 SDK 克隆失败

- 重试（网络抖动常见）
- 分步拉取（先主仓库，再子仓库）
- 优先确保 `LicheeRV-Nano-Build/host-tools` 完整

### 8.2 打包时报 `Fixed DTB not found`

按“6.1 准备固定 DTB”重新拷贝后再打包。

### 8.3 Binder 仍异常

先执行“5.2 每次构建后必检”，确认最终 `.config` 不是 binderfs 模式，再上板测试。
