#!/bin/bash
# ComfyUI Environment Installation Script
# Installs packages in specific order to avoid dependency conflicts

set -e  # Exit on error

# Suppress uv hardlink warnings when cache and venv are on different filesystems
export UV_LINK_MODE=copy

# ============================================
# Embedded Defaults
# ============================================
# Only this marked block is rewritten after a successful run.
# BEGIN COMFYUI INSTALLER DEFAULTS
BASE_PATH=/mnt/data/AI
PYTHON_VERSION=3.12.10
PYTORCH_VERSION=2.9.1
PYTORCH_WHEEL_VARIANT=cu130
NUMPY_VERSION=2.2.6
TRANSFORMERS_VERSION=5.3.0
DEFAULT_COMFYUI_VERSION=0.34.0
DEFAULT_FRONTEND_VERSION=1.45.21
DEFAULT_ALIAS=comfy
COMFYUI_LAUNCH_ARGS=--disable-pinned-memory
SYMLINK_MODELS=true
SYMLINK_INPUT=true
SYMLINK_OUTPUT=true
SYMLINK_USER=true
SYMLINK_CUSTOM_NODES=true
INSTALL_NUNCHAKU=true
INSTALL_MATCHING_CUDA_TOOLKIT=true
INSTALL_COMFYUI_FRONTEND=true
PIN_FRONTEND_VERSION_IN_ALIAS=false
# END COMFYUI INSTALLER DEFAULTS

PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
NUNCHAKU_VERSION="1.2.1"
NUNCHAKU_SUPPORTED_PYTHON_TAGS="cp310 cp311 cp312 cp313"
FLASH_ATTN_VERSION="2.8.3"
SAGEATTENTION_REPOSITORY="https://github.com/thu-ml/SageAttention.git"
SAGEATTENTION_REF="main"
SAGEATTENTION_FALLBACK_VERSION="1.0.6"
SCRIPT_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/$(basename -- "${BASH_SOURCE[0]}")"

EMBEDDED_BASE_PATH="$BASE_PATH"
EMBEDDED_PYTHON_VERSION="$PYTHON_VERSION"
EMBEDDED_PYTORCH_VERSION="$PYTORCH_VERSION"
EMBEDDED_PYTORCH_WHEEL_VARIANT="$PYTORCH_WHEEL_VARIANT"
EMBEDDED_NUMPY_VERSION="$NUMPY_VERSION"
EMBEDDED_TRANSFORMERS_VERSION="$TRANSFORMERS_VERSION"
EMBEDDED_COMFYUI_VERSION="$DEFAULT_COMFYUI_VERSION"
EMBEDDED_FRONTEND_VERSION="$DEFAULT_FRONTEND_VERSION"
EMBEDDED_ALIAS="$DEFAULT_ALIAS"
EMBEDDED_LAUNCH_ARGS="$COMFYUI_LAUNCH_ARGS"
EMBEDDED_SYMLINK_MODELS=$SYMLINK_MODELS
EMBEDDED_SYMLINK_INPUT=$SYMLINK_INPUT
EMBEDDED_SYMLINK_OUTPUT=$SYMLINK_OUTPUT
EMBEDDED_SYMLINK_USER=$SYMLINK_USER
EMBEDDED_SYMLINK_CUSTOM_NODES=$SYMLINK_CUSTOM_NODES
EMBEDDED_INSTALL_NUNCHAKU=$INSTALL_NUNCHAKU
EMBEDDED_INSTALL_MATCHING_CUDA_TOOLKIT=$INSTALL_MATCHING_CUDA_TOOLKIT
EMBEDDED_INSTALL_FRONTEND=$INSTALL_COMFYUI_FRONTEND
EMBEDDED_PIN_FRONTEND=$PIN_FRONTEND_VERSION_IN_ALIAS

MANAGE_BASE_PATH=true
MANAGE_PYTHON=true
MANAGE_PYTORCH=true
MANAGE_NUMPY=true
MANAGE_TRANSFORMERS=true
MANAGE_COMFYUI=true
MANAGE_NUNCHAKU=true
MANAGE_FRONTEND=true
MANAGE_LAUNCHER=true
MANAGE_SYMLINK_MODELS=true
MANAGE_SYMLINK_INPUT=true
MANAGE_SYMLINK_OUTPUT=true
MANAGE_SYMLINK_USER=true
MANAGE_SYMLINK_CUSTOM_NODES=true
CONFIG_MODE="easy"
HARDWARE_BACKEND=""

normalize_pytorch_version() {
    case "$1" in
        2.13) echo "2.13.0" ;;
        2.12) echo "2.12.1" ;;
        2.11) echo "2.11.0" ;;
        2.10) echo "2.10.0" ;;
        2.9) echo "2.9.1" ;;
        2.8) echo "2.8.0" ;;
        2.7) echo "2.7.1" ;;
        2.6) echo "2.6.0" ;;
        *) echo "$1" ;;
    esac
}

resolve_pytorch_stack() {
    PYTORCH_VERSION="$(normalize_pytorch_version "$PYTORCH_VERSION")"
    case "$PYTORCH_VERSION" in
        2.13.0) TORCHVISION_VERSION="0.28.0"; TORCHAUDIO_VERSION="2.11.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu130 rocm7.1 cpu" ;;
        2.12.1) TORCHVISION_VERSION="0.27.1"; TORCHAUDIO_VERSION="2.11.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu130 rocm7.1 cpu" ;;
        2.12.0) TORCHVISION_VERSION="0.27.0"; TORCHAUDIO_VERSION="2.11.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu130 rocm7.1 cpu" ;;
        2.11.0) TORCHVISION_VERSION="0.26.0"; TORCHAUDIO_VERSION="2.11.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cu130 rocm7.1 cpu" ;;
        2.10.0) TORCHVISION_VERSION="0.25.0"; TORCHAUDIO_VERSION="2.10.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cu130 rocm7.1 cpu" ;;
        2.9.1) TORCHVISION_VERSION="0.24.1"; TORCHAUDIO_VERSION="2.9.1"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cu130 cpu" ;;
        2.9.0) TORCHVISION_VERSION="0.24.0"; TORCHAUDIO_VERSION="2.9.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cu130 cpu" ;;
        2.8.0) TORCHVISION_VERSION="0.23.0"; TORCHAUDIO_VERSION="2.8.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cpu" ;;
        2.7.1) TORCHVISION_VERSION="0.22.1"; TORCHAUDIO_VERSION="2.7.1"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cpu" ;;
        2.7.0) TORCHVISION_VERSION="0.22.0"; TORCHAUDIO_VERSION="2.7.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cu128 cpu" ;;
        2.6.0) TORCHVISION_VERSION="0.21.0"; TORCHAUDIO_VERSION="2.6.0"; SUPPORTED_PYTORCH_WHEEL_VARIANTS="cu126 cpu" ;;
        *)
            echo "Unsupported PyTorch version: $PYTORCH_VERSION" >&2
            return 1
            ;;
    esac

    if [[ " $SUPPORTED_PYTORCH_WHEEL_VARIANTS " != *" $PYTORCH_WHEEL_VARIANT "* ]]; then
        echo "PyTorch $PYTORCH_VERSION is not available for $PYTORCH_WHEEL_VARIANT on Linux." >&2
        echo "Supported variants: $SUPPORTED_PYTORCH_WHEEL_VARIANTS" >&2
        return 1
    fi

    PYTORCH_MAJOR_MINOR="${PYTORCH_VERSION%.*}"
    PYTORCH_FULL_VERSION="${PYTORCH_VERSION}+${PYTORCH_WHEEL_VARIANT}"
    TORCHVISION_FULL_VERSION="${TORCHVISION_VERSION}+${PYTORCH_WHEEL_VARIANT}"
    TORCHAUDIO_FULL_VERSION="${TORCHAUDIO_VERSION}+${PYTORCH_WHEEL_VARIANT}"
    PYTORCH_INDEX_URL="https://download.pytorch.org/whl/${PYTORCH_WHEEL_VARIANT}"

    case "$PYTORCH_WHEEL_VARIANT" in
        cu*) HARDWARE_BACKEND="nvidia" ;;
        rocm*) HARDWARE_BACKEND="rocm" ;;
        cpu) HARDWARE_BACKEND="cpu" ;;
    esac

    case "$PYTORCH_WHEEL_VARIANT" in
        cu128)
            NUNCHAKU_CUDA_VARIANT="cu12.8"
            NUNCHAKU_SUPPORTED_TORCH_VERSIONS="2.8 2.9 2.10 2.11"
            ;;
        cu130)
            NUNCHAKU_CUDA_VARIANT="cu13.0"
            NUNCHAKU_SUPPORTED_TORCH_VERSIONS="2.9 2.10 2.11"
            ;;
        *)
            NUNCHAKU_CUDA_VARIANT=""
            NUNCHAKU_SUPPORTED_TORCH_VERSIONS=""
            ;;
    esac
}

resolve_pytorch_stack
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
# them into the ComfyUI tree when their corresponding SYMLINK_* setting is true.
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

alias_name_exists() {
    local candidate="$1"
    local config_file

    if [ -e "$BASE_PATH/start_${candidate}.sh" ]; then
        return 0
    fi

    for config_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.config/fish/config.fish"; do
        if [ -f "$config_file" ] && {
            grep -q "^alias ${candidate}=" "$config_file" 2>/dev/null ||
            grep -q "^function ${candidate}\$" "$config_file" 2>/dev/null
        }; then
            return 0
        fi
    done

    return 1
}

get_next_alias_name() {
    local candidate="$DEFAULT_ALIAS"
    local suffix=1

    while alias_name_exists "$candidate"; do
        candidate="${DEFAULT_ALIAS}${suffix}"
        suffix=$((suffix + 1))
    done

    echo "$candidate"
}

# ============================================
# Interactive Prompts
# ============================================
prompt_text() {
    local variable_name="$1"
    local label="$2"
    local default_value="$3"
    local answer
    read -r -p "  $label [$default_value]: " answer
    printf -v "$variable_name" '%s' "${answer:-$default_value}"
}

prompt_policy() {
    local variable_name="$1"
    local label="$2"
    local default_value="$3"
    local answer
    while true; do
        read -r -p "  $label [$default_value] (y/n/-): " answer
        answer="${answer:-$default_value}"
        case "${answer,,}" in
            y|yes|true) printf -v "$variable_name" '%s' true; return ;;
            n|no|false) printf -v "$variable_name" '%s' false; return ;;
            -) printf -v "$variable_name" '%s' preserve; return ;;
            *) echo "  Enter y, n, or - to preserve the installed state." ;;
        esac
    done
}

normalize_cuda_variant() {
    local value="${1,,}"
    value="${value#cuda}"
    value="${value#cu}"
    value="${value//./}"
    case "$value" in
        126|128|130) echo "cu$value" ;;
        12) echo "cu128" ;;
        13) echo "cu130" ;;
        *) return 1 ;;
    esac
}

normalize_rocm_variant() {
    local value="${1,,}"
    value="${value#rocm}"
    case "$value" in
        7.1|71) echo "rocm7.1" ;;
        *) return 1 ;;
    esac
}

default_backend() {
    case "$PYTORCH_WHEEL_VARIANT" in
        cu*) echo nvidia ;;
        rocm*) echo rocm ;;
        cpu) echo cpu ;;
        *) echo nvidia ;;
    esac
}

echo "=========================================="
echo "ComfyUI Environment Setup"
echo "=========================================="
echo ""
echo "Configuration mode:"
echo "  [E]asy (default) - ComfyUI, frontend, and launcher"
echo "  [A]dvanced       - complete configuration questionnaire"
echo "  [S]kip questions - use embedded defaults and select steps"
echo ""
while true; do
    read -r -p "Mode [E]: " MODE_SELECTION
    case "${MODE_SELECTION:-e}" in
        e|E|easy|Easy) CONFIG_MODE="easy"; break ;;
        a|A|advanced|Advanced) CONFIG_MODE="advanced"; break ;;
        s|S|skip|Skip) CONFIG_MODE="skip"; break ;;
        *) echo "Enter E, A, or S." ;;
    esac
done
echo ""

