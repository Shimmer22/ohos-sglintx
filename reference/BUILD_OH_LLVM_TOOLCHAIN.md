# 构建OH RISC-V LLVM工具链
当前提供的OH RISC-V LLVM工具链构建流程如下：
## 0. 系统环境准备
本次构建环境使用Docker容器ubuntu:20.04（docker环境搭建跳过）
````
docker pull ubuntu:20.04
docker run --name "oh_llvm" -it -v $(pwd):/home/oh_llvm/ ubuntu:20.04
````
## 1.  制作riscv-gnu-toolchain
## 1.1  环境准备
````
apt update
apt install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev \
            gawk build-essential bison flex texinfo gperf libtool patchutils bc \
            zlib1g-dev libexpat-dev git \
            libglib2.0-dev libfdt-dev libpixman-1-dev \
            libncurses5-dev libncursesw5-dev cmake wget rsync
````
## 1.2 下载源码
如果访问github速度慢，可以从gitee的riscv-gnu-toolchain仓库下载
````
git clone https://gitee.com/mirrors/riscv-gnu-toolchain
````
进入源码目录：
````
cd riscv-gnu-toolchain
````
下载子仓库源码

因不需要qemu子仓库，可以排除
````
git rm qemu
git submodule update --init --recursive
````
注意：如果无法从github下载，可从码云找到对应仓库手动下载，并切换到对应commit

## 1.3 编译riscv-gnu-toolchain工具链
GCC安装到/opt/riscv
````
./configure --prefix=/opt/riscv
make linux -j $(nproc)
cd ../
````
编译完成后，riscv-gnu-toolchain安装到/opt/riscv目录中，版本查看如下
````
$/opt/riscv/bin/riscv64-unknown-linux-gnu-gcc --version
riscv64-unknown-linux-gnu-gcc (g5964b5cd727) 11.1.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
````
## 2. 制作llvm编译器
## 2.1 下载源码(github下载有问题的可以使用gitee)
gitee的mirror下载
````
git clone https://gitee.com/mirrors/llvm-project.git
````
github下载
````
git clone https://github.com/llvm/llvm-project.git
````
## 2.2 源码修改
llvm官方10版本对riscv支持不够完善，这里直接使用llvm-12版本。
````
cd llvm-project/
git checkout release/12.x
````
riscv lld链接时会检查二进制abi类型是否匹配，oh中通过objcopy转换的配置文件，lld链接时，会报类型不匹配的错误，目前解决方案如下（注释掉比对源码）：
````
diff --git a/lld/ELF/Arch/RISCV.cpp b/lld/ELF/Arch/RISCV.cpp
index ca4178b..bfdc786 100644
--- a/lld/ELF/Arch/RISCV.cpp
+++ b/lld/ELF/Arch/RISCV.cpp
@@ -120,7 +120,7 @@ uint32_t RISCV::calcEFlags() const {
     uint32_t eflags = getEFlags(f);
     if (eflags & EF_RISCV_RVC)
       target |= EF_RISCV_RVC;
-
+/*
     if ((eflags & EF_RISCV_FLOAT_ABI) != (target & EF_RISCV_FLOAT_ABI))
       error(toString(f) +
             ": cannot link object files with different floating-point ABI");
@@ -128,6 +128,7 @@ uint32_t RISCV::calcEFlags() const {
     if ((eflags & EF_RISCV_RVE) != (target & EF_RISCV_RVE))
       error(toString(f) +
             ": cannot link object files with different EF_RISCV_RVE");
+*/
   }

   return target;

````
## 2.3 编译llvm riscv64工具链
````
mkdir build
cd build
cmake -G "Unix Makefiles" \
  -DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi;libunwind;lld;compiler-rt" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="X86;RISCV" \
  -DGCC_INSTALL_PREFIX="/opt/riscv" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="riscv64-unknown-linux-gnu" \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DBENCHMARK_DOWNLOAD_DEPENDENCIES=ON \
  ../llvm
make -j $(nproc)
cd ../
````
配置llvm的环境变量，方便后续编译使用（此处替换成实际路径）
````
export PATH="$PATH:/home/oh_llvm/llvm_oh/llvm-project/build/bin"
````
也可以写入.bashrc中

