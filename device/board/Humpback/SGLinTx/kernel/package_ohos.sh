#!/bin/bash
set -e

# Paths
OHOS_ROOT="/home/openharmony"
IMAGE_DIR="${OHOS_ROOT}/out/SGLinTx/packages/phone/images"
PACK_DIR="${OHOS_ROOT}/out/SGLinTx/pack"
SDK_TOOLS="${OHOS_ROOT}/lichee_sdk/build/tools/common/sd_tools"
FIP_BIN="${OHOS_ROOT}/lichee_sdk/install/soc_sg2002_licheervnano_sd/fip.bin"

echo "Preparing packaging directory..."
mkdir -p ${PACK_DIR}
mkdir -p ${PACK_DIR}/input
mkdir -p ${PACK_DIR}/root
mkdir -p ${PACK_DIR}/output

# Copy artifacts
echo "Copying images..."
cp -v ${IMAGE_DIR}/Image ${PACK_DIR}/input/
cp -v ${IMAGE_DIR}/sg2002_licheervnano_sd.dtb ${PACK_DIR}/input/
cp -v ${IMAGE_DIR}/ramdisk.img ${PACK_DIR}/input/
cp -v ${IMAGE_DIR}/system.img ${PACK_DIR}/input/
cp -v ${IMAGE_DIR}/vendor.img ${PACK_DIR}/input/
cp -v ${IMAGE_DIR}/userdata.img ${PACK_DIR}/input/
cp -v ${FIP_BIN} ${PACK_DIR}/input/

# Generate FIT image
echo "Creating ITS file for FIT image..."
cat > ${PACK_DIR}/input/ohos_boot.its <<'ITS_EOF'
/dts-v1/;

/ {
    description = "OpenHarmony SGLinTx Boot Image";
    #address-cells = <1>;

    images {
        kernel-1 {
            description = "cvitek kernel";
            data = /incbin/("Image");
            type = "kernel";
            arch = "riscv";
            os = "linux";
            compression = "none";
            load = <0x80200000>;
            entry = <0x80200000>;
            hash-1 {
                algo = "crc32";
            };
        };

        fdt-sg2002_licheervnano_sd {
            description = "cvitek device tree - sg2002_licheervnano_sd";
            data = /incbin/("sg2002_licheervnano_sd.dtb");
            type = "flat_dt";
            arch = "riscv";
            compression = "none";
            hash-1 {
                algo = "sha256";
            };
        };

        ramdisk-1 {
            description = "cvitek ramdisk";
            data = /incbin/("ramdisk.img");
            type = "ramdisk";
            arch = "riscv";
            os = "linux";
            compression = "none";
            hash-1 {
                algo = "crc32";
            };
        };
    };

    configurations {
        default = "config-sg2002_licheervnano_sd";
        config-sg2002_licheervnano_sd {
            description = "boot cvitek system with board sg2002_licheervnano_sd";
            kernel = "kernel-1";
            fdt = "fdt-sg2002_licheervnano_sd";
            ramdisk = "ramdisk-1";
        };
    };
};
ITS_EOF

echo "Compiling FIT image (boot.sd)..."
cd ${PACK_DIR}/input
if ! mkimage -f ohos_boot.its boot.sd; then
    echo "ERROR: Failed to generate boot.sd"
    exit 1
fi
echo "✓ boot.sd generated successfully"
cd ${PACK_DIR}