INPUT_COMFYUI_VERSION="$DEFAULT_COMFYUI_VERSION"
INPUT_FRONTEND_VERSION="$DEFAULT_FRONTEND_VERSION"
INPUT_ALIAS="$DEFAULT_ALIAS"

if [ "$CONFIG_MODE" = "easy" ]; then
    echo "Easy configuration (Enter accepts the default; - preserves a setting):"
    prompt_text INPUT_COMFYUI_VERSION "ComfyUI version" "$DEFAULT_COMFYUI_VERSION"
    if [ "$INPUT_COMFYUI_VERSION" = "-" ]; then
        MANAGE_COMFYUI=false
        INPUT_COMFYUI_VERSION="$DEFAULT_COMFYUI_VERSION"
    fi

    if $INSTALL_COMFYUI_FRONTEND; then
        prompt_text INPUT_FRONTEND_VERSION "Frontend version" "$DEFAULT_FRONTEND_VERSION"
        if [ "$INPUT_FRONTEND_VERSION" = "-" ]; then
            MANAGE_FRONTEND=false
            INPUT_FRONTEND_VERSION="$DEFAULT_FRONTEND_VERSION"
        fi
    fi

    SUGGESTED_ALIAS=$(get_next_alias_name)
    prompt_text INPUT_ALIAS "Launch alias" "$SUGGESTED_ALIAS"
    if [ "$INPUT_ALIAS" = "-" ]; then
        MANAGE_LAUNCHER=false
        INPUT_ALIAS="$DEFAULT_ALIAS"
    fi
elif [ "$CONFIG_MODE" = "advanced" ]; then
    echo "Advanced configuration (Enter accepts the default):"
    echo "  Hint: enter - to skip/ignore management for a setting and keep its installed state."
    prompt_text ADV_BASE_PATH "Base path" "$BASE_PATH"
    if [ "$ADV_BASE_PATH" = "-" ]; then
        MANAGE_BASE_PATH=false
    else
        BASE_PATH="$ADV_BASE_PATH"
    fi

    prompt_text ADV_PYTHON_VERSION "Python version" "$PYTHON_VERSION"
    if [ "$ADV_PYTHON_VERSION" = "-" ]; then
        MANAGE_PYTHON=false
    else
        PYTHON_VERSION="$ADV_PYTHON_VERSION"
    fi

    prompt_text ADV_PYTORCH_VERSION "PyTorch version" "$PYTORCH_VERSION"
    [ "$ADV_PYTORCH_VERSION" = "-" ] && MANAGE_PYTORCH=false || PYTORCH_VERSION="$ADV_PYTORCH_VERSION"

    BACKEND_DEFAULT=$(default_backend)
    while true; do
        prompt_text ADV_BACKEND "Hardware backend (NVIDIA/ROCm/CPU)" "$BACKEND_DEFAULT"
        case "${ADV_BACKEND,,}" in
            -) MANAGE_PYTORCH=false; break ;;
            n|nvidia)
                CUDA_DEFAULT="$PYTORCH_WHEEL_VARIANT"
                [[ "$CUDA_DEFAULT" == cu* ]] || CUDA_DEFAULT="cu128"
                prompt_text ADV_CUDA "CUDA version" "$CUDA_DEFAULT"
                if [ "$ADV_CUDA" = "-" ]; then
                    MANAGE_PYTORCH=false
                elif ! PYTORCH_WHEEL_VARIANT=$(normalize_cuda_variant "$ADV_CUDA"); then
                    echo "Unsupported CUDA alias: $ADV_CUDA. Use 12.6, 12.8, 13, or cu130." >&2
                    continue
                fi
                break
                ;;
            a|amd|rocm|amd/rocm)
                ROCM_DEFAULT="$PYTORCH_WHEEL_VARIANT"
                [[ "$ROCM_DEFAULT" == rocm* ]] || ROCM_DEFAULT="rocm7.1"
                prompt_text ADV_ROCM "ROCm version" "$ROCM_DEFAULT"
                if [ "$ADV_ROCM" = "-" ]; then
                    MANAGE_PYTORCH=false
                elif ! PYTORCH_WHEEL_VARIANT=$(normalize_rocm_variant "$ADV_ROCM"); then
                    echo "Unsupported ROCm version: $ADV_ROCM. Configured support: ROCm 7.1." >&2
                    continue
                fi
                break
                ;;
            c|cpu) PYTORCH_WHEEL_VARIANT="cpu"; break ;;
            *) echo "Enter NVIDIA, ROCm, CPU, or -." ;;
        esac
    done

    prompt_text ADV_NUMPY_VERSION "NumPy version" "$NUMPY_VERSION"
    [ "$ADV_NUMPY_VERSION" = "-" ] && MANAGE_NUMPY=false || NUMPY_VERSION="$ADV_NUMPY_VERSION"
    prompt_text ADV_TRANSFORMERS_VERSION "Transformers version" "$TRANSFORMERS_VERSION"
    [ "$ADV_TRANSFORMERS_VERSION" = "-" ] && MANAGE_TRANSFORMERS=false || TRANSFORMERS_VERSION="$ADV_TRANSFORMERS_VERSION"

    prompt_text INPUT_COMFYUI_VERSION "ComfyUI version" "$DEFAULT_COMFYUI_VERSION"
    if [ "$INPUT_COMFYUI_VERSION" = "-" ]; then
        MANAGE_COMFYUI=false
        INPUT_COMFYUI_VERSION="$DEFAULT_COMFYUI_VERSION"
    fi

    prompt_policy NUNCHAKU_POLICY "Install Nunchaku library" "$($INSTALL_NUNCHAKU && echo y || echo n)"
    case "$NUNCHAKU_POLICY" in
        true) INSTALL_NUNCHAKU=true ;;
        false) INSTALL_NUNCHAKU=false ;;
        preserve) MANAGE_NUNCHAKU=false ;;
    esac

    prompt_policy CUDA_TOOLKIT_POLICY "Install matching CUDA build toolkit when missing" "$($INSTALL_MATCHING_CUDA_TOOLKIT && echo y || echo n)"
    case "$CUDA_TOOLKIT_POLICY" in
        true) INSTALL_MATCHING_CUDA_TOOLKIT=true ;;
        false|preserve) INSTALL_MATCHING_CUDA_TOOLKIT=false ;;
    esac

    prompt_policy FRONTEND_POLICY "Manage ComfyUI frontend package" "$($INSTALL_COMFYUI_FRONTEND && echo y || echo n)"
    case "$FRONTEND_POLICY" in
        true)
            INSTALL_COMFYUI_FRONTEND=true
            prompt_text INPUT_FRONTEND_VERSION "Frontend version" "$DEFAULT_FRONTEND_VERSION"
            if [ "$INPUT_FRONTEND_VERSION" = "-" ]; then
                MANAGE_FRONTEND=false
                INPUT_FRONTEND_VERSION="$DEFAULT_FRONTEND_VERSION"
            fi
            prompt_policy PIN_POLICY "Pin frontend in launcher" "$($PIN_FRONTEND_VERSION_IN_ALIAS && echo y || echo n)"
            case "$PIN_POLICY" in
                true) PIN_FRONTEND_VERSION_IN_ALIAS=true ;;
                false) PIN_FRONTEND_VERSION_IN_ALIAS=false ;;
                preserve) MANAGE_LAUNCHER=false ;;
            esac
            ;;
        false) INSTALL_COMFYUI_FRONTEND=false ;;
        preserve) MANAGE_FRONTEND=false ;;
    esac

    SUGGESTED_ALIAS=$(get_next_alias_name)
    prompt_text INPUT_ALIAS "Launch alias" "$SUGGESTED_ALIAS"
    [ "$INPUT_ALIAS" = "-" ] && MANAGE_LAUNCHER=false && INPUT_ALIAS="$DEFAULT_ALIAS"
    prompt_text ADV_LAUNCH_ARGS "Launcher arguments" "$COMFYUI_LAUNCH_ARGS"
    if [ "$ADV_LAUNCH_ARGS" = "-" ]; then
        MANAGE_LAUNCHER=false
    else
        COMFYUI_LAUNCH_ARGS="$ADV_LAUNCH_ARGS"
    fi

    prompt_policy MODELS_POLICY "Share models" "$($SYMLINK_MODELS && echo y || echo n)"
    prompt_policy INPUT_POLICY "Share input" "$($SYMLINK_INPUT && echo y || echo n)"
    prompt_policy OUTPUT_POLICY "Share output" "$($SYMLINK_OUTPUT && echo y || echo n)"
    prompt_policy USER_POLICY "Share user data" "$($SYMLINK_USER && echo y || echo n)"
    prompt_policy NODES_POLICY "Share custom nodes" "$($SYMLINK_CUSTOM_NODES && echo y || echo n)"
    for policy in MODELS INPUT OUTPUT USER NODES; do
        value_var="${policy}_POLICY"
        value="${!value_var}"
        manage_var="MANAGE_SYMLINK_$policy"
        setting_var="SYMLINK_$policy"
        [ "$policy" = "NODES" ] && manage_var="MANAGE_SYMLINK_CUSTOM_NODES" && setting_var="SYMLINK_CUSTOM_NODES"
        if [ "$value" = "preserve" ]; then
            printf -v "$manage_var" '%s' false
        else
            printf -v "$setting_var" '%s' "$value"
        fi
    done
else
    echo "Skip mode: using embedded defaults without configuration questions."
fi
echo ""

if $MANAGE_PYTORCH; then
    resolve_pytorch_stack
    PYTHON_MINOR=$(printf '%s' "$PYTHON_VERSION" | cut -d. -f2)
    if ! [[ "$PYTHON_VERSION" =~ ^3\.(10|11|12|13|14)(\.|$) ]]; then
        echo "Python $PYTHON_VERSION is outside the configured 3.10-3.14 range." >&2
        exit 1
    fi
    if [ "$PYTHON_MINOR" = "14" ] && [[ "$PYTORCH_VERSION" =~ ^2\.(6|7)\. ]]; then
        echo "PyTorch $PYTORCH_VERSION is not configured for Python 3.14." >&2
        exit 1
    fi
else
    HARDWARE_BACKEND="preserve"
    INSTALL_NUNCHAKU=false
    NUNCHAKU_CUDA_VARIANT=""
    NUNCHAKU_SUPPORTED_TORCH_VERSIONS=""
fi

if [ "$HARDWARE_BACKEND" != "nvidia" ]; then
    INSTALL_NUNCHAKU=false
fi

# Re-derive paths after Advanced mode may have changed the base path.
VENV_PATH="$BASE_PATH/comfy_env"
COMFYUI_PARENT_DIR="$BASE_PATH"
USER_MODELS_PATH="$BASE_PATH/models"
USER_INPUT_PATH="$BASE_PATH/input"
USER_OUTPUT_PATH="$BASE_PATH/output"
USER_USERDATA_PATH="$BASE_PATH/user"
USER_CUSTOM_NODES_PATH="$BASE_PATH/custom_nodes"

COMFYUI_VERSION="v${INPUT_COMFYUI_VERSION}"
COMFYUI_DIR_NAME="ComfyUI_${INPUT_COMFYUI_VERSION}"
COMFYUI_FRONTEND_VERSION="$INPUT_FRONTEND_VERSION"
COMFYUI_ALIAS="$INPUT_ALIAS"
COMFYUI_WAS_CLONED=false


# Prevent unmanaged packages from being changed by ComfyUI or custom-node
# dependency resolution. Direct installer pins are independently gated below.
PACKAGE_EXCLUDE_FILE=""
ORIGINAL_UV_EXCLUDE="${UV_EXCLUDE-}"
UV_EXCLUDE_WAS_SET=false
[[ -v UV_EXCLUDE ]] && UV_EXCLUDE_WAS_SET=true

cleanup_package_exclude() {
    if $UV_EXCLUDE_WAS_SET; then
        export UV_EXCLUDE="$ORIGINAL_UV_EXCLUDE"
    else
        unset UV_EXCLUDE
    fi
    [ -n "$PACKAGE_EXCLUDE_FILE" ] && [ -f "$PACKAGE_EXCLUDE_FILE" ] && rm -f "$PACKAGE_EXCLUDE_FILE"
}

