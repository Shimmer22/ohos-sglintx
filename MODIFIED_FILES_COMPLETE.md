# SG2002移植 - 完整修改文件清单

**生成时间**: 2026-02-05  
**状态**: OpenHarmony构建成功 + 内核构建配置完成

---

## 一、OpenHarmony构建成功 (已实现)

### 构建结果
- ✅ 3136/3136 targets 完成
- ✅ 构建时间: 435秒
- ✅ 生成镜像:
  - system.img (1.5GB)
  - vendor.img (256MB)
  - userdata.img (1.4GB)
  - updater.img (20MB)

### 关键修复
1. **创建 `/usr/include/asm` 符号链接**
   - 解决: `fatal error: 'asm/errno.h' file not found`
   - 命令: `ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm`

---

## 二、修改的文件清单

### 1. 新增文件 (共23个)

#### 文档 (5个)
```
change/
├── sg2002_compiler_analysis.md          # 编译器分析文档
├── sg2002_porting_status.md             # 移植状态报告

├── KERNEL_BUILD_GUIDE.md                # 内核构建指南
├── MODIFIED_FILES_COMPLETE.md           # 本文件

```

#### 设备配置 (7个)
```
device/sophgo/
├── sg2002_nano/
│   ├── BUILD.gn                         # 设备构建入口
│   ├── build/
│   │   ├── BUILD.gn                     # 根文件系统构建配置
│   │   └── rootfs/
│   │       └── BUILD.gn                 # init配置
│   ├── kernel/
│   │   ├── BUILD.gn                     # 内核构建规则
│   │   └── build_kernel.sh              # 内核编译脚本
│   └── prebuilts/.gitkeep               # 预编译文件占位
├── build/
│   └── BUILD.gn                         # 设备全局构建
└── config/
    └── chips/
        └── sg2002/
            └── configs/
                └── nano/                # 芯片配置目录(空)
```

#### 产品配置 (4个)
```
productdefine/common/
├── products/
│   └── sg2002_nano.json                 # 产品定义
└── device/
    └── sg2002_nano.json                 # 设备定义
```

#### Vendor配置 (3个)
```
vendor/sophgo/
└── sg2002_nano/
    ├── ohos.build                       # 子系统构建配置
    ├── config.json                      # 产品子系统配置
    └── hdf_config/                      # HDF配置目录(从D1复制)
        ├── khdf/
        │   ├── device_info/
        │   ├── audio/
        │   ├── wifi/
        │   └── ...
        └── uhdf/
            └── hdf.hcs
```

#### 驱动配置 (1个)
```
drivers/peripheral/camera/hal/adapter/chipset/gni/
└── camera.sg2002_nano.gni             # 相机驱动配置
```

#### 内核配置 (4个)
```
kernel/linux/patches/
├── kernel-5.10.mk                      # Linux 5.10 内核Makefile
├── linux-5.10/
│   ├── sg2002_nano_defconfig           # 内核默认配置(占位)
│   └── sg2002_nano_kernel_config.patch # OH配置补丁
└── kernel_module_build.sh              # 修改后的构建脚本
```

### 2. 修改的文件 (2个)

#### kernel/linux/patches/kernel_module_build.sh
**修改内容**:
- 添加sg2002_nano支持
- 添加Linux 5.10内核支持
- 配置LicheeRV-Nano-Build GCC工具链路径

#### kernel/linux/patches/kernel-5.10.mk
**修改内容**:
- 基于LicheeRV-Nano-Build SDK配置
- 应用OpenHarmony配置补丁
- 自动追加OH必需的配置选项

---

## 三、构建系统分析

### 编译器使用情况

| 组件 | 编译器 | 配置位置 |
|------|--------|----------|
| **内核** | GCC 10.2.0 (Xuantie-900) | `kernel-5.10.mk` |
| **OH用户态** | Clang 12.0.1 | `build/toolchain/ohos/BUILD.gn:75-81` |
| **musl libc** | Clang + musl | `build/common/musl/BUILD.gn` |

### 关键发现