查看clang版本
````
$clang --version
clang version 12.0.1 (https://gitee.com/mirrors/llvm-project.git fed41342a82f5a3a9201819a82bf7a48313e296b)
Target: riscv64-unknown-linux-gnu
Thread model: posix
````
## 2.4 安装linux头文件
之后在编译libc++时，需要依赖linux的头文件。

下载安装linux-5.10内核头文件至/opt/sysroot目录中
````
cd ../
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.tar.xz
tar xvf linux-5.10.tar.xz
cd linux-5.10
make ARCH=riscv INSTALL_HDR_PATH=/opt/sysroot headers_install
cd ../
````
## 2.5 安装musl libc头文件
安装脚本如下：
````
wget http://musl.libc.org/releases/musl-1.2.2.tar.gz
tar xvf musl-1.2.2.tar.gz
cd musl-1.2.2
ARCH=riscv CROSS_COMPILE="riscv64-unknown-linux-gnu-" CC="clang" CFLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -z separate-code" ./configure --prefix=/opt/sysroot
make install-headers
cd ../
````
## 2.6 安装compiler-rt
上面2.3中安装llvm时已经配置安装了compiler-rt，并且在llvm-project/build/lib/clang/12.0.1/lib/linux/中生成，但通过file命令查看.o文件，发现依旧是x86_64版本，需要通过clang重新交叉编译。

````
cd llvm-project/
mkdir build-compiler-rt
cd build-compiler-rt
cmake -G "Unix Makefiles" \
  -DCOMPILER_RT_BUILD_BUILTINS=ON \
  -DCOMPILER_RT_INCLUDE_TESTS=OFF \
  -DCOMPILER_RT_BUILD_SANITIZERS=ON \
  -DCOMPILER_RT_BUILD_XRAY=ON \
  -DCOMPILER_RT_BUILD_LIBFUZZER=ON \
  -DCOMPILER_RT_BUILD_PROFILE=ON \
  -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_ASM_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d -mno-relax" \
  -DCMAKE_C_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d -mno-relax" \
  -DCMAKE_CXX_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d -mno-relax" \
  -DCMAKE_EXE_LINKER_FLAGS="-z separate-code" \
  -DCMAKE_SYSROOT="/opt/riscv/sysroot" \
  -DCMAKE_INSTALL_PREFIX="/opt/sysroot" \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_SIZEOF_VOID_P=8 \
  ../compiler-rt
make -j32
make install
cd ..
````
将生成的riscv64架构的complier-rt替换2.3中生成的x86_64版本
````
mv ./build/lib/clang/12.0.1/lib/linux/ ./build/lib/clang/12.0.1/lib/linux_x86_64
cp -r /opt/sysroot/lib/linux/ ./build/lib/clang/12.0.1/lib/
cd ../
````
## 2.7 安装musl
````
cd musl-1.2.2
ARCH=riscv CROSS_COMPILE="riscv64-unknown-linux-gnu-" CC="clang" CFLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mno-relax -z separate-code" LIBCC="/opt/sysroot/lib/linux/libclang_rt.builtins-riscv64.a" ./configure --prefix=/opt/sysroot
make -32
make install
cd ../
````
## 2.8 安装libunwind
````
cd llvm-project
mkdir build-libunwind
cd build-libunwind/
cmake -G "Unix Makefiles" \
  -DLIBUNWIND_USE_COMPILER_RT=YES \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_ASM_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_C_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_CXX_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_EXE_LINKER_FLAGS="-z separate-code" \
  -DCMAKE_SYSROOT="/opt/sysroot" \
  -DCMAKE_INSTALL_PREFIX="/opt/sysroot" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DLLVM_COMPILER_CHECKED=ON \
  ../libunwind
make -j32
make install
cd ../
````
## 2.9 安装libc++abi
````
mkdir build-libcxxabi
cd build-libcxxabi/
cmake -G "Unix Makefiles" \
  -DLIBCXXABI_USE_COMPILER_RT=YES \
  -DLIBCXXABI_USE_LLVM_UNWINDER=YES \
  -DLIBCXXABI_LIBCXX_PATH="../libcxx" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_C_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_CXX_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_EXE_LINKER_FLAGS="-z separate-code" \
  -DCMAKE_SYSROOT="/opt/sysroot" \
  -DCMAKE_INSTALL_PREFIX="/opt/sysroot" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  ../libcxxabi
make -j32
make install
cd ../
````
## 2.10 安装libc++
````
mkdir build-libcxx
cd build-libcxx/
cmake -G "Unix Makefiles" \
  -DLIBCXX_CXX_ABI=libcxxabi \
  -DLIBCXX_USE_COMPILER_RT=YES \
  -DLIBCXX_HAS_MUSL_LIBC=ON \
  -DLIBCXX_CXX_ABI_INCLUDE_PATHS="../libcxxabi/include" \
  -DLIBCXX_CXX_ABI_LIBRARY_PATH="../build-libcxxabi/lib" \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_C_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_CXX_COMPILER_TARGET="riscv64-unknown-linux-gnu" \
  -DCMAKE_ASM_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_C_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_CXX_FLAGS="-O2 --gcc-toolchain=/opt/riscv -march=rv64imafdc -mabi=lp64d" \
  -DCMAKE_EXE_LINKER_FLAGS="-z separate-code" \
  -DCMAKE_SYSROOT="/opt/sysroot"\
  -DCMAKE_INSTALL_PREFIX="/opt/sysroot" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  ../libcxx
make -j32
make install
cd ../../
````
## 3 整理oh llvm riscv64版本工具链
参照OH提供的llvm工具文件、文件夹命名方式整理出llvm-riscv版本的工具链
````
mkdir llvm-riscv
cp -r ./llvm-project/build/bin/ ./llvm-project/build/include/ ./llvm-project/build/lib* ./llvm-project/build/share/ ./llvm-riscv/
````
在llvm-riscv/lib/目录中创建riscv64-linux-ohosmusl/c++文件夹，放置libunwind、libc++、libc++abi等riscv64版本函数库
````
cd llvm-riscv/lib/
mkdir -p riscv64-linux-ohosmusl/c++
cp /opt/sysroot/lib/libunwind.* /opt/sysroot/lib/libc++* ./riscv64-linux-ohosmusl/c++/
````
移植OH至riscv64过程中，发现依赖atomic库，当前使用riscv-gnu-toolchain提供的libatomic库
````
cp /opt/riscv/riscv64-unknown-linux-gnu/lib/libatomic.* ./riscv64-linux-ohosmusl/c++/
````
修改compiler-rt库的文件夹和文件名称（riscv64-linux-ohosmusl命名可能需要去掉musl）
````
cd clang/12.0.1/lib/
mv linux riscv64-linux-ohosmusl
mv linux_x86_64 x86_64-linux-ohos
cd riscv64-linux-ohosmusl
for var in *; do mv $var `echo $var | sed 's/-riscv64//g'`;done
cd ../x86_64-linux-ohos
for var in *; do mv $var `echo $var | sed 's/-riscv64//g'`;done
````
到这里，llvm-riscv文件夹及为目前riscv64版本的oh编译工具链。