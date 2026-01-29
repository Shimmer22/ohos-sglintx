# SGLinTx OpenHarmony Port

This repository contains the board and vendor configuration files for porting OpenHarmony 3.2 Standard System to the SGLinTx (LicheeRV Nano) board.

## Directory Structure
*   `device/board/Humpback/SGLinTx`: Board-specific build scripts and kernel patches.
*   `vendor/Humpback/SGLinTx`: Product definition and config.json.

## Usage
To use these files in an OpenHarmony source tree:

1. Copy the `device` and `vendor` directories to your OpenHarmony root:
   ```bash
   cp -r device vendor /path/to/openharmony/
   ```

2. Run the build:
   ```bash
   ./build.sh --product-name SGLinTx --ccache
   ```
