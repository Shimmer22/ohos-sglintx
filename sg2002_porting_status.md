# SG2002 (LicheeRV Nano) OpenHarmony 移植状态报告

## 一、已完成工作

### 1. 编译器工具链配置 ✅

**LLVM工具链**
- 已解压: `prebuilts/clang/ohos/linux-x86_64/llvm-riscv/`
- 版本: clang 12.0.1
- 目标: riscv64-unknown-linux-gnu

**GCC工具链**
- 来源: LicheeRV-Nano-Build SDK
- 路径: `LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/`
- 版本: GCC 10.2.0 (Xuantie-900)
- 用于: Linux 5.10 内核编译

### 2. 设备目录结构创建 ✅

```
device/sophgo/
├── sg2002_nano/
│   ├── BUILD.gn                    # 设备构建入口
│   ├── build/
│   │   ├── BUILD.gn               # rc_files
│   │   └── rootfs/
│   │       └── BUILD.gn           # init配置
│   └── kernel/
│       ├── BUILD.gn               # 内核构建规则
│       └── build_kernel.sh        # 内核编译脚本
├── build/
│   └── BUILD.gn                   # 设备全局构建
└── config/
    └── chips/
        └── sg2002/
            └── configs/
                └── nano/          # 芯片配置(待完善)
```

### 3. 产品配置创建 ✅

**产品配置文件**:
- `productdefine/common/products/sg2002_nano.json`
- `productdefine/common/device/sg2002_nano.json`

**Vendor配置**:
- `vendor/sophgo/sg2002_nano/ohos.build`
- `vendor/sophgo/sg2002_nano/hdf_config/` (从D1复制)

**驱动配置**:
- `drivers/peripheral/camera/hal/adapter/chipset/gni/camera.sg2002_nano.gni`

### 4. 内核构建配置 ✅

**新增文件**:
- `kernel/linux/patches/kernel-5.10.mk` - Linux 5.10 内核构建规则
- 修改 `kernel/linux/patches/kernel_module_build.sh` - 添加sg2002支持

**内核信息**:
- 版本: Linux 5.10.4
- 源码: `kernel/linux_5.10/` (已存在，约1.4GB)
- 配置: 复用LicheeRV-Nano-Build的`.config`
- 工具链: riscv64-unknown-linux-gnu-gcc (Xuantie-900)

## 二、构建系统分析

### 编译器使用情况

| 组件 | 编译器 | 配置位置 |
|------|--------|----------|
| **内核** | GCC 10.2.0 | `kernel-5.10.mk` |
| **OH用户态** | Clang 12.0.1 | `build/toolchain/ohos/BUILD.gn:75-81` |
| **musl libc** | Clang + musl | `build/common/musl/BUILD.gn` |
| **交叉编译** | riscv64-linux-ohosmusl | `build/config/clang/clang.gni:14-18` |

### 关键配置

**工具链选择** (`build/config/clang/clang.gni`):
```gn
if (target_cpu == "riscv64") {
  clang_base_path = "//prebuilts/clang/ohos/${host_platform_dir}/llvm-riscv"
}
```

**RISC-V编译选项** (`build/config/compiler/BUILD.gn:726-738`):
```gn
cflags += [
  "-march=rv64imafdc",
  "-mabi=lp64d",
  "-mno-relax",
]
```

## 三、测试结果

### 构建命令测试

```bash
# 完整构建
./build.sh --product-name sg2002_nano --ccache

# 构建特定目标
./build.sh --product-name sg2002_nano --build-target kernel
```

### 当前状态 (更新于 2026-02-05)

#### ✅ 已完成
- ✅ OpenHarmony标准系统构建成功 (3136/3136 targets)
- ✅ GN生成成功 (7315 targets from 1466 files)
- ✅ 编译器配置正确 (Clang 12.0.1 + GCC 10.2.0)
- ✅ 生成系统镜像 (system.img, vendor.img, userdata.img, updater.img)
- ✅ 创建 `vendor/sophgo/sg2002_nano/config.json`
- ✅ 修复构建错误 (`/usr/include/asm` 符号链接)

#### ✅ 最新完成 (2026-02-05 12:00)
- ✅ **内核构建成功** - Linux 5.10.4 + OH配置 (9.2MB)
  - 已启用: `CONFIG_ANDROID_BINDER_IPC=y`
  - 构建命令: `make -f kernel-5.10.mk`
  