PACKAGE_EXCLUDES=()
(! $MANAGE_FRONTEND || ! $INSTALL_COMFYUI_FRONTEND) && PACKAGE_EXCLUDES+=("comfyui-frontend-package")
! $MANAGE_PYTORCH && PACKAGE_EXCLUDES+=("torch" "torchvision" "torchaudio")
! $MANAGE_NUMPY && PACKAGE_EXCLUDES+=("numpy")
! $MANAGE_TRANSFORMERS && PACKAGE_EXCLUDES+=("transformers")

if [ ${#PACKAGE_EXCLUDES[@]} -gt 0 ]; then
    PACKAGE_EXCLUDE_FILE=$(mktemp)
    printf '%s\n' "${PACKAGE_EXCLUDES[@]}" > "$PACKAGE_EXCLUDE_FILE"
    if [ -n "$ORIGINAL_UV_EXCLUDE" ]; then
        export UV_EXCLUDE="$ORIGINAL_UV_EXCLUDE $PACKAGE_EXCLUDE_FILE"
    else
        export UV_EXCLUDE="$PACKAGE_EXCLUDE_FILE"
    fi
    trap cleanup_package_exclude EXIT
fi

install_uv_requirements() {
    local requirements_file="$1"
    shift

    local filtered_requirements
    local install_status
    filtered_requirements=$(mktemp)
    cp "$requirements_file" "$filtered_requirements"

    if ! $MANAGE_FRONTEND || ! $INSTALL_COMFYUI_FRONTEND; then
        sed -Ei '/^[[:space:]]*comfyui[-_.]frontend[-_.]package([^[:alnum:]_-].*)?$/Id' "$filtered_requirements"
    fi
    if ! $MANAGE_PYTORCH; then
        sed -Ei '/^[[:space:]]*(torch|torchvision|torchaudio)([^[:alnum:]_-].*)?$/Id' "$filtered_requirements"
    fi
    if ! $MANAGE_NUMPY; then
        sed -Ei '/^[[:space:]]*numpy([^[:alnum:]_-].*)?$/Id' "$filtered_requirements"
    fi
    if ! $MANAGE_TRANSFORMERS; then
        sed -Ei '/^[[:space:]]*transformers([^[:alnum:]_-].*)?$/Id' "$filtered_requirements"
    fi

    if uv pip install "$@" -r "$filtered_requirements"; then
        install_status=0
    else
        install_status=$?
    fi
    rm -f "$filtered_requirements"
    return "$install_status"
}

distribution_installed() {
    python -c 'import importlib.metadata,sys; importlib.metadata.version(sys.argv[1])' "$1" >/dev/null 2>&1
}

remove_flash_attention() {
    if distribution_installed flash-attn; then
        echo "Removing incompatible Flash Attention installation..."
        uv pip uninstall flash-attn >/dev/null 2>&1 || true
    fi
}

verify_kornia_import() {
    python -c 'import kornia' >/dev/null 2>&1
}

verify_flash_attention_import() {
    python -c 'import flash_attn' >/dev/null 2>&1
}

cuda_toolkit_version() {
    "$1/bin/nvcc" --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1
}

install_matching_cuda_toolkit() {
    local torch_cuda="$1"
    local toolkit_home="/usr/local/cuda-${torch_cuda}"
    local compiler_package="cuda-compiler-${torch_cuda//./-}"
    local libraries_dev_package="cuda-libraries-dev-${torch_cuda//./-}"
    local package

    if [ -x "$toolkit_home/bin/nvcc" ] && \
        [ "$(cuda_toolkit_version "$toolkit_home")" = "$torch_cuda" ] && \
        [ -f "$toolkit_home/include/cusparse.h" ]; then
        return 0
    fi

    if ! $INSTALL_MATCHING_CUDA_TOOLKIT; then
        echo "ℹ️  Automatic CUDA compiler toolkit installation is disabled."
        return 1
    fi

    echo "Installing the CUDA $torch_cuda compiler and development libraries side-by-side (requires sudo)..."
    if command -v apt-get >/dev/null 2>&1; then
        for package in "$compiler_package" "$libraries_dev_package"; do
            if ! apt-cache show "$package" >/dev/null 2>&1; then
                echo "⚠️  $package is unavailable from the configured APT repositories."
                return 1
            fi
        done
        sudo apt-get install -y "$compiler_package" "$libraries_dev_package" || return 1
    elif command -v dnf >/dev/null 2>&1; then
        for package in "$compiler_package" "$libraries_dev_package"; do
            if ! dnf --quiet list --available "$package" >/dev/null 2>&1 && ! rpm -q "$package" >/dev/null 2>&1; then
                echo "⚠️  $package is unavailable from the configured DNF repositories."
                return 1
            fi
        done
        sudo dnf install -y "$compiler_package" "$libraries_dev_package" || return 1
    elif command -v yum >/dev/null 2>&1; then
        for package in "$compiler_package" "$libraries_dev_package"; do
            if ! yum --quiet list available "$package" >/dev/null 2>&1 && ! rpm -q "$package" >/dev/null 2>&1; then
                echo "⚠️  $package is unavailable from the configured Yum repositories."
                return 1
            fi
        done
        sudo yum install -y "$compiler_package" "$libraries_dev_package" || return 1
    elif command -v zypper >/dev/null 2>&1; then
        for package in "$compiler_package" "$libraries_dev_package"; do
            if ! zypper --non-interactive search --match-exact "$package" 2>/dev/null | grep -Fq "$package"; then
                echo "⚠️  $package is unavailable from the configured Zypper repositories."
                return 1
            fi
        done
        sudo zypper --non-interactive install "$compiler_package" "$libraries_dev_package" || return 1
    else
        echo "⚠️  Automatic versioned CUDA toolkit installation is not supported by this package manager."
        return 1
    fi

    if [ ! -x "$toolkit_home/bin/nvcc" ] || \
        [ "$(cuda_toolkit_version "$toolkit_home")" != "$torch_cuda" ] || \
        [ ! -f "$toolkit_home/include/cusparse.h" ]; then
        echo "⚠️  CUDA $torch_cuda packages installed, but the compiler toolkit is incomplete at $toolkit_home."
        return 1
    fi

    echo "✓ CUDA $torch_cuda compiler toolkit is available at $toolkit_home"
}

verify_sage_attention() {
    python - <<'PY'
import importlib.metadata
from packaging.version import Version

version = importlib.metadata.version("sageattention")
if Version(version).major < 2:
    raise RuntimeError(f"SageAttention {version} is obsolete; version 2 or newer is required")

import torch
from sageattention import sageattn
from sageattention.core import get_cuda_arch_versions

if not torch.cuda.is_available():
    raise RuntimeError("CUDA is unavailable for the SageAttention smoke test")

expected_arch = "sm" + "".join(map(str, torch.cuda.get_device_capability()))
available_arches = get_cuda_arch_versions()
if expected_arch not in available_arches:
    raise RuntimeError(
        f"SageAttention does not expose the active GPU architecture "
        f"{expected_arch}: {available_arches}"
    )

query = torch.randn((1, 4, 128, 64), device="cuda", dtype=torch.float16)
sageattn(query, query, query, tensor_layout="HND")
torch.cuda.synchronize()
PY
}

sage_attention_is_modern() {
    local major
    major=$(python -c 'import importlib.metadata; from packaging.version import Version; print(Version(importlib.metadata.version("sageattention")).major)' 2>/dev/null) || return 1
    [[ "$major" =~ ^[0-9]+$ ]] && [ "$major" -ge 2 ]
}

verify_sage_attention_fallback() {
    python - <<'PY'
import importlib.metadata
import sageattention
from packaging.version import Version

version = importlib.metadata.version("sageattention")
if Version(version).major >= 2:
    raise RuntimeError(f"SageAttention {version} is not the legacy fallback")
PY
}

install_sage_attention_fallback() {
    echo "Installing SageAttention $SAGEATTENTION_FALLBACK_VERSION as the no-compile fallback..."
    if uv pip install --reinstall --no-deps "sageattention==$SAGEATTENTION_FALLBACK_VERSION" && verify_sage_attention_fallback; then
        echo "⚠️  SageAttention $SAGEATTENTION_FALLBACK_VERSION fallback installed; integrations that require SageAttention 2 remain unavailable."
        return 0
    fi

    echo "⚠️  SageAttention fallback installation failed; SageAttention is unavailable."
    uv pip uninstall sageattention >/dev/null 2>&1 || true
    return 1
}

install_sage_attention() {
    local constraints_file="$1"
    local cuda_home matching_cuda_home torch_cuda nvcc_cuda gpu_arch available_kb available_memory_kb
    local existing_sage_usable=false
    local existing_fallback_usable=false
    local sage_build_ready=true

    torch_cuda=$(python -c 'import torch; print(torch.version.cuda or "")' 2>/dev/null || true)
    gpu_arch=$(python -c 'import torch; print(".".join(map(str, torch.cuda.get_device_capability()))) if torch.cuda.is_available() else print("")' 2>/dev/null || true)

    if [ -n "$torch_cuda" ]; then
        install_matching_cuda_toolkit "$torch_cuda" || true
    fi

    cuda_home=$(python -c 'from torch.utils.cpp_extension import CUDA_HOME; print(CUDA_HOME or "")' 2>/dev/null || true)

    # Prefer a matching side-by-side toolkit without changing the system-wide
    # /usr/local/cuda alternative. CUDA packages conventionally use this path.
    matching_cuda_home="/usr/local/cuda-${torch_cuda}"
    if [ -n "$torch_cuda" ] && [ -x "$matching_cuda_home/bin/nvcc" ]; then
        cuda_home="$matching_cuda_home"
    fi

    if distribution_installed sageattention; then
        if sage_attention_is_modern && verify_sage_attention; then
            existing_sage_usable=true
        elif ! sage_attention_is_modern && verify_sage_attention_fallback; then
            existing_fallback_usable=true
        else
            echo "Removing incompatible SageAttention installation..."
            uv pip uninstall sageattention >/dev/null 2>&1 || true
        fi
    fi

    if [ -z "$cuda_home" ] || [ ! -x "$cuda_home/bin/nvcc" ]; then
        echo "⚠️  Latest SageAttention build skipped: nvcc was not found in CUDA_HOME."
        sage_build_ready=false
    else
        nvcc_cuda=$("$cuda_home/bin/nvcc" --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1)
        if [ "$nvcc_cuda" != "$torch_cuda" ]; then
            echo "⚠️  Latest SageAttention build skipped: CUDA toolkit $nvcc_cuda does not match Torch CUDA $torch_cuda."
            sage_build_ready=false
        fi
    fi
    case "$gpu_arch" in
        8.0|8.6|8.9|9.0|10.0|12.0|12.1) ;;
        *)
            echo "⚠️  Latest SageAttention build skipped: unsupported or unavailable GPU architecture ${gpu_arch:-unknown}."
            sage_build_ready=false
            ;;
    esac
    command -v g++ >/dev/null 2>&1 || sage_build_ready=false
    command -v ninja >/dev/null 2>&1 || sage_build_ready=false
    available_kb=$(df -Pk "${TMPDIR:-/tmp}" 2>/dev/null | awk 'NR==2 {print $4}')
    available_memory_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null)
    if [ -z "$available_kb" ] || [ "$available_kb" -lt 10485760 ]; then
        echo "⚠️  Latest SageAttention build skipped: at least 10 GiB of temporary disk space is required."
        sage_build_ready=false
    fi
    if [ -z "$available_memory_kb" ] || [ "$available_memory_kb" -lt 16777216 ]; then
        echo "⚠️  Latest SageAttention build skipped: at least 16 GiB of available memory is required."
        sage_build_ready=false
    fi

    if $sage_build_ready; then
        echo "Building the latest SageAttention from ${SAGEATTENTION_REPOSITORY}@${SAGEATTENTION_REF}..."
        if CUDA_HOME="$cuda_home" CUDA_PATH="$cuda_home" CUDA_VERSION="$torch_cuda" \
            CUDACXX="$cuda_home/bin/nvcc" PATH="$cuda_home/bin:$PATH" \
            CFLAGS="-I$cuda_home/include" CXXFLAGS="-I$cuda_home/include" \
            LDFLAGS="-L$cuda_home/lib64" LIBRARY_PATH="$cuda_home/lib64" \
            LD_LIBRARY_PATH="$cuda_home/lib64" MAX_JOBS=4 \
            NVCC_APPEND_FLAGS="--threads 4" uv pip install \
            --constraint "$constraints_file" \
            --refresh-package sageattention \
            --reinstall \
            --no-build-isolation \
            "git+${SAGEATTENTION_REPOSITORY}@${SAGEATTENTION_REF}" && verify_sage_attention; then
            echo "✓ Latest SageAttention source build passed its CUDA and architecture smoke tests"
            return 0
        fi
        echo "⚠️  Latest SageAttention build or smoke test failed."
        if $existing_sage_usable && sage_attention_is_modern && verify_sage_attention; then
            echo "ℹ️  The previously working SageAttention 2 installation was retained."
            return 0
        fi
        if $existing_fallback_usable && ! sage_attention_is_modern && verify_sage_attention_fallback; then
            echo "ℹ️  The existing SageAttention $SAGEATTENTION_FALLBACK_VERSION fallback was retained."
            return 0
        fi
        # A newly installed v2 package may have replaced the old package before
        # failing its smoke test. Do not trust the pre-build state after this point.
        existing_sage_usable=false
        existing_fallback_usable=false
    fi

    if $existing_sage_usable; then
        echo "ℹ️  SageAttention rebuild was skipped; the existing installation passed the CUDA and architecture smoke tests."
        return 0
    fi
    if $existing_fallback_usable; then
        echo "⚠️  SageAttention 2 is unavailable; retaining the existing $SAGEATTENTION_FALLBACK_VERSION fallback."
        return 0
    fi

    install_sage_attention_fallback || true
    return 0
}

