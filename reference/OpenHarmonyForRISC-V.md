# OpenHarmony for RISC-V

## 概述

OpenHarmony for RISC-V旨在实现OpenHarmony对RISC-V平台的支持。

本文介绍目前在OpenHarmony for RISC-V的工作内容，工作进展，遇到的问题和计划，并提供进展的源码获取方式。

## 工作内容

- RISC-V工具链构建
OH采用llvm/clang工具链编译，需要根据OH所需依赖库定制支持riscv64架构的llvm/clang

- 编译构建系统添加riscv64架构选项
build公共编译配置文件中添加riscv64选项，包括工具链，编译配置，依赖库等

- 适配标准系统涉及的第三方库
依赖的部分第三方库与架构强相关

- 适配标准系统中各子系统
    1. 部分组件与架构强相关
    2. 部分组件和海思闭源库(ARM架构)强绑定

- 标准系统中RISC-V平台芯片移植
    1. 定义开发板（赛方科技-星光开发板-惊鸿7100和全志-哪吒开发板-D1）
    2. 内核移植，文件系统构建
    3. 驱动移植，包括LCD、触摸屏、WLAN等

## 工作进展

- 完成llvm/clang工具链的构建
    1. 支持riscv64
    2. clang12

- 完成标准系统涉及的第三方库的适配
    1. 架构强相关三方库：musl、grpc、openssl、boringssl、libffi、curl、libunwind、flutter
    2. OH编译环境中，完成标准系统涉及的所有三方库的编译

- 完成对标准系统各子系统组件的梳理和验证
    1. 完成子系统组件的编译构建

- 完成内核和最小文件系统构建
    1. 星光、哪吒开发板启动init进程，进入控制台

- 完成ohos-riscv64通用soc编译
    
## 主要问题

- LLVM/Clang工具链RISC-V平台支持情况
    1. 部分依赖不支持

- 海思闭源库

    1. 部分组件与与海思闭源库强相关：libdisplay_gralloc.z.so，libdisplay_device.z.so，libdisplay_gfx.z.so等
    OH 3.0 master源码中已提供display_gralloc和display_device的源码,display_gfx暂未支持，当前结合开源源码，先通过编译。

## 工作计划

- 继续推进OpenHarmony各子系统在RISC-V平台的移植适配工作
- 年底初步完成OpenHarmony对RISC-V架构的支持

## 源码获取
- 版本说明:
由于OpenHarmony更新较频繁，在OH-3.0-riscv64.xml中对各仓库进行了版本控制，后续会和主仓保持一致。
通过下面命令获取源码