- ✅ **打包脚本完成** - `device/sophgo/build/pack`
  - 支持ext4和squashfs根文件系统
  - 自动生成boot.img（内核+ramdisk）
  - 支持SD卡镜像生成（需要root权限）
  - 提供烧录脚本 `flash.sh`
  - 文档: `PACKING_GUIDE.md`

#### ⚠️ 待完成
- ⚠️ 烧录测试 - 验证固件在sg2002上启动
- ⚠️ HDF驱动配置 - 需要根据sg2002硬件调整
- ⚠️ 设备树适配 - 需要添加OH特定的设备树配置

### 最新进展 (2026-02-05)

#### 重大里程碑: OpenHarmony构建成功！🎉

- ✅ **修复构建错误**: 创建 `/usr/include/asm` 符号链接解决 `asm/errno.h` 找不到的问题
- ✅ **构建成功**: `./build.sh --product-name sg2002_nano --ccache`
- ✅ **构建时间**: 435秒 (~7分钟)
- ✅ **构建目标**: 3136个目标全部完成
- ✅ **生成镜像**:
  - `system.img` (1.5GB)
  - `vendor.img` (256MB)
  - `userdata.img` (1.4GB)
  - `updater.img` (20MB)

#### 之前的进展
- 更新 `kernel_module_build.sh` 添加sg2002支持
- 验证GCC工具链路径: `LicheeRV-Nano-Build/host-tools/gcc/riscv64-linux-x86_64/bin/`
- GCC版本: 10.2.0 (Xuantie-900 linux-5.10.4)
- 创建 `config.json` 基础配置
- 创建 `/usr/include/asm` 符号链接修复构建错误

## 四、已知问题

### 1. 构建目标问题
内核目标未正确注册到ninja，需要检查:
- `device/sophgo/sg2002_nano/BUILD.gn` 依赖关系
- `vendor/sophgo/sg2002_nano/ohos.build` 模块列表

### 2. 缺少配置
- 缺少`vendor/sophgo/sg2002_nano/config.json`
- 可能需要调整HDF配置以适配sg2002硬件

### 3. 驱动适配
- 当前使用了D1的HDF配置作为临时方案
- 需要根据sg2002实际硬件调整设备树和驱动

## 五、下一步工作

### 高优先级

1. **修复构建目标**
   - 创建`vendor/sophgo/sg2002_nano/config.json`
   - 检查并修复内核构建规则

2. **验证内核编译**
   - 单独测试内核编译流程
   - 确保Image生成正确

3. **创建打包脚本**
   - 参考`device/sunxi/build/pack`
   - 创建`device/sophgo/build/pack`

### 中优先级

4. **设备树配置**
   - 从LicheeRV-Nano-Build提取设备树
   - 适配OH的内核配置

5. **HDF驱动移植**
   - 根据sg2002硬件规格调整HDF配置
   - 移植必要的平台驱动

### 低优先级

6. **根文件系统**
   - 配置init进程
   - 添加必要的系统服务

7. **测试验证**
   - 烧录测试
   - 功能验证

## 六、参考资源

- **内核源码**: `LicheeRV-Nano-Build/linux_5.10/`
- **工具链**: `LicheeRV-Nano-Build/host-tools/gcc/`
- **D1参考**: `device/sunxi/`
- **文档**: `reference/` 目录下的移植文档

## 七、关键文件清单

### 新增文件
1. `sg2002_compiler_analysis.md` - 编译器分析文档
2. `sg2002_porting_status.md` - 本状态文档
3. `device/sophgo/sg2002_nano/` 目录树
   - `BUILD.gn` - 设备构建入口
   - `build/` - 构建配置
   - `kernel/` - 内核构建配置
   - `prebuilts/` - 预编译文件目录
   - `kernel_config.patch` - 内核配置补丁
4. `productdefine/common/products/sg2002_nano.json`
5. `productdefine/common/device/sg2002_nano.json`
6. `vendor/sophgo/sg2002_nano/ohos.build`
7. `vendor/sophgo/sg2002_nano/hdf_config/` - HDF配置(从D1复制)
8. `kernel/linux/patches/kernel-5.10.mk`
9. `device/sophgo/build/BUILD.gn` - 设备全局构建

### 修改文件
1. `kernel/linux/patches/kernel_module_build.sh`
2. `drivers/peripheral/camera/hal/adapter/chipset/gni/camera.sg2002_nano.gni`

---

**更新时间**: 2026-02-05  
**状态**: 基础配置完成，需要调试和验证  
**下一步**: 修复构建问题，验证内核编译
