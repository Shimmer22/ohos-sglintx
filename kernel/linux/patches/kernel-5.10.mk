# Copyright (c) 2024 Sophgo Technologies Co., Ltd.
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# ohos makefile to build kernel for sg2002 (Linux 5.10)
PRODUCT_NAME=$(TARGET_PRODUCT)

# Check required environment variables
ifeq ($(PRODUCT_NAME),)
$(error PRODUCT_NAME is not set. Please run: export TARGET_PRODUCT=sg2002_nano)
endif

ifeq ($(OUT_DIR),)
OUT_DIR := $(realpath $(shell pwd)/../../../out/KERNEL_OBJ)
$(warning OUT_DIR not set, using default: $(OUT_DIR))
endif

ifeq ($(OHOS_ROOT_PATH),)
OHOS_ROOT_PATH := $(realpath $(shell pwd)/../../../)
$(warning OHOS_ROOT_PATH not set, using default: $(OHOS_ROOT_PATH))
endif

ifeq ($(LICHEERV_SDK_PATH),)
LICHEERV_SDK_PATH := $(OHOS_ROOT_PATH)/LicheeRV-Nano-Build
$(warning LICHEERV_SDK_PATH not set, using default: $(LICHEERV_SDK_PATH))
endif

OHOS_BUILD_HOME := $(OHOS_ROOT_PATH)
KERNEL_SRC_TMP_PATH := $(OUT_DIR)/kernel/src_tmp/linux-5.10

ifeq ($(PRODUCT_NAME), sg2002_nano)
OHOS_BUILD_HOME := $(OHOS_ROOT_PATH)
KERNEL_SRC_TMP_PATH := $(OUT_DIR)/kernel/src_tmp/linux-5.10
endif

# Use the actual kernel source from LicheeRV-Nano-Build
# kernel/linux_5.10 is a symlink to LicheeRV-Nano-Build/linux_5.10
KERNEL_SRC_PATH := $(LICHEERV_SDK_PATH)/linux_5.10
KERNEL_PATCH_PATH := $(OHOS_BUILD_HOME)/kernel/linux/patches/linux-5.10
KERNEL_CONFIG_PATH := $(OHOS_BUILD_HOME)/kernel/linux/config/linux-5.10

# Use GCC toolchain from LicheeRV-Nano-Build SDK
LICHEERV_SDK_PATH := $(OHOS_BUILD_HOME)/LicheeRV-Nano-Build
PREBUILTS_GCC_DIR := $(LICHEERV_SDK_PATH)/host-tools/gcc
KERNEL_TARGET_TOOLCHAIN := $(PREBUILTS_GCC_DIR)/riscv64-linux-x86_64/bin
KERNEL_TARGET_TOOLCHAIN_PREFIX := riscv64-unknown-linux-gnu-
GNU_CC := $(KERNEL_TARGET_TOOLCHAIN)/$(KERNEL_TARGET_TOOLCHAIN_PREFIX)gcc

KERNEL_PREBUILT_MAKE := make
KERNEL_PERL := /usr/bin/perl

KERNEL_ARCH := riscv
KERNEL_CROSS_COMPILE += CC="$(GNU_CC)"
KERNEL_CROSS_COMPILE += PERL=$(KERNEL_PERL)
KERNEL_CROSS_COMPILE += CROSS_COMPILE="$(KERNEL_TARGET_TOOLCHAIN_PREFIX)"

KERNEL_MAKE := PATH="$(KERNEL_TARGET_TOOLCHAIN):$(PATH)" $(KERNEL_PREBUILT_MAKE)

ifeq ($(PRODUCT_NAME), sg2002_nano)
KERNEL_IMAGE_FILE := $(KERNEL_SRC_TMP_PATH)/arch/riscv/boot/Image
DEFCONFIG_FILE := sg2002_nano_defconfig
# Kernel config patches for OpenHarmony
KERNEL_CONFIG_PATCH := $(OHOS_BUILD_HOME)/kernel/linux/patches/linux-5.10/sg2002_nano_kernel_config.patch
endif

export HDF_PROJECT_ROOT=$(OHOS_BUILD_HOME)/

