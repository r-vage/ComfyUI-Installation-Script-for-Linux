# ComfyUI Installation Script for Linux & Windows

Automated installation scripts for ComfyUI on **Linux** and **Windows** systems that handle everything from Python environment setup to custom node installation. These scripts provide a streamlined, dependency-conflict-free installation process with full control over package versions and installation steps.

## 🌟 Features

- **Automated Environment Setup**: Installs pyenv, Python, and creates an isolated virtual environment
- **Interactive Prompts**: Collects ComfyUI version, optional managed frontend version, and alias name at runtime
- **Version Control**: Pin specific versions of ComfyUI, PyTorch, NumPy, Transformers, and other critical packages
- **Optional Frontend Pinning**: Pin a frontend per launcher or preserve a custom/existing frontend package
- **GPU Acceleration**: Supports CUDA 13.0, CUDA 12.8, CUDA 12.6, ROCm 7.1, and CPU-only installations
- **Performance Optimization**: Includes optional Nunchaku, Flash Attention, and Sage Attention
- **Custom Node Collection**: Automatically clones and configures 51 popular custom nodes
- **Lowercase Cloning**: Clones custom nodes with lowercase directory names to match ComfyUI-Manager convention
- **Selective Installation**: Choose which components to install via interactive menu
- **Smart Dependency Management**: Prevents version conflicts by enforcing package versions
- **Per-Directory Sharing**: Independently centralize models, input, output, user data, and custom_nodes
- **Multi-Install Support**: Run multiple ComfyUI versions side-by-side with per-version aliases and launchers
- **Shell Integration**: Adds user-chosen aliases (e.g., `comfy2`, `comfy3`) with non-destructive, additive handling
- **Automatic Alias Naming**: Leaving the alias prompt empty selects `comfy`, then `comfy1`, `comfy2`, and so on
- **Multiple Shell Support**: Auto-detects and configures bash, zsh, and fish shells
- **Launch Arguments**: Append configurable flags to every generated alias and launcher

## 📋 Prerequisites

### Linux
- **Operating System**: Linux (Ubuntu, Debian, Fedora, Arch, openSUSE, etc.)
- **Permissions**: Sudo access for installing system dependencies
- **Disk Space**: ~10-20GB for full installation (varies with custom nodes)
- **GPU** (optional): NVIDIA GPU with CUDA support for acceleration features
- **Git**: For cloning repositories

