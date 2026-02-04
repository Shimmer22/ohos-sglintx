#!/usr/bin/env python3
"""
Kernel Image Analyzer
分析并对比 OHOS 编译的内核和 Vendor 内核的差异
"""

import struct
import sys
from pathlib import Path

class KernelImageAnalyzer:
    """分析 Linux RISC-V 内核 Image"""
    
    def __init__(self, image_path):
        self.path = Path(image_path)
        self.data = self.path.read_bytes()
        self.size = len(self.data)
        
    def analyze_header(self):
        """分析 RISC-V Image header (64 bytes)"""
        if self.size < 64:
            return {"error": "Image too small"}
        
        # RISC-V Image header structure:
        # 0x00: code (branch instruction or magic)
        # 0x08: image_size
        # 0x10: flags
        # 0x18: version
        # 0x20: res1
        # 0x28: res2
        # 0x30: magic ("RISCV\x00\x00\x00")
        # 0x38: res3
        
        header = {}
        
        # 读取前 8 字节的指令
        code = struct.unpack('<Q', self.data[0:8])[0]
        header['entry_code'] = f"0x{code:016x}"
        
        # 读取 image_size (offset 0x08)
        image_size = struct.unpack('<Q', self.data[8:16])[0]
        header['image_size'] = image_size
        header['image_size_mb'] = f"{image_size / 1024 / 1024:.2f} MB"
        
        # 读取 flags (offset 0x10)
        flags = struct.unpack('<Q', self.data[16:24])[0]
        header['flags'] = f"0x{flags:016x}"
        
        # 读取 version (offset 0x18)
        version = struct.unpack('<I', self.data[24:28])[0]
        header['version'] = version
        
        # 读取 magic (offset 0x30, 8 bytes)
        magic = self.data[48:56]
        header['magic'] = magic.hex()
        header['magic_str'] = magic.decode('ascii', errors='replace').rstrip('\x00')
        
        return header
    
    def find_strings(self, patterns, max_results=10):
        """在内核中搜索字符串"""
        results = {}
        data_str = self.data.decode('latin1', errors='ignore')
        
        for pattern in patterns:
            positions = []
            start = 0
            while len(positions) < max_results:
                pos = data_str.find(pattern, start)
                if pos == -1:
                    break
                positions.append(pos)
                start = pos + 1
            results[pattern] = positions
        
        return results
    
    def extract_linux_version(self):
        """提取 Linux 版本字符串"""
        # 搜索 "Linux version " 字符串
        marker = b"Linux version "
        pos = self.data.find(marker)
        if pos == -1:
            return None
        
        # 提取版本字符串（最多 200 字节）
        version_data = self.data[pos:pos+200]
        # 找到第一个换行符或 null
        end = version_data.find(b'\x00')
        if end == -1:
            end = version_data.find(b'\n')
        if end == -1:
            end = 200
        
        return version_data[:end].decode('ascii', errors='replace')
    
    def check_config_options(self, options):
        """检查内核是否包含特定配置选项的痕迹"""
        results = {}
        for opt in options:
            # 搜索配置项名称
            if opt.encode() in self.data:
                results[opt] = "FOUND"
            else:
                results[opt] = "NOT FOUND"
        return results
    
    def compare_with(self, other_analyzer):
        """与另一个内核进行对比"""
        comparison = {}
        
        # 对比大小
        comparison['size_diff'] = {
            'ohos': self.size,
            'vendor': other_analyzer.size,
            'diff_bytes': self.size - other_analyzer.size,
            'diff_percent': f"{((self.size - other_analyzer.size) / other_analyzer.size * 100):.2f}%"
        }
        
        # 对比头部
        h1 = self.analyze_header()
        h2 = other_analyzer.analyze_header()
        comparison['header_diff'] = {
            'ohos': h1,
            'vendor': h2
        }
        
        # 对比版本字符串
        v1 = self.extract_linux_version()
        v2 = other_analyzer.extract_linux_version()
        comparison['version'] = {
            'ohos': v1,
            'vendor': v2
        }
        
        return comparison

