# SGLinTx OpenHarmony 移植项目

将 OpenHarmony Standard System (L2) 移植到 Sophgo SG2002 (LicheeRV Nano) 开发板

---

## 快速开始

1. 阅读 [AGENTS.md](AGENTS.md) - 了解AI Agent工作规则和项目上下文
2. 阅读 [ARCHITECTURE.md](ARCHITECTURE.md) - 查看工程架构和技术设计
3. 阅读 [WALKTHROUGH.md](WALKTHROUGH.md) - 了解工作进展历史
4. 参考 LicheeRV-Nano-Build/ 和 reference/ 目录进行实际工作

---

## 技术栈

- OpenHarmony 版本: 3.2 Release (Standard System / L2)
- 内核版本: Linux 5.10.4
- 目标架构: RISC-V 64 (riscv64)
- 芯片: Sophgo SG2002 (双核 RISC-V C906@1GHz + ARM A53)
- 工作环境: Docker 容器 `ohos_build_env`

---

## 文档组织

本项目的Git仓库在 `ohos-sglintx/` 目录，所有文档在此目录进行版本管理。

| 文档 | 用途 |
|------|------|
| [AGENTS.md](AGENTS.md) | AI Agent上下文、工作规则、用户习惯 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 工程架构、代码结构、技术文档 |
| [WALKTHROUGH.md](WALKTHROUGH.md) | 每轮对话记录、工作总结 |

---

## 编译命令

```bash
# 进入Docker环境
docker start ohos_build_env && docker exec -it ohos_build_env bash

# 完整编译
cd /home/openharmony
./build.sh --product-name SGLinTx --ccache

# 单独编译内核
./build.sh --product-name SGLinTx --build-target kernel
```

---

## 参考资源

- Vendor SDK: `LicheeRV-Nano-Build/` (Linux 5.10内核、设备树)
- 参考移植: `reference/Allwinner D1/` (平头哥C906 RISC-V)
- ARM标准系统: `device/hisilicon/hispark_taurus/`
