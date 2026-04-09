#!/bin/bash
# Indiedroid Nova LLM Setup Script
# Automated setup for RKLLM runtime and dependencies
# Tested on: Debian 12 (bookworm) aarch64, Kernel 6.1.0-1023-rockchip

set -e  # Exit on error

echo "=================================================="
echo "Indiedroid Nova LLM Setup"
echo "=================================================="
echo ""

# Check if running on aarch64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "ERROR: This script requires aarch64 architecture. Detected: $(uname -m)"
    exit 1
fi

echo "[1/7] Checking btrfs filesystem..."
if df -T / | grep -q btrfs; then
    TOTAL_SIZE=$(df -h / | awk 'NR==2 {print $2}')
    USED_SIZE=$(df -h / | awk 'NR==2 {print $3}')
    echo "  ✓ Detected btrfs filesystem"
    echo "  Current usage: $USED_SIZE / $TOTAL_SIZE"
    
    # Check for device slack (unallocated space in btrfs)
    SLACK=$(sudo btrfs filesystem usage / 2>/dev/null | grep -oP 'Device slack:\s+\K[0-9.]+\s*[KMGT]iB' || echo "0B")
    if [[ "$SLACK" != "0B" ]] && [[ "$SLACK" != "0.00B" ]]; then
        echo "  ⚠ Warning: Device slack detected: $SLACK"
        echo "  This means btrfs hasn't expanded to fill the partition."
        read -p "  Expand filesystem now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "  Expanding btrfs filesystem..."
            sudo btrfs filesystem resize max /
            echo "  ✓ Filesystem expanded"
        fi
    else
        echo "  ✓ Filesystem already at maximum size"
    fi
else
    echo "  ℹ Not using btrfs (this is fine)"
fi
echo ""

echo "[2/7] Installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-dev \
    git \
    build-essential \
    cmake \
    libopencv-dev
echo "  ✓ Dependencies installed"
echo ""

echo "[3/7] Installing Python packages..."
pip3 install --upgrade pip --break-system-packages
pip3 install "huggingface_hub[cli]" opencv-python --break-system-packages
echo "  ✓ Python packages installed"
echo ""

echo "[4/7] Cloning RKNN Toolkit..."
mkdir -p "$HOME/projects"
cd "$HOME/projects"

if [ ! -d "rknn-toolkit2" ]; then
    git clone --depth 1 https://github.com/airockchip/rknn-toolkit2.git
    echo "  ✓ RKNN Toolkit cloned"
else
    echo "  ℹ RKNN Toolkit already exists, skipping"
fi

# Install runtime library
echo "  Installing librknnrt.so..."
RUNTIME_LIB="$HOME/projects/rknn-toolkit2/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so"
if [ -f "$RUNTIME_LIB" ]; then
    sudo cp "$RUNTIME_LIB" /usr/lib/
    echo "  ✓ librknnrt.so installed to /usr/lib/"
else
    echo "  ⚠ librknnrt.so not found at expected path"
    echo "  You may need to find and copy it manually"
fi

# Install rknn-toolkit-lite2 Python package
echo "  Installing rknn-toolkit-lite2..."
PYVER=$(python3 -c 'import sys; print(f"cp{sys.version_info.major}{sys.version_info.minor}")')
echo "  Detected Python ABI tag: $PYVER"
WHEEL_PATH=$(find "$HOME/projects/rknn-toolkit2" -name "rknn_toolkit_lite2*${PYVER}*aarch64.whl" 2>/dev/null | head -1)
if [ -n "$WHEEL_PATH" ]; then
    pip3 install "$WHEEL_PATH" --break-system-packages
    echo "  ✓ rknn-toolkit-lite2 installed"
else
    echo "  ⚠ Wheel file not found, trying pip install"
    pip3 install rknn-toolkit-lite2 --break-system-packages || echo "  ⚠ Could not install rknn-toolkit-lite2"
fi
echo ""

echo "[5/7] Cloning ezrknn-llm (RKLLM CLI tool)..."
cd "$HOME/projects"

if [ ! -d "ezrknn-llm" ]; then
    git clone --depth 1 https://github.com/Pelochus/ezrknn-llm.git
    cd ezrknn-llm
    echo "  Running install.sh (this compiles the runtime)..."
    sudo bash install.sh
    echo "  ✓ ezrknn-llm installed"
else
    echo "  ℹ ezrknn-llm already exists"
    if ! command -v rkllm &> /dev/null; then
        echo "  rkllm not in PATH, running install..."
        cd ezrknn-llm
        sudo bash install.sh
    else
        echo "  ✓ rkllm binary already available"
    fi
fi
echo ""

echo "[6/7] Configuring user permissions..."
sudo usermod -aG render,video "$USER"
echo "  ✓ Added $USER to render and video groups"
echo "  ⚠ Log out and back in for group changes to take effect"
echo ""

echo "[7/7] Setting ulimit for LLM inference..."
if ! grep -q "ulimit -n 65536" "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Increase file descriptor limit for LLM inference" >> "$HOME/.bashrc"
    echo "ulimit -n 65536" >> "$HOME/.bashrc"
    echo "  ✓ ulimit added to .bashrc"
else
    echo "  ℹ ulimit already configured"
fi

# Add ~/.local/bin to PATH (required for pip-installed CLI tools on Debian 12)
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
    echo "" >> "$HOME/.bashrc"
    echo "# Add pip user scripts to PATH" >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "  ✓ PATH updated in .bashrc"
else
    echo "  ℹ PATH already configured"
fi
echo ""

echo "=================================================="
echo "✓ Setup Complete!"
echo "=================================================="
echo ""
echo "IMPORTANT: Log out and log back in for permissions to apply"
echo ""
echo "Next steps:"
echo ""
echo "1. Download a model:"
echo "   huggingface-cli download VRxiaojie/Qwen2.5-3B-Instruct-RKLLM --include '*.rkllm' --local-dir ~/models/qwen-3b"
echo ""
echo "2. Run inference:"
echo "   rkllm ~/models/qwen-3b/<model>.rkllm 1024 4096"
echo ""
echo "3. Use chat template (for instruction models like Qwen):"
echo "   <|im_start|>user"
echo "   Your prompt here<|im_end|>"
echo "   <|im_start|>assistant"
echo ""
