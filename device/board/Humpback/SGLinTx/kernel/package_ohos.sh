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

# Create genimage.cfg
echo "Creating genimage.cfg..."
cat <<EOF > ${PACK_DIR}/genimage.cfg
image boot.vfat {
    vfat {
        label = "boot"
        files = {
            "fip.bin",
            "Image",
            "sg2002_licheervnano_sd.dtb",
            "ramdisk.img"
        }
    }
    size = 128M
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
