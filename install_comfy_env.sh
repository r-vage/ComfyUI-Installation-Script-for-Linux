#!/bin/bash
# ComfyUI Environment Installation Script
# Installs packages in specific order to avoid dependency conflicts

set -e  # Exit on error

# ============================================
# Configuration Variables - Adjust as needed
# ============================================
# Recommended Python versions: 3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x
# These versions have prebuilt wheels for PyTorch, nunchaku, and flash-attn
# Other versions may work but will require compilation from source
PYTHON_VERSION="3.12.10"          # Python version to install via pyenv
VENV_PATH="/mnt/daten/AI/comfy_env"  # Virtual environment location
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"  # pyenv installation directory

# PyTorch version configuration
PYTORCH_VERSION="2.9"             # PyTorch major.minor version for wheel URLs (e.g., 2.9, 2.10)
PYTORCH_FULL_VERSION="2.9.1+cu128" # Full PyTorch version for pip install (e.g., 2.9.1+cu128, 2.10.0+cpu)
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"  # PyTorch index URL (cu128, cu121, cpu)

# Critical package versions (enforced at end to override custom node dependencies)
NUMPY_VERSION="2.2.6"             # NumPy version (2.2.x compatible with PyTorch 2.9+)
TRANSFORMERS_VERSION="4.57.3"      # Transformers version (5.x for Qwen3-VL/Mistral3 support)

# ComfyUI installation configuration
COMFYUI_PARENT_DIR="/mnt/daten/AI"  # Parent directory where ComfyUI will be cloned
COMFYUI_DIR_NAME="ComfyUI"          # ComfyUI folder name (change if you want a different name)

# Symlink configuration for models and output
CREATE_SYMLINKS=true                # Set to false to skip symlink creation
USER_MODELS_PATH="/mnt/daten/AI/models"  # Your centralized models directory
USER_OUTPUT_PATH="/mnt/daten/AI/output"  # Your centralized output directory

# Optional features (set to false to disable)
INSTALL_NUNCHAKU=true               # Set to false to skip Nunchaku (NVIDIA GPU required)

# Detect shell and config file
DETECTED_SHELL="Unknown"
SHELL_CONFIG_FILE=""
if [ -n "$BASH_VERSION" ]; then
    DETECTED_SHELL="bash"
    SHELL_CONFIG_FILE="~/.bashrc"
elif [ -n "$ZSH_VERSION" ]; then
    DETECTED_SHELL="zsh"
    SHELL_CONFIG_FILE="~/.zshrc"
elif [[ "$SHELL" == *"fish"* ]]; then
    DETECTED_SHELL="fish"
    SHELL_CONFIG_FILE="~/.config/fish/config.fish"
elif [[ "$SHELL" == *"bash"* ]]; then
    DETECTED_SHELL="bash"
    SHELL_CONFIG_FILE="~/.bashrc"
elif [[ "$SHELL" == *"zsh"* ]]; then
    DETECTED_SHELL="zsh"
    SHELL_CONFIG_FILE="~/.zshrc"
else
    DETECTED_SHELL="$(basename "$SHELL" 2>/dev/null || echo "Unknown")"
    SHELL_CONFIG_FILE="~/.profile"
fi

echo "=========================================="
echo "ComfyUI Environment Setup"
echo "=========================================="
echo "Configuration:"
echo "  Python Version: $PYTHON_VERSION"
echo "  PyTorch Version: $PYTORCH_FULL_VERSION (torchvision/torchaudio auto-selected)"
echo "  NumPy Version: $NUMPY_VERSION"
echo "  Transformers Version: $TRANSFORMERS_VERSION"
echo "  ComfyUI Location: $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME"
echo "  Virtual Env: $VENV_PATH"
echo "  Pyenv Root: $PYENV_ROOT"
echo "  Shell: $DETECTED_SHELL"
echo "  Shell Config: $SHELL_CONFIG_FILE"
if $CREATE_SYMLINKS; then
    echo "  Symlinks: Enabled"
    echo "    Models: $USER_MODELS_PATH"
    echo "    Output: $USER_OUTPUT_PATH"
else
    echo "  Symlinks: Disabled"