# Copy additional vendor boot files (required for U-Boot environment detection)
echo "Copying vendor boot marker files..."
VENDOR_BOOT_FILES="${OHOS_ROOT}/lichee_sdk/install/soc_sg2002_licheervnano_sd"
if [ -d "${VENDOR_BOOT_FILES}" ]; then
    # Extract files from vendor boot.sd image if they exist
    VENDOR_IMG="${VENDOR_BOOT_FILES}/images/2026-01-21-18-59-f3639b.img"
    if [ -f "${VENDOR_IMG}" ]; then
        echo "Extracting marker files from vendor image..."
        mkdir -p ${PACK_DIR}/tmp_extract
        # Extract boot partition
        dd if=${VENDOR_IMG} bs=512 skip=1 count=32768 of=${PACK_DIR}/tmp_extract/boot.vfat 2>/dev/null
        # Copy marker files using mtools
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.dev ${PACK_DIR}/input/ 2>/dev/null || touch ${PACK_DIR}/input/usb.dev
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.ncm ${PACK_DIR}/input/ 2>/dev/null || touch ${PACK_DIR}/input/usb.ncm
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::usb.rndis ${PACK_DIR}/input/ 2>/dev/null || touch ${PACK_DIR}/input/usb.rndis
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::wifi.sta ${PACK_DIR}/input/ 2>/dev/null || touch ${PACK_DIR}/input/wifi.sta
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::gt9xx ${PACK_DIR}/input/ 2>/dev/null || touch ${PACK_DIR}/input/gt9xx
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::logo.jpeg ${PACK_DIR}/input/ 2>/dev/null || echo "logo.jpeg not found"
        mcopy -i ${PACK_DIR}/tmp_extract/boot.vfat ::ver ${PACK_DIR}/input/ 2>/dev/null || echo "OHOS-Port" > ${PACK_DIR}/input/ver
        rm -rf ${PACK_DIR}/tmp_extract
        echo "✓ Marker files extracted"
    else
        echo "⚠️  Vendor image not found, creating empty marker files"
        touch ${PACK_DIR}/input/usb.dev
        touch ${PACK_DIR}/input/usb.ncm
        touch ${PACK_DIR}/input/usb.rndis
        touch ${PACK_DIR}/input/wifi.sta
        touch ${PACK_DIR}/input/gt9xx
        echo "OHOS-Port" > ${PACK_DIR}/input/ver
    fi
fi

# Create genimage.cfg
echo "Creating genimage.cfg..."
cat <<EOF > ${PACK_DIR}/genimage.cfg
image boot.vfat {
    vfat {
        label = "boot"
        files = {
            "fip.bin",
            "boot.sd",
            "usb.dev",
            "usb.ncm",
            "usb.rndis",
            "wifi.sta",
            "gt9xx",
            "logo.jpeg",
            "ver"
        }
        # Match vendor FAT parameters EXACTLY: sectors-per-cluster=4, reserved=4, FAT16
        # NOTE: mkdosfs -s sets CLUSTER size, -R sets reserved sectors
        extraargs = "-F 16 -s 4 -R 4"
    }
    size = 16M  # CRITICAL: Match vendor size exactly for proper FAT geometry
}

image ohos_sglintx.img {
    hdimage {
    }

    partition boot {
        partition-type = 0x0C
        bootable = "true"
        image = "boot.vfat"
    }

    partition system {
        partition-type = 0x83
        image = "system.img"
    }

    partition vendor {
        partition-type = 0x83
        image = "vendor.img"
    }

    partition userdata {
        partition-type = 0x83
        image = "userdata.img"
    }
}
EOF

# Run genimage
echo "Running genimage..."
cd ${PACK_DIR}
GENIMAGE_TMP="${PACK_DIR}/tmp"
rm -rf ${GENIMAGE_TMP}
mkdir -p ${GENIMAGE_TMP}

# We use the genimage binary from SDK
export PATH=${SDK_TOOLS}:$PATH
export LD_LIBRARY_PATH=${SDK_TOOLS}/libconfuse/lib:$LD_LIBRARY_PATH
genimage --config genimage.cfg --tmppath ${GENIMAGE_TMP} --inputpath ${PACK_DIR}/input --outputpath ${PACK_DIR}/output

echo "-------------------------------------------------------"
echo "Image packaged successfully!"
echo "Result: ${PACK_DIR}/output/ohos_sglintx.img"
echo "-------------------------------------------------------"
