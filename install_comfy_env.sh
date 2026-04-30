#!/bin/bash
# ComfyUI Environment Installation Script
# Installs packages in specific order to avoid dependency conflicts

set -e  # Exit on error

# Suppress uv hardlink warnings when cache and venv are on different filesystems
export UV_LINK_MODE=copy

# ============================================
# Configuration Variables - Adjust as needed
# ============================================

# Base directory configuration
# All paths will be derived from this base path
BASE_PATH="/mnt/data/AI"            # Parent directory for ComfyUI, venv, models, input, output, user, custom_nodes

# Recommended Python versions: 3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x
# These versions have prebuilt wheels for PyTorch, nunchaku, and flash-attn
# Other versions may work but will require compilation from source
PYTHON_VERSION="3.12.10"            # Python version to install via pyenv
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"  # pyenv installation directory

# PyTorch version configuration
PYTORCH_VERSION="2.9"               # PyTorch major.minor version for wheel URLs (e.g., 2.9, 2.10)
PYTORCH_FULL_VERSION="2.9.1+cu128"  # Full PyTorch version for package installation (e.g., 2.9.1+cu128, 2.10.0+cpu)
PYTORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"  # PyTorch index URL (cu128, cu121, cpu)

# Critical package versions (enforced at end to override custom node dependencies)
NUMPY_VERSION="2.2.6"               # NumPy version (2.2.x compatible with PyTorch 2.9+)
TRANSFORMERS_VERSION="5.3.0"       # Transformers version (5.x for Qwen3-VL/Mistral3 support)
COMFYUI_FRONTEND_VERSION="1.42.11"  # ComfyUI frontend version (installed in venv's site-packages)

# ComfyUI installation defaults (overridden by interactive prompts below)
DEFAULT_COMFYUI_VERSION="0.19.3"     # Default ComfyUI version (numeric, e.g., 0.18.0)
DEFAULT_FRONTEND_VERSION="1.42.11"   # Default frontend version (numeric, e.g., 1.41.21)
DEFAULT_ALIAS="comfyui"              # Default shell alias (e.g., comfyui, comfy2, comfy3)

# Symlink configuration for models, input, output, user, and custom_nodes
CREATE_SYMLINKS=true                # Set to false to skip all symlink creation
SYMLINK_CUSTOM_NODES=true           # Set to false to keep custom_nodes as a regular directory (only applies if CREATE_SYMLINKS=true)

# Optional features (set to false to disable)
INSTALL_NUNCHAKU=true               # Set to false to skip Nunchaku (NVIDIA GPU required)

# ============================================
# Derived Paths (auto-generated from BASE_PATH)
# ============================================
# By default these are all relative to BASE_PATH. To place any of them
# on a different drive or location, simply override the variable below.
#
# Example: models on a separate drive
#   USER_MODELS_PATH="/mnt/ssd2/models"
#
# Example: output on a different partition
#   USER_OUTPUT_PATH="/home/$USER/comfyui_output"
#
# Example: input on a different partition
#   USER_INPUT_PATH="/home/$USER/comfyui_input"
#
# Example: shared user folder (settings, workflows, templates) on another partition
#   USER_USERDATA_PATH="/home/$USER/comfyui_user"
#
# Example: shared custom_nodes across installs on another disk
#   USER_CUSTOM_NODES_PATH="/mnt/data/shared_custom_nodes"
#
# The script will create the directories if they don't exist and symlink
# them into the ComfyUI tree (when CREATE_SYMLINKS=true).
# ============================================
VENV_PATH="$BASE_PATH/comfy_env"                # Virtual environment location
COMFYUI_PARENT_DIR="$BASE_PATH"                 # Parent directory where ComfyUI will be cloned
USER_MODELS_PATH="$BASE_PATH/models"            # Centralized models directory
USER_INPUT_PATH="$BASE_PATH/input"              # Centralized input directory (shared across ComfyUI installations)
USER_OUTPUT_PATH="$BASE_PATH/output"            # Centralized output directory
USER_USERDATA_PATH="$BASE_PATH/user"            # Centralized user directory (settings, workflows, templates) — shared across ComfyUI installations
USER_CUSTOM_NODES_PATH="$BASE_PATH/custom_nodes" # Centralized custom_nodes directory (shared across ComfyUI installations)

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

# ============================================
# Interactive Prompts — collect per-install values
# ============================================
# These change frequently when testing new ComfyUI versions.
# Static config (Python, PyTorch, numpy, transformers) stays at the top of the script.
echo "=========================================="
echo "ComfyUI Environment Setup"
echo "=========================================="
echo ""
echo "Enter values for this installation (press Enter for defaults):"
echo ""

