# SGLinTx OpenHarmony 移植架构设计

## 一、总体架构

### 目标
将 OpenHarmony Standard System (L2) 移植到 Sophgo SG2002 (LicheeRV Nano) 开发板

### 技术栈
- **OpenHarmony 版本**: 3.2 Release (Standard System / L2)
- **内核版本**: Linux 5.10.4
- **目标架构**: RISC-V 64 (riscv64)
- **芯片**: Sophgo SG2002 (双核 RISC-V C906@1GHz + ARM A53)

### 移植策略
采用快速移植方法：
```
OH 内核态层 = 三方Linux内核 + OH内核态基础代码 + OH内核态特性(HDF)
```

其中：
- **三方Linux内核**: LicheeRV-Nano-Build 提供的已验证 Linux 5.10
- **OH内核态基础代码**: hilog, hievent, 安全补丁等
- **OH内核态特性**: HDF (Hardware Driver Framework)

---

## 二、目录结构设计

### 2.1 产品定义
```
productdefine/common/products/
├── SGLinTx.json                          # SGLinTx产品定义
├── _ohos_common_parts.json
├── ohos-arm64.json
├── ohos-riscv64.json                     # RISC-V64架构配置
└── ...
```

### 2.2 板级配置
```
device/
└── sophgo/                               # Sophgo厂商目录
    └── sg2002/                           # SG2002芯片目录
        └── licheervnano/                 # LicheeRV Nano板级目录
            ├── BUILD.gn                  # 板级构建入口
            ├── build/                    # 板级构建脚本
            │   ├── BUILD.gn
            │   ├── rootfs/
            │   │   └── init_configs/
            │   └── ...
            ├── kernel/                   # 内核编译脚本
            │   ├── BUILD.gn
            │   ├── build_kernel.sh
            │   └── ...
            └── ...
```

### 2.3 内核补丁和配置
```
kernel/linux/
├── patches/
│   └── linux-5.10/
│       └── sg2002_patch/                 # SG2002补丁目录
│           ├── sg2002.patch              # SG2002硬件驱动补丁
│           ├── hdf.patch                 # HDF补丁
│           └── README_zh.md              # 补丁说明
└── config/
    └── linux-5.10/
        └── arch/
            └── riscv/
                └── configs/              # RISC-V配置目录
                    ├── sg2002_standard_defconfig   # SG2002标准系统config
                    └── standard_common_defconfig   # RISC-V通用config
```

### 2.4 内核源码管理
```
kernel/linux-5.10-riscv -> ../LicheeRV-Nano-Build/linux_5.10
```

### 2.5 设备树（Device Tree）
```
out/kernel/src_tmp/linux-5.10/arch/riscv/boot/dts/cvitek/
├── sg2002_licheervnano_sd.dts            # 主板DTS（来自LicheeRV-Nano-Build）
├── soph_*.dtsi                           # 公共DTSI
└── ...

最终输出：out/SGLinTx/packages/phone/images/sg2002_licheervnano_sd.dtb
```

---

## 三、移植步骤规划

### 阶段一：基础环境搭建

#### 1.1 创建产品定义
**目标文件**: `productdefine/common/products/SGLinTx.json`

**参考**:
- `productdefine/common/products/Hi3516DV300.json` (标准系统示例)
- `reference/Allwinner D1` (RISC-V参考移植)

#### 1.2 创建板级构建框架
**目标目录**: `device/sophgo/sg2002/licheervnano/`

**创建文件**:
- `BUILD.gn` - 板级构建组入口
- `build/BUILD.gn` - build组件
- `build/rootfs/init_configs/` - init配置
- `kernel/BUILD.gn` - kernel构建配置
- `kernel/build_kernel.sh` - 内核编译脚本

---

### 阶段二：内核移植

#### 2.1 准备三方Linux内核
创建符号链接：
```bash
cd kernel/
ln -s ../LicheeRV-Nano-Build/linux_5.10 linux-5.10-riscv
```

#### 2.2 创建内核补丁目录
**目标目录**: `kernel/linux/patches/linux-5.10/sg2002_patch/`

**所需补丁**:
1. `sg2002.patch` - 硬件驱动补丁
2. `hdf.patch` - HDF补丁（adapt到RISC-V）
3. `README_zh.md` - 补丁说明文档

#### 2.3 创建内核defconfig
**目标目录**: `kernel/linux/config/linux-5.10/arch/riscv/configs/`

**文件**:
- `sg2002_standard_defconfig` - SG2002标准系统配置
- `standard_common_defconfig` - RISC-V通用配置

