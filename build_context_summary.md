# SGLinTx Porting Summary & Context

## Objectives
1. Build OpenHarmony Standard System for SGLinTx (LicheeRV Nano).
2. Integrate Vendor Kernel (Linux 5.10 from Lichee SDK) with OpenHarmony Build System.

## Current Status
- **Build System**: Configured `config.json`, `BUILD.gn`, and `build_kernel.sh`.
- **Kernel Source**: Using `lichee_sdk/linux_5.10` with `sg2002_licheervnano_sd` configuration.
- **Toolchain Strategy**: Hybrid.
    - **Compiler**: OpenHarmony Clang (required for system compatibility).
    - **Assembler**: Lichee SDK GCC (`riscv64-unknown-linux-gnu-as`) via `LLVM_IAS=0`.
    - **Linker**: OpenHarmony LLVM Linker (`ld.lld`).

## Solved Issues
1. **DTS Compilation**:
   - Fixed missing `cvi_board_memmap.h` by copying from SDK.
   - Removed broken symlinks and incompatible DTS directories (`thead`).
2. **Compiler Flags**:
   - Removed GCC-specific `-mno-ldd`.
   - Injected `--target=riscv64-linux-ohos` for Clang.
   - Stripped `v0p7` vector extension flag (Clang driver rejected it).
3. **Assembler Compatibility**:
   - Vendor kernel uses legacy RISC-V Vector v0.7 syntax (`vsetvli`).
   - Clang's integrated assembler (v1.0 compliant) failed to parse it.
   - **Solution**: Switched to SDK's GCC assembler.

## Current Blockers
- **Linker Relaxation (`R_RISCV_ALIGN`)**:
    - Build fails at VDSO linking: `relocation R_RISCV_ALIGN requires unimplemented linker relaxation`.
    - Cause: GCC Assembler generates relaxed code by default; `ld.lld` generally doesn't support this for RISC-V.
    - Attempted `-Wa,-mno-relax` global injection, but likely not propagating effectively to VDSO makefiles.

## Next Steps
1. Force `-mno-relax` specifically into `arch/riscv/kernel/vdso/Makefile`.
2. Verify Kernel Image generation.