# ComfyUI version (numeric) → derives COMFYUI_VERSION and COMFYUI_DIR_NAME
read -p "  ComfyUI version [${DEFAULT_COMFYUI_VERSION}]: " INPUT_COMFYUI_VERSION
INPUT_COMFYUI_VERSION="${INPUT_COMFYUI_VERSION:-$DEFAULT_COMFYUI_VERSION}"

# Frontend version (numeric) → used directly as pip package version
read -p "  Frontend version [${DEFAULT_FRONTEND_VERSION}]: " INPUT_FRONTEND_VERSION
INPUT_FRONTEND_VERSION="${INPUT_FRONTEND_VERSION:-$DEFAULT_FRONTEND_VERSION}"

# Shell alias name → derives COMFYUI_ALIAS and ENVACT_ALIAS
read -p "  Launch alias [${DEFAULT_ALIAS}]: " INPUT_ALIAS
INPUT_ALIAS="${INPUT_ALIAS:-$DEFAULT_ALIAS}"

echo ""

# Derive all values from inputs
COMFYUI_VERSION="v${INPUT_COMFYUI_VERSION}"                               # e.g., v0.18.0
COMFYUI_DIR_NAME="ComfyUI_${INPUT_COMFYUI_VERSION}"                         # e.g., ComfyUI_0.18.2 (full version)
COMFYUI_FRONTEND_VERSION="${INPUT_FRONTEND_VERSION}"                       # e.g., 1.41.21
COMFYUI_ALIAS="${INPUT_ALIAS}"                                            # e.g., comfyui or comfy2

# Derive envact alias: always "envact" since all installs share the same venv
ENVACT_ALIAS="envact"

# ============================================
# Configuration Summary
# ============================================
echo "──────────────────────────────────────────"
echo "Configuration:"
if [ -n "$COMFYUI_VERSION" ]; then
    echo "  ComfyUI Version: $COMFYUI_VERSION"
else
    echo "  ComfyUI Version: Latest (default branch)"
fi
echo "  ComfyUI Frontend Version: $COMFYUI_FRONTEND_VERSION"
echo "  Python Version: $PYTHON_VERSION"
echo "  PyTorch Version: $PYTORCH_FULL_VERSION (torchvision/torchaudio auto-selected)"
echo "  NumPy Version: $NUMPY_VERSION"
echo "  Transformers Version: $TRANSFORMERS_VERSION"
echo "  Shell: $DETECTED_SHELL ($SHELL_CONFIG_FILE)"
if $INSTALL_NUNCHAKU; then
    echo "  Nunchaku: Enabled"
else
    echo "  Nunchaku: Disabled (custom node will be skipped)"
fi
echo ""
echo "  Base Path: $BASE_PATH"
echo "  ComfyUI Location: $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME"
echo "  Virtual Env: $VENV_PATH"
echo "  Pyenv Root: $PYENV_ROOT"
echo "  Aliases: $COMFYUI_ALIAS (launch), $ENVACT_ALIAS (activate venv)"
echo ""
echo "  Symlink Configuration:"
if [ "$CREATE_SYMLINKS" = true ]; then
    echo "  Symlinks: Enabled"
    echo "    Models:       $USER_MODELS_PATH → $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME/models"
    echo "    Input:        $USER_INPUT_PATH → $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME/input"
    echo "    Output:       $USER_OUTPUT_PATH → $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME/output"
    echo "    User Data:    $USER_USERDATA_PATH → $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME/user"
    if [ "$SYMLINK_CUSTOM_NODES" = true ]; then
        echo "    Custom Nodes: $USER_CUSTOM_NODES_PATH → $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME/custom_nodes"
    else
        echo "    Custom Nodes: Regular directory (no symlink)"
    fi
else
    echo "  Symlinks: Disabled"
fi
echo "=========================================="
echo ""
echo "Select installation steps (numbers, ranges, or 'a' for all — e.g., 6-10 or 1 5 6-8):"
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
echo " 11) Configure shell aliases ($COMFYUI_ALIAS, $ENVACT_ALIAS)"
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
    # Expand ranges (e.g., "6-10" → "6 7 8 9 10") and individual numbers
    EXPANDED=""
    for token in $STEP_SELECTION; do
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                EXPANDED="$EXPANDED $i"
            done
        else
            EXPANDED="$EXPANDED $token"
        fi
    done

    for num in $EXPANDED; do
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
        # Check if dnf5 or dnf4 (dnf5 uses 'group install' and lowercase group names)
        if dnf --version 2>&1 | grep -q "^dnf5"; then
            sudo dnf group install -y development-tools
        else
            sudo dnf groupinstall -y "Development Tools"
        fi
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
    
    # Check if pyenv directory already exists
    if [ -d "$PYENV_ROOT" ]; then
        echo "✓ Found existing pyenv installation at $PYENV_ROOT"
        echo "  Using existing pyenv installation"
    else
        # Install pyenv
        echo "Installing pyenv..."
        curl https://pyenv.run | bash
    fi
    
    # Add pyenv to PATH for this session
    export PYENV_ROOT="$PYENV_ROOT"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    
    echo "✓ pyenv configured successfully"
    
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