### Windows
- **Operating System**: Windows 10 or Windows 11
- **PowerShell**: Version 5.1+ (included with Windows 10/11) or PowerShell 7+
- **Disk Space**: ~10-20GB for full installation
- **GPU** (optional): NVIDIA GPU with CUDA support for acceleration features
- **Git**: Git for Windows installed and in PATH ([download](https://git-scm.com/download/win))
- **Visual Studio Build Tools** (optional): Required only if building packages from source (e.g., flash-attn)

## 🚀 Quick Start

### Linux

```bash
# Download the script
git clone https://github.com/r-vage/ComfyUI-Installation-Script-for-Linux.git
cd ComfyUI-Installation-Script-for-Linux

# Make executable
chmod +x install_comfy_env.sh

# Run the script
./install_comfy_env.sh
```

### Windows

```powershell
# Download the script
git clone https://github.com/r-vage/ComfyUI-Installation-Script-for-Linux.git
cd ComfyUI-Installation-Script-for-Linux

# Allow script execution (if not already enabled)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the script
.\install_comfy_env_win.ps1
```

> **Note:** The Windows script uses **directory junctions** (similar to symlinks) which work without Administrator privileges. If you need true symlinks, run PowerShell as Administrator.

The script will display your configuration and prompt you to select which installation steps to run.

## ⚙️ Configuration

Before running the script, you can customize these variables at the top of `install_comfy_env.sh` (Linux) or `install_comfy_env_win.ps1` (Windows):

### Python Configuration

```bash
PYTHON_VERSION="3.12.10"          # Python version (3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x recommended)
VENV_PATH="/mnt/data/AI/comfy_env"  # Virtual environment location
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"  # pyenv installation directory
```

> **Windows equivalent:** `$PYTHON_VERSION = "3.12.10"` — venv path defaults to `$BASE_PATH\comfy_env` (e.g. `D:\AI\comfy_env`)

**Recommended Python versions**: 3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x have prebuilt wheels for PyTorch, Nunchaku, and Flash Attention. Other versions will require compilation from source.

### PyTorch Configuration

```bash
PYTORCH_VERSION="2.9"             # PyTorch major.minor for wheel URLs
PYTORCH_FULL_VERSION="2.9.1+cu128" # Full version string
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"  # Wheel repository
```

**Available options**:
- **CUDA 13.0**: `cu130` (latest)
- **CUDA 12.8**: `cu128` (default)
- **CUDA 12.6**: `cu126`
- **ROCm 7.1**: `rocm7.1` (AMD GPUs)
- **CPU only**: `cpu` (no GPU)

Example CUDA 13.0 configuration:
```bash
PYTORCH_FULL_VERSION="2.9.1+cu130"
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu130"
```

Example ROCm 7.1 configuration (AMD GPUs):
```bash
PYTORCH_FULL_VERSION="2.9.1+rocm7.1"
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/rocm7.1"
```

Example CPU configuration:
```bash
PYTORCH_FULL_VERSION="2.9.1+cpu"
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cpu"
```

### Critical Package Versions

```bash
NUMPY_VERSION="2.2.6"             # NumPy version (2.2.x for PyTorch 2.9+)
TRANSFORMERS_VERSION="5.3.0"      # Transformers (5.x for Qwen3-VL/Mistral3)
```

These versions are enforced at the end of installation to override any conflicting dependencies from custom nodes.

### ComfyUI Installation (Interactive)

When frontend management is enabled (the default), the script prompts for three values:

```
Enter values for this installation (press Enter for defaults):

  ComfyUI version [0.28.0]:     # → clones/checks out this tag (e.g., v0.28.0)
  Frontend version [1.45.21]:   # → pinned in aliases and launchers
  Launch alias [comfy]:         # → first available name (comfy, comfy1, comfy2, ...)
```

The folder name is derived automatically: version `0.28.0` → `ComfyUI_0.28.0`.

If the alias prompt is left empty, the installer checks existing shell/profile definitions and generated launcher files, then uses the first available name in the sequence `comfy`, `comfy1`, `comfy2`, etc. An explicitly entered alias is always used unchanged.

Static configuration (Python, PyTorch, NumPy, Transformers, launch arguments) stays at the top of the script and rarely changes.
Set `INSTALL_COMFYUI_FRONTEND=false` (`$false` on Windows) to skip the frontend-version prompt and prevent every installer and launcher path from installing, upgrading, downgrading, or enforcing `comfyui-frontend-package`. This includes frontend pins pulled from ComfyUI or custom-node requirements.

When sharing is enabled for a new installation, files introduced by the fresh ComfyUI checkout are copied into the shared directory only when the same relative path does not already exist. Existing shared files are never overwritten. The checkout folder is then removed and replaced by the symlink or junction. This also repairs a previous incomplete sharing setup when the local folder still contains only pristine checkout files. If an existing local installation contains modified, untracked, or ignored files while the shared directory also contains data, both directories are preserved and the installer asks you to merge them manually.

**Multiple ComfyUI Installations**:
Simply run the script again with different values at the prompts:
```
# First run:   version 0.28.0, alias comfy    → /mnt/data/AI/ComfyUI_0.28.0
# Second run:  version 0.19.0, alias comfy1   → /mnt/data/AI/ComfyUI_0.19.0
# Third run:   version 0.18.2, alias comfy2   → /mnt/data/AI/ComfyUI_0.18.2
```

Each installation gets its own alias and launcher script (`start_comfy2.sh` on Linux or `comfy2.bat`/`comfy2.ps1` on Windows).
All installations share the same venv. The five directory-sharing settings below determine whether models, input, output, user data, and custom nodes are shared or local to each installation.
The `envact` alias is always shared (one venv for all installs).

### Symlink / Junction Configuration

```bash
SYMLINK_MODELS=true                 # Share models
SYMLINK_INPUT=true                  # Share input
SYMLINK_OUTPUT=true                 # Share output
SYMLINK_USER=true                   # Share settings, workflows, and templates
SYMLINK_CUSTOM_NODES=true           # Share custom nodes
USER_MODELS_PATH="/mnt/data/AI/models"          # Centralized models directory
USER_INPUT_PATH="/mnt/data/AI/input"            # Centralized input directory
USER_OUTPUT_PATH="/mnt/data/AI/output"          # Centralized output directory
USER_USERDATA_PATH="/mnt/data/AI/user"          # Centralized user directory (settings, workflows, templates)
USER_CUSTOM_NODES_PATH="/mnt/data/AI/custom_nodes"  # Centralized custom_nodes directory
```

> **Windows equivalent:** use `$SYMLINK_MODELS`, `$SYMLINK_INPUT`, `$SYMLINK_OUTPUT`, `$SYMLINK_USER`, and `$SYMLINK_CUSTOM_NODES` with `$true`/`$false`. Paths default to `D:\AI\models`, `D:\AI\input`, `D:\AI\output`, `D:\AI\user`, and `D:\AI\custom_nodes` (using directory junctions instead of symlinks).

**Symlinks allow you to**:
- Share models across multiple ComfyUI installations
- Share input images across multiple ComfyUI installations
- Share custom nodes across multiple ComfyUI installations (useful when testing different ComfyUI versions)
- Share **user data** (frontend settings, saved workflows, node templates) across all versions — cross-version safe because `comfy.settings.json` is merged against frontend defaults at runtime
- Store models on a different drive/partition
- Keep outputs in a centralized location

Set any `SYMLINK_*` variable to `false` to keep that directory local. If an older run already created a link for a disabled path, the installer preserves it and prints removal instructions rather than detaching it automatically.

Migration is conservative: populated local data is copied only when the shared target is empty. If both directories contain data, both are preserved and the link is skipped until you merge them manually. A failed copy never causes the local directory to be removed.

> **Tip — directories outside `BASE_PATH`:**
> By default, the centralized paths (`USER_MODELS_PATH`, `USER_INPUT_PATH`, `USER_OUTPUT_PATH`, `USER_USERDATA_PATH`, `USER_CUSTOM_NODES_PATH`) are derived from `BASE_PATH`. You can point any of them to a completely different location — for example a larger disk — by editing the *"Derived Paths"* section in the script:
>
> **Linux:**
> ```bash
> USER_MODELS_PATH="/mnt/ssd2/models"             # Models on a fast SSD
> USER_OUTPUT_PATH="/home/$USER/comfyui_output"   # Output in home directory
> USER_USERDATA_PATH="/home/$USER/comfyui_user"   # User data in home directory
> ```
>
> **Windows:**
> ```powershell
> $USER_MODELS_PATH = "E:\models"                         # Models on drive E:
> $USER_OUTPUT_PATH = "C:\Users\$env:USERNAME\comfyui_out" # Output in user profile
> ```
>
> The script creates the target directories automatically and symlinks/junctions them into the ComfyUI tree.

### Optional Features

```bash
INSTALL_NUNCHAKU=true               # Nunchaku acceleration (requires NVIDIA GPU)
INSTALL_COMFYUI_FRONTEND=true       # Pin/install the configured frontend package
COMFYUI_LAUNCH_ARGS="--multi-user --disable-pinned-memory"
```

`COMFYUI_LAUNCH_ARGS` is appended after `python main.py` in every generated alias and launcher. Set it to an empty string to launch without predefined flags. Arguments supplied when invoking a launcher are appended after these configured defaults.

Set to `false` to skip Nunchaku installation if you don't have an NVIDIA GPU or don't need this optimization.

## 📦 What Gets Installed

### Installation Steps

The script is divided into 11 steps that you can run selectively:

1. **Python Environment** - pyenv, Python version, virtual environment
2. **PyTorch** - PyTorch, torchvision, torchaudio with CUDA/CPU support
3. **Nunchaku** - Acceleration library (optional, NVIDIA GPU only)
4. **Face Recognition** - facexlib, insightface, onnxruntime-gpu, facenet_pytorch
5. **ComfyUI Core** - ComfyUI base installation and requirements
6. **Custom Nodes** - 51 popular custom nodes (see list below)
7. **Custom Node Dependencies** - Install requirements for all custom nodes
8. **Performance Libraries** - llama-cpp-python, flash-attn, sageattention
9. **Upgrade/Pin Packages** - Upgrade specific packages to latest compatible versions
10. **Enforce Versions** - Force exact versions of PyTorch, NumPy, Transformers, ComfyUI Frontend
11. **Shell Aliases** - Add user-chosen launch alias and `envact` alias to shell config

### Custom Nodes Included (51 nodes)

#### Core Extensions
- [ComfyUI_Eclipse](https://github.com/r-vage/ComfyUI_Eclipse) - Extended toolkit with Smart LM subsystem
- [ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) - Node manager

> `ComfyUI-GGUF` and `ComfyUI-Florence2` are supplied through Eclipse's external-node integration and are not cloned separately.

#### UI & Workflow Tools
- [ComfyUI-Crystools-MonitorOnly](https://github.com/BobRandomNumber/ComfyUI-Crystools-MonitorOnly) - System resource monitoring
- [ComfyUI-Custom-Scripts](https://github.com/pythongosssss/ComfyUI-Custom-Scripts) - UI enhancements
- [rgthree-comfy](https://github.com/rgthree/rgthree-comfy) - Workflow utilities
- [ComfyUI-Easy-Use](https://github.com/yolain/ComfyUI-Easy-Use) - Simplified nodes
- [ComfyUI_essentials](https://github.com/cubiq/ComfyUI_essentials) - Essential utilities
- [ComfyUI_essentials_mb](https://github.com/MinorBoy/ComfyUI_essentials_mb) - Additional essentials
- [cg-image-filter](https://github.com/chrisgoringe/cg-image-filter) - Image filter/selector
- [comfyui-find-perfect-resolution](https://github.com/ashtar1984/comfyui-find-perfect-resolution) - Resolution calculator
- [WhatDreamsCost-ComfyUI](https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI) - Free workflow and media-generation utilities
- [ComfyUI-DaSiWa-Nodes](https://github.com/darksidewalker/ComfyUI-DaSiWa-Nodes) - DaSiWa utility nodes
- [Nvidia_RTX_Nodes_ComfyUI](https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI) - NVIDIA RTX optimization nodes

#### Model Support & Optimization
- [ComfyUI-TeaCache](https://github.com/welltop-cn/ComfyUI-TeaCache) - Cache-based inference acceleration
- [ComfyUI_Patches_ll](https://github.com/lldacing/ComfyUI_Patches_ll) - Performance patches

#### Sampling & Scheduling
- [RES4LYF](https://github.com/r-vage/RES4LYF) - Advanced samplers, schedulers, and noise types (fork)
- [sd-dynamic-thresholding](https://github.com/mcmonkeyprojects/sd-dynamic-thresholding) - Dynamic CFG thresholding
- [ComfyUI-Raffle](https://github.com/r-vage/ComfyUI-Raffle) - Semi-random prompt generator for danbooru tags (fork)
- [SeedVarianceEnhancer](https://github.com/ChangeTheConstants/SeedVarianceEnhancer) - Adds diversity to Z-Image Turbo outputs
- [ComfyUI-DyPE](https://github.com/wildminder/ComfyUI-DyPE) - Artifact-free 4K+ image generation
- [comfyui-WhiteRabbit](https://github.com/Artificial-Sweetener/comfyui-WhiteRabbit) - White Rabbit nodes

#### ControlNet & Advanced Control
- [ComfyUI-Advanced-ControlNet](https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet) - Advanced ControlNet features
- [comfyui_controlnet_aux](https://github.com/Fannovel16/comfyui_controlnet_aux) - ControlNet preprocessors

#### Image Processing & Effects
- [ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack) - Image enhancement suite
- [ComfyUI-Impact-Subpack](https://github.com/ltdrdata/ComfyUI-Impact-Subpack) - Impact Pack extensions
- [ComfyUI_LayerStyle](https://github.com/chflame163/ComfyUI_LayerStyle) - Layer effects
- [ComfyUI_LayerStyle_Advance](https://github.com/chflame163/ComfyUI_LayerStyle_Advance) - Advanced layer effects
- [ComfyUI-Detail-Daemon](https://github.com/Jonseed/ComfyUI-Detail-Daemon) - Detail enhancement
- [ComfyUI-KJNodes](https://github.com/kijai/ComfyUI-KJNodes) - Various utilities
- [ComfyUI_UltimateSDUpscale](https://github.com/ssitu/ComfyUI_UltimateSDUpscale) - Tiled upscaling
- [ComfyUI-CorridorKey](https://github.com/SeanBRVFX/ComfyUI-CorridorKey) - Native CorridorKey foreground and alpha-matting inference
- [ComfyUI_Fill-Nodes](https://github.com/filliptm/ComfyUI_Fill-Nodes) - Image, video, audio, file, and workflow utilities
- [ComfyUI-TiledDiffusion](https://github.com/shiimizu/ComfyUI-TiledDiffusion) - Tiled diffusion and VAE processing for large images

#### Specialized Models
- [ComfyUI-SUPIR](https://github.com/kijai/ComfyUI-SUPIR) - Super resolution
- [ComfyUI_BiRefNet_ll](https://github.com/lldacing/ComfyUI_BiRefNet_ll) - Background removal
- [ComfyUI_PuLID_Flux_ll](https://github.com/r-vage/ComfyUI_PuLID_Flux_ll) - Face ID for Flux (project fork)
- [comfyui-krea2edit](https://github.com/lbouaraba/comfyui-krea2edit) - Instruction-based Krea 2 image editing
- [ComfyUI-Krea2T-Enhancer](https://github.com/capitan01R/ComfyUI-Krea2T-Enhancer) - Krea 2 prompt-adherence enhancement
- [ComfyUI-SCAIL-Pose](https://github.com/kijai/ComfyUI-SCAIL-Pose) - Pose estimation

#### Audio & Media
- [ComfyUI-MMAudio](https://github.com/kijai/ComfyUI-MMAudio) - Multi-modal audio generation
- [ComfyUI-MelBandRoFormer](https://github.com/kijai/ComfyUI-MelBandRoFormer) - Audio source separation
- [comfyui-audio-expo](https://github.com/mattjohnpowell/comfyui-audio-expo) - Audio export utilities

#### Video Processing
- [ComfyUI-VideoHelperSuite](https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite) - Video utilities
- [ComfyUI-Frame-Interpolation](https://github.com/Fannovel16/ComfyUI-Frame-Interpolation) - Video frame interpolation
- [ComfyUI-GIMM-VFI](https://github.com/kijai/ComfyUI-GIMM-VFI) - GIMM video frame interpolation
- [ComfyUI-VFI](https://github.com/GACLove/ComfyUI-VFI) - RIFE video frame interpolation
- [ComfyUI-WanVideoWrapper](https://github.com/kijai/ComfyUI-WanVideoWrapper) - Wan video generation
- [ComfyUI-WanAnimatePreprocess](https://github.com/kijai/ComfyUI-WanAnimatePreprocess) - Wan animate preprocessing
- [ComfyUI-SeedVR2_VideoUpscaler](https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler) - Video upscaling
- [ComfyUI-WanMoeKSampler](https://github.com/stduhpf/ComfyUI-WanMoeKSampler) - Wan MoE sampling
- [ComfyUI-LTXVideo](https://github.com/Lightricks/ComfyUI-LTXVideo) - LTX video generation

## 🎯 Usage

### Interactive Installation

Run the script and select steps interactively:

```bash
./install_comfy_env.sh
```

You'll see a menu:
```
Select installation steps (numbers, ranges, or 'a' for all — e.g., 6-10 or 1 5 6-8):
  1) Python environment (pyenv + venv)
  2) PyTorch and base dependencies
  ...
  a) All steps (default)

Your selection [a]:
```

**Examples**:
- `a` - Install everything (default)
- `1 2 5` - Only setup Python, PyTorch, and ComfyUI core
- `6-7` - Only clone and setup custom nodes (if you already have ComfyUI)
- `5 9-11` - ComfyUI core + upgrade/pin/aliases
- `10` - Only enforce package versions (useful after manual package changes)

### Running ComfyUI

After installation, you have several options (examples assume alias `comfy2` and version `0.19.0`):

#### Linux

**Option 1: Launcher script (recommended)**
```bash
/mnt/data/AI/start_comfy2.sh
```

**Option 2: Shell alias (if Step 11 was run)**
```bash
comfy2    # Activates the environment and launches ComfyUI
```

**Option 3: Manual**
```bash
source /mnt/data/AI/comfy_env/bin/activate
cd /mnt/data/AI/ComfyUI_0.19.0
python main.py
```

#### Windows

**Option 1: Double-click launcher**
```
D:\AI\comfy2.bat
```

**Option 2: PowerShell launcher**
```powershell
D:\AI\comfy2.ps1
```

**Option 3: PowerShell alias (if Step 11 was run, after reloading profile)**
```powershell
comfy2
```

**Option 4: Manual**
```powershell
& "D:\AI\comfy_env\Scripts\Activate.ps1"
cd "D:\AI\ComfyUI_0.19.0"
python main.py
```

With `INSTALL_COMFYUI_FRONTEND=true`, each alias and launcher pins the configured frontend via `uv pip install -q comfyui-frontend-package==VERSION` (an instant no-op when already installed). With it disabled, launchers leave the current/custom frontend untouched. Both modes append `COMFYUI_LAUNCH_ARGS` to `python main.py`.

### Activating Virtual Environment Only

```bash
# Shared across all installations (Step 11)
envact

# Or manually
source /mnt/data/AI/comfy_env/bin/activate
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
And select steps `6-7` to update custom nodes and their dependencies.

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
- CUDA 12.6+ or compatible version
- Prebuilt wheels for your Python version

If you don't have an NVIDIA GPU, set `INSTALL_NUNCHAKU=false` and skip step 3.

### Custom Node Dependencies Conflict

If a custom node installs incompatible package versions, run step 10 to enforce configured versions:

```bash
./install_comfy_env.sh  # Select step 10 only
```

### Shell Aliases Not Working

#### Linux
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

#### Windows
After step 11, reload your PowerShell profile:

```powershell
. $PROFILE

# Or just restart PowerShell
```

### Windows: Execution Policy Error

If you get a script execution error:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Windows: pyenv-win Not Found After Installation

Close and reopen PowerShell. If still not found, ensure these are in your PATH:
- `%USERPROFILE%\.pyenv\pyenv-win\bin`
- `%USERPROFILE%\.pyenv\pyenv-win\shims`

### Windows: Flash Attention Not Available

Flash Attention rarely has prebuilt Windows wheels. You can either:
- Skip it (it's optional — ComfyUI works fine without it)
- Install Visual Studio Build Tools and compile from source
- Use Sage Attention as an alternative

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

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the version history and recent changes.

## 🙏 Acknowledgments

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) - The amazing stable diffusion GUI
- [pyenv](https://github.com/pyenv/pyenv) - Python version management (Linux)
- [pyenv-win](https://github.com/pyenv-win/pyenv-win) - Python version management (Windows)
- All the custom node developers for their incredible work

## 📞 Support

If you encounter issues:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [Issues](https://github.com/r-vage/ComfyUI-Installation-Script-for-Linux/issues)
3. Open a new issue with detailed information

---

**Happy ComfyUI-ing! 🎨**