fi
echo "=========================================="
echo ""
echo "Select installation steps (enter numbers separated by spaces, or 'a' for all):"
echo ""
echo "  1) Python environment (pyenv + venv)"
echo "  2) PyTorch and base dependencies"
echo "  3) Nunchaku acceleration library"
echo "  4) Face recognition libraries"
echo "  5) ComfyUI core"
echo "  6) Clone custom nodes"
echo "  7) Install custom node dependencies"
echo "  8) Performance libraries (llama-cpp, flash-attn, sageattention)"
echo "  9) Upgrade and pin package versions"
echo " 10) Enforce final package versions"
echo " 11) Configure shell aliases (comfyui, envact)"
echo ""
echo "  a) All steps (default)"
echo ""
read -p "Your selection [a]: " STEP_SELECTION
STEP_SELECTION=${STEP_SELECTION:-a}

# Initialize step flags
STEP_1=false
STEP_2=false
STEP_3=false
STEP_4=false
STEP_5=false
STEP_6=false
STEP_7=false
STEP_8=false
STEP_9=false
STEP_10=false
STEP_11=false

# Parse selection
if [[ "$STEP_SELECTION" == "a" ]]; then
    STEP_1=true
    STEP_2=true
    STEP_3=$INSTALL_NUNCHAKU  # Only install Nunchaku if enabled (NVIDIA GPU required)
    STEP_4=true
    STEP_5=true
    STEP_6=true
    STEP_7=true
    STEP_8=true
    STEP_9=true
    STEP_10=true
    STEP_11=true
else
    for num in $STEP_SELECTION; do
        case $num in
            1) STEP_1=true ;;
            2) STEP_2=true ;;
            3) STEP_3=true ;;
            4) STEP_4=true ;;
            5) STEP_5=true ;;
            6) STEP_6=true ;;
            7) STEP_7=true ;;
            8) STEP_8=true ;;
            9) STEP_9=true ;;
            10) STEP_10=true ;;
            11) STEP_11=true ;;
            *) echo "Unknown option: $num" ;;
        esac
    done
fi

# Display selected steps
echo ""
echo "Selected steps:"
$STEP_1 && echo "  ✓ Python environment"
$STEP_2 && echo "  ✓ PyTorch and base dependencies"
$STEP_3 && echo "  ✓ Nunchaku"
$STEP_4 && echo "  ✓ Face recognition libraries"
$STEP_5 && echo "  ✓ ComfyUI core"
$STEP_6 && echo "  ✓ Clone custom nodes"
$STEP_7 && echo "  ✓ Custom node dependencies"
$STEP_8 && echo "  ✓ Performance libraries"
$STEP_9 && echo "  ✓ Upgrade/pin packages"
$STEP_10 && echo "  ✓ Enforce final versions"
$STEP_11 && echo "  ✓ Configure shell aliases"
echo ""
read -p "Continue with these steps? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

# ============================================================================
# Activate existing virtual environment if present
# ============================================================================
# If running steps 2-10 without step 1, we need to activate the existing venv
if [ -d "$VENV_PATH" ] && [ -f "$VENV_PATH/bin/activate" ]; then
    if ! $STEP_1; then
        echo "Found existing virtual environment at $VENV_PATH"
        echo "Activating virtual environment..."
        source "$VENV_PATH/bin/activate"
        echo "✓ Virtual environment activated"
        echo ""
    fi
fi