def main():
    # 内核路径
    ohos_image = "/home/openharmony/out/SGLinTx/packages/phone/images/Image"
    vendor_image = "/home/openharmony/lichee_sdk/linux_5.10/build/sg2002_licheervnano_sd/arch/riscv/boot/Image"
    
    print("=" * 80)
    print("RISC-V Kernel Image Analysis")
    print("=" * 80)
    print()
    
    # 检查文件是否存在
    ohos_path = Path(ohos_image)
    vendor_path = Path(vendor_image)
    
    if not ohos_path.exists():
        print(f"ERROR: OHOS Image not found: {ohos_image}")
        return 1
    
    if not vendor_path.exists():
        print(f"ERROR: Vendor Image not found: {vendor_image}")
        return 1
    
    # 分析两个内核
    print("Analyzing OHOS kernel...")
    ohos = KernelImageAnalyzer(ohos_image)
    
    print("Analyzing Vendor kernel...")
    vendor = KernelImageAnalyzer(vendor_image)
    
    print()
    print("=" * 80)
    print("1. Basic Information")
    print("=" * 80)
    
    print(f"\nOHOS Kernel:")
    print(f"  File: {ohos.path}")
    print(f"  Size: {ohos.size:,} bytes ({ohos.size / 1024 / 1024:.2f} MB)")
    
    print(f"\nVendor Kernel:")
    print(f"  File: {vendor.path}")
    print(f"  Size: {vendor.size:,} bytes ({vendor.size / 1024 / 1024:.2f} MB)")
    
    # Header 分析
    print()
    print("=" * 80)
    print("2. RISC-V Image Header")
    print("=" * 80)
    
    ohos_header = ohos.analyze_header()
    vendor_header = vendor.analyze_header()
    
    print(f"\nOHOS Header:")
    for key, value in ohos_header.items():
        print(f"  {key}: {value}")
    
    print(f"\nVendor Header:")
    for key, value in vendor_header.items():
        print(f"  {key}: {value}")
    
    # 版本字符串
    print()
    print("=" * 80)
    print("3. Linux Version String")
    print("=" * 80)
    
    ohos_ver = ohos.extract_linux_version()
    vendor_ver = vendor.extract_linux_version()
    
    print(f"\nOHOS:   {ohos_ver}")
    print(f"Vendor: {vendor_ver}")
    
    # 关键配置检查
    print()
    print("=" * 80)
    print("4. Key Configuration Strings")
    print("=" * 80)
    
    key_configs = [
        "CONFIG_CMDLINE",
        "CONFIG_SERIAL_8250",
        "CONFIG_EARLY_PRINTK",
        "CONFIG_KALLSYMS",
        "earlycon",
        "console=ttyS0",
        "keep_bootconsole"
    ]
    
    print("\nOHOS Kernel:")
    ohos_configs = ohos.check_config_options(key_configs)
    for opt, status in ohos_configs.items():
        print(f"  {opt}: {status}")
    
    print("\nVendor Kernel:")
    vendor_configs = vendor.check_config_options(key_configs)
    for opt, status in vendor_configs.items():
        print(f"  {opt}: {status}")
    
    # 差异汇总
    print()
    print("=" * 80)
    print("5. Summary of Differences")
    print("=" * 80)
    
    size_diff = ohos.size - vendor.size
    size_diff_pct = (size_diff / vendor.size * 100)
    
    print(f"\n• Size difference: {size_diff:+,} bytes ({size_diff_pct:+.2f}%)")
    
    if ohos_header['entry_code'] != vendor_header['entry_code']:
        print(f"• Entry code different!")
        print(f"  OHOS:   {ohos_header['entry_code']}")
        print(f"  Vendor: {vendor_header['entry_code']}")
    
    if ohos_ver != vendor_ver:
        print(f"• Version string different!")
    
    # 配置差异
    print(f"\n• Configuration string differences:")
    for opt in key_configs:
        if ohos_configs[opt] != vendor_configs[opt]:
            print(f"  - {opt}: OHOS={ohos_configs[opt]}, Vendor={vendor_configs[opt]}")
    
    print()
    print("=" * 80)
    print("Analysis Complete")
    print("=" * 80)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