**内核构建方式**：
1. **不修改SDK源码**：使用`LicheeRV-Nano-Build/linux_5.10`
2. **只改配置**：通过`.config`补丁添加OH选项
3. **必需配置**：`CONFIG_ANDROID_BINDER_IPC=y` (SDK缺失)

**HDF补丁**：
- OH 3.0 LTS不需要HDF内核补丁
- HDF在用户态通过drivers/hdf_core实现
- 参考D1的做法：纯配置方式

---

## 四、文件目录树

```
/home/openharmony/change/
├── MODIFIED_FILES_COMPLETE.md          # 本文件
├── KERNEL_BUILD_GUIDE.md               # 内核构建指南

├── sg2002_compiler_analysis.md         # 编译器分析
├── sg2002_porting_status.md            # 移植状态

│
├── device/
│   └── sophgo/
│       ├── build/
│       │   └── BUILD.gn
│       ├── sg2002_nano/
│       │   ├── BUILD.gn
│       │   ├── build/
│       │   │   ├── BUILD.gn
│       │   │   └── rootfs/
│       │   │       └── BUILD.gn
│       │   ├── kernel/
│       │   │   ├── BUILD.gn
│       │   │   └── build_kernel.sh
│       │   ├── prebuilts/
│       │   │   └── .gitkeep
│       │   └── kernel_config.patch
│       └── config/
│           └── chips/
│               └── sg2002/
│                   └── configs/
│                       └── nano/
│
├── productdefine/
│   └── common/
│       ├── device/
│       │   └── sg2002_nano.json
│       └── products/
│           └── sg2002_nano.json
│
├── vendor/
│   └── sophgo/
│       └── sg2002_nano/
│           ├── ohos.build
│           ├── config.json
│           └── hdf_config/
│               ├── khdf/
│               │   ├── device_info/
│               │   ├── audio/
│               │   ├── wifi/
│               │   └── ...
│               └── uhdf/
│                   └── hdf.hcs
│
├── drivers/
│   └── peripheral/
│       └── camera/
│           └── hal/
│               └── adapter/
│                   └── chipset/
│                       └── gni/
│                           └── camera.sg2002_nano.gni
│
└── kernel/
    └── linux/
        └── patches/
            ├── kernel-5.10.mk
            ├── kernel_module_build.sh
            └── linux-5.10/
                ├── sg2002_nano_defconfig
                └── sg2002_nano_kernel_config.patch
```

---

## 五、使用说明

### 恢复修改

将所有文件复制回原位置：

```bash
cd /home/openharmony/change

# 复制所有目录
cp -r device/* /home/openharmony/device/
cp -r productdefine/* /home/openharmony/productdefine/
cp -r vendor/* /home/openharmony/vendor/
cp -r drivers/* /home/openharmony/drivers/
cp -r kernel/* /home/openharmony/kernel/

# 创建符号链接(如果需要)
ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/asm
```

### 构建命令

```bash
# 1. 构建OH用户态
cd /home/openharmony
./build.sh --product-name sg2002_nano --ccache

# 2. 构建内核
cd /home/openharmony/kernel/linux/patches
make -f kernel-5.10.mk

# 3. 查看输出
ls /home/openharmony/out/ohos-riscv64-release/packages/phone/images/
ls /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image
```

---

## 六、已知问题

1. **内核未集成到标准构建**
   - 原因：OH 3.0 LTS标准系统不包含内核子系统
   - 解决：单独构建内核（见KERNEL_BUILD_GUIDE.md）

2. **缺少打包脚本**
   - 需要创建 `device/sophgo/build/pack`
   - 参考 `device/sunxi/build/pack`

3. **HDF配置**
   - 当前使用D1的HDF配置作为占位
   - 需要根据sg2002硬件调整

---

## 七、后续工作

### 高优先级
1. [ ] 测试内核编译
2. [ ] 创建打包脚本（pack）
3. [ ] 打包完整固件

### 中优先级
4. [ ] 调整HDF配置
5. [ ] 添加设备树支持
6. [ ] 烧录测试

### 低优先级
7. [ ] 驱动适配
8. [ ] 系统服务验证
9. [ ] 文档完善

---

**总文件数**: 23个新增文件 + 2个修改文件 = 25个文件  
**备份位置**: `/home/openharmony/change/`