# Derive envact alias: always "envact" since all installs share the same venv
ENVACT_ALIAS="envact"

# ============================================
# ============================================
# Configuration Summary
# ============================================
sharing_summary() {
    local enabled="$1"
    local managed="$2"
    local path="$3"
    if ! $managed; then
        echo "Preserve existing entry"
    elif $enabled; then
        echo "Shared ($path)"
    else
        echo "Local"
    fi
}

echo "──────────────────────────────────────────"
echo "Resolved configuration ($CONFIG_MODE):"
$MANAGE_COMFYUI && echo "  ComfyUI Version: $COMFYUI_VERSION" || echo "  ComfyUI Version: Preserved (location uses $COMFYUI_DIR_NAME)"
if ! $MANAGE_FRONTEND; then
    echo "  ComfyUI Frontend: Preserved"
elif $INSTALL_COMFYUI_FRONTEND; then
    echo "  ComfyUI Frontend Version: $COMFYUI_FRONTEND_VERSION"
else
    echo "  ComfyUI Frontend: Unmanaged"
fi
$MANAGE_PYTHON && echo "  Python Version: $PYTHON_VERSION" || echo "  Python Version: Preserved"
if $MANAGE_PYTORCH; then
    echo "  Hardware Backend: $HARDWARE_BACKEND"
    echo "  PyTorch Stack: torch $PYTORCH_FULL_VERSION, torchvision $TORCHVISION_FULL_VERSION, torchaudio $TORCHAUDIO_FULL_VERSION"
else
    echo "  PyTorch Stack: Preserved (installed metadata will be inspected only when required)"
fi
$MANAGE_NUMPY && echo "  NumPy Version: $NUMPY_VERSION" || echo "  NumPy Version: Preserved"
$MANAGE_TRANSFORMERS && echo "  Transformers Version: $TRANSFORMERS_VERSION" || echo "  Transformers Version: Preserved"
if ! $MANAGE_NUNCHAKU; then
    echo "  Nunchaku: Preserved"
elif $INSTALL_NUNCHAKU; then
    echo "  Nunchaku: Enabled ($NUNCHAKU_VERSION, $NUNCHAKU_CUDA_VARIANT)"
else
    echo "  Nunchaku: Disabled/unavailable for $HARDWARE_BACKEND"
fi
if [ "$HARDWARE_BACKEND" = "nvidia" ]; then
    $INSTALL_MATCHING_CUDA_TOOLKIT && echo "  CUDA Build Toolkit: Install matching version if missing" || echo "  CUDA Build Toolkit: Preserve installed toolkits"
fi
echo "  Shell: $DETECTED_SHELL ($SHELL_CONFIG_FILE)"
echo ""
echo "  Base Path: $BASE_PATH$($MANAGE_BASE_PATH || echo ' (not saved)')"
echo "  ComfyUI Location: $COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME"
echo "  Virtual Env: $VENV_PATH"
$MANAGE_LAUNCHER && echo "  Aliases: $COMFYUI_ALIAS (launch), envact (activate venv)" || echo "  Launchers: Preserved"
echo "  Launch Arguments: ${COMFYUI_LAUNCH_ARGS:-None}"
echo ""
echo "  Directory Sharing:"
echo "    Models:       $(sharing_summary $SYMLINK_MODELS $MANAGE_SYMLINK_MODELS "$USER_MODELS_PATH")"
echo "    Input:        $(sharing_summary $SYMLINK_INPUT $MANAGE_SYMLINK_INPUT "$USER_INPUT_PATH")"
echo "    Output:       $(sharing_summary $SYMLINK_OUTPUT $MANAGE_SYMLINK_OUTPUT "$USER_OUTPUT_PATH")"
echo "    User Data:    $(sharing_summary $SYMLINK_USER $MANAGE_SYMLINK_USER "$USER_USERDATA_PATH")"
echo "    Custom Nodes: $(sharing_summary $SYMLINK_CUSTOM_NODES $MANAGE_SYMLINK_CUSTOM_NODES "$USER_CUSTOM_NODES_PATH")"
echo "=========================================="
echo ""

CONFIGURED_PYTHON_TAG="cp$(printf '%s' "$PYTHON_VERSION" | cut -d. -f1,2 | tr -d '.')"
NUNCHAKU_AVAILABLE=true
NUNCHAKU_UNAVAILABLE_REASON=""
if ! $MANAGE_NUNCHAKU; then
    NUNCHAKU_AVAILABLE=false
    NUNCHAKU_UNAVAILABLE_REASON="installed Nunchaku state is preserved"
elif ! $INSTALL_NUNCHAKU; then
    NUNCHAKU_AVAILABLE=false
    NUNCHAKU_UNAVAILABLE_REASON="Nunchaku is disabled or the selected backend is not NVIDIA"
elif [ -z "$NUNCHAKU_CUDA_VARIANT" ]; then
    NUNCHAKU_AVAILABLE=false
    NUNCHAKU_UNAVAILABLE_REASON="no official $NUNCHAKU_VERSION wheel exists for $PYTORCH_WHEEL_VARIANT"
elif [[ " $NUNCHAKU_SUPPORTED_TORCH_VERSIONS " != *" $PYTORCH_MAJOR_MINOR "* ]]; then
    NUNCHAKU_AVAILABLE=false
    NUNCHAKU_UNAVAILABLE_REASON="no official wheel exists for PyTorch $PYTORCH_MAJOR_MINOR"
elif [[ " $NUNCHAKU_SUPPORTED_PYTHON_TAGS " != *" $CONFIGURED_PYTHON_TAG "* ]]; then
    NUNCHAKU_AVAILABLE=false
    NUNCHAKU_UNAVAILABLE_REASON="no official wheel exists for $CONFIGURED_PYTHON_TAG"
fi

offer_save_defaults() {
    [ "$CONFIG_MODE" = "skip" ] && return 0

    local answer
    read -r -p "Save successful choices as new defaults? (y/N) " answer
    [[ "$answer" =~ ^[Yy]$ ]] || return 0

    if [ ! -w "$SCRIPT_PATH" ]; then
        echo "⚠️  Defaults were not saved because $SCRIPT_PATH is read-only."
        return 0
    fi

    local save_base="$EMBEDDED_BASE_PATH"
    local save_python="$EMBEDDED_PYTHON_VERSION"
    local save_torch="$EMBEDDED_PYTORCH_VERSION"
    local save_variant="$EMBEDDED_PYTORCH_WHEEL_VARIANT"
    local save_numpy="$EMBEDDED_NUMPY_VERSION"
    local save_transformers="$EMBEDDED_TRANSFORMERS_VERSION"
    local save_comfy="$EMBEDDED_COMFYUI_VERSION"
    local save_frontend="$EMBEDDED_FRONTEND_VERSION"
    local save_alias="$EMBEDDED_ALIAS"
    local save_args="$EMBEDDED_LAUNCH_ARGS"
    local save_models=$EMBEDDED_SYMLINK_MODELS
    local save_input=$EMBEDDED_SYMLINK_INPUT
    local save_output=$EMBEDDED_SYMLINK_OUTPUT
    local save_user=$EMBEDDED_SYMLINK_USER
    local save_nodes=$EMBEDDED_SYMLINK_CUSTOM_NODES
    local save_nunchaku=$EMBEDDED_INSTALL_NUNCHAKU
    local save_cuda_toolkit=$EMBEDDED_INSTALL_MATCHING_CUDA_TOOLKIT
    local save_manage_frontend=$EMBEDDED_INSTALL_FRONTEND
    local save_pin_frontend=$EMBEDDED_PIN_FRONTEND

    local package_work=false
    ($STEP_2 || $STEP_4 || $STEP_5 || $STEP_7 || $STEP_9 || $STEP_10) && package_work=true
    local any_work=false
    for step_var in STEP_{1..12}; do ${!step_var} && any_work=true; done

    if [ "$CONFIG_MODE" = "easy" ]; then
        $STEP_5 && $MANAGE_COMFYUI && save_comfy="$INPUT_COMFYUI_VERSION"
        $package_work && $MANAGE_FRONTEND && save_frontend="$COMFYUI_FRONTEND_VERSION"
        if $STEP_11 && $MANAGE_LAUNCHER; then
            save_alias="$COMFYUI_ALIAS"
        fi
    else
        $any_work && $MANAGE_BASE_PATH && save_base="$BASE_PATH"
        $STEP_1 && $MANAGE_PYTHON && save_python="$PYTHON_VERSION"
        if { $STEP_2 || $STEP_10; } && $MANAGE_PYTORCH; then
            save_torch="$PYTORCH_VERSION"
            save_variant="$PYTORCH_WHEEL_VARIANT"
        fi
        if $package_work; then
            $MANAGE_NUMPY && save_numpy="$NUMPY_VERSION"
            $MANAGE_TRANSFORMERS && save_transformers="$TRANSFORMERS_VERSION"
            if $MANAGE_FRONTEND; then
                save_manage_frontend=$INSTALL_COMFYUI_FRONTEND
                $INSTALL_COMFYUI_FRONTEND && save_frontend="$COMFYUI_FRONTEND_VERSION"
            fi
        fi
        $STEP_5 && $MANAGE_COMFYUI && save_comfy="$INPUT_COMFYUI_VERSION"
        $STEP_3 && $MANAGE_NUNCHAKU && save_nunchaku=$INSTALL_NUNCHAKU
        $STEP_8 && save_cuda_toolkit=$INSTALL_MATCHING_CUDA_TOOLKIT
        if $STEP_11 && $MANAGE_LAUNCHER; then
            save_alias="$COMFYUI_ALIAS"
            save_args="$COMFYUI_LAUNCH_ARGS"
            save_pin_frontend=$PIN_FRONTEND_VERSION_IN_ALIAS
        fi
        if $STEP_5; then
            $MANAGE_SYMLINK_MODELS && save_models=$SYMLINK_MODELS
            $MANAGE_SYMLINK_INPUT && save_input=$SYMLINK_INPUT
            $MANAGE_SYMLINK_OUTPUT && save_output=$SYMLINK_OUTPUT
            $MANAGE_SYMLINK_USER && save_user=$SYMLINK_USER
            $MANAGE_SYMLINK_CUSTOM_NODES && save_nodes=$SYMLINK_CUSTOM_NODES
        fi
    fi

    local block_file candidate
    block_file=$(mktemp)
    candidate=$(mktemp "${SCRIPT_PATH}.candidate.XXXXXX") || {
        rm -f "$block_file"
        echo "⚠️  Defaults were not saved because a same-directory candidate could not be created."
        return 0
    }
    {
        echo "# BEGIN COMFYUI INSTALLER DEFAULTS"
        printf 'BASE_PATH=%q\n' "$save_base"
        printf 'PYTHON_VERSION=%q\n' "$save_python"
        printf 'PYTORCH_VERSION=%q\n' "$save_torch"
        printf 'PYTORCH_WHEEL_VARIANT=%q\n' "$save_variant"
        printf 'NUMPY_VERSION=%q\n' "$save_numpy"
        printf 'TRANSFORMERS_VERSION=%q\n' "$save_transformers"
        printf 'DEFAULT_COMFYUI_VERSION=%q\n' "$save_comfy"
        printf 'DEFAULT_FRONTEND_VERSION=%q\n' "$save_frontend"
        printf 'DEFAULT_ALIAS=%q\n' "$save_alias"
        printf 'COMFYUI_LAUNCH_ARGS=%q\n' "$save_args"
        echo "SYMLINK_MODELS=$save_models"
        echo "SYMLINK_INPUT=$save_input"
        echo "SYMLINK_OUTPUT=$save_output"
        echo "SYMLINK_USER=$save_user"
        echo "SYMLINK_CUSTOM_NODES=$save_nodes"
        echo "INSTALL_NUNCHAKU=$save_nunchaku"
        echo "INSTALL_MATCHING_CUDA_TOOLKIT=$save_cuda_toolkit"
        echo "INSTALL_COMFYUI_FRONTEND=$save_manage_frontend"
        echo "PIN_FRONTEND_VERSION_IN_ALIAS=$save_pin_frontend"
        echo "# END COMFYUI INSTALLER DEFAULTS"
    } > "$block_file"

    awk -v block="$block_file" '
        /^# BEGIN COMFYUI INSTALLER DEFAULTS$/ {
            while ((getline line < block) > 0) print line
            in_defaults=1
            next
        }
        /^# END COMFYUI INSTALLER DEFAULTS$/ { in_defaults=0; next }
        !in_defaults { print }
    ' "$SCRIPT_PATH" > "$candidate"

    if [ "${COMFY_INSTALLER_FORCE_INVALID_CANDIDATE:-0}" = "1" ]; then
        echo 'if invalid candidate' >> "$candidate"
    fi

    if ! bash -n "$candidate"; then
        rm -f "$block_file" "$candidate"
        echo "⚠️  Defaults were not saved because candidate syntax validation failed."
        return 0
    fi

    chmod --reference="$SCRIPT_PATH" "$candidate"
    if mv -f "$candidate" "$SCRIPT_PATH"; then
        echo "✓ Saved successful choices in $SCRIPT_PATH"
    else
        rm -f "$candidate"
        echo "⚠️  Installation succeeded, but defaults could not be saved."
    fi
    rm -f "$block_file"
}