$(KERNEL_IMAGE_FILE):
	@echo "build kernel for $(PRODUCT_NAME)..."
	@rm -rf $(KERNEL_SRC_TMP_PATH); mkdir -p $(KERNEL_SRC_TMP_PATH)
	@echo "Copying kernel source..."
	@cd $(KERNEL_SRC_PATH) && cp -rf * $(KERNEL_SRC_TMP_PATH)/ 2>/dev/null || true
	@rm -f $(KERNEL_SRC_TMP_PATH)/linux_5.10  # Remove cyclic symlink
ifeq ($(PRODUCT_NAME), sg2002_nano)
	@echo "Using kernel config from LicheeRV-Nano-Build with OpenHarmony patches"
	@cp $(LICHEERV_SDK_PATH)/linux_5.10/.config $(KERNEL_SRC_TMP_PATH)/arch/riscv/configs/$(DEFCONFIG_FILE)
	@echo "Applying OpenHarmony kernel config patches..."
	@cat $(KERNEL_CONFIG_PATCH) >> $(KERNEL_SRC_TMP_PATH)/arch/riscv/configs/$(DEFCONFIG_FILE)
	@echo "OpenHarmony config patches applied successfully"
endif
	@$(KERNEL_MAKE) -C $(KERNEL_SRC_TMP_PATH) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) distclean
	@$(KERNEL_MAKE) -C $(KERNEL_SRC_TMP_PATH) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) $(DEFCONFIG_FILE)
	@echo "Enforcing D1-style Binder config (/dev/binder, binderfs disabled)..."
	@sed -i '/^CONFIG_ANDROID=/d' $(KERNEL_SRC_TMP_PATH)/.config
	@sed -i '/^CONFIG_ANDROID_BINDER_IPC=/d' $(KERNEL_SRC_TMP_PATH)/.config
	@sed -i '/^CONFIG_ANDROID_BINDER_DEVICES=/d' $(KERNEL_SRC_TMP_PATH)/.config
	@sed -i '/^CONFIG_ANDROID_BINDERFS=/d' $(KERNEL_SRC_TMP_PATH)/.config
	@sed -i '/^# CONFIG_ANDROID_BINDERFS is not set/d' $(KERNEL_SRC_TMP_PATH)/.config
	@printf '%s\n' \
		'CONFIG_ANDROID=y' \
		'CONFIG_ANDROID_BINDER_IPC=y' \
		'CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"' \
		'# CONFIG_ANDROID_BINDERFS is not set' >> $(KERNEL_SRC_TMP_PATH)/.config
	@$(KERNEL_MAKE) -C $(KERNEL_SRC_TMP_PATH) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) olddefconfig
	@grep -E '^CONFIG_ANDROID=|^CONFIG_ANDROID_BINDER_IPC=|^CONFIG_ANDROID_BINDER_DEVICES=|^CONFIG_ANDROID_BINDERFS=|^# CONFIG_ANDROID_BINDERFS is not set' $(KERNEL_SRC_TMP_PATH)/.config
	@$(KERNEL_MAKE) -C $(KERNEL_SRC_TMP_PATH) ARCH=$(KERNEL_ARCH) $(KERNEL_CROSS_COMPILE) -j$(shell nproc) Image dtbs

.PHONY: build-kernel clean info
build-kernel: $(KERNEL_IMAGE_FILE)

info:
	@echo "Build Information:"
	@echo "  PRODUCT_NAME: $(PRODUCT_NAME)"
	@echo "  OUT_DIR: $(OUT_DIR)"
	@echo "  KERNEL_SRC_TMP_PATH: $(KERNEL_SRC_TMP_PATH)"
	@echo "  KERNEL_IMAGE_FILE: $(KERNEL_IMAGE_FILE)"
	@echo "  KERNEL_SRC_PATH: $(KERNEL_SRC_PATH)"

clean:
	@echo "Cleaning kernel build..."
	@rm -rf $(OUT_DIR)/kernel $(OUT_DIR)/../kernel
	@echo "Kernel build cleaned"
	@echo "To rebuild, run: make -f kernel-5.10.mk"
