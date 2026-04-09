# Indiedroid Nova LLM Benchmarks

**Running Llama 3.1 8B and other LLMs on the RK3588 NPU**

I wanted to see if the Indiedroid Nova could actually beat a Raspberry Pi 5 for local LLM inference. Short answer: yes, by a lot. The NPU makes a real difference, getting 2-3× the performance on comparable models.

[![Hardware](https://img.shields.io/badge/Hardware-Indiedroid%20Nova-blue)](https://ameridroid.com/products/indiedroid-nova)
[![OS](https://img.shields.io/badge/OS-Debian%2012-red)](https://www.debian.org/)
[![NPU](https://img.shields.io/badge/NPU-RK3588S%206%20TOPS-green)](https://www.rock-chips.com/a/en/products/RK35_Series/2022/0926/1660.html)

---

## 🚀 Performance Results

| Model | Size | Speed | RAM | NPU Utilization |
|-------|------|-------|-----|-----------------|
| **Llama 3.1 8B Instruct** | 8.59 GB | **3.72 tok/s** | 8.5 GiB | 79% avg, 83% peak |
| **Qwen 2.5 3B Instruct** | ~3.5 GB | **7.0 tok/s** | 4.0 GiB | 68% avg |
| **DeepSeek-R1 1.5B** | ~2.0 GB | **11.5 tok/s** | 2.6 GiB | 60% avg |

### vs. Raspberry Pi 5

| Model Size | Nova (NPU) | Pi 5 (CPU) | Advantage |
|------------|-----------|-----------|-----------|
| **1.5B** | 11.5 t/s | ~6-8 t/s | **1.5-2× faster** |
| **3B** | 7.0 t/s | ~2-3 t/s | **2-3× faster** |
| **8B** | 3.72 t/s | ~2.0 t/s | **1.9× faster** |

*Pi 5 benchmarks from Jeff Geerling and community testing (llama.cpp, CPU-only)*

---

## 💻 Hardware Specifications

- **Board:** Indiedroid Nova  
- **SoC:** Rockchip RK3588S (4× Cortex-A76 @ 2.3GHz + 4× Cortex-A55 @ 1.8GHz)  
- **NPU:** 6 TOPS (3 cores), RKNPU driver v0.9.7  
- **RAM:** 16GB LPDDR4x  
- **Storage:** 64GB eMMC  
- **OS:** Debian 12 (bookworm) aarch64  
- **Kernel:** 6.1.0-1023-rockchip  
- **Runtime:** RKLLM 1.2.1  

---

## 🎯 Why This Matters

Look, I like the Pi 5. But for LLM inference it's pushing everything through CPU cores. No dedicated AI hardware. Once you hit 7-8B models, it starts swapping to disk and you're looking at 1-2 tok/s if you're lucky.

The Nova has a 6 TOPS NPU that actually does the heavy lifting. Same 16GB RAM as a maxed Pi 5, but the 8B model runs entirely in memory with hardware acceleration.

Basically: Nova runs bigger, smarter models at the speed the Pi 5 runs smaller, dumber ones.

---

## 📦 Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/TrevTron/indiedroid-nova-llm.git
cd indiedroid-nova-llm
```

### 2. Run Setup Script

```bash
chmod +x setup-nova.sh
./setup-nova.sh
```

This installs:
- Python 3.11+ (auto-detected) + dependencies
- RKNN Toolkit Lite 2
- RKLLM CLI tools (ezrknn-llm)
- Runtime libraries
- Configures permissions and ulimits

**Important:** Log out and back in after setup (for group permissions).

### 3. Download a Model

Using HuggingFace CLI:

```bash
# Install HuggingFace CLI
pip3 install "huggingface_hub[cli]" --break-system-packages

# Add pip scripts to PATH (required on Debian 12)
export PATH="$HOME/.local/bin:$PATH"

# Make it permanent (if not already done by setup-nova.sh)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Download Qwen 2.5 3B (recommended starting point)
huggingface-cli download VRxiaojie/Qwen2.5-3B-Instruct-RKLLM1.1.4 \
    --include "*.rkllm" \
    --local-dir ~/models/qwen-3b

# Or download Llama 3.1 8B
huggingface-cli download c01zaut/Llama-3.1-8B-Instruct-rk3588-1.1.1 \
    --include "*.rkllm" \
    --local-dir ~/models/llama-8b
```

**Model Compatibility:** Use models converted with RKLLM runtime **1.1.4 or newer**. Older conversions (May-June 2024) will fail with "model version too old" errors.

### 4. Run Inference

**Terminal 1** - Start monitoring:
```bash
chmod +x monitor-npu.sh
./monitor-npu.sh my_benchmark.log
```

**Terminal 2** - Run inference:
```bash
rkllm ~/models/qwen-3b/Qwen2.5-3B-Instruct-rk3588-w8a8.rkllm 1024 4096
```

Then paste your prompt. For **instruction-tuned models**, use the correct chat template:

**Llama 3.1:**
```
<|begin_of_text|><|start_header_id|>user<|end_header_id|>

List all 50 US state capitals in alphabetical order by state name.<|eot_id|><|start_header_id|>assistant<|end_header_id|>


```

**Qwen:**
```
<|im_start|>user
List all 50 US state capitals in alphabetical order by state name.<|im_end|>
<|im_start|>assistant

```

---

## 📊 Detailed Results

### Llama 3.1 8B Instruct (c01zaut w8a8-opt-1-hybrid-ratio-1.0)

**Performance:**
- Speed: **3.72 tokens/second**
- Output: 411 tokens in 110.52 seconds
- Model size: 8.59 GB

**Resource Usage:**
- RAM: 8.5-8.6 GiB sustained (8.6 GiB peak)
- NPU: 79% average per core, 83% peak
- All 3 NPU cores balanced within 1-2%

**Comparison:**
- Pi 5 (16GB, Llama 3.1 8B): ~1.99 tok/s (Jeff Geerling)
- **Nova advantage: 1.9× faster**

### Qwen 2.5 3B Instruct (VRxiaojie)

**Performance:**
- Speed: **7.0 tokens/second** average
- Test 1: 444 tokens in 63.95s (6.94 t/s)
- Test 2: 1018 tokens in 143.11s (7.11 t/s)

**Resource Usage:**
- RAM: 4.0 GiB flat (no spikes during 143s run)
- NPU: 68% average, 66-70% range
- Perfect load distribution across 3 cores

**Quality:**
- **ALL 50 state capitals correct** (DeepSeek 1.5B got ~30-35 right)
- Coherent technical explanations
- No hallucinations observed

**Comparison:**
- Pi 5 (Phi 3.5 3.8B): ~2 tok/s
- **Nova advantage: 3.5× faster on comparable model**

### DeepSeek-R1-Distill-Qwen-1.5B

**Performance:**
- Speed: **11.5 tokens/second** average
- Consistent across 256-2048 token runs (11.32-11.73 t/s)

**Resource Usage:**
- RAM: 2.6 GiB stable
- NPU: 58-68% depending on load
- Efficient but lower quality output

**Quality Note:**
- Fast but lower accuracy (~30-35 state capitals correct)
- Good for speed testing, not production use

---

## 🛠️ Troubleshooting

### "Only 3.5GB usable after flashing 64GB SD card"

This one got me. The Debian image uses btrfs instead of ext4, and btrfs doesn't auto-expand on first boot like you'd expect coming from Pi OS.

Fix it with:
```bash
# Check current usage
df -h /

# Check for device slack
sudo btrfs filesystem usage /

# Expand to fill partition
sudo btrfs filesystem resize max /

# Verify
df -h /
```

**Why this matters:** Pi OS uses ext4 (auto-expands). This is a gotcha for Pi users switching to Nova.

### "Model version too old" error

Ran into this a bunch. The current RKLLM runtime (1.2.1) won't load models converted back in May-June 2024.

Stick with:
- VRxiaojie (recent conversions, runtime 1.1.4+)
- c01zaut (also recent)
- Official Rockchip examples

Pelochus has great blog posts but his model files are outdated now.

### Model outputs garbage

Probably forgot the chat template. Llama 3.1 and Qwen need specific formatting or they just spit out nonsense.

Check the Quick Start section for the templates. The `run-benchmark.py` script also shows the right format for common models.

### NPU shows 0% during inference

Make sure the driver is loaded and you have the right permissions:

```bash
# Check if NPU driver is there
ls -la /sys/kernel/debug/rknpu/

# Your user needs to be in render and video groups
groups

# If you just ran setup, log out and back in
```

---

## 📁 Repository Structure

```
indiedroid-nova-llm/
├── README.md                 # This file
├── setup-nova.sh             # Automated setup script
├── monitor-npu.sh            # NPU/RAM monitoring script
├── run-benchmark.py          # Python helper (shows commands + chat templates)
├── benchmarks/
│   └── results.md            # Detailed benchmark analysis with all test data
└── images/
    ├── neofetch.png          # System specs screenshot
    ├── desktop.png           # GNOME desktop
    └── README.md             # Screenshot guide
```

---

## 🔗 Resources

### Purchase Hardware
- **AmeriDroid:** [Indiedroid Nova](https://ameridroid.com/products/indiedroid-nova?ref=ioqothsk)  
  16GB model with 64GB eMMC + heatsink + fan: **$179.95**  
  *(Pi 5 16GB is $150 but requires separate microSD, cooling, etc.)*

### Model Sources (Runtime 1.1.4+ Compatible)
- **Qwen2.5-3B-Instruct-RKLLM:** [HuggingFace](https://huggingface.co/VRxiaojie/Qwen2.5-3B-Instruct-RKLLM1.1.4)
- **Llama-3.1-8B-Instruct-RKLLM:** [HuggingFace](https://huggingface.co/c01zaut/Llama-3.1-8B-Instruct-rk3588-1.1.1)

### Official Documentation
- **AmeriDroid Wiki:** [Indiedroid Nova User Guide](https://wiki.indiedroid.us/en/Nova/user-guide)
- **RKNN Toolkit:** [GitHub](https://github.com/airockchip/rknn-toolkit2)
- **ezrknn-llm:** [GitHub](https://github.com/Pelochus/ezrknn-llm)

### Community
- **Reddit:** [r/LocalLLaMA](https://reddit.com/r/LocalLLaMA)
- **Discord:** [AmeriDroid Community](https://discord.gg/CstQjW8gX9)

---

## 🙏 Acknowledgments

**Hardware provided by [AmeriDroid](https://ameridroid.com).**  
Testing conducted independently by Trevor Unland.

Special thanks to:
- **Rockchip** for RKNN toolkit and NPU support
- **Pelochus** for ezrknn-llm wrapper (excellent work!)
- **VRxiaojie** and **c01zaut** for maintaining up-to-date model conversions
- **Jeff Geerling** for Pi 5 benchmark data

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

## 👤 Author

**Trevor Unland**  
- Website: [unland.dev](https://unland.dev)  
- GitHub: [@TrevTron](https://github.com/TrevTron)  
- Email: [trevorunland@gmail.com](mailto:trevorunland@gmail.com)

---

## 🎯 The Bottom Line

Yeah, the Pi 5 has `ollama pull modelname` going for it. That's nice. But the second you want to try different quantizations or test new models, you're downloading from HuggingFace and reading docs anyway, same as RK3588.

I got the Nova working with the same tools Pi users use. HuggingFace, Python, standard Linux stuff. Just 2-3× faster because there's actual AI hardware doing the work.

Honestly, the "complexity gap" is overblown. If you can set up a Pi, you can set up this.

---

**⭐ If this repository helped you, please star it!**