**必须包含的CONFIG**:
```
CONFIG_DRIVERS_HDF=y
CONFIG_HDF_SUPPORT_LEVEL=2
CONFIG_DRIVERS_HDF_PLATFORM=y
CONFIG_DRIVERS_HDF_PLATFORM_GPIO=y
CONFIG_DRIVERS_HDF_PLATFORM_I2C=y
CONFIG_DRIVERS_HDF_INPUT=y
CONFIG_DRIVERS_HDF_SENSOR=y
CONFIG_HILOG=y
CONFIG_HIEVENT=y
```

---

### 阶段三：OpenHarmony内核态代码移植

#### 3.1 移植基础日志服务
**代码位置**: `kernel/linux/linux-5.10/drivers/staging/`

#### 3.2 打HDF补丁
```bash
drivers/hdf_core/adapter/khdf/linux/patch_hdf.sh \
  /home/openharmony \
  out/KERNEL_OBJ/kernel/src_tmp/linux-5.10 \
  /home/openharmony/kernel/linux/patches/linux-5.10 \
  sg2002
```

---

### 阶段四：构建系统适配

#### 4.1 修改kernel构建脚本
**目标文件**: `device/sophgo/sg2002/licheervnano/kernel/build_kernel.sh`

#### 4.2 修改GN构建配置
**目标文件**: `device/sophgo/sg2002/licheervnano/kernel/BUILD.gn`

---

### 阶段五：用户态配置

#### 5.1 创建rootfs init配置
**目标目录**: `device/sophgo/sg2002/licheervnano/build/rootfs/init_configs/`

---

### 阶段六：编译测试

#### 6.1 首次编译
```bash
docker start ohos_build_env && docker exec -it ohos_build_env bash
cd /home/openharmony
./build.sh --product-name SGLinTx --ccache
```

#### 6.2 内核编译测试
```bash
./build.sh --product-name SGLinTx --build-target kernel
```

---

## 四、关键路径清单

### 产品定义
| 路径 | 说明 |
|------|------|
| `productdefine/common/products/SGLinTx.json` | 产品定义文件 |
| `productdefine/common/products/ohos-riscv64.json` | RISC-V架构配置 |

### 板级配置
| 路径 | 说明 |
|------|------|
| `device/sophgo/` | Sophgo厂商目录 |
| `device/sophgo/sg2002/licheervnano/` | 板级目录 |
| `device/sophgo/sg2002/licheervnano/BUILD.gn` | 构建入口 |
| `device/sophgo/sg2002/licheervnano/kernel/BUILD.gn` | 内核构建配置 |
| `device/sophgo/sg2002/licheervnano/kernel/build_kernel.sh` | 内核编译脚本 |

### 内核补丁
| 路径 | 说明 |
|------|------|
| `kernel/linux/patches/linux-5.10/sg2002_patch/` | 补丁目录 |
| `kernel/linux/patches/linux-5.10/sg2002_patch/sg2002.patch` | 硬件驱动补丁 |
| `kernel/linux/patches/linux-5.10/sg2002_patch/hdf.patch` | HDF补丁 |

### 内核配置
| 路径 | 说明 |
|------|------|
| `kernel/linux/config/linux-5.10/arch/riscv/configs/` | RISC-V配置目录 |
| `kernel/linux/config/linux-5.10/arch/riscv/configs/sg2002_standard_defconfig` | 内核config |

### 内核源码
| 路径 | 说明 |
|------|------|
| `kernel/linux-5.10-riscv -> ../LicheeRV-Nano-Build/linux_5.10` | 内核源码符号链接 |
| `out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/` | 内核编译工作目录 |

---

## 五、依赖关系图

```
SGLinTx.json
    └── device/sophgo/sg2002/licheervnano/build
            ├── BUILD.gn (rootfs)
            └── kernel/BUILD.gn
                    ├── kernel/build_kernel.sh
                    │       └── kernel/linux/patches/linux-5.10/sg2002_patch/
                    │               ├── sg2002.patch
                    │               └── hdf.patch
                    └── kernel/linux-5.10-riscv (LicheeRV-Nano-Build/linux_5.10)
```

---

## 六、风险点和注意事项

### 6.1 架构差异
⚠️ OpenHarmony标准系统目前主要支持ARM，RISC-V需要适配

### 6.2 HDF补丁兼容性
⚠️ HDF补丁需要adapt到RISC-V

### 6.3 参考移植版本
⚠️ Allwinner D1参考移植可能不是最新版本

### 6.4 设备树格式
⚠️ LicheeRV-Nano-Build的DTS可能需要调整

---

## 七、参考资源

| 资源 | 路径 |
|------|------|
| Vendor SDK | `/home/openharmony/LicheeRV-Nano-Build/` |
| 参考移植 | `/home/openharmony/reference/Allwinner D1/` |
| ARM参考 | `device/hisilicon/hispark_taurus/` |
