# AI Agent 工作规则

## 项目上下文

**目标**: 将 OpenHarmony Standard System 移植到 Sophgo SG2002 (LicheeRV Nano) 开发板

**核心信息**:
- OpenHarmony 版本: 3.2 Release (Standard System / L2)
- 内核版本: Linux 5.10.4
- 目标架构: RISC-V 64 (riscv64)
- 芯片: Sophgo SG2002 (双核 RISC-V C906@1GHz + ARM A53)
- 工作环境: Docker 容器 `ohos_build_env`

---

## 文档分工说明

AI Agent 必须严格遵守以下文档分工：

| 文档 | 职责 | 更新时机 |
|------|------|----------|
| **index.md** | 项目主入口，介绍其他文档 | 仅当文档结构变化时 |
| **AGENTS.md** | AI Agent约束、工作规则、用户习惯 | 仅当Agent规则变化时 |
| **ARCHITECTURE.md** | 工程架构、代码结构、技术文档 | 仅当架构或代码变化时 |
| **WALKTHROUGH.md** | 每轮对话记录、工作总结 | 用户明确要求时更新 |

**重要**: AI Agent 不得随意修改职责之外的内容，保持文档职责单一。

---

## 文件同步规则

### 代码/配置文件同步

在外侧目录（如 `/home/openharmony/ab/a.txt`）修改或新建的文件，需要按照相同路径复制到 `ohos-sglintx/` 目录中，以便进行版本管理。

**示例**:
```
修改文件: /home/openharmony/device/sophgo/sg2002/BUILD.gn
同步位置: /home/openharmony/ohos-sglintx/device/sophgo/sg2002/BUILD.gn
```

**重要**: 仅在用户明确要求"总结到WALKTHROUGH"后，才执行此同步操作。

### 执行时机

1. **必须等待用户明确指令**
   - 用户必须明确要求"将工作总结到WALKTHROUGH"或类似指令
   - 不得在完成某些更改后主动执行同步

2. **等待用户测试反馈**
   - 修改后的文件先在外侧工作
   - 等待用户测试确认
   - 用户明确指令后再同步到ohos-sglintx

3. **操作步骤**
   ```bash
   # 用户明确要求后才执行
   # 1. 读取修改后的完整文件
   # 2. 按照相同路径写入到ohos-sglintx/
   # 3. 更新WALKTHROUGH.md记录变更
   ```

---

## AI Agent 编辑规则

### 重要原则
1. **创建新文档**: 必须在 `ohos-sglintx/` 目录中创建
2. **修改文档**: 始终修改 `ohos-sglintx/` 中的源文件
3. **查看文档**: 可以在外侧目录或 `ohos-sglintx/` 目录查看同一文件
4. **Git操作**: 所有git操作在 `ohos-sglintx/` 目录执行

### 不要这样做 ❌
✗ 在 `/home/openharmony/` 根目录直接创建新的.md文档
✗ 未经用户明确指令将外侧修改同步到ohos-sglintx
✗ 在根目录执行git操作（ohos-sglintx才是仓库）

### 正确做法 ✓
✓ 在 `/home/openharmony/ohos-sglintx/` 创建新文档
✓ 编辑 `/home/openharmony/ohos-sglintx/` 中的源文件
✓ 在 `/home/openharmony/ohos-sglintx/` 执行git add/commit/push
✓ 外侧修改后，等待用户明确指令才同步到ohos-sglintx

### 示例
```bash
# ✗ 错误示例
echo "# New Doc" > /home/openharmony/NEW_DOC.md  # 不要在根目录创建

# ✓ 正确示例
echo "# New Doc" > /home/openharmony/ohos-sglintx/NEW_DOC.md

# ✓ 外侧修改示例
# 1. 在 /home/openharmony/device/xxx 修改文件
# 2. 用户测试验证
# 3. 用户明确"总结到WALKTHROUGH"
# 4. 复制到 /home/openharmony/ohos-sglintx/device/xxx
```

---

## 核心路径对照表

### 产品与板级配置
```
/home/openharmony/productdefine/common/products/SGLinTx.json  # 产品定义
/home/openharmony/device/sophgo/sg2002/licheervnano/          # 板级目录
```

### 内核相关
```
kernel/linux-5.10-riscv (链接到LicheeRV-Nano-Build/linux_5.10)  # 内核源码
kernel/linux/patches/linux-5.10/sg2002_patch/                 # SG2002补丁
kernel/linux/config/linux-5.10/arch/riscv/configs/            # 内核配置
```

### 设备树
```
LicheeRV-Nano-Build/build/boards/sg200x/sg2002_licheervnano_sd/dts_riscv/  # 设备树源文件
out/SGLinTx/packages/phone/images/sg2002_licheervnano_sd.dtb                # 编译产物
```

### 输出镜像
```
out/SGLinTx/packages/phone/images/
├── Image                        # 内核镜像
├── sg2002_licheervnano_sd.dtb   # 设备树
├── ramdisk                      # RAM磁盘镜像
├── system                       # system分区镜像
└── updater                      # updater分区镜像
```

---

## 编译命令速查

```bash
# 一键进入并编译
docker start ohos_build_env && docker exec -it ohos_build_env bash

# 在容器内执行编译
cd /home/openharmony
./build.sh --product-name SGLinTx --ccache

# 仅 GN 配置检查
./build.sh --product-name SGLinTx --build-only-gn

# 单独编译内核
./build.sh --product-name SGLinTx --build-target kernel
```

---

## 参考资源

- **Vendor SDK**: `LicheeRV-Nano-Build` (LicheeRV 官方 Buildroot SDK)
- **参考移植**: `reference/Allwinner D1` (平头哥C906 RISC-V架构)
- **标准参考**: `device/hisilicon/hispark_taurus` (ARM标准系统)
