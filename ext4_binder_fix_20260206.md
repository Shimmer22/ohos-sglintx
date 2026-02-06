# 2026-02-06 EXT4 Rootfs & Binder D1 兼容性修复

## 概述
本次会话解决了两个关键问题：
1. **EXT4 根文件系统启动失败** - 切换到 EXT4 后系统无法启动
2. **Binder 配置对齐** - 参照 Allwinner D1 (C906 RISC-V) 配置优化 Binder/Ashmem 支持

---

## 问题 1: EXT4 Rootfs 启动失败

### 现象
切换 rootfs 类型从 SquashFS 到 EXT4 后，系统在 `bootconsole [sbi0] enabled` 后挂起。

### 根因分析
| 问题 | 原因 |
|------|------|
| 文件权限错误 | `genimage` 以普通用户运行，生成的 EXT4 镜像中文件所有者为 UID 1000 而非 root |
| `fakeroot` 失效 | 容器环境中 `fakeroot` 的 `LD_PRELOAD` 无法正常工作 |

### 解决方案
修改 `pack_v3` 脚本，使用 `genext2fs -U` 手动生成 EXT4 镜像：
- `-U` 参数强制将所有文件 UID/GID 设为 0 (root)
- 使用 `tune2fs` 升级到 EXT4 特性
- 分区大小调整为 2GB（适应 OpenHarmony 系统大小）

### 修改的文件
- `device/sophgo/build/pack_v3` - EXT4 生成逻辑
- `out/sg2002_debug.dts` - 添加 `rootfstype=ext4` 到 bootargs

---

## 问题 2: Binder 配置 D1 兼容性

### 目标
参照 Allwinner D1 (哪吒) 的 Binder 配置，确保 OpenHarmony IPC 正常工作。

### D1 参考配置
```
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
# CONFIG_ANDROID_BINDERFS is not set  (传统 /dev/binder 模式)
```

### 问题
直接修改 defconfig 无效，Kconfig 依赖解析会覆盖我们的设置。

### 解决方案
创建 `build_kernel_fixed.sh` 脚本：
1. 运行 `make defconfig` 生成基础配置
2. 手动 `sed` 修改 `.config` 文件
3. 运行 `make olddefconfig` 解析依赖
4. 编译内核

### 最终内核配置
| 配置项 | 值 |
|--------|-----|
| `CONFIG_STAGING` | =y |
| `CONFIG_ANDROID` | =y |
| `CONFIG_ASHMEM` | =y |
| `CONFIG_ANDROID_BINDER_IPC` | =y |
| `CONFIG_ANDROID_BINDERFS` | is not set |
| `CONFIG_ANDROID_BINDER_DEVICES` | "binder,hwbinder,vndbinder" |

### 修改的文件
- `kernel/linux/patches/kernel-5.10.mk` - 添加配置强制逻辑（备用）
- `build_kernel_fixed.sh` - 手动内核构建脚本（主要方法）

---

## 同步的文件列表

| 源文件 | 说明 |
|--------|------|
| `device/sophgo/build/pack_v3` | 带 EXT4 手动生成逻辑的打包脚本 |
| `kernel/linux/patches/kernel-5.10.mk` | 带 Binder 配置逻辑的内核 Makefile |
| `build_kernel_fixed.sh` | 手动内核构建脚本 |
| `out/sg2002_debug.dts` | 带 EXT4 bootargs 的设备树源文件 |

---

## 验证结果

- ✅ EXT4 根文件系统正常启动
- ✅ Binder 配置与 D1 对齐
- ✅ 系统可进入交互界面