echo "Select installation steps (numbers, ranges, or 'a' for all — e.g., 6-10 or 1 5 6-8 or 5,11):"
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
echo " 12) Compatibility audit and curated repair"
echo ""
echo "Unavailable steps:"
$MANAGE_PYTHON || echo "  1) Python version is preserved"
$MANAGE_PYTORCH || echo "  2) PyTorch stack is preserved"
$NUNCHAKU_AVAILABLE || echo "  3) $NUNCHAKU_UNAVAILABLE_REASON"
$MANAGE_COMFYUI || echo "  5) ComfyUI checkout is preserved"
$MANAGE_LAUNCHER || echo " 11) Launchers are preserved"
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
STEP_12=false

# Normalize commas to spaces so "5,11" and "5 11" both work
STEP_SELECTION=$(echo "$STEP_SELECTION" | tr ',' ' ')

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
    STEP_12=true
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
            12) STEP_12=true ;;
            *) echo "Unknown option: $num" ;;
        esac
    done
fi

# Disable selected work whose configuration was explicitly preserved.
disable_step() {
    local step_var="$1"
    local reason="$2"
    if ${!step_var}; then
        echo "⚠️  Step ${step_var#STEP_} unavailable: $reason"
        printf -v "$step_var" '%s' false
    fi
}

$MANAGE_PYTHON || disable_step STEP_1 "Python version is preserved"
$MANAGE_PYTORCH || disable_step STEP_2 "the installed PyTorch stack is preserved"
$NUNCHAKU_AVAILABLE || disable_step STEP_3 "$NUNCHAKU_UNAVAILABLE_REASON"
$MANAGE_COMFYUI || disable_step STEP_5 "ComfyUI checkout management is preserved"
$MANAGE_LAUNCHER || disable_step STEP_11 "launcher alias, arguments, or pinning are preserved"

ANY_SELECTED=false
for step_var in STEP_{1..12}; do
    ${!step_var} && ANY_SELECTED=true
done
if ! $ANY_SELECTED; then
    echo "No available steps remain after applying the configuration." >&2
    exit 1
fi

NEEDS_VENV=false
for step_var in STEP_{2..12}; do
    ${!step_var} && NEEDS_VENV=true
done
if $NEEDS_VENV && ! $STEP_1 && [ ! -f "$VENV_PATH/bin/activate" ] && [ "${COMFY_INSTALLER_TEST_VENV_PRESENT:-0}" != "1" ]; then
    echo "Selected steps require an existing virtual environment at $VENV_PATH because step 1 was omitted." >&2
    exit 1
fi

NEEDS_COMFYUI=false
for step_var in STEP_6 STEP_7 STEP_8 STEP_11; do
    ${!step_var} && NEEDS_COMFYUI=true
done
COMFYUI_DIR="$COMFYUI_PARENT_DIR/$COMFYUI_DIR_NAME"
if $NEEDS_COMFYUI && ! $STEP_5 && [ ! -d "$COMFYUI_DIR" ] && [ "${COMFY_INSTALLER_TEST_COMFYUI_PRESENT:-0}" != "1" ]; then
    echo "Selected steps require an existing ComfyUI checkout at $COMFYUI_DIR because step 5 was omitted." >&2
    exit 1
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
$STEP_12 && echo "  ✓ Compatibility audit and curated repair"
echo ""
read -r -p "Continue with these steps? (y/N) " REPLY
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi
echo ""

if [ "${COMFY_INSTALLER_TEST_MODE:-0}" = "1" ]; then
    echo "Test mode: selected work completed without filesystem or network changes."
    offer_save_defaults
    exit 0
fi

# ============================================================================
# Activate existing virtual environment if present
# ============================================================================
# If running environment-dependent steps without step 1, activate the existing venv.
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
# [1/12] Python Environment Setup
# ============================================================================
if $STEP_1; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [1/12] Setting up Python Environment"
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
    echo "[1/12] Creating virtual environment at $VENV_PATH..."
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
# Inspect unmanaged versions only when selected dependency work needs exact
# constraints. A missing preserved package gets an impossible local constraint,
# so dependency resolution fails instead of silently installing it.
METADATA_REQUIRED=false
for step_var in STEP_4 STEP_5 STEP_7 STEP_8 STEP_9 STEP_10 STEP_12; do
    ${!step_var} && METADATA_REQUIRED=true
done

installed_distribution_version() {
    local distribution="$1"
    if [ ! -x "$VENV_PATH/bin/python" ]; then
        return 1
    fi
    "$VENV_PATH/bin/python" -c 'import importlib.metadata,sys; print(importlib.metadata.version(sys.argv[1]))' "$distribution" 2>/dev/null
}

if $METADATA_REQUIRED; then
    PYTHON_WHEEL_TAG=$(python -c 'import sys; print(f"cp{sys.version_info.major}{sys.version_info.minor}")')
    if ! $MANAGE_PYTORCH; then
        PYTORCH_FULL_VERSION=$(installed_distribution_version torch || echo "0+preserve")
        TORCHVISION_FULL_VERSION=$(installed_distribution_version torchvision || echo "0+preserve")
        TORCHAUDIO_FULL_VERSION=$(installed_distribution_version torchaudio || echo "0+preserve")
        INSTALLED_TORCH_BASE="${PYTORCH_FULL_VERSION%%+*}"
        PYTORCH_MAJOR_MINOR="${INSTALLED_TORCH_BASE%.*}"
        INSTALLED_BACKEND_METADATA=$(python -c 'import torch; print(f"nvidia:{torch.version.cuda}" if torch.version.cuda else (f"rocm:{torch.version.hip}" if torch.version.hip else "cpu"))' 2>/dev/null || echo unknown)
        case "$INSTALLED_BACKEND_METADATA" in
            nvidia:*)
                HARDWARE_BACKEND="nvidia"
                INSTALLED_CUDA_VERSION="${INSTALLED_BACKEND_METADATA#nvidia:}"
                PYTORCH_WHEEL_VARIANT="cu${INSTALLED_CUDA_VERSION//./}"
                PYTORCH_INDEX_URL="https://download.pytorch.org/whl/${PYTORCH_WHEEL_VARIANT}"
                ;;
            rocm:*)
                HARDWARE_BACKEND="rocm"
                INSTALLED_ROCM_VERSION="${INSTALLED_BACKEND_METADATA#rocm:}"
                PYTORCH_WHEEL_VARIANT="rocm$(printf '%s' "$INSTALLED_ROCM_VERSION" | cut -d. -f1,2)"
                PYTORCH_INDEX_URL="https://download.pytorch.org/whl/${PYTORCH_WHEEL_VARIANT}"
                ;;
            cpu) HARDWARE_BACKEND="cpu"; PYTORCH_WHEEL_VARIANT="cpu" ;;
            *) HARDWARE_BACKEND="unknown" ;;
        esac
        echo "ℹ️  Preserving installed PyTorch metadata: $PYTORCH_FULL_VERSION"
        echo "ℹ️  Detected installed hardware backend: $HARDWARE_BACKEND"
    fi
    if ! $MANAGE_NUMPY; then
        NUMPY_VERSION=$(installed_distribution_version numpy || echo "0+preserve")
        echo "ℹ️  Preserving installed NumPy metadata: $NUMPY_VERSION"
    fi
    if ! $MANAGE_TRANSFORMERS; then
        TRANSFORMERS_VERSION=$(installed_distribution_version transformers || echo "0+preserve")
        echo "ℹ️  Preserving installed Transformers metadata: $TRANSFORMERS_VERSION"
    fi
fi

# [2/12] Install PyTorch
# ============================================================================
if $STEP_2; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [2/12] Installing PyTorch and Base Dependencies"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Install PyTorch
# Note: PyTorch version is configurable via PYTORCH_FULL_VERSION variable
# Ensure nunchaku and flash-attn wheels are available for selected PyTorch version
echo "Installing PyTorch ${PYTORCH_FULL_VERSION}..."
uv pip install torch==${PYTORCH_FULL_VERSION} torchvision==${TORCHVISION_FULL_VERSION} torchaudio==${TORCHAUDIO_FULL_VERSION} --index-url ${PYTORCH_INDEX_URL}

fi  # End STEP_2

