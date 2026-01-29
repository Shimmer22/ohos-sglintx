# OpenHarmony SGLinTx Porting - Status & Handover

## 1. Context & Objective
*   **Target**: Port OpenHarmony 3.2 Release (Standard System) to **SGLinTx** (LicheeRV Nano, SG2002/C906 RISC-V).
*   **Kernel**: Linux 5.10 (Vendor Kernel from Lichee SDK).
*   **Build Environment**: Docker `ohos_build_env` (Ubuntu 20.04).
*   **Core Challenge**: The Vendor Kernel is written for GCC + Binutils with legacy RISC-V Vector v0.7 (`v0p7`) support. OpenHarmony strictly mandates **LLVM/Clang** toolchain. These two are fundamentally incompatible regarding legacy vector assembly syntax and architecture flags.

## 2. Technical Roadmap & Decisions
We adopted a **"Vendor Kernel + Hybrid Toolchain"** strategy:
1.  **Codebase**: Clone vendor kernel source -> Apply patches -> Build within OHOS environment.
2.  **Toolchain**:
    *   **Compiler (C/C++)**: OpenHarmony Clang (Required for ABI/System compatibility).
    *   **Assembler (ASM)**: Lichee SDK GCC (`riscv64-unknown-linux-gnu-as`). **Why?** Clang's integrated assembler (LLVM IAS) strictly enforces RISC-V Vector v1.0 spec and rejects the v0.7 instructions (`vsetvli`, `vlb.v` etc.) used extensively in the vendor kernel driver and optimizations.
    *   **Linker**: OpenHarmony LLVM Linker (`ld.lld`).

## 3. "The Battle" - Problem Solving History

### Phase 1: Infrastructure & Configuration
*   Created `device/board/Humpback/SGLinTx` and `vendor/Humpback/SGLinTx`.
*   Configured `config.json` for `standard` system, `riscv64`.
*   Implemented `build_kernel.sh` to wrap the complex kernel build process.

### Phase 2: Compiler Flag Hell
*   **Issue**: GCC flags like `-mno-ldd` caused Clang to fail.
    *   *Fix*: `sed` removal in `build_kernel.sh`.
*   **Issue**: Clang default target is x86.
    *   *Fix*: Injected `--target=riscv64-linux-ohos`.

### Phase 3: The Vector Extension Deadlock (Current Focus)
This has been the most difficult hurdle.
*   **Attempt 1 (Pure Clang)**: Failed. Clang doesn't support v0.7 asm.
*   **Attempt 2 (Hybrid - GCC ASM)**: Switched to `LLVM_IAS=0` and set `CROSS_COMPILE` to SDK GCC.
    *   *Result*: Fixed general assembly config, but hit Linker Relaxation issues.
*   **Attempt 3 (Linker Relaxation)**: `ld.lld` failed to link GCC-produced objects due to `R_RISCV_ALIGN`.
    *   *Fix*: Forced `-Wa,-mno-relax` into `KBUILD_CFLAGS` and specifically patched `arch/riscv/kernel/vdso/Makefile`.
*   **Attempt 4 (Arch Flag Mismatch)**:
    *   Clang Driver verifies `-march`. It rejects `v0p7` (deprecated).
    *   If we remove `v0p7`, Clang is happy, but it passes "no vector support" to the Assembler.
    *   The Assembler then fails on `vector.S` with "unrecognized opcode".
    *   If we use `v`, Clang complains it's "experimental" and needs flags, but seemingly still passes incompatible version info to Assembler.

### Phase 4: Final Strategy (Hybrid Bypass)
We are currently implementing a **"Bypass" Strategy**:
1.  **Strip Vector from Clang**: Remove `v0p7` from the `KBUILD_CFLAGS` that Clang sees. This makes Clang driver happy.
2.  **Force Vector to Assembler**: Explicitly append `-Wa,-march=rv64imafdcv0p7` to the Makefile. ` -Wa` tells Clang "pass this directly to the assembler, don't look at it".
3.  This ensures the GCC Assembler gets the strict v0.7 architecture it needs, while Clang remains ignorant.

## 5. Current State (Files)
*   **Repository**: All work consolidated and synced in `SGLinTx_Port/`.
*   **Kernel Build**: **Success**. Produced `Image` and `dtb`.
*   **Image Packaging**: **Success**. Created `package_ohos.sh` and generated `ohos_sglintx.img` using SDK's `genimage`.
*   **Key Fixes**: `Hybrid Bypass` for Vector v0.7, `-Wa,-mno-relax` for Linker Relaxation, `medany` for memory model, and disabled `KALLSYMS`.

## 6. Next Steps for Next Session
1.  **Flash and Boot**: Verify the generated `ohos_sglintx.img` (SD card image) on the physical SGLinTx board.
2.  **HDF/Driver Patching**: Ongoing verification of HDF driver compilation compatibility if needed.
3.  **Refine kallsyms**: Investigate if kallsyms can be re-enabled without overflow if needed for debugging (likely needs more complex linker script work).