# ============================================================================
# [1/10] Python Environment Setup
# ============================================================================
if $STEP_1; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [1/10] Setting up Python Environment"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if pyenv is installed
if ! command -v pyenv &> /dev/null; then
    echo "[Setup] pyenv not found. Installing pyenv..."
    
    # Detect package manager and install pyenv dependencies
    echo "Detecting package manager..."
    if command -v apt-get &> /dev/null; then
        echo "Detected: Debian/Ubuntu (apt-get)"
        echo "Installing pyenv dependencies (requires sudo)..."
        sudo apt-get update
        sudo apt-get install -y make build-essential libssl-dev zlib1g-dev \
            libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
            libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
            libffi-dev liblzma-dev
    elif command -v dnf &> /dev/null; then
        echo "Detected: Fedora/RHEL (dnf)"
        echo "Installing pyenv dependencies (requires sudo)..."
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y gcc make patch zlib-devel bzip2 bzip2-devel \
            readline-devel sqlite sqlite-devel openssl-devel tk-devel \
            libffi-devel xz-devel libuuid-devel gdbm-devel libnsl2-devel
    elif command -v yum &> /dev/null; then
        echo "Detected: CentOS/RHEL (yum)"
        echo "Installing pyenv dependencies (requires sudo)..."
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y gcc make patch zlib-devel bzip2 bzip2-devel \
            readline-devel sqlite sqlite-devel openssl-devel tk-devel \
            libffi-devel xz-devel
    elif command -v pacman &> /dev/null; then
        echo "Detected: Arch Linux (pacman)"
        echo "Installing pyenv dependencies (requires sudo)..."
        sudo pacman -Syu --needed --noconfirm base-devel openssl zlib xz tk
    elif command -v zypper &> /dev/null; then
        echo "Detected: openSUSE (zypper)"
        echo "Installing pyenv dependencies (requires sudo)..."
        sudo zypper install -y gcc make patch zlib-devel bzip2 libbz2-devel \
            readline-devel sqlite3 sqlite3-devel libopenssl-devel tk-devel \
            libffi-devel xz-devel
    else
        echo "⚠️  WARNING: Could not detect package manager"
        echo "   Supported: apt-get, dnf, yum, pacman, zypper"
        echo "   Attempting to install pyenv anyway (may fail without dependencies)"
        echo ""
        read -p "Continue without installing dependencies? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled. Please install pyenv dependencies manually."
            exit 1
        fi
    fi
    
    # Install pyenv
    echo "Installing pyenv..."
    curl https://pyenv.run | bash
    
    # Add pyenv to PATH for this session
    export PYENV_ROOT="$PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    echo "✓ pyenv installed successfully"
    
    # Detect shell config file
    if [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    else
        SHELL_CONFIG="$HOME/.profile"
    fi
    
    # Check if pyenv initialization is already in config
    if [ -f "$SHELL_CONFIG" ] && grep -q 'PYENV_ROOT' "$SHELL_CONFIG"; then
        echo "✓ pyenv already configured in $SHELL_CONFIG"
    else
        echo "Adding pyenv initialization to $SHELL_CONFIG..."
        cat >> "$SHELL_CONFIG" << 'EOF'

# pyenv initialization
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
        echo "✓ pyenv initialization added to $SHELL_CONFIG"
        echo "⚠️  IMPORTANT: Run 'source $SHELL_CONFIG' or restart your shell"
    fi
    echo ""
else
    echo "✓ pyenv is already installed"
    # Initialize pyenv for current session
    export PYENV_ROOT="$PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

# Check if the required Python version is installed
if ! pyenv versions --bare | grep -q "^${PYTHON_VERSION}$"; then
    echo "[Setup] Installing Python $PYTHON_VERSION via pyenv..."
    pyenv install "$PYTHON_VERSION"
    echo "✓ Python $PYTHON_VERSION installed"
else
    echo "✓ Python $PYTHON_VERSION already installed"
fi

# Set local Python version
echo "[Setup] Setting Python version to $PYTHON_VERSION..."
pyenv local "$PYTHON_VERSION"

# Verify Python version
CURRENT_PYTHON=$(python --version 2>&1 | awk '{print $2}')
echo "✓ Using Python $CURRENT_PYTHON"

# Extract Python version for wheel compatibility (e.g., 3.12.10 -> cp312)
PYTHON_MAJOR_MINOR=$(python -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')
PYTHON_WHEEL_TAG="cp${PYTHON_MAJOR_MINOR}"
echo "✓ Python wheel tag: $PYTHON_WHEEL_TAG"

# Validate Python version compatibility
SUPPORTED_VERSIONS=("cp310" "cp311" "cp312" "cp313" "cp314")
if [[ ! " ${SUPPORTED_VERSIONS[@]} " =~ " ${PYTHON_WHEEL_TAG} " ]]; then
    echo "⚠️  WARNING: Python ${CURRENT_PYTHON} (${PYTHON_WHEEL_TAG}) may not have prebuilt wheels"
    echo "   Supported versions: Python 3.10, 3.11, 3.12, 3.13, 3.14"
    echo "   Installation will attempt fallback methods but may take longer or fail"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled. Please use Python 3.10, 3.11, 3.12, 3.13, or 3.14"
        exit 1
    fi
fi

# Check if venv exists, create if not
if [ ! -d "$VENV_PATH" ]; then
    echo "[0/10] Creating virtual environment at $VENV_PATH..."
    python -m venv "$VENV_PATH"
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists at $VENV_PATH"
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source "$VENV_PATH/bin/activate"
echo "✓ Virtual environment activated"

# Upgrade pip first
echo "Upgrading pip..."
pip install --upgrade pip

fi  # End STEP_1

# ============================================================================
# [2/10] Install PyTorch
# ============================================================================
if $STEP_2; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [2/10] Installing PyTorch and Base Dependencies"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Install PyTorch
# Note: PyTorch version is configurable via PYTORCH_FULL_VERSION variable
# Ensure nunchaku and flash-attn wheels are available for selected PyTorch version
# torchvision and torchaudio versions are automatically selected by PyTorch index
echo "Installing PyTorch ${PYTORCH_FULL_VERSION}..."
pip install torch==${PYTORCH_FULL_VERSION} torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}

fi  # End STEP_2

# ============================================================================
# [3/10] Install Nunchaku
# ============================================================================
if $STEP_3; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [3/10] Installing Nunchaku Acceleration Library"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Install nunchaku for PyTorch (dynamically select correct wheel for Python and PyTorch version)
echo "Installing nunchaku 1.2.1 for PyTorch ${PYTORCH_VERSION} (Python ${PYTHON_WHEEL_TAG})..."
NUNCHAKU_WHEEL="https://github.com/nunchaku-ai/nunchaku/releases/download/v1.2.1/nunchaku-1.2.1+cu12.8torch${PYTORCH_VERSION}-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-linux_x86_64.whl"
pip install "$NUNCHAKU_WHEEL" || {
    echo "⚠️  Prebuilt nunchaku wheel not found for PyTorch ${PYTORCH_VERSION} / Python ${PYTHON_WHEEL_TAG}"
    echo "   Trying to install from source or latest compatible version..."
    pip install nunchaku || echo "⚠️  Nunchaku installation failed (optional)"
}

fi  # End STEP_3

# ============================================================================
# [4/10] Install Face Recognition and Runtime Libraries
# ============================================================================
if $STEP_4; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [4/10] Installing Face Recognition and Runtime Libraries"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Create temporary constraints file to prevent torch downgrade
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
numpy>=${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
EOF

# Install packages that may pull wrong dependencies (install early to override later)
echo "Installing face recognition and runtime libraries..."
echo "Using constraints to prevent torch/numpy/transformers downgrade"
pip install --constraint "$CONSTRAINTS_FILE" facexlib
pip install --constraint "$CONSTRAINTS_FILE" insightface
pip install --constraint "$CONSTRAINTS_FILE" onnxruntime
pip install --constraint "$CONSTRAINTS_FILE" onnxruntime-gpu
pip install --constraint "$CONSTRAINTS_FILE" comfy-cli
pip install --constraint "$CONSTRAINTS_FILE" bitsandbytes>=0.46.1
pip install --constraint "$CONSTRAINTS_FILE" tensorflow
pip install --constraint "$CONSTRAINTS_FILE" hf-xet
pip install --constraint "$CONSTRAINTS_FILE" requests
pip install --constraint "$CONSTRAINTS_FILE" pilgram
pip install --constraint "$CONSTRAINTS_FILE" tf-keras

# Install facenet_pytorch
echo "Installing facenet_pytorch"
pip install --constraint "$CONSTRAINTS_FILE" facenet_pytorch

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_4

# ============================================================================
# [5/10] Install ComfyUI
# ============================================================================
if $STEP_5; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [5/10] Installing ComfyUI Core"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

COMFYUI_DIR="${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}"

# Check if ComfyUI is already cloned
if [ ! -d "$COMFYUI_DIR/.git" ]; then
    echo "Cloning ComfyUI repository to $COMFYUI_DIR..."
    mkdir -p "$COMFYUI_PARENT_DIR"
    cd "$COMFYUI_PARENT_DIR"
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR_NAME"
else
    echo "✓ ComfyUI already exists at $COMFYUI_DIR"
fi

# Install ComfyUI base requirements
echo ""
echo "Installing ComfyUI dependencies..."
cd "$COMFYUI_DIR"

# Create temporary constraints file to prevent torch downgrade
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
numpy>=${NUMPY_VERSION}
EOF
echo "Using constraints to prevent torch/numpy downgrade"
pip install --constraint "$CONSTRAINTS_FILE" -r requirements.txt
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_5

# ============================================================================
# Create Symlinks for Models and Output
# ============================================================================
if $CREATE_SYMLINKS; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Creating Symlinks for Models and Output"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR is set
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

# Create user directories if they don't exist
mkdir -p "$USER_MODELS_PATH"
mkdir -p "$USER_OUTPUT_PATH"

# Handle models directory
if [ -L "$COMFYUI_DIR/models" ]; then
    echo "✓ models is already a symlink"
elif [ -d "$COMFYUI_DIR/models" ]; then
    echo "⚠️  Removing existing models directory at $COMFYUI_DIR/models"
    rm -rf "$COMFYUI_DIR/models"
    ln -s "$USER_MODELS_PATH" "$COMFYUI_DIR/models"
    echo "✓ Created symlink: $COMFYUI_DIR/models -> $USER_MODELS_PATH"
else
    ln -s "$USER_MODELS_PATH" "$COMFYUI_DIR/models"
    echo "✓ Created symlink: $COMFYUI_DIR/models -> $USER_MODELS_PATH"
fi

# Handle output directory
if [ -L "$COMFYUI_DIR/output" ]; then
    echo "✓ output is already a symlink"
elif [ -d "$COMFYUI_DIR/output" ]; then
    echo "⚠️  Removing existing output directory at $COMFYUI_DIR/output"
    rm -rf "$COMFYUI_DIR/output"
    ln -s "$USER_OUTPUT_PATH" "$COMFYUI_DIR/output"
    echo "✓ Created symlink: $COMFYUI_DIR/output -> $USER_OUTPUT_PATH"
else
    ln -s "$USER_OUTPUT_PATH" "$COMFYUI_DIR/output"
    echo "✓ Created symlink: $COMFYUI_DIR/output -> $USER_OUTPUT_PATH"
fi

fi  # End CREATE_SYMLINKS

# ============================================================================
# [6/10] Clone Custom Nodes
# ============================================================================
if $STEP_6; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [6/10] Cloning Custom Nodes"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR is set (may not be if STEP_5 was skipped)
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

# Create custom_nodes directory if it doesn't exist
mkdir -p "$CUSTOM_NODES_DIR"
cd "$CUSTOM_NODES_DIR"

# Function to clone a custom node if not already present
clone_if_missing() {
    local repo_url="$1"
    local repo_name=$(basename "$repo_url" .git)
    
    if [ ! -d "$repo_name/.git" ]; then
        echo "→ Cloning $repo_name..."
        git clone "$repo_url" || echo "⚠️  Failed to clone $repo_name"
    else
        echo "✓ $repo_name already exists"
    fi
}

# Core Extensions
echo "Cloning core extensions..."
clone_if_missing "https://github.com/r-vage/ComfyUI_SmartLML.git"
clone_if_missing "https://github.com/r-vage/ComfyUI_Eclipse.git"
clone_if_missing "https://github.com/Comfy-Org/ComfyUI-Manager.git"

# UI & Workflow Tools
echo ""
echo "Cloning UI & workflow tools..."
clone_if_missing "https://github.com/r-vage/ComfyUI-Crystools-MonitorOnly.git"
clone_if_missing "https://github.com/r-vage/ComfyUI-Custom-Scripts.git"
clone_if_missing "https://github.com/r-vage/rgthree-comfy.git"
clone_if_missing "https://github.com/yolain/ComfyUI-Easy-Use.git"
clone_if_missing "https://github.com/cubiq/ComfyUI_essentials.git"
clone_if_missing "https://github.com/MinorBoy/ComfyUI_essentials_mb.git"

# Model Support & Optimization
echo ""
echo "Cloning model support & optimization..."
clone_if_missing "https://github.com/city96/ComfyUI-GGUF.git"
clone_if_missing "https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
clone_if_missing "https://github.com/r-vage/ComfyUI-TeaCache.git"
clone_if_missing "https://github.com/r-vage/ComfyUI_Patches_ll.git"

# ControlNet & Advanced Control
echo ""
echo "Cloning ControlNet & advanced control..."
clone_if_missing "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
clone_if_missing "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

# Image Processing & Effects
echo ""
echo "Cloning image processing & effects..."
clone_if_missing "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
clone_if_missing "https://github.com/chflame163/ComfyUI_LayerStyle.git"
clone_if_missing "https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git"
clone_if_missing "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git"
clone_if_missing "https://github.com/kijai/ComfyUI-KJNodes.git"
clone_if_missing "https://github.com/TTPlanetPig/Comfyui_TTP_Toolset.git"
clone_if_missing "https://github.com/rainlizard/ComfyUI-Raffle.git"
clone_if_missing "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
clone_if_missing "https://github.com/ltdrdata/was-node-suite-comfyui.git"

# Specialized Models
echo ""
echo "Cloning specialized models..."
clone_if_missing "https://github.com/kijai/ComfyUI-Florence2.git"
clone_if_missing "https://github.com/kijai/ComfyUI-SUPIR.git"
clone_if_missing "https://github.com/lldacing/ComfyUI_BiRefNet_ll.git"
clone_if_missing "https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git"
clone_if_missing "https://github.com/Gourieff/ComfyUI-ReActor.git"

# Video Processing
echo ""
echo "Cloning video processing..."
clone_if_missing "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
clone_if_missing "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
clone_if_missing "https://github.com/kijai/ComfyUI-GIMM-VFI.git"
clone_if_missing "https://github.com/kijai/ComfyUI-WanVideoWrapper.git"

# Custom/Additional
echo ""
echo "Cloning custom/additional nodes..."
clone_if_missing "https://github.com/r-vage/RES4LYF.git"
clone_if_missing "https://github.com/melMass/comfy_mtb.git"


fi  # End STEP_6

# ============================================================================
# [7/10] Install Custom Node Dependencies
# ============================================================================
if $STEP_7; then

# Ensure COMFYUI_DIR and CUSTOM_NODES_DIR are set
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFYUI_DIR/custom_nodes}"

# Create temporary constraints file to prevent torch/transformers downgrade
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
numpy>=${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
EOF

# Install dependencies for all custom nodes
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Installing dependencies for all custom nodes..."
echo "═══════════════════════════════════════════════════════════════════"
echo "Using constraints to prevent torch/numpy/transformers downgrade"
for node_dir in "$CUSTOM_NODES_DIR"/*; do
    if [ -d "$node_dir" ] && [ -f "$node_dir/requirements.txt" ]; then
        node_name=$(basename "$node_dir")
        echo ""
        echo "→ Installing dependencies for: $node_name"
        pip install --constraint "$CONSTRAINTS_FILE" -r "$node_dir/requirements.txt" || echo "⚠️  Some dependencies for $node_name failed (may be optional)"
    fi
done

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_7

# ============================================================================
# [8/10] Install Performance Libraries
# ============================================================================
if $STEP_8; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [8/10] Installing Performance Libraries"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Create temporary constraints file
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
numpy>=${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
EOF

# Install llama-cpp-python
echo "Installing llama-cpp-python..."
pip install --constraint "$CONSTRAINTS_FILE" llama-cpp-python>=0.3.16

# Install flash-attn (pre-built wheel for PyTorch + CUDA 12.8)
echo "Installing Flash Attention 2.8.3 for PyTorch ${PYTORCH_VERSION} (Python ${PYTHON_WHEEL_TAG})..."
FLASH_ATTN_WHEEL="https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch${PYTORCH_VERSION}cxx11abiTRUE-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-linux_x86_64.whl"
pip install "$FLASH_ATTN_WHEEL" 2>/dev/null || {
    echo "⚠️  Prebuilt flash-attn wheel not found for PyTorch ${PYTORCH_VERSION} / Python ${PYTHON_WHEEL_TAG}"
    echo "   Attempting to install from PyPI or skip..."
    pip install --constraint "$CONSTRAINTS_FILE" flash-attn --no-build-isolation 2>/dev/null || echo "⚠️  Flash Attention installation failed (optional)"
}

# Try sageattention
echo "Installing Sage Attention..."
pip install --constraint "$CONSTRAINTS_FILE" sageattention 2>/dev/null || echo "⚠️  Sage Attention installation failed (optional)"

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_8

# ============================================================================
# [9/10] Upgrade & Pin Package Versions
# ============================================================================
if $STEP_9; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [9/10] Upgrading & Pinning Package Versions"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Create temporary constraints file
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
numpy>=${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
EOF

# Upgrade specific packages to latest versions
echo "Upgrading packages to latest versions..."
pip install --constraint "$CONSTRAINTS_FILE" --upgrade av
pip install --constraint "$CONSTRAINTS_FILE" --upgrade ultralytics
pip install --constraint "$CONSTRAINTS_FILE" --upgrade onnxruntime
pip install --constraint "$CONSTRAINTS_FILE" --upgrade onnxruntime-gpu
pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference 2>/dev/null || echo "⚠️  inference upgrade skipped"
pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference-gpu 2>/dev/null || echo "⚠️  inference-gpu upgrade skipped"
pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference-cli 2>/dev/null || echo "⚠️  inference-cli upgrade skipped"
pip install --constraint "$CONSTRAINTS_FILE" --upgrade opencv-python
pip install --constraint "$CONSTRAINTS_FILE" --upgrade gguf

# Pin critical package versions
echo "Pinning critical package versions..."
pip install mistral-common>=1.8.6
pip install numpy>=${NUMPY_VERSION}
pip install transformers==${TRANSFORMERS_VERSION}

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_9

# ============================================================================
# [10/10] Enforce Configured Package Versions
# ============================================================================
if $STEP_10; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [10/10] Enforcing Configured Package Versions"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Note: Custom nodes may have installed incompatible versions."
echo "      Ensuring PyTorch ${PYTORCH_FULL_VERSION}, NumPy ${NUMPY_VERSION}, Transformers ${TRANSFORMERS_VERSION}"
echo ""

# Ensure PyTorch with exact configured version (will upgrade/downgrade if needed)
# torchvision and torchaudio versions are automatically selected by PyTorch index
pip install torch==${PYTORCH_FULL_VERSION} torchvision torchaudio --index-url ${PYTORCH_INDEX_URL} || {
    echo "⚠️  PyTorch installation failed, continuing anyway..."
}

# Ensure NumPy and Transformers with exact configured versions
pip install numpy==${NUMPY_VERSION} || {
    echo "⚠️  NumPy installation failed, continuing anyway..."
}
pip install transformers==${TRANSFORMERS_VERSION} || {
    echo "⚠️  Transformers installation failed, continuing anyway..."
}

echo "✓ Package versions enforced successfully"

fi  # End STEP_10

# ============================================================================
# [11/11] Configure Shell Aliases
# ============================================================================
if $STEP_11; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [11/11] Configuring Shell Aliases"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR is set (may not be if STEP_5 was skipped)
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

# Function to add/update aliases in a shell config file
add_bash_aliases() {
    local config_file="$1"
    local config_name="$2"
    
    # Check if aliases already exist
    if [ -f "$config_file" ] && grep -q "alias comfyui=" "$config_file"; then
        echo "✓ ComfyUI aliases already exist in $config_name"
        echo "Current aliases:"
        grep "alias comfy\|alias envact" "$config_file" || true
        echo ""
        read -p "Update aliases in $config_name? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping $config_name"
            return
        fi
        # Remove old aliases
        sed -i '/# ComfyUI aliases/,+2d' "$config_file" 2>/dev/null || true
        sed -i '/alias comfyui=/d' "$config_file" 2>/dev/null || true
        sed -i '/alias envact=/d' "$config_file" 2>/dev/null || true
    fi
    
    # Add new aliases
    cat >> "$config_file" << EOF

# ComfyUI aliases
alias comfyui='source $VENV_PATH/bin/activate && cd $COMFYUI_DIR && python main.py'
alias envact='source $VENV_PATH/bin/activate'
EOF
    echo "✓ Aliases added to $config_name"
}

# Function to add/update Fish shell functions
add_fish_functions() {
    local config_file="$1"
    
    # Check if functions already exist
    if [ -f "$config_file" ] && grep -q "function comfyui" "$config_file"; then
        echo "✓ ComfyUI functions already exist in Fish config"
        echo ""
        read -p "Update Fish functions? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping Fish config"
            return
        fi
        # Remove old functions
        sed -i '/# ComfyUI functions/,/^end$/d' "$config_file" 2>/dev/null || true
    fi
    
    # Add new functions (Fish syntax)
    cat >> "$config_file" << EOF

# ComfyUI functions
function comfyui
    source $VENV_PATH/bin/activate.fish
    cd $COMFYUI_DIR
    python main.py
end

function envact
    source $VENV_PATH/bin/activate.fish
end
EOF
    echo "✓ Functions added to Fish config"
}

# Detect and configure all applicable shells
CONFIGS_UPDATED=0
CONFIGURED_SHELLS=""

# bash - Check both .bashrc and .bash_profile
if [ -f "$HOME/.bashrc" ] || [ "$SHELL" = *"bash"* ]; then
    echo "Configuring bash..."
    if [ ! -f "$HOME/.bashrc" ]; then
        touch "$HOME/.bashrc"
        echo "Created $HOME/.bashrc"
    fi
    add_bash_aliases "$HOME/.bashrc" "~/.bashrc"
    CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
    CONFIGURED_SHELLS="${CONFIGURED_SHELLS}~/.bashrc "
    echo ""
fi

# zsh
if [ -f "$HOME/.zshrc" ] || [ "$SHELL" = *"zsh"* ]; then
    echo "Configuring zsh..."
    if [ ! -f "$HOME/.zshrc" ]; then
        touch "$HOME/.zshrc"
        echo "Created $HOME/.zshrc"
    fi
    add_bash_aliases "$HOME/.zshrc" "~/.zshrc"
    CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
    CONFIGURED_SHELLS="${CONFIGURED_SHELLS}~/.zshrc "
    echo ""
fi

# Fish shell
if [ -f "$HOME/.config/fish/config.fish" ] || [ "$SHELL" = *"fish"* ]; then
    echo "Configuring Fish shell..."
    if [ ! -f "$HOME/.config/fish/config.fish" ]; then
        mkdir -p "$HOME/.config/fish"
        touch "$HOME/.config/fish/config.fish"
        echo "Created $HOME/.config/fish/config.fish"
    fi
    add_fish_functions "$HOME/.config/fish/config.fish"
    CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
    CONFIGURED_SHELLS="${CONFIGURED_SHELLS}~/.config/fish/config.fish "
    echo ""
fi

# Fallback to .profile if no other shell detected
if [ $CONFIGS_UPDATED -eq 0 ]; then
    echo "No common shell config detected, using ~/.profile as fallback..."
    if [ ! -f "$HOME/.profile" ]; then
        touch "$HOME/.profile"
        echo "Created $HOME/.profile"
    fi
    add_bash_aliases "$HOME/.profile" "~/.profile"
    CONFIGURED_SHELLS="~/.profile"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════════"
echo "Alias configuration complete!"
echo "  - comfyui: activate environment and launch ComfyUI"
echo "  - envact: activate environment only"
echo ""
echo "To use the aliases, either:"
echo "  - Restart your terminal"
echo "  - Or run: source ~/.bashrc (or ~/.zshrc, etc.)"
echo "═══════════════════════════════════════════════════════════════════"

fi  # End STEP_11

# ============================================================================
# Create Launcher Script
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Creating ComfyUI Launcher Script"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR is set (may not be if STEP_5 was skipped)
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

LAUNCHER_SCRIPT="${COMFYUI_PARENT_DIR}/start_comfyui.sh"

cat > "$LAUNCHER_SCRIPT" << 'LAUNCHER_EOF'
#!/bin/bash
# ComfyUI Launcher Script
# Auto-generated by install_comfy_env.sh

# Change to ComfyUI directory
cd "COMFYUI_DIR_PLACEHOLDER"

# Use virtual environment's Python directly (bypasses pyenv shims)
VENV_PATH_PLACEHOLDER/bin/python main.py "$@"
LAUNCHER_EOF

# Replace placeholders with actual paths
sed -i "s|COMFYUI_DIR_PLACEHOLDER|${COMFYUI_DIR}|g" "$LAUNCHER_SCRIPT"
sed -i "s|VENV_PATH_PLACEHOLDER|${VENV_PATH}|g" "$LAUNCHER_SCRIPT"

# Make executable
chmod +x "$LAUNCHER_SCRIPT"

echo "✓ Launcher script created at: $LAUNCHER_SCRIPT"
echo "  You can start ComfyUI by running: $LAUNCHER_SCRIPT"

# ============================================================================
# Installation Complete
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✓ Installation Complete!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Installed Versions:"
echo "  PyTorch: ${PYTORCH_FULL_VERSION} (with compatible torchvision/torchaudio)"
echo "  NumPy: ${NUMPY_VERSION}"
echo "  Transformers: ${TRANSFORMERS_VERSION}"
echo ""
echo "Environment: $VENV_PATH"
echo "ComfyUI Location: $COMFYUI_DIR"
if [ -n "$CONFIGURED_SHELLS" ]; then
    echo "Shell Config(s): $CONFIGURED_SHELLS"
fi
echo ""
echo "To start ComfyUI:"
echo ""
echo "  Option 1 - Launcher script (recommended):"
echo "    $LAUNCHER_SCRIPT"
echo ""
# Check if aliases were added to any shell config
if grep -q "alias comfyui=" "$HOME/.bashrc" 2>/dev/null || \
   grep -q "alias comfyui=" "$HOME/.zshrc" 2>/dev/null || \
   grep -q "function comfyui" "$HOME/.config/fish/config.fish" 2>/dev/null; then
    echo "  Option 2 - Shell alias (after reloading shell):"
    echo "    comfyui          # Activate env and launch ComfyUI"
    echo "    envact           # Activate env only"
    echo ""
    echo "  Option 3 - Manual activation:"
else
    echo "  Option 2 - Manual activation:"
fi
echo "    source $VENV_PATH/bin/activate && cd $COMFYUI_DIR && python main.py"
echo ""
echo "Press any key to exit..."
read -n 1 -s
