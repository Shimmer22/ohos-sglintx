# 常见问题与排查

## 1. repo / SDK 拉取失败

现象：

- `repo sync` 失败
- `git clone` 中断

建议：

- 直接重试（网络抖动常见）
- 分步克隆（先主仓库，后子仓库）
- 确保 `LicheeRV-Nano-Build/host-tools` 拉取完整

## 2. 用户态构建报缺少 riscv clang 运行时

现象：

- 缺少 `llvm-riscv/.../libclang_rt.builtins.a`

排查：

- 检查 `prebuilts/clang/ohos/linux-x86_64/llvm-riscv/` 是否存在且目录层级正确。
- 确认 `lib/clang/12.0.1/lib/riscv64-linux-ohosmusl/libclang_rt.builtins.a` 存在。

## 3. 打包报 Fixed DTB not found

现象：

- `ERROR: Fixed DTB not found ... sg2002_fixed.dtb`

处理：

- 按 `docs/03_pack_flash.md` 重新拷贝 `sg2002_fixed.dtb`。
- 重新执行 `pack`。

## 4. Binder 异常

优先检查内核最终配置：

```bash
grep -E '^CONFIG_ANDROID=|^CONFIG_ANDROID_BINDER_IPC=|^CONFIG_ANDROID_BINDER_DEVICES=|^CONFIG_ANDROID_BINDERFS=|^# CONFIG_ANDROID_BINDERFS is not set' \
  /home/openharmony/out/KERNEL_OBJ/kernel/src_tmp/linux-5.10/.config
```

必须满足：

- `CONFIG_ANDROID_BINDER_IPC=y`
- `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"`
- `# CONFIG_ANDROID_BINDERFS is not set`

若不满足：

- 确认已同步本仓库 `kernel/linux/patches/kernel-5.10.mk` 与 `sg2002_nano_kernel_config.patch`
- 重新执行内核构建

## 5. 启动阶段无输出或早期失败

优先检查：

- `fip.bin` 是否为真实可启动版本
- 镜像分区是否为 `boot(16MB FAT32)` + `rootfs(Linux)`
- boot 分区是否包含 `fip.bin` 与 `boot.sd`