# Install uv (ultra-fast pip replacement)
echo "Installing uv package manager..."
pip install --upgrade uv
echo "✓ uv installed successfully"

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
uv pip install torch==${PYTORCH_FULL_VERSION} torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}

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
uv pip install "$NUNCHAKU_WHEEL" || {
    echo "⚠️  Prebuilt nunchaku wheel not found for PyTorch ${PYTORCH_VERSION} / Python ${PYTHON_WHEEL_TAG}"
    echo "   Trying to install from source or latest compatible version..."
    uv pip install nunchaku || echo "⚠️  Nunchaku installation failed (optional)"
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
uv pip install --constraint "$CONSTRAINTS_FILE" facexlib
uv pip install --constraint "$CONSTRAINTS_FILE" insightface
uv pip install --constraint "$CONSTRAINTS_FILE" onnxruntime
uv pip install --constraint "$CONSTRAINTS_FILE" onnxruntime-gpu
uv pip install --constraint "$CONSTRAINTS_FILE" comfy-cli
uv pip install --constraint "$CONSTRAINTS_FILE" "bitsandbytes>=0.46.1"
uv pip install --constraint "$CONSTRAINTS_FILE" tensorflow
uv pip install --constraint "$CONSTRAINTS_FILE" hf-xet
uv pip install --constraint "$CONSTRAINTS_FILE" requests
uv pip install --constraint "$CONSTRAINTS_FILE" pilgram
uv pip install --constraint "$CONSTRAINTS_FILE" tf-keras

# Install facenet_pytorch
echo "Installing facenet_pytorch"
uv pip install --constraint "$CONSTRAINTS_FILE" facenet_pytorch

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
    
    # Checkout specific version if specified
    if [ -n "$COMFYUI_VERSION" ]; then
        echo "Checking out ComfyUI version: $COMFYUI_VERSION"
        cd "$COMFYUI_DIR"
        git checkout "$COMFYUI_VERSION"
    fi
else
    echo "✓ ComfyUI already exists at $COMFYUI_DIR"
    
    # Checkout specific version if specified and not already on it
    if [ -n "$COMFYUI_VERSION" ]; then
        cd "$COMFYUI_DIR"
        # Get current commit SHA
        CURRENT_COMMIT=$(git rev-parse HEAD)
        
        # Try to resolve target version to commit SHA
        TARGET_COMMIT=""
        if git rev-parse --verify "$COMFYUI_VERSION" >/dev/null 2>&1; then
            TARGET_COMMIT=$(git rev-parse --verify "$COMFYUI_VERSION")
        else
            # If we can't resolve locally, fetch and try again
            echo "Fetching updates to resolve version: $COMFYUI_VERSION"
            git fetch origin
            if git rev-parse --verify "$COMFYUI_VERSION" >/dev/null 2>&1; then
                TARGET_COMMIT=$(git rev-parse --verify "$COMFYUI_VERSION")
            fi
        fi
        
        if [ -z "$TARGET_COMMIT" ]; then
            echo "Warning: Could not resolve version '$COMFYUI_VERSION'."
            echo "Please verify this version exists in the repository (check tags/branches/commits)."
            echo "Attempting checkout anyway..."
            git checkout "$COMFYUI_VERSION"
        elif [ "$CURRENT_COMMIT" != "$TARGET_COMMIT" ]; then
            echo "Checking out ComfyUI version: $COMFYUI_VERSION"
            git checkout "$COMFYUI_VERSION"
        else
            echo "✓ Already on version: $COMFYUI_VERSION"
        fi
    fi
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
uv pip install --constraint "$CONSTRAINTS_FILE" -r requirements.txt
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_5

# ============================================================================
# Create Symlinks for Models and Output
# ============================================================================
if $CREATE_SYMLINKS; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Creating Symlinks for Models, Input, Output, User Data, and Custom Nodes"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR is set
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

# Create user directories if they don't exist
mkdir -p "$USER_MODELS_PATH"
mkdir -p "$USER_INPUT_PATH"
mkdir -p "$USER_OUTPUT_PATH"
mkdir -p "$USER_USERDATA_PATH"
mkdir -p "$USER_CUSTOM_NODES_PATH"

# Handle models directory
if [ -L "$COMFYUI_DIR/models" ]; then
    # Check if symlink points to the correct target
    CURRENT_TARGET=$(readlink "$COMFYUI_DIR/models")
    if [ "$CURRENT_TARGET" = "$USER_MODELS_PATH" ]; then
        echo "✓ models is already a symlink to correct location"
    else
        echo "⚠️  models symlink points to wrong location:"
        echo "   Current: $CURRENT_TARGET"
        echo "   Expected: $USER_MODELS_PATH"
        echo "   Removing old symlink and creating correct one..."
        rm -f "$COMFYUI_DIR/models"
        ln -s "$USER_MODELS_PATH" "$COMFYUI_DIR/models"
        echo "✓ Fixed symlink: $COMFYUI_DIR/models -> $USER_MODELS_PATH"
    fi
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
    # Check if symlink points to the correct target
    CURRENT_TARGET=$(readlink "$COMFYUI_DIR/output")
    if [ "$CURRENT_TARGET" = "$USER_OUTPUT_PATH" ]; then
        echo "✓ output is already a symlink to correct location"
    else
        echo "⚠️  output symlink points to wrong location:"
        echo "   Current: $CURRENT_TARGET"
        echo "   Expected: $USER_OUTPUT_PATH"
        echo "   Removing old symlink and creating correct one..."
        rm -f "$COMFYUI_DIR/output"
        ln -s "$USER_OUTPUT_PATH" "$COMFYUI_DIR/output"
        echo "✓ Fixed symlink: $COMFYUI_DIR/output -> $USER_OUTPUT_PATH"
    fi
elif [ -d "$COMFYUI_DIR/output" ]; then
    echo "⚠️  Removing existing output directory at $COMFYUI_DIR/output"
    rm -rf "$COMFYUI_DIR/output"
    ln -s "$USER_OUTPUT_PATH" "$COMFYUI_DIR/output"
    echo "✓ Created symlink: $COMFYUI_DIR/output -> $USER_OUTPUT_PATH"
else
    ln -s "$USER_OUTPUT_PATH" "$COMFYUI_DIR/output"
    echo "✓ Created symlink: $COMFYUI_DIR/output -> $USER_OUTPUT_PATH"
fi

# Handle input directory
if [ -L "$COMFYUI_DIR/input" ]; then
    # Check if symlink points to the correct target
    CURRENT_TARGET=$(readlink "$COMFYUI_DIR/input")
    if [ "$CURRENT_TARGET" = "$USER_INPUT_PATH" ]; then
        echo "✓ input is already a symlink to correct location"
    else
        echo "⚠️  input symlink points to wrong location:"
        echo "   Current: $CURRENT_TARGET"
        echo "   Expected: $USER_INPUT_PATH"
        echo "   Removing old symlink and creating correct one..."
        rm -f "$COMFYUI_DIR/input"
        ln -s "$USER_INPUT_PATH" "$COMFYUI_DIR/input"
        echo "✓ Fixed symlink: $COMFYUI_DIR/input -> $USER_INPUT_PATH"
    fi
elif [ -d "$COMFYUI_DIR/input" ]; then
    echo "⚠️  Moving existing input to centralized location"
    # If the centralized location is empty, copy from current installation to preserve existing inputs
    if [ -z "$(ls -A "$USER_INPUT_PATH" 2>/dev/null)" ]; then
        echo "   Copying input contents to $USER_INPUT_PATH"
        if ! cp -r "$COMFYUI_DIR/input/." "$USER_INPUT_PATH/" 2>/dev/null; then
            echo "⚠️  Warning: Failed to copy some input content, continuing anyway..."
        fi
    fi
    rm -rf "$COMFYUI_DIR/input"
    ln -s "$USER_INPUT_PATH" "$COMFYUI_DIR/input"
    echo "✓ Created symlink: $COMFYUI_DIR/input -> $USER_INPUT_PATH"
else
    ln -s "$USER_INPUT_PATH" "$COMFYUI_DIR/input"
    echo "✓ Created symlink: $COMFYUI_DIR/input -> $USER_INPUT_PATH"
fi

# Handle user directory (settings, workflows, templates) — shared across versions.
# Cross-version safe: comfy.settings.json is a flat key→value map merged against
# frontend defaults at runtime, so new/removed/renamed keys are handled gracefully.
if [ -L "$COMFYUI_DIR/user" ]; then
    # Check if symlink points to the correct target
    CURRENT_TARGET=$(readlink "$COMFYUI_DIR/user")
    if [ "$CURRENT_TARGET" = "$USER_USERDATA_PATH" ]; then
        echo "✓ user is already a symlink to correct location"
    else
        echo "⚠️  user symlink points to wrong location:"
        echo "   Current: $CURRENT_TARGET"
        echo "   Expected: $USER_USERDATA_PATH"
        echo "   Removing old symlink and creating correct one..."
        rm -f "$COMFYUI_DIR/user"
        ln -s "$USER_USERDATA_PATH" "$COMFYUI_DIR/user"
        echo "✓ Fixed symlink: $COMFYUI_DIR/user -> $USER_USERDATA_PATH"
    fi
elif [ -d "$COMFYUI_DIR/user" ]; then
    echo "⚠️  Moving existing user data to centralized location"
    # If the centralized location is empty, copy from current installation to preserve existing settings/workflows
    if [ -z "$(ls -A "$USER_USERDATA_PATH" 2>/dev/null)" ]; then
        echo "   Copying user data to $USER_USERDATA_PATH"
        if ! cp -r "$COMFYUI_DIR/user/." "$USER_USERDATA_PATH/" 2>/dev/null; then
            echo "⚠️  Warning: Failed to copy some user data, continuing anyway..."
        fi
    fi
    rm -rf "$COMFYUI_DIR/user"
    ln -s "$USER_USERDATA_PATH" "$COMFYUI_DIR/user"
    echo "✓ Created symlink: $COMFYUI_DIR/user -> $USER_USERDATA_PATH"
else
    ln -s "$USER_USERDATA_PATH" "$COMFYUI_DIR/user"
    echo "✓ Created symlink: $COMFYUI_DIR/user -> $USER_USERDATA_PATH"
fi

# Handle custom_nodes directory
if [ "$SYMLINK_CUSTOM_NODES" = true ]; then
    if [ -L "$COMFYUI_DIR/custom_nodes" ]; then
        # Check if symlink points to the correct target
        CURRENT_TARGET=$(readlink "$COMFYUI_DIR/custom_nodes")
        if [ "$CURRENT_TARGET" = "$USER_CUSTOM_NODES_PATH" ]; then
            echo "✓ custom_nodes is already a symlink to correct location"
        else
            echo "⚠️  custom_nodes symlink points to wrong location:"
            echo "   Current: $CURRENT_TARGET"
            echo "   Expected: $USER_CUSTOM_NODES_PATH"
            echo "   Removing old symlink and creating correct one..."
            rm -f "$COMFYUI_DIR/custom_nodes"
            ln -s "$USER_CUSTOM_NODES_PATH" "$COMFYUI_DIR/custom_nodes"
            echo "✓ Fixed symlink: $COMFYUI_DIR/custom_nodes -> $USER_CUSTOM_NODES_PATH"
        fi
    elif [ -d "$COMFYUI_DIR/custom_nodes" ]; then
        echo "⚠️  Moving existing custom_nodes to centralized location"
        # If the centralized location is empty or doesn't have content, copy from current installation
        if [ -z "$(ls -A "$USER_CUSTOM_NODES_PATH" 2>/dev/null)" ]; then
            echo "   Copying custom_nodes to $USER_CUSTOM_NODES_PATH"
            if ! cp -r "$COMFYUI_DIR/custom_nodes/." "$USER_CUSTOM_NODES_PATH/" 2>/dev/null; then
                echo "⚠️  Warning: Failed to copy some custom_nodes content, continuing anyway..."
            fi
        fi
        rm -rf "$COMFYUI_DIR/custom_nodes"
        ln -s "$USER_CUSTOM_NODES_PATH" "$COMFYUI_DIR/custom_nodes"
        echo "✓ Created symlink: $COMFYUI_DIR/custom_nodes -> $USER_CUSTOM_NODES_PATH"
    else
        ln -s "$USER_CUSTOM_NODES_PATH" "$COMFYUI_DIR/custom_nodes"
        echo "✓ Created symlink: $COMFYUI_DIR/custom_nodes -> $USER_CUSTOM_NODES_PATH"
    fi
else
    echo "ℹ️  Skipping custom_nodes symlink (SYMLINK_CUSTOM_NODES=false)"
    # Ensure custom_nodes directory exists as a regular directory
    if [ ! -d "$COMFYUI_DIR/custom_nodes" ]; then
        mkdir -p "$COMFYUI_DIR/custom_nodes"
        echo "✓ Created regular custom_nodes directory"
    else
        echo "✓ Using existing custom_nodes directory"
    fi
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
# Uses lowercase directory names to match ComfyUI-Manager convention
clone_if_missing() {
    local repo_url="$1"
    local repo_name_original=$(basename "$repo_url" .git)
    local repo_name=$(echo "$repo_name_original" | tr '[:upper:]' '[:lower:]')

    if [ -d "$repo_name/.git" ]; then
        echo "✓ $repo_name already exists"
    elif [ -d "$repo_name_original/.git" ] && [ "$repo_name_original" != "$repo_name" ]; then
        echo "→ Renaming $repo_name_original → $repo_name (lowercase)"
        mv "$repo_name_original" "$repo_name"
    else
        echo "→ Cloning $repo_name..."
        git clone "$repo_url" "$repo_name" || echo "⚠️  Failed to clone $repo_name"
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
clone_if_missing "https://github.com/BobRandomNumber/ComfyUI-Crystools-MonitorOnly.git"
clone_if_missing "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
clone_if_missing "https://github.com/r-vage/rgthree-comfy.git"
clone_if_missing "https://github.com/yolain/ComfyUI-Easy-Use.git"
clone_if_missing "https://github.com/cubiq/ComfyUI_essentials.git"
clone_if_missing "https://github.com/MinorBoy/ComfyUI_essentials_mb.git"
clone_if_missing "https://github.com/chrisgoringe/cg-image-filter.git"

# Model Support & Optimization
echo ""
echo "Cloning model support & optimization..."
clone_if_missing "https://github.com/city96/ComfyUI-GGUF.git"
if $INSTALL_NUNCHAKU; then
    clone_if_missing "https://github.com/nunchaku-ai/ComfyUI-nunchaku.git"
fi
clone_if_missing "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
clone_if_missing "https://github.com/lldacing/ComfyUI_Patches_ll.git"
clone_if_missing "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git"

# Sampling & Scheduling
echo ""
echo "Cloning sampling & scheduling..."
clone_if_missing "https://github.com/r-vage/RES4LYF.git"
clone_if_missing "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
clone_if_missing "https://github.com/rainlizard/ComfyUI-Raffle.git"
clone_if_missing "https://github.com/ChangeTheConstants/SeedVarianceEnhancer.git"
clone_if_missing "https://github.com/wildminder/ComfyUI-DyPE.git"

# ControlNet & Advanced Control
echo ""
echo "Cloning ControlNet & advanced control..."
clone_if_missing "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
clone_if_missing "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

# Image Processing & Effects
echo ""
echo "Cloning image processing & effects..."
clone_if_missing "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
clone_if_missing "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
clone_if_missing "https://github.com/chflame163/ComfyUI_LayerStyle.git"
clone_if_missing "https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git"
clone_if_missing "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git"
clone_if_missing "https://github.com/kijai/ComfyUI-KJNodes.git"
clone_if_missing "https://github.com/TTPlanetPig/Comfyui_TTP_Toolset.git"
clone_if_missing "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
clone_if_missing "https://github.com/spacepxl/ComfyUI-VAE-Utils.git"
clone_if_missing "https://github.com/ltdrdata/was-node-suite-comfyui.git"
clone_if_missing "https://github.com/melMass/comfy_mtb.git"

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
clone_if_missing "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
clone_if_missing "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"


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
numba>=0.58.0
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
        uv pip install --constraint "$CONSTRAINTS_FILE" -r "$node_dir/requirements.txt" || echo "⚠️  Some dependencies for $node_name failed (may be optional)"
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
uv pip install --constraint "$CONSTRAINTS_FILE" "llama-cpp-python>=0.3.16"

# Install flash-attn (pre-built wheel for PyTorch + CUDA 12.8)
echo "Installing Flash Attention 2.8.3 for PyTorch ${PYTORCH_VERSION} (Python ${PYTHON_WHEEL_TAG})..."
FLASH_ATTN_WHEEL="https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch${PYTORCH_VERSION}cxx11abiTRUE-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-linux_x86_64.whl"
uv pip install "$FLASH_ATTN_WHEEL" 2>/dev/null || {
    echo "⚠️  Prebuilt flash-attn wheel not found for PyTorch ${PYTORCH_VERSION} / Python ${PYTHON_WHEEL_TAG}"
    echo "   Attempting to install from PyPI or skip..."
    uv pip install --constraint "$CONSTRAINTS_FILE" flash-attn --no-build-isolation 2>/dev/null || echo "⚠️  Flash Attention installation failed (optional)"
}

# Try sageattention
echo "Installing Sage Attention..."
uv pip install --constraint "$CONSTRAINTS_FILE" sageattention 2>/dev/null || echo "⚠️  Sage Attention installation failed (optional)"

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
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade av
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade ultralytics
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade onnxruntime
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade onnxruntime-gpu
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference 2>/dev/null || echo "⚠️  inference upgrade skipped"
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference-gpu 2>/dev/null || echo "⚠️  inference-gpu upgrade skipped"
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade inference-cli 2>/dev/null || echo "⚠️  inference-cli upgrade skipped"
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade opencv-python
uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade gguf

# Pin critical package versions
echo "Pinning critical package versions..."
uv pip install "mistral-common>=1.8.6"
uv pip install "numpy>=${NUMPY_VERSION}"
uv pip install transformers==${TRANSFORMERS_VERSION}

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
echo "      Ensuring PyTorch ${PYTORCH_FULL_VERSION}, NumPy ${NUMPY_VERSION}, Transformers ${TRANSFORMERS_VERSION}, Frontend ${COMFYUI_FRONTEND_VERSION}"
echo ""

# Ensure PyTorch with exact configured version (will upgrade/downgrade if needed)
# torchvision and torchaudio versions are automatically selected by PyTorch index
uv pip install torch==${PYTORCH_FULL_VERSION} torchvision torchaudio --index-url ${PYTORCH_INDEX_URL} || {
    echo "⚠️  PyTorch installation failed, continuing anyway..."
}

# Ensure NumPy and Transformers with exact configured versions
uv pip install numpy==${NUMPY_VERSION} || {
    echo "⚠️  NumPy installation failed, continuing anyway..."
}
uv pip install transformers==${TRANSFORMERS_VERSION} || {
    echo "⚠️  Transformers installation failed, continuing anyway..."
}

# Ensure ComfyUI Frontend with exact configured version
uv pip install comfyui-frontend-package==${COMFYUI_FRONTEND_VERSION} || {
    echo "⚠️  ComfyUI frontend installation failed, continuing anyway..."
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

# Function to add aliases to a bash/zsh config file (non-destructive, additive only)
add_bash_aliases() {
    local config_file="$1"
    local config_name="$2"
    local added=0

    # Show existing ComfyUI-related aliases for context
    if [ -f "$config_file" ]; then
        local existing
        existing=$(grep -E "^alias (comfy|envact)" "$config_file" 2>/dev/null)
        if [ -n "$existing" ]; then
            echo "  Existing ComfyUI aliases in $config_name:"
            echo "$existing" | while IFS= read -r line; do echo "    $line"; done
            echo ""
        fi
    fi

    # Add launch alias if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^alias ${COMFYUI_ALIAS}=" "$config_file"; then
        echo "  ✓ Alias '${COMFYUI_ALIAS}' already exists in $config_name — skipping"
    else
        {
            echo ""
            echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend $COMFYUI_FRONTEND_VERSION)"
            echo "alias ${COMFYUI_ALIAS}='source $VENV_PATH/bin/activate && uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION && cd $COMFYUI_DIR && python main.py'"
        } >> "$config_file"
        echo "  ✓ Added alias '${COMFYUI_ALIAS}' to $config_name"
        added=1
    fi

    # Add venv activation alias if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^alias ${ENVACT_ALIAS}=" "$config_file"; then
        echo "  ✓ Alias '${ENVACT_ALIAS}' already exists in $config_name — skipping"
    else
        {
            echo "# ComfyUI: ${ENVACT_ALIAS} -> $VENV_PATH"
            echo "alias ${ENVACT_ALIAS}='source $VENV_PATH/bin/activate'"
        } >> "$config_file"
        echo "  ✓ Added alias '${ENVACT_ALIAS}' to $config_name"
        added=1
    fi

    if [ $added -eq 0 ]; then
        echo "  No changes needed in $config_name"
    fi
}

# Function to add Fish shell functions (non-destructive, additive only)
add_fish_functions() {
    local config_file="$1"
    local added=0

    # Show existing ComfyUI-related functions for context
    if [ -f "$config_file" ]; then
        local existing
        existing=$(grep -E "^function (comfy|envact)" "$config_file" 2>/dev/null)
        if [ -n "$existing" ]; then
            echo "  Existing ComfyUI functions in Fish config:"
            echo "$existing" | while IFS= read -r line; do echo "    $line"; done
            echo ""
        fi
    fi

    # Add launch function if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^function ${COMFYUI_ALIAS}\$" "$config_file"; then
        echo "  ✓ Function '${COMFYUI_ALIAS}' already exists in Fish config — skipping"
    else
        {
            echo ""
            echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend $COMFYUI_FRONTEND_VERSION)"
            echo "function ${COMFYUI_ALIAS}"
            echo "    source $VENV_PATH/bin/activate.fish"
            echo "    uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
            echo "    cd $COMFYUI_DIR"
            echo "    python main.py"
            echo "end"
        } >> "$config_file"
        echo "  ✓ Added function '${COMFYUI_ALIAS}' to Fish config"
        added=1
    fi

    # Add venv activation function if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^function ${ENVACT_ALIAS}\$" "$config_file"; then
        echo "  ✓ Function '${ENVACT_ALIAS}' already exists in Fish config — skipping"
    else
        {
            echo "# ComfyUI: ${ENVACT_ALIAS} -> $VENV_PATH"
            echo "function ${ENVACT_ALIAS}"
            echo "    source $VENV_PATH/bin/activate.fish"
            echo "end"
        } >> "$config_file"
        echo "  ✓ Added function '${ENVACT_ALIAS}' to Fish config"
        added=1
    fi

    if [ $added -eq 0 ]; then
        echo "  No changes needed in Fish config"
    fi
}

# Detect and configure all applicable shells
CONFIGS_UPDATED=0
CONFIGURED_SHELLS=""

# bash - Check both .bashrc and .bash_profile
if [ -f "$HOME/.bashrc" ] || [[ "$SHELL" == *"bash"* ]]; then
    echo "Configuring bash..."
    if [ ! -f "$HOME/.bashrc" ]; then
        touch "$HOME/.bashrc"
        echo "  Created $HOME/.bashrc"
    fi
    add_bash_aliases "$HOME/.bashrc" "~/.bashrc"
    CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
    CONFIGURED_SHELLS="${CONFIGURED_SHELLS}~/.bashrc "
    echo ""
fi

# zsh
if [ -f "$HOME/.zshrc" ] || [[ "$SHELL" == *"zsh"* ]]; then
    echo "Configuring zsh..."
    if [ ! -f "$HOME/.zshrc" ]; then
        touch "$HOME/.zshrc"
        echo "  Created $HOME/.zshrc"
    fi
    add_bash_aliases "$HOME/.zshrc" "~/.zshrc"
    CONFIGS_UPDATED=$((CONFIGS_UPDATED + 1))
    CONFIGURED_SHELLS="${CONFIGURED_SHELLS}~/.zshrc "
    echo ""
fi

# Fish shell
if [ -f "$HOME/.config/fish/config.fish" ] || [[ "$SHELL" == *"fish"* ]]; then
    echo "Configuring Fish shell..."
    if [ ! -f "$HOME/.config/fish/config.fish" ]; then
        mkdir -p "$HOME/.config/fish"
        touch "$HOME/.config/fish/config.fish"
        echo "  Created $HOME/.config/fish/config.fish"
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
        echo "  Created $HOME/.profile"
    fi
    add_bash_aliases "$HOME/.profile" "~/.profile"
    CONFIGURED_SHELLS="~/.profile"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════════"
echo "Alias configuration complete!"
echo "  - ${COMFYUI_ALIAS}: activate environment and launch ComfyUI"
echo "  - ${ENVACT_ALIAS}: activate environment only"
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

LAUNCHER_SCRIPT="${COMFYUI_PARENT_DIR}/start_${COMFYUI_ALIAS}.sh"

cat > "$LAUNCHER_SCRIPT" << 'LAUNCHER_EOF'
#!/bin/bash
# ComfyUI Launcher Script
# Auto-generated by install_comfy_env.sh

# Ensure correct frontend version for this installation
VENV_PATH_PLACEHOLDER/bin/python -m uv pip install -q comfyui-frontend-package==FRONTEND_VERSION_PLACEHOLDER

# Change to ComfyUI directory
cd "COMFYUI_DIR_PLACEHOLDER"

# Use virtual environment's Python directly (bypasses pyenv shims)
VENV_PATH_PLACEHOLDER/bin/python main.py "$@"
LAUNCHER_EOF

# Replace placeholders with actual paths
sed -i "s|COMFYUI_DIR_PLACEHOLDER|${COMFYUI_DIR}|g" "$LAUNCHER_SCRIPT"
sed -i "s|VENV_PATH_PLACEHOLDER|${VENV_PATH}|g" "$LAUNCHER_SCRIPT"
sed -i "s|FRONTEND_VERSION_PLACEHOLDER|${COMFYUI_FRONTEND_VERSION}|g" "$LAUNCHER_SCRIPT"

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
if grep -q "alias ${COMFYUI_ALIAS}=" "$HOME/.bashrc" 2>/dev/null || \
   grep -q "alias ${COMFYUI_ALIAS}=" "$HOME/.zshrc" 2>/dev/null || \
   grep -q "function ${COMFYUI_ALIAS}" "$HOME/.config/fish/config.fish" 2>/dev/null; then
    echo "  Option 2 - Shell alias (after reloading shell):"
    echo "    ${COMFYUI_ALIAS}          # Activate env and launch ComfyUI"
    echo "    ${ENVACT_ALIAS}           # Activate env only"
    echo ""
    echo "  Option 3 - Manual activation:"
else
    echo "  Option 2 - Manual activation:"
fi
echo "    source $VENV_PATH/bin/activate && cd $COMFYUI_DIR && python main.py"
echo ""
echo "Press any key to exit..."
read -n 1 -s