# ============================================================================
# [3/12] Install Nunchaku
# ============================================================================
if $STEP_3; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [3/12] Installing Nunchaku Acceleration Library"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Compute the wheel tag when step 3 is run against an existing environment
# without rerunning the Python setup step.
if [ -z "${PYTHON_WHEEL_TAG:-}" ]; then
    PYTHON_MAJOR_MINOR=$(python -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')
    PYTHON_WHEEL_TAG="cp${PYTHON_MAJOR_MINOR}"
    echo "✓ Python wheel tag: $PYTHON_WHEEL_TAG"
fi

# Install the official Nunchaku AI wheel matching the configured CUDA, PyTorch,
# and Python versions. Do not fall back to PyPI: it contains an unrelated
# package with the same distribution name.
if [ -z "$NUNCHAKU_CUDA_VARIANT" ]; then
    echo "❌ Nunchaku ${NUNCHAKU_VERSION} has no official wheel for PyTorch variant ${PYTORCH_WHEEL_VARIANT}." >&2
    echo "   Supported NVIDIA variants: cu128 and cu130." >&2
    exit 1
fi

if [[ " $NUNCHAKU_SUPPORTED_TORCH_VERSIONS " != *" $PYTORCH_MAJOR_MINOR "* ]]; then
    echo "❌ Nunchaku ${NUNCHAKU_VERSION} ${NUNCHAKU_CUDA_VARIANT} has no official wheel for PyTorch ${PYTORCH_MAJOR_MINOR}." >&2
    echo "   Supported PyTorch versions: ${NUNCHAKU_SUPPORTED_TORCH_VERSIONS}" >&2
    exit 1
fi

if [[ " $NUNCHAKU_SUPPORTED_PYTHON_TAGS " != *" $PYTHON_WHEEL_TAG "* ]]; then
    echo "❌ Nunchaku ${NUNCHAKU_VERSION} has no official wheel for Python ${PYTHON_WHEEL_TAG}." >&2
    echo "   Supported Python wheel tags: ${NUNCHAKU_SUPPORTED_PYTHON_TAGS}" >&2
    exit 1
fi

echo "Installing nunchaku ${NUNCHAKU_VERSION} (${NUNCHAKU_CUDA_VARIANT}) for PyTorch ${PYTORCH_MAJOR_MINOR} (Python ${PYTHON_WHEEL_TAG})..."
NUNCHAKU_WHEEL="https://github.com/nunchaku-ai/nunchaku/releases/download/v${NUNCHAKU_VERSION}/nunchaku-${NUNCHAKU_VERSION}+${NUNCHAKU_CUDA_VARIANT}torch${PYTORCH_MAJOR_MINOR}-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-linux_x86_64.whl"
if ! uv pip install "$NUNCHAKU_WHEEL"; then
    echo "❌ Failed to install the official Nunchaku wheel:" >&2
    echo "   $NUNCHAKU_WHEEL" >&2
    echo "   No PyPI fallback was attempted because the package named 'nunchaku' there is unrelated." >&2
    exit 1
fi

fi  # End STEP_3

# ============================================================================
# [4/12] Install Face Recognition and Runtime Libraries
# ============================================================================
if $STEP_4; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [4/12] Installing Face Recognition and Runtime Libraries"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Create temporary constraints file to prevent torch downgrade
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
torchvision==${TORCHVISION_FULL_VERSION}
torchaudio==${TORCHAUDIO_FULL_VERSION}
numpy==${NUMPY_VERSION}
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
# [5/12] Install ComfyUI
# ============================================================================
if $STEP_5; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [5/12] Installing ComfyUI Core"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

COMFYUI_DIR="${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}"

# Check if ComfyUI is already cloned
if [ ! -d "$COMFYUI_DIR/.git" ]; then
    echo "Cloning ComfyUI repository to $COMFYUI_DIR..."
    mkdir -p "$COMFYUI_PARENT_DIR"
    cd "$COMFYUI_PARENT_DIR"
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR_NAME"
    COMFYUI_WAS_CLONED=true
    
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
torchvision==${TORCHVISION_FULL_VERSION}
torchaudio==${TORCHAUDIO_FULL_VERSION}
numpy==${NUMPY_VERSION}
EOF
echo "Using constraints to prevent torch/numpy downgrade"
install_uv_requirements requirements.txt --constraint "$CONSTRAINTS_FILE"
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_5

# ============================================================================
# Configure Shared/Local ComfyUI Directories
# ============================================================================

# Ensure COMFYUI_DIR is set (may not be if STEP_5 was skipped)
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Configuring Shared and Local Directories"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

directory_contains_only_pristine_repo_content() {
    local directory="$1"
    local repo_root="$2"
    local entry
    local repo_relative_path

    git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

    while IFS= read -r -d '' entry; do
        repo_relative_path="${entry#"$repo_root"/}"
        if ! git -C "$repo_root" ls-files --error-unmatch -- "$repo_relative_path" >/dev/null 2>&1; then
            return 1
        fi
        if ! git -C "$repo_root" diff --quiet HEAD -- "$repo_relative_path"; then
            return 1
        fi
    done < <(find "$directory" \( -type f -o -type l \) -print0)

    return 0
}

copy_missing_directory_content() {
    local source_path="$1"
    local destination_path="$2"
    local source_entry
    local destination_entry
    local entry_name

    while IFS= read -r -d '' source_entry; do
        entry_name="${source_entry##*/}"
        destination_entry="$destination_path/$entry_name"

        if [ -d "$source_entry" ] && [ ! -L "$source_entry" ]; then
            if [ ! -e "$destination_entry" ] && [ ! -L "$destination_entry" ]; then
                if ! mkdir -p "$destination_entry"; then
                    return 1
                fi
            fi

            if [ -d "$destination_entry" ] && [ ! -L "$destination_entry" ]; then
                if ! copy_missing_directory_content "$source_entry" "$destination_entry"; then
                    return 1
                fi
            fi
        elif [ ! -e "$destination_entry" ] && [ ! -L "$destination_entry" ]; then
            if ! cp -a "$source_entry" "$destination_entry"; then
                return 1
            fi
        fi
    done < <(find "$source_path" -mindepth 1 -maxdepth 1 -print0)

    return 0
}

configure_shared_directory() {
    local name="$1"
    local local_path="$2"
    local shared_path="$3"
    local enabled="$4"
    local new_install="${5:-false}"

    if [ "$enabled" != true ]; then
        if [ -L "$local_path" ]; then
            echo "⚠️  $name: sharing is disabled, but an existing symlink is preserved: $local_path -> $(readlink "$local_path")"
            echo "   Remove the symlink manually if you want this installation to use a local directory."
        elif [ -d "$local_path" ]; then
            echo "✓ $name: using local directory $local_path"
        elif [ -e "$local_path" ]; then
            echo "⚠️  $name: cannot create a local directory because a non-directory path exists at $local_path"
        else
            mkdir -p "$local_path"
            echo "✓ $name: created local directory $local_path"
        fi
        return
    fi

    mkdir -p "$shared_path"

    if [ -L "$local_path" ]; then
        local current_target
        current_target=$(readlink "$local_path")
        if [ "$current_target" = "$shared_path" ]; then
            echo "✓ $name: already shared at $shared_path"
        else
            echo "⚠️  $name: symlink points to $current_target; relinking to $shared_path"
            rm -f "$local_path"
            ln -s "$shared_path" "$local_path"
            echo "✓ $name: fixed shared symlink"
        fi
        return
    fi

    if [ -d "$local_path" ]; then
        if [ -z "$(ls -A "$local_path" 2>/dev/null)" ]; then
            rmdir "$local_path"
        elif [ "$new_install" = true ] || directory_contains_only_pristine_repo_content "$local_path" "$COMFYUI_DIR"; then
            echo "→ $name: moving checkout files that are missing from $shared_path"
            if copy_missing_directory_content "$local_path" "$shared_path"; then
                rm -rf "$local_path"
            else
                echo "⚠️  $name: merge failed; preserving the local directory and skipping the symlink"
                return
            fi
        elif [ -z "$(ls -A "$shared_path" 2>/dev/null)" ]; then
            echo "→ $name: copying existing local data to $shared_path"
            if cp -a "$local_path/." "$shared_path/"; then
                rm -rf "$local_path"
            else
                echo "⚠️  $name: copy failed; preserving the local directory and skipping the symlink"
                return
            fi
        else
            echo "⚠️  $name: local and shared directories both contain data; preserving both and skipping the symlink"
            echo "   Merge them manually, then rerun the installer."
            return
        fi
    elif [ -e "$local_path" ]; then
        echo "⚠️  $name: cannot create a symlink because a non-directory path exists at $local_path"
        return
    fi

    ln -s "$shared_path" "$local_path"
    echo "✓ $name: shared $local_path -> $shared_path"
}

print_directory_state() {
    local name="$1"
    local path="$2"
    local enabled="$3"

    if [ -L "$path" ]; then
        if [ "$enabled" = true ]; then
            echo "  $name: Shared ($(readlink "$path"))"
        else
            echo "  $name: Existing symlink preserved ($(readlink "$path"))"
        fi
    else
        echo "  $name: Local ($path)"
    fi
}

$STEP_5 && $MANAGE_SYMLINK_MODELS && configure_shared_directory "Models" "$COMFYUI_DIR/models" "$USER_MODELS_PATH" "$SYMLINK_MODELS" "$COMFYUI_WAS_CLONED"
$STEP_5 && $MANAGE_SYMLINK_INPUT && configure_shared_directory "Input" "$COMFYUI_DIR/input" "$USER_INPUT_PATH" "$SYMLINK_INPUT" "$COMFYUI_WAS_CLONED"
$STEP_5 && $MANAGE_SYMLINK_OUTPUT && configure_shared_directory "Output" "$COMFYUI_DIR/output" "$USER_OUTPUT_PATH" "$SYMLINK_OUTPUT" "$COMFYUI_WAS_CLONED"
$STEP_5 && $MANAGE_SYMLINK_USER && configure_shared_directory "User Data" "$COMFYUI_DIR/user" "$USER_USERDATA_PATH" "$SYMLINK_USER" "$COMFYUI_WAS_CLONED"
$STEP_5 && $MANAGE_SYMLINK_CUSTOM_NODES && configure_shared_directory "Custom Nodes" "$COMFYUI_DIR/custom_nodes" "$USER_CUSTOM_NODES_PATH" "$SYMLINK_CUSTOM_NODES" "$COMFYUI_WAS_CLONED"

# ============================================================================
# [6/12] Clone Custom Nodes
# ============================================================================
if $STEP_6; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [6/12] Cloning Custom Nodes"
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
    local repo_name_original repo_name disabled_match legacy_disabled_match
    repo_name_original=$(basename "$repo_url" .git)
    repo_name=$(echo "$repo_name_original" | tr '[:upper:]' '[:lower:]')
    disabled_match=""
    legacy_disabled_match=""

    if [ -d "$CUSTOM_NODES_DIR/.disabled" ]; then
        disabled_match=$(find "$CUSTOM_NODES_DIR/.disabled" -mindepth 1 -maxdepth 1 -type d -iname "$repo_name" -print -quit 2>/dev/null || true)
    fi
    legacy_disabled_match=$(find "$CUSTOM_NODES_DIR" -mindepth 1 -maxdepth 1 -type d -iname "${repo_name}.disabled" -print -quit 2>/dev/null || true)

    if [ -d "$repo_name/.git" ]; then
        echo "✓ $repo_name already exists"
    elif [ -d "$repo_name" ]; then
        echo "⚠️  $repo_name already exists but is not a Git checkout; preserving it as unmanaged"
    elif [ -d "$repo_name_original/.git" ] && [ "$repo_name_original" != "$repo_name" ]; then
        echo "→ Renaming $repo_name_original → $repo_name (lowercase)"
        mv "$repo_name_original" "$repo_name"
    elif [ -d "$repo_name_original" ]; then
        echo "⚠️  $repo_name_original already exists but is not a Git checkout; preserving it as unmanaged"
    elif [ -n "$disabled_match" ]; then
        echo "⊘ $repo_name is disabled by ComfyUI-Manager; leaving $disabled_match untouched"
    elif [ -n "$legacy_disabled_match" ]; then
        echo "⊘ $repo_name has a legacy .disabled directory; leaving $legacy_disabled_match untouched"
    else
        echo "→ Cloning $repo_name..."
        git clone "$repo_url" "$repo_name" || echo "⚠️  Failed to clone $repo_name"
    fi
}

# Core Extensions
echo "Cloning core extensions..."
clone_if_missing "https://github.com/r-vage/ComfyUI_Eclipse.git"
clone_if_missing "https://github.com/Comfy-Org/ComfyUI-Manager.git"

# UI & Workflow Tools
echo ""
echo "Cloning UI & workflow tools..."
clone_if_missing "https://github.com/BobRandomNumber/ComfyUI-Crystools-MonitorOnly.git"
clone_if_missing "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
clone_if_missing "https://github.com/rgthree/rgthree-comfy"
clone_if_missing "https://github.com/yolain/ComfyUI-Easy-Use.git"
clone_if_missing "https://github.com/cubiq/ComfyUI_essentials.git"
clone_if_missing "https://github.com/MinorBoy/ComfyUI_essentials_mb.git"
clone_if_missing "https://github.com/chrisgoringe/cg-image-filter.git"
clone_if_missing "https://github.com/ashtar1984/comfyui-find-perfect-resolution"
clone_if_missing "https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI"
clone_if_missing "https://github.com/darksidewalker/ComfyUI-DaSiWa-Nodes"
clone_if_missing "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI"

