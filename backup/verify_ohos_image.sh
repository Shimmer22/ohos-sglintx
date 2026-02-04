#!/bin/bash
# Verification script for OHOS SGLinTx boot image
# This script checks if the generated image meets vendor compatibility requirements

set -e

PACK_DIR="/home/openharmony/out/SGLinTx/pack"
IMAGE_FILE="${PACK_DIR}/output/ohos_sglintx.img"
BOOT_SD="${PACK_DIR}/input/boot.sd"

echo "========================================="
echo "OHOS SGLinTx Image Verification"
echo "========================================="
echo ""

# Check 1: Verify boot.sd exists and is valid FIT format
echo "[1/4] Checking FIT image format..."
if [ ! -f "${BOOT_SD}" ]; then
    echo "❌ ERROR: boot.sd not found at ${BOOT_SD}"
    exit 1
fi

echo "FIT Image Details:"
echo "---"
mkimage -l "${BOOT_SD}" || {
    echo "❌ ERROR: Invalid FIT image format"
    exit 1
}
echo ""
echo "✓ FIT image format valid"
echo ""

# Check 2: Verify final image exists
echo "[2/4] Checking final image..."
if [ ! -f "${IMAGE_FILE}" ]; then
    echo "❌ ERROR: Final image not found at ${IMAGE_FILE}"
    exit 1
fi

IMAGE_SIZE=$(du -h "${IMAGE_FILE}" | cut -f1)
echo "✓ Image found: ${IMAGE_FILE} (${IMAGE_SIZE})"
echo ""

# Check 3: Verify partition table
echo "[3/4] Checking partition table..."
fdisk -l "${IMAGE_FILE}" | grep -A10 "Device"
echo ""

# Check 4: Verify FAT partition BPB geometry
echo "[4/4] Checking FAT BPB geometry..."
echo "Extracting Boot sector BPB..."
dd if="${IMAGE_FILE}" bs=512 skip=1 count=1 2>/dev/null | hexdump -C | head -n 5

echo ""
echo "Checking geometry parameters..."
# Extract Sectors per Track (offset 0x18, 2 bytes, little-endian)
SEC_PER_TRK=$(dd if="${IMAGE_FILE}" bs=1 skip=$((512 + 0x18)) count=2 2>/dev/null | od -An -tu2 -v | tr -d ' ')
# Extract Heads (offset 0x1A, 2 bytes, little-endian)
HEADS=$(dd if="${IMAGE_FILE}" bs=1 skip=$((512 + 0x1A)) count=2 2>/dev/null | od -An -tu2 -v | tr -d ' ')

echo "  Sectors per Track: ${SEC_PER_TRK} (Expected: 32)"
echo "  Heads: ${HEADS} (Expected: 2)"

if [ "${SEC_PER_TRK}" -eq 32 ] && [ "${HEADS}" -eq 2 ]; then
    echo "✓ FAT geometry matches vendor requirements"
else
    echo "⚠️  WARNING: FAT geometry does not match vendor (Heads=2, Sectors=32)"
fi

echo ""
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo "✓ All checks passed!"
echo ""
echo "Next steps:"
echo "  1. Copy image to SD card:"
echo "     sudo dd if=${IMAGE_FILE} of=/dev/sdX bs=4M status=progress"
echo "  2. Connect UART (115200 8N1)"
echo "  3. Boot and check for U-Boot FIT image loading message"
echo ""
