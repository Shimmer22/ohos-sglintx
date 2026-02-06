# SG2002 OpenHarmony 启动修复记录 (2026-02-06)

## 1. 问题现象
*   **初始问题**: 串口无输出（Silent Boot），无法进入内核。
*   **中期问题**: 修复部分后，内核启动但静默挂死（Hang），仅显示 `earlycon`。
*   **后期问题**: 修复内存后，内核 Panic 重启（3行日志循环）。

## 2. 根因分析 (Root Cause Analysis)

### A. 设备树不匹配 (DTS Mismatch)
*   **原因**: OpenHarmony 构建系统默认编译使用了 `ice.dts` (平头哥 ICE 参考板)，而非 LicheeRV Nano (`sg2002_licheervnano_sd`) 专用设备树。
*   **影响**: 内存布局、外设地址、中断控制器配置完全错误。

### B. 内存布局冲突 (ION Memory Conflict)
*   **原因**: SG2002 的 ION（多媒体内存）需要从物理内存中切分专用区域。即使使用了正确的厂商 DTS，如果 `ion` 节点未指定固定地址（或指定错误），内核动态分配时会覆盖 FDT（设备树二进制）的加载地址 (`0x880E1000`)。
*   **影响**: 内核读取设备树失败，导致早期静默挂死。

### C. Ramdisk 损坏 (Corrupt Initrd)
*   **原因**: `pack_v3` 生成的 ramdisk 仅 248 字节（仅包含 FIT 头），导致内核解压 Initrd 时 Panic。
*   **影响**: 启动中断，无法挂载文件系统。

### D. Bootargs 缺失 (Missing Bootargs)
*   **原因**: U-Boot 环境变量可能被清除或不正确，且 DTS 的 `chosen` 节点为空。
*   **影响**: 内核不知道根文件系统位置 (`root=/dev/mmcblk0p2`)，也不知道串口波特率。

## 3. 修复方案 (Solution)

### A. 提取与修补 DTS
由于缺乏完整的厂商内核源码（缺生成的头文件），无法直接编译厂商 DTS。
1.  **提取**: 从厂商 `ramboot.itb` 提取 `sg2002_licheervnano_sd.dtb`。
2.  **反编译**: `dtc -I dtb -O dts ...`
3.  **修补 (Critical)**:
    *   **ION Pinning**: 在 `ion` 节点强制添加 `alloc-ranges = <0x00 0x8b300000 0x00 0x4B00000>;` (地址 0x8B300000, 大小 75MB)，与厂商 Log 精确对齐。
    *   **Bootargs Injection**: 在 `chosen` 节点注入完整参数：
        ```dts
        bootargs = "root=/dev/mmcblk0p2 rootwait rw console=tty0 console=ttyS0,115200 earlycon=sbi riscv.fwsz=0x80000 loglevel=9";
        ```
4.  **重编译**: 生成 `sg2002_fixed.dtb`。

### B. 升级打包脚本 (pack_v3)
1.  **移除 Ramdisk**: 彻底移除 FIT 镜像中的 Ramdisk 部分，改为内核直挂 SD 卡 (`root=/dev/mmcblk0p2`)。
2.  **集成 Fixed DTB**: 脚本自动复制并使用修补后的 `sg2002_fixed.dtb`。
3.  **Docker 适配**: 解决权限和库依赖 (`LD_LIBRARY_PATH`) 问题。

## 4. 结果验证
*   **串口输出**: 正常显示完整内核日志 (`loglevel=9` 生效)。
*   **启动流程**: 成功挂载 Rootfs，进入 Shell。
*   **文件归档**:
    *   `pack_v3`: 打包脚本
    *   `sg2002_fixed.dtb`: 修复后的二进制设备树

---
*Created by Antigravity Agent*