# Model Support & Optimization
echo ""
echo "Cloning model support & optimization..."
clone_if_missing "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
clone_if_missing "https://github.com/lldacing/ComfyUI_Patches_ll.git"

# Sampling & Scheduling
echo ""
echo "Cloning sampling & scheduling..."
clone_if_missing "https://github.com/r-vage/RES4LYF.git"
clone_if_missing "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
clone_if_missing "https://github.com/ChangeTheConstants/SeedVarianceEnhancer"
clone_if_missing "https://github.com/wildminder/ComfyUI-DyPE"
clone_if_missing "https://github.com/Artificial-Sweetener/comfyui-WhiteRabbit"

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
clone_if_missing "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
clone_if_missing "https://github.com/SeanBRVFX/ComfyUI-CorridorKey"
clone_if_missing "https://github.com/filliptm/ComfyUI_Fill-Nodes.git"
clone_if_missing "https://github.com/shiimizu/ComfyUI-TiledDiffusion"

# Specialized Models
echo ""
echo "Cloning specialized models..."
clone_if_missing "https://github.com/kijai/ComfyUI-SUPIR.git"
clone_if_missing "https://github.com/lldacing/ComfyUI_BiRefNet_ll.git"
clone_if_missing "https://github.com/r-vage/ComfyUI_PuLID_Flux_ll.git"
clone_if_missing "https://github.com/lbouaraba/comfyui-krea2edit.git"
clone_if_missing "https://github.com/capitan01R/ComfyUI-Krea2T-Enhancer.git"
clone_if_missing "https://github.com/kijai/ComfyUI-SCAIL-Pose.git"

# Audio & Media
echo ""
echo "Cloning audio & media..."
clone_if_missing "https://github.com/kijai/ComfyUI-MMAudio"
clone_if_missing "https://github.com/kijai/ComfyUI-MelBandRoFormer"
clone_if_missing "https://github.com/mattjohnpowell/comfyui-audio-expo"

# Video Processing
echo ""
echo "Cloning video processing..."
clone_if_missing "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
clone_if_missing "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
clone_if_missing "https://github.com/kijai/ComfyUI-GIMM-VFI"
clone_if_missing "https://github.com/GACLove/ComfyUI-VFI"
clone_if_missing "https://github.com/kijai/ComfyUI-WanVideoWrapper"
clone_if_missing "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
clone_if_missing "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
clone_if_missing "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
clone_if_missing "https://github.com/r-vage/ComfyUI-LTXVideo.git"


fi  # End STEP_6

# ============================================================================
# [7/12] Install Custom Node Dependencies
# ============================================================================
if $STEP_7; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [7/12] Installing Custom Node Dependencies"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Ensure COMFYUI_DIR and CUSTOM_NODES_DIR are set
COMFYUI_DIR="${COMFYUI_DIR:-${COMFYUI_PARENT_DIR}/${COMFYUI_DIR_NAME}}"
CUSTOM_NODES_DIR="${CUSTOM_NODES_DIR:-$COMFYUI_DIR/custom_nodes}"