- 前提条件
同[OpenHarmony官方](https://gitee.com/openharmony/docs/blob/master/zh-cn/device-dev/quick-start/quickstart-standard-docker-environment.md)注册gitee账号，安装配置git客户端和git-lfs以及安装码云repo工具。
1. 注册码云gitee账号。
2. 注册码云SSH公钥，请参考[码云帮助中心](https://gitee.com/help/articles/4191)。（使用https下载可跳过）
3. 安装[git客户端](https://git-scm.com/book/zh/v2/%E8%B5%B7%E6%AD%A5-%E5%AE%89%E8%A3%85-Git)和[git-lfs](https://gitee.com/vcs-all-in-one/git-lfs?_from=gitee_search#downloading)并配置用户信息。
4. 安装码云repo工具，可以执行如下命令。

```
curl -s https://gitee.com/oschina/repo/raw/fork_flow/repo-py3 > /usr/local/bin/repo  #如果没有权限，可下载至其他目录，并将其配置到环境变量中
chmod a+x /usr/local/bin/repo
pip3 install -i https://repo.huaweicloud.com/repository/pypi/simple requests
```

- 通过下面命令获取源码

```
repo init -u https://gitee.com/iscas-taiyang/manifest.git -m OH-3.0-riscv64.xml --no-repo-verify
repo sync -c
repo forall -c 'git lfs pull'
```

源码仓库主要有三个来源：

1.  OpenHarmony官方仓库 - https://gitee.com/openharmony
2.  iscas-taiyang支持riscv的仓库 - https://gitee.com/iscas-taiyang
3.  D1平台相关仓库 - https://gitee.com/allwinnertech-d1

## 执行prebuilts
- 在源码根目录下执行脚本，安装编译器及二进制工具。
```
bash build/prebuilts_download.sh
```
    下载prebuilts二进制默认存放到OpenHarmony同目录下的 prebuilts下。

## 构建编译环境
- 获取Docker镜像
    1. 获取Docker镜像。
    ```
    docker pull swr.cn-south-1.myhuaweicloud.com/openharmony-docker/openharmony-docker-standard:0.0.4
    ```
    2. 进入源码根目录执行如下命令，从而进入Docker构建环境。
    ```
    docker run -it -v $(pwd):/home/openharmony swr.cn-south-1.myhuaweicloud.com/openharmony-docker/openharmony-docker-standard:0.0.4
    ```
    3. 添加llvm riscv工具链

    从 https://pan.baidu.com/s/19JVNwFrl5ISOAsruW_y9hA 提取码: chds 下载llvm-riscv工具链llvm-riscv-1124.tar.gz（临时使用），解压到OpenHarmony/prebuilts/clang/ohos/linux-x86_64/llvm-riscv/

    4. 新的容器环境中GCC存在7.0，7.5.0和8.0（新增加的）版本，clang工具链会默认选择8.0，8.0版本缺少库，编译有问题，请删除8.0。clang将默认选择7.5.0版本，已验证，编译通过。
    ```
    rm -r /usr/lib/gcc/x86_64-linux-gnu/8.0
    ```
## 编译构建方法

OpenHarmony for RISC-V各子系统组件还在持续适配中，目前提供如下方式构建
- ohos-riscv64 soc完整编译
    ```
    ./build.sh --product-name ohos-riscv64 --ccache
    ```
- 单独编译组件和三方库，用于编译调试。
    1. 编译命令示例如下（需确定target名称，可从组件和三方库gn配置文件中查看）：
    ```
    ./build.sh --product-name ohos-riscv64 --ccache --build-target init
    ./build.sh --product-name ohos-riscv64 --ccache --build-target ffi
    ```
- 哪吒D1构建

    源码编译构建环境中D1支持内核和文件系统打包，方便开发者进行验证。
    1. [新建tina-d1目录（与OpenHarmony目录平级），全志d1下载以及公钥和git信息配置](https://d1.docs.aw-ol.com/study/study_2getsdk/)，下载完成后将tina-d1/prebuilt/gcc/linux-x86/riscv/toolchain-thead-glibc/riscv64-glibc-gcc-thead_20200702复制到OpenHarmony/prebuilts/gcc/linux-x86/riscv/riscv64-glibc-gcc-thead_20200702
    2. 编译源码
    ```
    ./build.sh --product-name sunxi_d1 --ccache
    ```
    3. 打包sunxi_d1固件
    - 生成ext4格式(可写)的rootfs(推荐)
    ```
    ./device/sunxi/build/pack -e
    ```
    如果打包过程中出现下面这类log，文件超过了分区的大小，修改device/sunxi/config/chips/d1/configs/nezha/sys_partition.fex，调大对应分区的size即可。
    ```
    ERROR: dl file rootfs.fex size too large
    ERROR: filename = rootfs.fex
    ERROR: dl_file_size = 254720 sector
    ERROR: part_size = 40824 sector
    ERROR: update mbr file fail
    ERROR: update_mbr failed
    ```
    rootfs size修改成829200
    ```
    [partition]
      name         = rootfs
    -    size         = 258048
    +    size         = 829200
    ```
    - 生成squashfs格式(只读，不可写，OH部分服务无法正常启动)
    ```
    ./device/sunxi/build/pack
    ```
    - 注意：如果出现ERROR: update_boot0 boot0_nand.fex run error错误，可以退出docker环境再次执行。

    4. sunxi_d1固件烧录
    - 烧写参考链接[D1编译和烧写](https://d1.docs.aw-ol.com/study/study_4compile/)
    - 默认打包的rootfs是squashfs类型，只读，不可写。执行: ./device/sunxi/build/pack -e，可生成ext4格式(可写)的rootfs，此时固件大小会超过256M（D1开发板flash总大小），无法直接烧写，需使用TF卡烧写方式。
    - [TF卡烧写工具:PhoenixCardv4.2.7.7z](https://www.aw-ol.com/downloads?cat=5)登录后下载，烧写时将TF卡设定为启动卡。

    来源[OpenHarmony 构建 d1_nezha](https://gitee.com/allwinnertech-d1/device_sunxi)

- 星光JH7100构建
    1. 编译源码
    ```
    ./build.sh --product-name ohos-riscv64 --ccache
    ```
    2. 构建文件系统
    ```
    cp ./device/sunxi/sunxi_d1/build/rootfs/init.cfg ./out/ohos-riscv64-release/packages/phone/system/etc/
    cp -r ./out/ohos-riscv64-release/packages/phone/root ./out/ohos-riscv64-release/packages/phone/rootfs
    cp -r ./out/ohos-riscv64-release/packages/phone/system ./out/ohos-riscv64-release/packages/phone/rootfs/
    cd ./out/ohos-riscv64-release/packages/phone/rootfs/
    find . | cpio -o -H newc | gzip > ../rootfs.cpio.gz
    ```
    3. 星光开发板OpenSBI、Uboot、linux内核构建以及启动系统请参考星光开发板技术手册(同目录:StarLight_Software_Technical_Reference_Manual.pdf)。
    
    注意:
    - 内核分支：beaglev-5.13.y 
    - 内核配置(arch/riscv/configs/beaglev_defconfig)添加：CONFIG_ANDROID=y CONFIG_ANDROID_BINDER_IPC=y （OH依赖BINDER）
    - uboot环境变量修改：setenv kernel_comp_addr_r 0xa0000000  （文件系统太大，uboot无法解压，启动之前需修改该配置）
