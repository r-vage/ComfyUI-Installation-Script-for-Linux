# ComfyUI Installation Script for Linux

An automated installation script for ComfyUI on Linux systems that handles everything from Python environment setup to custom node installation. This script provides a streamlined, dependency-conflict-free installation process with full control over package versions and installation steps.

## 🌟 Features

- **Automated Environment Setup**: Installs pyenv, Python, and creates an isolated virtual environment
- **Version Control**: Pin specific versions of ComfyUI, PyTorch, NumPy, Transformers, and other critical packages
- **GPU Acceleration**: Supports CUDA 12.8, CUDA 12.1, and CPU-only installations
- **Performance Optimization**: Includes optional Nunchaku, Flash Attention, and Sage Attention
- **Custom Node Collection**: Automatically clones and configures 30+ popular custom nodes
- **Selective Installation**: Choose which components to install via interactive menu
- **Smart Dependency Management**: Prevents version conflicts by enforcing package versions
- **Symlink Support**: Centralize models and outputs across multiple installations
- **Shell Integration**: Adds convenient aliases (`comfyui`, `envact`) to your shell
- **Multiple Shell Support**: Auto-detects and configures bash, zsh, and fish shells

## 📋 Prerequisites

- **Operating System**: Linux (Ubuntu, Debian, Fedora, Arch, openSUSE, etc.)
- **Permissions**: Sudo access for installing system dependencies
- **Disk Space**: ~10-20GB for full installation (varies with custom nodes)
- **GPU** (optional): NVIDIA GPU with CUDA support for acceleration features
- **Git**: For cloning repositories

## 🚀 Quick Start

```bash
# Download the script
git clone https://github.com/yourusername/ComfyUI-Installation-Script-for-Linux.git
cd ComfyUI-Installation-Script-for-Linux

# Make executable
chmod +x install_comfy_env.sh

# Run the script
./install_comfy_env.sh
```

The script will display your configuration and prompt you to select which installation steps to run.

## ⚙️ Configuration

Before running the script, you can customize these variables at the top of `install_comfy_env.sh`:

### Python Configuration

```bash
PYTHON_VERSION="3.12.10"          # Python version (3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x recommended)
VENV_PATH="/mnt/daten/AI/comfy_env"  # Virtual environment location
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"  # pyenv installation directory
```

**Recommended Python versions**: 3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x have prebuilt wheels for PyTorch, Nunchaku, and Flash Attention. Other versions will require compilation from source.

### PyTorch Configuration

```bash
PYTORCH_VERSION="2.9"             # PyTorch major.minor for wheel URLs
PYTORCH_FULL_VERSION="2.9.1+cu128" # Full version string
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"  # Wheel repository
```

**Available options**:
- **CUDA 12.8**: `cu128` (default, latest)
- **CUDA 12.1**: `cu121` (older hardware)
- **CPU only**: `cpu` (no GPU)

Example CPU configuration:
```bash
PYTORCH_FULL_VERSION="2.9.1+cpu"
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
```

### Critical Package Versions

```bash
NUMPY_VERSION="2.2.6"             # NumPy version (2.2.x for PyTorch 2.9+)
TRANSFORMERS_VERSION="4.57.3"      # Transformers (4.57+ for Qwen3-VL/Mistral3)
```

These versions are enforced at the end of installation to override any conflicting dependencies from custom nodes.

### ComfyUI Installation

```bash
COMFYUI_PARENT_DIR="/mnt/daten/AI"  # Parent directory for ComfyUI
COMFYUI_DIR_NAME="ComfyUI"          # Folder name
COMFYUI_VERSION=""                  # ComfyUI version (tag, branch, or commit SHA)
```

ComfyUI will be cloned to: `${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}`

