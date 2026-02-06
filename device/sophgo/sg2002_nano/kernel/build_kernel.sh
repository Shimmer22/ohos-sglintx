#!/bin/bash

# Copyright (c) 2024 Sophgo Technologies Co., Ltd.
# Licensed under the Apache License, Version 2.0

set -e

#$1 - kernel build script work dir
#$2 - kernel build script stage dir
#$3 - GN target output dir
#$4 - device type
#$5 - root out dir
#$6 - product path

pushd ${1}
./kernel_module_build.sh ${2} ${4} ${5} ${6}
mkdir -p ${3}
cp ${2}/kernel/src_tmp/linux-5.10/arch/riscv/boot/Image ${3}/Image
popd