# Create temporary constraints file to prevent torch/transformers downgrade
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
torchvision==${TORCHVISION_FULL_VERSION}
torchaudio==${TORCHAUDIO_FULL_VERSION}
numpy==${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
numba>=0.58.0
EOF

# Install dependencies for all custom nodes
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Installing dependencies for all custom nodes..."
echo "═══════════════════════════════════════════════════════════════════"
echo "Using constraints to prevent torch/numpy/transformers downgrade"
if [ -d "$CUSTOM_NODES_DIR/.disabled" ]; then
    echo "⊘ Skipping ComfyUI-Manager disabled nodes in $CUSTOM_NODES_DIR/.disabled"
fi
for node_dir in "$CUSTOM_NODES_DIR"/*; do
    [ -d "$node_dir" ] || continue
    node_name=$(basename "$node_dir")
    case "${node_name,,}" in
        *.disabled)
            echo "⊘ Skipping legacy disabled node: $node_name"
            continue
            ;;
    esac
    if [ -f "$node_dir/requirements.txt" ]; then
        echo ""
        echo "→ Installing dependencies for: $node_name"
        install_uv_requirements "$node_dir/requirements.txt" --constraint "$CONSTRAINTS_FILE" || echo "⚠️  Some dependencies for $node_name failed (may be optional)"
    fi
done

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_7

# ============================================================================
# [8/12] Install Performance Libraries
# ============================================================================
if $STEP_8; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [8/12] Installing Performance Libraries"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Create temporary constraints file
CONSTRAINTS_FILE=$(mktemp)
cat > "$CONSTRAINTS_FILE" << EOF
torch==${PYTORCH_FULL_VERSION}
torchvision==${TORCHVISION_FULL_VERSION}
torchaudio==${TORCHAUDIO_FULL_VERSION}
numpy==${NUMPY_VERSION}
transformers==${TRANSFORMERS_VERSION}
EOF

# Install llama-cpp-python
echo "Installing llama-cpp-python..."
uv pip install --constraint "$CONSTRAINTS_FILE" "llama-cpp-python>=0.3.16"

if [ "$HARDWARE_BACKEND" = "nvidia" ]; then
    flash_usable=false
    case "$PYTORCH_WHEEL_VARIANT" in
        cu126|cu128)
            echo "Installing the exact official Flash Attention $FLASH_ATTN_VERSION wheel for PyTorch ${PYTORCH_MAJOR_MINOR} (Python ${PYTHON_WHEEL_TAG})..."
            FLASH_ATTN_WHEEL="https://github.com/Dao-AILab/flash-attention/releases/download/v${FLASH_ATTN_VERSION}/flash_attn-${FLASH_ATTN_VERSION}+cu12torch${PYTORCH_MAJOR_MINOR}cxx11abiTRUE-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-linux_x86_64.whl"
            if uv pip install --constraint "$CONSTRAINTS_FILE" --reinstall --no-deps "$FLASH_ATTN_WHEEL" && verify_flash_attention_import; then
                flash_usable=true
                echo "✓ Flash Attention passed its import check"
            else
                echo "⚠️  No compatible official Flash Attention wheel was installed for this exact ABI."
            fi
            ;;
        *)
            echo "ℹ️  No official Flash Attention $FLASH_ATTN_VERSION wheel is configured for $PYTORCH_WHEEL_VARIANT."
            ;;
    esac
    if ! $flash_usable; then
        remove_flash_attention
        echo "ℹ️  Flash Attention is disabled; ComfyUI will use PyTorch attention."
    fi
    if ! verify_kornia_import; then
        remove_flash_attention
        if ! verify_kornia_import; then
            echo "❌ Kornia still fails to import after removing Flash Attention." >&2
            exit 1
        fi
    fi

    install_sage_attention "$CONSTRAINTS_FILE"
else
    echo "ℹ️  Removing CUDA-only attention accelerators for $HARDWARE_BACKEND"
    remove_flash_attention
    uv pip uninstall sageattention >/dev/null 2>&1 || true
fi

# Clean up constraints file
rm -f "$CONSTRAINTS_FILE"

fi  # End STEP_8

# ============================================================================
# [9/12] Upgrade & Pin Package Versions
# ============================================================================
if $STEP_9; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  [9/12] Upgrading & Pinning Package Versions"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    CONSTRAINTS_FILE=$(mktemp)
    {
        echo "torch==$PYTORCH_FULL_VERSION"
        echo "torchvision==$TORCHVISION_FULL_VERSION"
        echo "torchaudio==$TORCHAUDIO_FULL_VERSION"
        echo "numpy==$NUMPY_VERSION"
        echo "transformers==$TRANSFORMERS_VERSION"
        echo "nvidia-ml-py>=12,<13"
    } >> "$CONSTRAINTS_FILE"
    echo "Upgrading selected direct packages without broadly upgrading their dependencies..."
    uv pip install --constraint "$CONSTRAINTS_FILE" --upgrade-package ultralytics --upgrade-package gguf ultralytics gguf
    echo "ℹ️  Preserving AV, protobuf, OpenCV, inference, tokenizers, and other conflict-prone packages for step 12."

    uv pip install "mistral-common>=1.8.6"
    $MANAGE_NUMPY && uv pip install "numpy==$NUMPY_VERSION"
    $MANAGE_TRANSFORMERS && uv pip install "transformers==$TRANSFORMERS_VERSION"
    if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND; then
        uv pip install "comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
    fi
    rm -f "$CONSTRAINTS_FILE"
fi

# ============================================================================
# [10/12] Enforce Configured Package Versions
# ============================================================================
if $STEP_10; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  [10/12] Enforcing Configured Package Versions"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    if $MANAGE_PYTORCH; then
        uv pip install "torch==$PYTORCH_FULL_VERSION" "torchvision==$TORCHVISION_FULL_VERSION" "torchaudio==$TORCHAUDIO_FULL_VERSION" --index-url "$PYTORCH_INDEX_URL" ||
            echo "⚠️  PyTorch installation failed, continuing anyway..."
    else
        echo "ℹ️  Preserving the installed PyTorch stack"
    fi
    $MANAGE_NUMPY && uv pip install "numpy==$NUMPY_VERSION" || true
    $MANAGE_TRANSFORMERS && uv pip install "transformers==$TRANSFORMERS_VERSION" || true
    if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND; then
        uv pip install "comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION" ||
            echo "⚠️  ComfyUI frontend installation failed, continuing anyway..."
    else
        echo "ℹ️  Preserving or leaving the ComfyUI frontend unmanaged"
    fi
    echo "✓ Managed package versions enforced successfully"
fi

# ============================================================================
# [11/12] Configure Shell Aliases
# ============================================================================
if $STEP_11; then

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  [11/12] Configuring Shell Aliases"
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
        existing=$(grep -E "^alias (comfy|envact)" "$config_file" 2>/dev/null || true)
        if [ -n "$existing" ]; then
            echo "  Existing ComfyUI aliases in $config_name:"
            echo "$existing" | while IFS= read -r line; do echo "    $line"; done
            echo ""
        fi
    fi

    # Add launch alias if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^alias ${COMFYUI_ALIAS}=" "$config_file"; then
        echo "  ✓ Alias '${COMFYUI_ALIAS}' already exists in $config_name — skipping"
        if { ! $MANAGE_FRONTEND || ! $INSTALL_COMFYUI_FRONTEND || ! $PIN_FRONTEND_VERSION_IN_ALIAS; } && grep -E "^alias ${COMFYUI_ALIAS}=.*comfyui-frontend-package" "$config_file" >/dev/null 2>&1; then
            echo "  ⚠️  Existing alias still pins the frontend; remove it and rerun step 11 to regenerate it"
        fi
        if [ -n "$COMFYUI_LAUNCH_ARGS" ] && ! grep -E "^alias ${COMFYUI_ALIAS}=" "$config_file" | grep -Fq -- "$COMFYUI_LAUNCH_ARGS"; then
            echo "  ⚠️  Existing alias may not include the configured launch arguments; remove it and rerun step 11 to regenerate it"
        fi
    else
        {
            echo ""
            if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND && $PIN_FRONTEND_VERSION_IN_ALIAS; then
                echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend $COMFYUI_FRONTEND_VERSION)"
                echo "alias ${COMFYUI_ALIAS}='source $VENV_PATH/bin/activate && uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION && cd $COMFYUI_DIR && python main.py $COMFYUI_LAUNCH_ARGS'"
            else
                echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend not pinned on launch)"
                echo "alias ${COMFYUI_ALIAS}='source $VENV_PATH/bin/activate && cd $COMFYUI_DIR && python main.py $COMFYUI_LAUNCH_ARGS'"
            fi
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
        existing=$(grep -E "^function (comfy|envact)" "$config_file" 2>/dev/null || true)
        if [ -n "$existing" ]; then
            echo "  Existing ComfyUI functions in Fish config:"
            echo "$existing" | while IFS= read -r line; do echo "    $line"; done
            echo ""
        fi
    fi

    # Add launch function if it doesn't already exist
    if [ -f "$config_file" ] && grep -q "^function ${COMFYUI_ALIAS}\$" "$config_file"; then
        echo "  ✓ Function '${COMFYUI_ALIAS}' already exists in Fish config — skipping"
        if ! $MANAGE_FRONTEND || ! $INSTALL_COMFYUI_FRONTEND || ! $PIN_FRONTEND_VERSION_IN_ALIAS; then
            echo "  ⚠️  Existing function may still pin the frontend; remove it and rerun step 11 to regenerate it"
        fi
        if [ -n "$COMFYUI_LAUNCH_ARGS" ]; then
            echo "  ⚠️  Existing function may not include the configured launch arguments; remove it and rerun step 11 to regenerate it"
        fi
    else
        {
            echo ""
            if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND && $PIN_FRONTEND_VERSION_IN_ALIAS; then
                echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend $COMFYUI_FRONTEND_VERSION)"
            else
                echo "# ComfyUI: ${COMFYUI_ALIAS} -> $COMFYUI_DIR (frontend not pinned on launch)"
            fi
            echo "function ${COMFYUI_ALIAS}"
            echo "    source $VENV_PATH/bin/activate.fish"
            if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND && $PIN_FRONTEND_VERSION_IN_ALIAS; then
                echo "    uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
            fi
            echo "    cd $COMFYUI_DIR"
            echo "    python main.py $COMFYUI_LAUNCH_ARGS \$argv"
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

{
    echo "#!/bin/bash"
    echo "# ComfyUI Launcher Script"
    echo "# Auto-generated by install_comfy_env.sh"
    echo ""
    if $MANAGE_FRONTEND && $INSTALL_COMFYUI_FRONTEND && $PIN_FRONTEND_VERSION_IN_ALIAS; then
        echo "# Ensure correct frontend version for this installation"
        echo "\"$VENV_PATH/bin/python\" -m uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
        echo ""
    else
        echo "# Frontend package is managed externally"
    fi
    echo "# Change to ComfyUI directory"
    echo "cd \"$COMFYUI_DIR\""
    echo ""
    echo "# Use virtual environment's Python directly (bypasses pyenv shims)"
    echo "\"$VENV_PATH/bin/python\" main.py $COMFYUI_LAUNCH_ARGS \"\$@\""
} > "$LAUNCHER_SCRIPT"

# Make executable
chmod +x "$LAUNCHER_SCRIPT"

echo "✓ Launcher script created at: $LAUNCHER_SCRIPT"
echo "  You can start ComfyUI by running: $LAUNCHER_SCRIPT"

fi  # End STEP_11

# ============================================================================
# [12/12] Compatibility Audit and Curated Repair
# ============================================================================
if $STEP_12; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  [12/12] Compatibility Audit and Curated Repair"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    PIP_CHECK_BEFORE=$(mktemp)
    PIP_CHECK_AFTER=$(mktemp)
    if uv pip check >"$PIP_CHECK_BEFORE" 2>&1; then
        echo "✓ pip check found no declared dependency conflicts"
    else
        echo "⚠️  Declared dependency conflicts before curated repair:"
        sed 's/^/   /' "$PIP_CHECK_BEFORE"
    fi

    CURATED_REPAIRS=()
    # Prefer versions shared by active inference packages and the wider runtime.
    grep -Eqi "(inference|inference-gpu).*requires.*filelock" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("filelock==3.16.1")
    grep -Eqi "(inference|inference-gpu).*requires.*opencv-python" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("opencv-python==4.10.0.84")
    grep -Eqi "(inference|inference-gpu).*requires.*packaging" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("packaging==24.2")
    grep -Eqi "(inference|inference-gpu).*requires.*rich" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("rich==13.9.4")
    grep -Eqi "(inference|inference-cli|inference-gpu).*requires.*nvidia-ml-py" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("nvidia-ml-py==12.575.51")
    grep -Eqi "aiortc.*requires.*av" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("av==17.0.0")

    # Restore the modern managed side if an older installer run downgraded it.
    # The legacy inference packages have mutually exclusive requirements here,
    # so their remaining declarations are reported instead of winning by count.
    grep -Eqi "huggingface-hub.*requires.*click" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("click==8.4.2")
    grep -Eqi "(typing-inspection|google-genai|runwayml|onnx).*requires.*typing-extensions" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("typing-extensions==4.16.0")
    grep -Eqi "inference-cli.*requires.*aiohttp" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("aiohttp==3.14.3")
    grep -Eqi "inference-cli.*requires.*pillow" "$PIP_CHECK_BEFORE" && CURATED_REPAIRS+=("pillow==12.3.0")

    if [ ${#CURATED_REPAIRS[@]} -gt 0 ]; then
        REPAIR_CONSTRAINTS=$(mktemp)
        AUDIT_TORCH_VERSION=$(installed_distribution_version torch || echo "0+missing")
        AUDIT_TORCHVISION_VERSION=$(installed_distribution_version torchvision || echo "0+missing")
        AUDIT_TORCHAUDIO_VERSION=$(installed_distribution_version torchaudio || echo "0+missing")
        AUDIT_NUMPY_VERSION=$(installed_distribution_version numpy || echo "0+missing")
        AUDIT_TRANSFORMERS_VERSION=$(installed_distribution_version transformers || echo "0+missing")
        {
            echo "torch==$AUDIT_TORCH_VERSION"
            echo "torchvision==$AUDIT_TORCHVISION_VERSION"
            echo "torchaudio==$AUDIT_TORCHAUDIO_VERSION"
            echo "numpy==$AUDIT_NUMPY_VERSION"
            echo "transformers==$AUDIT_TRANSFORMERS_VERSION"
            echo "nvidia-ml-py>=12,<13"
        } > "$REPAIR_CONSTRAINTS"
        echo "→ Dry-running curated compatibility repairs: ${CURATED_REPAIRS[*]}"
        if uv pip install --constraint "$REPAIR_CONSTRAINTS" --dry-run "${CURATED_REPAIRS[@]}"; then
            uv pip install --constraint "$REPAIR_CONSTRAINTS" "${CURATED_REPAIRS[@]}" || echo "⚠️  Curated compatibility repairs were not fully applied"
        else
            echo "⚠️  Curated repairs were skipped because the complete candidate set was not resolvable."
        fi
        rm -f "$REPAIR_CONSTRAINTS"
    fi

    if distribution_installed flash-attn && ! verify_flash_attention_import; then
        echo "⚠️  Flash Attention has a native-extension ABI failure."
        remove_flash_attention
    fi
    if ! verify_kornia_import; then
        remove_flash_attention
    fi
    if distribution_installed sageattention; then
        if sage_attention_is_modern; then
            if ! verify_sage_attention; then
                echo "⚠️  SageAttention 2 failed verification; installing the no-compile fallback."
                install_sage_attention_fallback || true
            fi
        elif ! verify_sage_attention_fallback; then
            echo "⚠️  SageAttention fallback failed its import check; reinstalling it."
            install_sage_attention_fallback || true
        fi
    fi

    CORE_IMPORT_FAILURE=false
    if python -c 'import bz2' >/dev/null 2>&1; then
        echo "✓ Python standard-library bz2 import"
    else
        echo "❌ Python cannot import bz2. Reinstall this Python version after installing the OS bzip2 development package; no library symlink was created." >&2
        CORE_IMPORT_FAILURE=true
    fi
    if python -c 'import torch, torchvision, torchaudio' >/dev/null 2>&1; then
        echo "✓ PyTorch, TorchVision, and TorchAudio imports"
    else
        echo "❌ The managed PyTorch stack failed its runtime import probe." >&2
        CORE_IMPORT_FAILURE=true
    fi
    if verify_kornia_import; then
        echo "✓ Kornia import"
    else
        echo "❌ Kornia still fails to import without Flash Attention." >&2
        CORE_IMPORT_FAILURE=true
    fi
    if distribution_installed nunchaku; then
        if python -c 'import nunchaku' >/dev/null 2>&1; then
            echo "✓ Nunchaku import"
        else
            echo "⚠️  Nunchaku is installed but failed its import probe."
        fi
    fi
    if distribution_installed sageattention; then
        if sage_attention_is_modern && verify_sage_attention; then
            echo "✓ SageAttention verification"
        elif verify_sage_attention_fallback; then
            echo "⚠️  SageAttention $SAGEATTENTION_FALLBACK_VERSION fallback import; SageAttention 2 integrations are unavailable."
        else
            echo "⚠️  SageAttention remains unavailable; ComfyUI can use PyTorch attention."
        fi
    fi

    if uv pip check >"$PIP_CHECK_AFTER" 2>&1; then
        echo "✓ pip check is clean after curated repair"
    else
        echo "⚠️  Remaining tolerated or irreconcilable dependency conflicts:"
        sed 's/^/   /' "$PIP_CHECK_AFTER"
        echo "   No broad resolver was run; working custom-node ecosystems were left in place."
    fi
    rm -f "$PIP_CHECK_BEFORE" "$PIP_CHECK_AFTER"

    if $CORE_IMPORT_FAILURE; then
        echo "❌ Compatibility audit failed because a ComfyUI core runtime import is broken." >&2
        exit 1
    fi
    echo "✓ Compatibility audit completed; optional unresolved conflicts are listed above"
fi

# ============================================================================
# Installation Complete
# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✓ Installation Complete!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
SUMMARY_PYTORCH_VERSION=$(installed_distribution_version torch || echo "not installed")
SUMMARY_NUMPY_VERSION=$(installed_distribution_version numpy || echo "not installed")
SUMMARY_TRANSFORMERS_VERSION=$(installed_distribution_version transformers || echo "not installed")
echo "Installed Environment Versions:"
echo "  PyTorch: $SUMMARY_PYTORCH_VERSION"
echo "  NumPy: $SUMMARY_NUMPY_VERSION"
echo "  Transformers: $SUMMARY_TRANSFORMERS_VERSION"
echo ""
echo "Environment: $VENV_PATH"
COMFY_CONTEXT_SELECTED=false
for step_var in STEP_5 STEP_6 STEP_7 STEP_8 STEP_11; do
    ${!step_var} && COMFY_CONTEXT_SELECTED=true
done
if $COMFY_CONTEXT_SELECTED; then
    echo "ComfyUI Location: $COMFYUI_DIR"
echo "Directory Storage:"
print_directory_state "Models" "$COMFYUI_DIR/models" "$SYMLINK_MODELS"
print_directory_state "Input" "$COMFYUI_DIR/input" "$SYMLINK_INPUT"
print_directory_state "Output" "$COMFYUI_DIR/output" "$SYMLINK_OUTPUT"
print_directory_state "User Data" "$COMFYUI_DIR/user" "$SYMLINK_USER"
print_directory_state "Custom Nodes" "$COMFYUI_DIR/custom_nodes" "$SYMLINK_CUSTOM_NODES"
else
    echo "ComfyUI Checkout: not modified (configured location: $COMFYUI_DIR)"
fi
if [ -n "$CONFIGURED_SHELLS" ]; then
    echo "Shell Config(s): $CONFIGURED_SHELLS"
fi
echo ""
echo "Available start methods for the configured checkout:"
EXPECTED_LAUNCHER_SCRIPT="${COMFYUI_PARENT_DIR}/start_${COMFYUI_ALIAS}.sh"
if [ -f "$EXPECTED_LAUNCHER_SCRIPT" ]; then
    echo "  Launcher: $EXPECTED_LAUNCHER_SCRIPT"
fi
if grep -q "alias ${COMFYUI_ALIAS}=" "$HOME/.bashrc" 2>/dev/null || \
   grep -q "alias ${COMFYUI_ALIAS}=" "$HOME/.zshrc" 2>/dev/null || \
   grep -q "function ${COMFYUI_ALIAS}" "$HOME/.config/fish/config.fish" 2>/dev/null; then
    echo "  Shell alias: ${COMFYUI_ALIAS} (reload the shell profile first)"
    echo "  Venv alias:  ${ENVACT_ALIAS}"
fi
if [ -x "$VENV_PATH/bin/python" ] && [ -f "$COMFYUI_DIR/main.py" ]; then
    echo "  Manual: source $VENV_PATH/bin/activate && cd $COMFYUI_DIR && python main.py $COMFYUI_LAUNCH_ARGS"
else
    echo "  No verified launcher for the configured checkout was found in this run."
fi
echo ""
offer_save_defaults
echo ""
echo "Press any key to exit..."
read -n 1 -s