**Version Selection**:
- Leave `COMFYUI_VERSION=""` (empty) to clone the latest version from the default branch
- Set to a specific tag: `COMFYUI_VERSION="v0.2.0"` (use tags from the [ComfyUI releases](https://github.com/comfyanonymous/ComfyUI/tags))
- Set to a branch name: `COMFYUI_VERSION="master"` or `COMFYUI_VERSION="dev"`
- Set to a commit SHA: `COMFYUI_VERSION="abc123def456"`

Examples:
```bash
COMFYUI_VERSION=""              # Latest version (default)
COMFYUI_VERSION="v0.2.0"        # Specific release tag
COMFYUI_VERSION="master"        # Master branch
COMFYUI_VERSION="abc123"        # Specific commit
```

### Symlink Configuration

```bash
CREATE_SYMLINKS=true                # Enable/disable symlink creation
USER_MODELS_PATH="/mnt/daten/AI/models"  # Centralized models directory
USER_OUTPUT_PATH="/mnt/daten/AI/output"  # Centralized output directory
```

**Symlinks allow you to**:
- Share models across multiple ComfyUI installations
- Store models on a different drive/partition
- Keep outputs in a centralized location

Set `CREATE_SYMLINKS=false` to use default `ComfyUI/models` and `ComfyUI/output` directories.

### Optional Features

```bash
INSTALL_NUNCHAKU=true               # Nunchaku acceleration (requires NVIDIA GPU)
```

Set to `false` to skip Nunchaku installation if you don't have an NVIDIA GPU or don't need this optimization.

## 📦 What Gets Installed

### Installation Steps

The script is divided into 11 steps that you can run selectively:

1. **Python Environment** - pyenv, Python version, virtual environment
2. **PyTorch** - PyTorch, torchvision, torchaudio with CUDA/CPU support
3. **Nunchaku** - Acceleration library (optional, NVIDIA GPU only)
4. **Face Recognition** - facexlib, insightface, onnxruntime-gpu, facenet_pytorch
5. **ComfyUI Core** - ComfyUI base installation and requirements
6. **Custom Nodes** - 30+ popular custom nodes (see list below)
7. **Custom Node Dependencies** - Install requirements for all custom nodes
8. **Performance Libraries** - llama-cpp-python, flash-attn, sageattention
9. **Upgrade/Pin Packages** - Upgrade specific packages to latest compatible versions
10. **Enforce Versions** - Force exact versions of PyTorch, NumPy, Transformers
11. **Shell Aliases** - Add `comfyui` and `envact` aliases to shell config

### Custom Nodes Included

#### Core Extensions
- ComfyUI_SmartLML - Smart Language Model Loader
- ComfyUI_Eclipse - Extended toolkit
- ComfyUI-Manager - Node manager

#### UI & Workflow Tools
- ComfyUI-Crystools-MonitorOnly - System monitoring
- ComfyUI-Custom-Scripts - UI enhancements
- rgthree-comfy - Workflow utilities
- ComfyUI-Easy-Use - Simplified nodes
- ComfyUI_essentials - Essential utilities
- ComfyUI_essentials_mb - Additional essentials

#### Model Support & Optimization
- ComfyUI-GGUF - GGUF model support
- ComfyUI-nunchaku - Nunchaku integration
- ComfyUI-TeaCache - Caching optimizations
- ComfyUI_Patches_ll - Performance patches

#### ControlNet & Advanced Control
- ComfyUI-Advanced-ControlNet - Advanced ControlNet features
- comfyui_controlnet_aux - ControlNet preprocessors

#### Image Processing & Effects
- ComfyUI-Impact-Pack - Image enhancement suite
- ComfyUI_LayerStyle - Layer effects
- ComfyUI_LayerStyle_Advance - Advanced layer effects
- ComfyUI-Detail-Daemon - Detail enhancement
- ComfyUI-KJNodes - Various utilities
- Comfyui_TTP_Toolset - Additional tools
- ComfyUI-Raffle - Random generation
- sd-dynamic-thresholding - Dynamic thresholding
- was-node-suite-comfyui - WAS toolkit

#### Specialized Models
- ComfyUI-Florence2 - Florence2 model support
- ComfyUI-SUPIR - Super resolution
- ComfyUI_BiRefNet_ll - Background removal
- ComfyUI_PuLID_Flux_ll - Face ID for Flux
- ComfyUI-ReActor - Face swapping

#### Video Processing
- ComfyUI-VideoHelperSuite - Video utilities
- ComfyUI-Frame-Interpolation - Video frame interpolation
- ComfyUI-GIMM-VFI - Video frame interpolation
- ComfyUI-WanVideoWrapper - Video processing

#### Custom/Additional
- RES4LYF - Resolution presets
- comfy_mtb - MTB's custom nodes

## 🎯 Usage

### Interactive Installation

Run the script and select steps interactively:

```bash
./install_comfy_env.sh
```

You'll see a menu:
```
Select installation steps (enter numbers separated by spaces, or 'a' for all):
  1) Python environment (pyenv + venv)
  2) PyTorch and base dependencies
  ...
  a) All steps (default)

Your selection [a]:
```

**Examples**:
- `a` - Install everything (default)
- `1 2 5` - Only setup Python, PyTorch, and ComfyUI core
- `6 7` - Only clone and setup custom nodes (if you already have ComfyUI)
- `10` - Only enforce package versions (useful after manual package changes)

### Running ComfyUI

After installation, you have three options:

**Option 1: Launcher script (recommended)**
```bash
/mnt/daten/AI/start_comfyui.sh
```

**Option 2: Shell alias (if Step 11 was run)**
```bash
comfyui
```

**Option 3: Manual**
```bash
source /mnt/daten/AI/comfy_env/bin/activate
cd /mnt/daten/AI/ComfyUI
python main.py
```

### Activating Virtual Environment Only

```bash
# If aliases are configured (Step 11)
envact

# Or manually
source /mnt/daten/AI/comfy_env/bin/activate
```

## 🔧 Customizing Custom Nodes

To add/remove custom nodes, edit the `[6/10] Clone Custom Nodes` section around line 550:

```bash
# Add your custom node:
clone_if_missing "https://github.com/yourusername/your-custom-node.git"

# Remove a node by commenting it out or deleting the line:
# clone_if_missing "https://github.com/some/node-you-dont-want.git"
```

Then run:
```bash
./install_comfy_env.sh
```
And select steps `6 7` to update custom nodes and their dependencies.

## 🐛 Troubleshooting

### pyenv Installation Fails

If pyenv dependencies fail to install, you may need to manually install build dependencies for your distribution:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install build-essential libssl-dev zlib1g-dev \
libbz2-dev libreadline-dev libsqlite3-dev curl git \
libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
```

**Fedora:**
```bash
sudo dnf install make gcc patch zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel libuuid-devel gdbm-libs libnsl2
```

### Nunchaku or Flash Attention Installation Fails

These require:
- NVIDIA GPU
- CUDA 12.8 or compatible version
- Prebuilt wheels for your Python version

If you don't have an NVIDIA GPU, set `INSTALL_NUNCHAKU=false` and skip step 3.

### Custom Node Dependencies Conflict

If a custom node installs incompatible package versions, run step 10 to enforce configured versions:

```bash
./install_comfy_env.sh  # Select step 10 only
```

### Shell Aliases Not Working

After step 11, you need to reload your shell configuration:

```bash
# For bash
source ~/.bashrc

# For zsh
source ~/.zshrc

# For fish
source ~/.config/fish/config.fish

# Or just restart your terminal
```

### Out of Disk Space

The full installation requires 10-20GB. To reduce space:
- Skip custom nodes (don't run step 6-7)
- Remove unused custom nodes manually from `custom_nodes/` directory
- Use symlinks to store models on a different drive

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**:
   - Add new custom nodes to the installation list
   - Update package versions
   - Add support for new Linux distributions
   - Improve error handling
4. **Test your changes** on a fresh system if possible
5. **Commit your changes** (`git commit -m 'Add amazing feature'`)
6. **Push to the branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Reporting Issues

When reporting issues, please include:
- Your Linux distribution and version
- Python version being installed
- Full error output
- Which installation step failed

## 📝 License

This script is provided as-is for the ComfyUI community. Feel free to modify and distribute.

## 🙏 Acknowledgments

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) - The amazing stable diffusion GUI
- [pyenv](https://github.com/pyenv/pyenv) - Python version management
- All the custom node developers for their incredible work

## 📞 Support

If you encounter issues:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [Issues](https://github.com/yourusername/ComfyUI-Installation-Script-for-Linux/issues)
3. Open a new issue with detailed information

---

**Happy ComfyUI-ing! 🎨**
