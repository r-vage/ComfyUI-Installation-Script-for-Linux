# ComfyUI Environment Installation Script for Windows (PowerShell)
# Installs packages in specific order to avoid dependency conflicts
#
# Usage: Run in PowerShell 5.1+ or PowerShell 7+
#   .\install_comfy_env.ps1
#
# Requirements:
#   - Windows 10/11 (AMD ROCm acceleration requires Windows 11)
#   - Git installed and in PATH
#   - Internet connection
#   - NVIDIA CUDA or a supported AMD ROCm GPU/APU (for GPU acceleration)
#
# Note: Run PowerShell as Administrator if you want to create directory symlinks.
#       Without admin, the script uses directory junctions (which work for most cases).

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ============================================
# Embedded Defaults
# ============================================
# Only this marked block is rewritten after a successful run.
# BEGIN COMFYUI INSTALLER DEFAULTS
$BASE_PATH = "D:\AI"
$PYTHON_VERSION = "3.12.10"
$PYTORCH_VERSION = "2.9.1"
$PYTORCH_WHEEL_VARIANT = "cu128"
$NUMPY_VERSION = "2.2.6"
$TRANSFORMERS_VERSION = "4.57.3"
$DEFAULT_COMFYUI_VERSION = "0.28.0"
$DEFAULT_FRONTEND_VERSION = "1.45.21"
$DEFAULT_ALIAS = "comfy"
$COMFYUI_LAUNCH_ARGS = "--disable-pinned-memory"
$SYMLINK_MODELS = $true
$SYMLINK_INPUT = $true
$SYMLINK_OUTPUT = $true
$SYMLINK_USER = $true
$SYMLINK_CUSTOM_NODES = $true
$INSTALL_NUNCHAKU = $false
$INSTALL_COMFYUI_FRONTEND = $true
$PIN_FRONTEND_VERSION_IN_ALIAS = $false
# END COMFYUI INSTALLER DEFAULTS

$NUNCHAKU_VERSION = "1.2.1"
$NUNCHAKU_SUPPORTED_PYTHON_TAGS = @("cp310", "cp311", "cp312", "cp313")
$FLASH_ATTN_VERSION = "2.8.3"
$SAGEATTENTION_VERSION = "2.2.0"
$SAGEATTENTION_FALLBACK_VERSION = "1.0.6"
$AMD_ROCM_VERSION = "7.2.1"
$AMD_ROCM_REQUIRED_DRIVER = "26.2.2"
$AMD_ROCM_REQUIRED_PYTHON = "3.12"
$AMD_ROCM_PYTORCH_VERSION = "2.9.1"
$AMD_ROCM_TORCHVISION_VERSION = "0.24.1"
$AMD_ROCM_TORCHAUDIO_VERSION = "2.9.1"
$AMD_ROCM_BASE_URL = "https://repo.radeon.com/rocm/windows/rocm-rel-$AMD_ROCM_VERSION"
$AMD_ROCM_SDK_PACKAGES = @(
    "$AMD_ROCM_BASE_URL/rocm_sdk_core-$AMD_ROCM_VERSION-py3-none-win_amd64.whl"
    "$AMD_ROCM_BASE_URL/rocm_sdk_devel-$AMD_ROCM_VERSION-py3-none-win_amd64.whl"
    "$AMD_ROCM_BASE_URL/rocm_sdk_libraries_custom-$AMD_ROCM_VERSION-py3-none-win_amd64.whl"
    "$AMD_ROCM_BASE_URL/rocm-$AMD_ROCM_VERSION.tar.gz"
)

$InstallerScriptPath = $PSCommandPath

$Embedded = @{
    BasePath = $BASE_PATH
    Python = $PYTHON_VERSION
    Torch = $PYTORCH_VERSION
    Variant = $PYTORCH_WHEEL_VARIANT
    Numpy = $NUMPY_VERSION
    Transformers = $TRANSFORMERS_VERSION
    Comfy = $DEFAULT_COMFYUI_VERSION
    Frontend = $DEFAULT_FRONTEND_VERSION
    Alias = $DEFAULT_ALIAS
    Args = $COMFYUI_LAUNCH_ARGS
    Models = $SYMLINK_MODELS
    Input = $SYMLINK_INPUT
    Output = $SYMLINK_OUTPUT
    User = $SYMLINK_USER
    Nodes = $SYMLINK_CUSTOM_NODES
    Nunchaku = $INSTALL_NUNCHAKU
    ManageFrontend = $INSTALL_COMFYUI_FRONTEND
    PinFrontend = $PIN_FRONTEND_VERSION_IN_ALIAS
}

$Manage = @{
    BasePath = $true
    Python = $true
    Torch = $true
    Numpy = $true
    Transformers = $true
    Comfy = $true
    Nunchaku = $true
    Frontend = $true
    Launcher = $true
    Models = $true
    Input = $true
    Output = $true
    User = $true
    Nodes = $true
}
$CONFIG_MODE = "easy"
$HARDWARE_BACKEND = ""

$PYTORCH_COMPATIBILITY = @{
    "2.13.0" = @{ TorchVision = "0.28.0"; TorchAudio = "2.11.0"; Variants = @("cu126", "cu130", "cpu") }
    "2.12.1" = @{ TorchVision = "0.27.1"; TorchAudio = "2.11.0"; Variants = @("cu126", "cu130", "cpu") }
    "2.12.0" = @{ TorchVision = "0.27.0"; TorchAudio = "2.11.0"; Variants = @("cu126", "cu130", "cpu") }
    "2.11.0" = @{ TorchVision = "0.26.0"; TorchAudio = "2.11.0"; Variants = @("cu126", "cu128", "cu130", "cpu") }
    "2.10.0" = @{ TorchVision = "0.25.0"; TorchAudio = "2.10.0"; Variants = @("cu126", "cu128", "cu130", "cpu") }
    "2.9.1" = @{ TorchVision = "0.24.1"; TorchAudio = "2.9.1"; Variants = @("cu126", "cu128", "cu130", "rocm7.2.1", "cpu") }
    "2.9.0" = @{ TorchVision = "0.24.0"; TorchAudio = "2.9.0"; Variants = @("cu126", "cu128", "cu130", "cpu") }
    "2.8.0" = @{ TorchVision = "0.23.0"; TorchAudio = "2.8.0"; Variants = @("cu126", "cu128", "cpu") }
    "2.7.1" = @{ TorchVision = "0.22.1"; TorchAudio = "2.7.1"; Variants = @("cu126", "cu128", "cpu") }
    "2.7.0" = @{ TorchVision = "0.22.0"; TorchAudio = "2.7.0"; Variants = @("cu126", "cu128", "cpu") }
    "2.6.0" = @{ TorchVision = "0.21.0"; TorchAudio = "2.6.0"; Variants = @("cu126", "cpu") }
}

function Normalize-PyTorchVersion {
    param([string]$Version)
    $patches = @{
        "2.13" = "2.13.0"; "2.12" = "2.12.1"; "2.11" = "2.11.0"
        "2.10" = "2.10.0"; "2.9" = "2.9.1"; "2.8" = "2.8.0"
        "2.7" = "2.7.1"; "2.6" = "2.6.0"
    }
    if ($patches.ContainsKey($Version)) { return $patches[$Version] }
    return $Version
}

function Resolve-PyTorchStack {
    $script:PYTORCH_VERSION = Normalize-PyTorchVersion $PYTORCH_VERSION
    if (-not $PYTORCH_COMPATIBILITY.ContainsKey($PYTORCH_VERSION)) {
        throw "Unsupported PyTorch version: $PYTORCH_VERSION"
    }
    $stack = $PYTORCH_COMPATIBILITY[$PYTORCH_VERSION]
    if ($stack.Variants -notcontains $PYTORCH_WHEEL_VARIANT) {
        throw "PyTorch $PYTORCH_VERSION is not available for $PYTORCH_WHEEL_VARIANT on Windows. Supported variants: $($stack.Variants -join ', ')"
    }
    $script:PYTORCH_MAJOR_MINOR = ($PYTORCH_VERSION -split '\.')[0..1] -join '.'
    $script:TORCHVISION_VERSION = $stack.TorchVision
    $script:TORCHAUDIO_VERSION = $stack.TorchAudio
    $script:PYTORCH_FULL_VERSION = "$PYTORCH_VERSION+$PYTORCH_WHEEL_VARIANT"
    $script:TORCHVISION_FULL_VERSION = "$TORCHVISION_VERSION+$PYTORCH_WHEEL_VARIANT"
    $script:TORCHAUDIO_FULL_VERSION = "$TORCHAUDIO_VERSION+$PYTORCH_WHEEL_VARIANT"
    if ($PYTORCH_WHEEL_VARIANT -eq "rocm$AMD_ROCM_VERSION") {
        if ($PYTORCH_VERSION -ne $AMD_ROCM_PYTORCH_VERSION -or
            $TORCHVISION_VERSION -ne $AMD_ROCM_TORCHVISION_VERSION -or
            $TORCHAUDIO_VERSION -ne $AMD_ROCM_TORCHAUDIO_VERSION) {
            throw "Windows ROCm $AMD_ROCM_VERSION requires torch $AMD_ROCM_PYTORCH_VERSION, torchvision $AMD_ROCM_TORCHVISION_VERSION, and torchaudio $AMD_ROCM_TORCHAUDIO_VERSION."
        }
        $script:PYTORCH_INDEX_URL = $AMD_ROCM_BASE_URL
        $script:HARDWARE_BACKEND = "rocm"
        $script:AMD_ROCM_TORCH_PACKAGES = @(
            "$AMD_ROCM_BASE_URL/torch-$PYTORCH_FULL_VERSION-cp312-cp312-win_amd64.whl"
            "$AMD_ROCM_BASE_URL/torchaudio-$TORCHAUDIO_FULL_VERSION-cp312-cp312-win_amd64.whl"
            "$AMD_ROCM_BASE_URL/torchvision-$TORCHVISION_FULL_VERSION-cp312-cp312-win_amd64.whl"
        )
    }
    else {
        $script:PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/$PYTORCH_WHEEL_VARIANT"
        $script:HARDWARE_BACKEND = if ($PYTORCH_WHEEL_VARIANT -eq "cpu") { "cpu" } else { "nvidia" }
        $script:AMD_ROCM_TORCH_PACKAGES = @()
    }

    switch ($PYTORCH_WHEEL_VARIANT) {
        "cu128" {
            $script:NUNCHAKU_CUDA_VARIANT = "cu12.8"
            $script:NUNCHAKU_SUPPORTED_TORCH_VERSIONS = @("2.8", "2.9", "2.10", "2.11")
        }
        "cu130" {
            $script:NUNCHAKU_CUDA_VARIANT = "cu13.0"
            $script:NUNCHAKU_SUPPORTED_TORCH_VERSIONS = @("2.9", "2.10", "2.11")
        }
        default {
            $script:NUNCHAKU_CUDA_VARIANT = ""
            $script:NUNCHAKU_SUPPORTED_TORCH_VERSIONS = @()
        }
    }
}

Resolve-PyTorchStack

# ============================================
# Derived Paths (auto-generated from BASE_PATH)
# ============================================
# By default these are all relative to BASE_PATH. To place any of them
# on a different drive or location, simply override the variable below.
#
# Example: models on a separate drive
#   $USER_MODELS_PATH = "E:\models"
#
# Example: output on a different partition
#   $USER_OUTPUT_PATH = "C:\Users\$env:USERNAME\comfyui_output"
#
# Example: input on a different partition
#   $USER_INPUT_PATH = "C:\Users\$env:USERNAME\comfyui_input"
#
# Example: shared user folder (settings, workflows, templates) on another partition
#   $USER_USERDATA_PATH = "C:\Users\$env:USERNAME\comfyui_user"
#
# Example: shared custom_nodes across installs on another disk
#   $USER_CUSTOM_NODES_PATH = "E:\shared_custom_nodes"
#
# The script will create the directories if they don't exist and create
# junctions into the ComfyUI tree when their corresponding $SYMLINK_* setting is $true.
# ============================================
$VENV_PATH = "$BASE_PATH\comfy_env"           # Virtual environment location
$COMFYUI_PARENT_DIR = $BASE_PATH              # Parent directory where ComfyUI will be cloned
$USER_MODELS_PATH = "$BASE_PATH\models"       # Centralized models directory
$USER_INPUT_PATH = "$BASE_PATH\input"         # Centralized input directory (shared across ComfyUI installations)
$USER_OUTPUT_PATH = "$BASE_PATH\output"       # Centralized output directory
$USER_USERDATA_PATH = "$BASE_PATH\user"       # Centralized user directory (settings, workflows, templates) — shared across ComfyUI installations
$USER_CUSTOM_NODES_PATH = "$BASE_PATH\custom_nodes"  # Centralized custom_nodes directory

# ============================================
# Helper Functions
# ============================================

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 67) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 67) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[!!] $Text" -ForegroundColor Yellow
}

function Write-Step {
    param([string]$Text)
    Write-Host " ->  $Text" -ForegroundColor White
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-ComfyAliasNameExists {
    param([string]$Candidate)

    if ((Test-Path (Join-Path $BASE_PATH "$Candidate.bat")) -or
        (Test-Path (Join-Path $BASE_PATH "$Candidate.ps1"))) {
        return $true
    }

    $escapedCandidate = [regex]::Escape($Candidate)
    $profilePaths = @($PROFILE.CurrentUserAllHosts, $PROFILE) | Where-Object { $_ } | Select-Object -Unique
    foreach ($profilePath in $profilePaths) {
        if (Test-Path $profilePath) {
            $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($profileContent -match "(?m)^\s*function\s+$escapedCandidate(?:\s|\{)") {
                return $true
            }
        }
    }

    return $false
}

function Get-NextComfyAliasName {
    $candidate = $DEFAULT_ALIAS
    $suffix = 1

    while (Test-ComfyAliasNameExists -Candidate $candidate) {
        $candidate = "$DEFAULT_ALIAS$suffix"
        $suffix++
    }

    return $candidate
}

function Invoke-SafeCommand {
    # Run a command and return $true/$false instead of throwing on failure
    param(
        [string]$Description,
        [scriptblock]$Command,
        [switch]$Optional
    )
    Write-Step $Description
    try {
        & $Command
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            if ($Optional) {
                Write-Warn "$Description failed (optional, continuing)"
                return $false
            }
            throw "Command exited with code $LASTEXITCODE"
        }
        return $true
    }

    catch {
        if ($Optional) {
            Write-Warn "$Description failed: $($_.Exception.Message) (optional, continuing)"
            return $false
        }
        throw
    }
}

function Test-DistributionInstalled {
    param([string]$Distribution)
    python -c "import importlib.metadata,sys; importlib.metadata.version(sys.argv[1])" $Distribution 2>$null
    return $LASTEXITCODE -eq 0
}

function Remove-FlashAttention {
    if (Test-DistributionInstalled "flash-attn") {
        Write-Step "Removing incompatible Flash Attention installation..."
        uv pip uninstall flash-attn 2>$null | Out-Null
    }
}

function Test-PythonImport {
    param([string]$ImportStatement)
    python -c $ImportStatement 2>$null
    return $LASTEXITCODE -eq 0
}

function Test-AmdRocmTorch {
    $probe = @'
import torch
if not torch.version.hip:
    raise RuntimeError("The installed PyTorch build does not report a HIP runtime")
if not torch.cuda.is_available():
    raise RuntimeError("PyTorch ROCm cannot access a supported AMD GPU")
torch.empty(1, device="cuda")
torch.cuda.synchronize()
'@
    python -c $probe 2>$null
    return $LASTEXITCODE -eq 0
}

function Test-SageAttention {
    $probe = @'
import importlib.metadata
import sageattention
version = importlib.metadata.version("sageattention")
if version.startswith("2."):
    import torch
    from sageattention import sageattn
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable for the SageAttention 2 smoke test")
    query = torch.randn((1, 4, 128, 64), device="cuda", dtype=torch.float16)
    sageattn(query, query, query, tensor_layout="HND")
    torch.cuda.synchronize()
'@
    python -c $probe 2>$null
    return $LASTEXITCODE -eq 0
}

function Install-SageAttention {
    param([string]$ConstraintFile)

    $cudaHome = (python -c "from torch.utils.cpp_extension import CUDA_HOME; print(CUDA_HOME or )" 2>$null | Select-Object -First 1)
    $torchCuda = (python -c "import torch; print(torch.version.cuda or )" 2>$null | Select-Object -First 1)
    $gpuArch = (python -c "import torch; print(..join(map(str, torch.cuda.get_device_capability()))) if torch.cuda.is_available() else print()" 2>$null | Select-Object -First 1)
    $nvccPath = if ($cudaHome) { Join-Path $cudaHome "bin\nvcc.exe" } else { $null }
    $buildReady = $true

    if (-not $nvccPath -or -not (Test-Path $nvccPath)) {
        Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: nvcc was not found in CUDA_HOME."
        $buildReady = $false
    }
    else {
        $nvccText = (& $nvccPath --version 2>$null) -join "`n"
        $nvccCuda = if ($nvccText -match "release\s+(\d+\.\d+)") { $Matches[1] } else { "" }
        if ($nvccCuda -ne $torchCuda) {
            Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: CUDA toolkit $nvccCuda does not match Torch CUDA $torchCuda."
            $buildReady = $false
        }
    }
    if (@("8.0", "8.6", "8.9", "9.0", "10.0", "12.0", "12.1") -notcontains $gpuArch) {
        Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: unsupported or unavailable GPU architecture $gpuArch."
        $buildReady = $false
    }
    if (-not (Test-CommandExists "cl") -or -not (Test-CommandExists "ninja")) {
        Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: Visual C++ and ninja are required."
        $buildReady = $false
    }
    try {
        $tempDrive = New-Object System.IO.DriveInfo((Get-Item $env:TEMP).PSDrive.Name)
        if ($tempDrive.AvailableFreeSpace -lt 10GB) {
            Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: at least 10 GiB of temporary disk space is required."
            $buildReady = $false
        }
    }
    catch {
        Write-Warn "SageAttention build disk-space preflight failed."
        $buildReady = $false
    }
    try {
        $availableMemory = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).FreePhysicalMemory * 1KB
        if ($availableMemory -lt 16GB) {
            Write-Warn "SageAttention $SAGEATTENTION_VERSION build skipped: at least 16 GiB of available memory is required."
            $buildReady = $false
        }
    }
    catch {
        Write-Warn "SageAttention build memory preflight failed."
        $buildReady = $false
    }

    if ($buildReady) {
        Write-Step "Building SageAttention $SAGEATTENTION_VERSION from the official PyPI source distribution..."
        uv pip uninstall sageattention 2>$null | Out-Null
        $oldMaxJobs = $env:MAX_JOBS
        $oldNvccFlags = $env:NVCC_APPEND_FLAGS
        try {
            $env:MAX_JOBS = "4"
            $env:NVCC_APPEND_FLAGS = "--threads 4"
            uv pip install --constraint $ConstraintFile --reinstall "sageattention==$SAGEATTENTION_VERSION" --no-binary sageattention --no-build-isolation
            if ($LASTEXITCODE -eq 0 -and (Test-SageAttention)) {
                Write-Success "SageAttention $SAGEATTENTION_VERSION built and passed its CUDA smoke test"
                return
            }
        }
        finally {
            $env:MAX_JOBS = $oldMaxJobs
            $env:NVCC_APPEND_FLAGS = $oldNvccFlags
        }
        Write-Warn "SageAttention $SAGEATTENTION_VERSION build or smoke test failed; using the Triton fallback."
        uv pip uninstall sageattention 2>$null | Out-Null
    }

    uv pip install --constraint $ConstraintFile --reinstall "sageattention==$SAGEATTENTION_FALLBACK_VERSION"
    if ($LASTEXITCODE -eq 0 -and (Test-SageAttention)) {
        Write-Success "SageAttention $SAGEATTENTION_FALLBACK_VERSION installed and import-verified"
    }
    else {
        Write-Warn "SageAttention could not be installed or verified (optional)"
    }
}

function Install-UvRequirements {
    param(
        [string]$RequirementsFile,
        [string]$ConstraintFile
    )

    $filteredRequirements = [System.IO.Path]::GetTempFileName()
    try {
        $filteredLines = @(Get-Content $RequirementsFile | Where-Object {
            $line = $_
            if ((-not $Manage.Frontend -or -not $INSTALL_COMFYUI_FRONTEND) -and
                $line -match '^\s*comfyui[-_.]frontend[-_.]package(?:[^A-Za-z0-9_-].*)?$') { return $false }
            if (-not $Manage.Torch -and
                $line -match '^\s*(torch|torchvision|torchaudio)(?:[^A-Za-z0-9_-].*)?$') { return $false }
            if (-not $Manage.Numpy -and $line -match '^\s*numpy(?:[^A-Za-z0-9_-].*)?$') { return $false }
            if (-not $Manage.Transformers -and $line -match '^\s*transformers(?:[^A-Za-z0-9_-].*)?$') { return $false }
            return $true
        })
        [System.IO.File]::WriteAllLines($filteredRequirements, [string[]]$filteredLines)

        if ([string]::IsNullOrWhiteSpace($ConstraintFile)) {
            uv pip install -r $filteredRequirements
        } else {
            uv pip install --constraint $ConstraintFile -r $filteredRequirements
        }
    }
    finally {
        Remove-Item $filteredRequirements -Force -ErrorAction SilentlyContinue
    }
}

function New-DirectoryJunction {
    # Create a directory junction after the caller has safely cleared the link path.
    param(
        [string]$Link,
        [string]$Target
    )

    if (Test-Path $Link) {
        throw "Cannot create junction because the path still exists: $Link"
    }

    # Use cmd /c mklink /J for junctions (no admin required)
    cmd /c mklink /J "`"$Link`"" "`"$Target`"" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create junction: $Link -> $Target"
    }
    Write-Success "Created junction: $Link -> $Target"
}

function Test-DirectoryContainsOnlyPristineRepoContent {
    param(
        [string]$DirectoryPath,
        [string]$RepoPath
    )

    & git -C $RepoPath rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $repoPrefix = $RepoPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $entries = @(Get-ChildItem $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
        -not $_.PSIsContainer -or ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    })

    foreach ($entry in $entries) {
        if (-not $entry.FullName.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }

        $repoRelativePath = $entry.FullName.Substring($repoPrefix.Length).Replace('\', '/')
        & git -C $RepoPath ls-files --error-unmatch -- $repoRelativePath 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        & git -C $RepoPath diff --quiet HEAD -- $repoRelativePath
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }

    return $true
}

function Copy-MissingDirectoryContent {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    foreach ($sourceItem in @(Get-ChildItem -LiteralPath $SourcePath -Force -ErrorAction Stop)) {
        $destinationItemPath = Join-Path $DestinationPath $sourceItem.Name

        if ($sourceItem.PSIsContainer -and -not ($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            if (-not (Test-Path -LiteralPath $destinationItemPath)) {
                New-Item -ItemType Directory -Path $destinationItemPath -Force -ErrorAction Stop | Out-Null
            }

            $destinationItem = Get-Item -LiteralPath $destinationItemPath -Force -ErrorAction Stop
            if ($destinationItem.PSIsContainer -and -not ($destinationItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Copy-MissingDirectoryContent -SourcePath $sourceItem.FullName -DestinationPath $destinationItemPath
            }
        }
        elseif (-not (Test-Path -LiteralPath $destinationItemPath)) {
            Copy-Item -LiteralPath $sourceItem.FullName -Destination $destinationItemPath -Recurse -Force -ErrorAction Stop
        }
    }
}

function Set-ComfyDirectorySharing {
    param(
        [string]$Name,
        [string]$LocalPath,
        [string]$SharedPath,
        [bool]$Enabled,
        [bool]$NewInstall = $false
    )

    if (-not $Enabled) {
        if (Test-Path $LocalPath) {
            $item = Get-Item $LocalPath -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Warn "$Name sharing is disabled, but the existing junction is preserved: $LocalPath -> $($item.Target)"
                Write-Host "   Remove the junction manually if you want this installation to use a local directory."
            }
            elseif ($item.PSIsContainer) {
                Write-Success "$Name uses local directory $LocalPath"
            }
            else {
                Write-Warn "$Name cannot use a local directory because a non-directory path exists at $LocalPath"
            }
        }
        else {
            New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
            Write-Success "$Name created local directory $LocalPath"
        }
        return
    }

    if (-not (Test-Path $SharedPath)) {
        New-Item -ItemType Directory -Path $SharedPath -Force | Out-Null
    }

    if (Test-Path $LocalPath) {
        $item = Get-Item $LocalPath -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $currentTarget = $item.Target
            if ($currentTarget -eq $SharedPath) {
                Write-Success "$Name is already shared at $SharedPath"
            }
            else {
                Write-Warn "$Name junction points to $currentTarget; relinking to $SharedPath"
                [System.IO.Directory]::Delete($LocalPath)
                New-DirectoryJunction -Link $LocalPath -Target $SharedPath
            }
            return
        }

        if (-not $item.PSIsContainer) {
            Write-Warn "$Name cannot be shared because a non-directory path exists at $LocalPath"
            return
        }

        $localItems = @(Get-ChildItem $LocalPath -Force -ErrorAction SilentlyContinue)
        $sharedItems = @(Get-ChildItem $SharedPath -Force -ErrorAction SilentlyContinue)
        if ($localItems.Count -eq 0) {
            [System.IO.Directory]::Delete($LocalPath)
        }
        elseif ($NewInstall -or (Test-DirectoryContainsOnlyPristineRepoContent -DirectoryPath $LocalPath -RepoPath $COMFYUI_DIR)) {
            Write-Step "$Name moving checkout files that are missing from $SharedPath"
            try {
                Copy-MissingDirectoryContent -SourcePath $LocalPath -DestinationPath $SharedPath
                Remove-Item $LocalPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warn "$Name merge failed; preserving the local directory and skipping the junction"
                return
            }
        }
        elseif ($sharedItems.Count -eq 0) {
            Write-Step "$Name copying existing local data to $SharedPath"
            try {
                Copy-Item (Join-Path $LocalPath "*") $SharedPath -Recurse -Force -ErrorAction Stop
                Remove-Item $LocalPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warn "$Name copy failed; preserving the local directory and skipping the junction"
                return
            }
        }
        else {
            Write-Warn "$Name local and shared directories both contain data; preserving both and skipping the junction"
            Write-Host "   Merge them manually, then rerun the installer."
            return
        }
    }

    New-DirectoryJunction -Link $LocalPath -Target $SharedPath
}

function Write-ComfyDirectoryState {
    param(
        [string]$Name,
        [string]$Path,
        [bool]$Enabled
    )

    if (Test-Path $Path) {
        $item = Get-Item $Path -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            if ($Enabled) {
                Write-Host "  ${Name}: Shared ($($item.Target))"
            } else {
                Write-Host "  ${Name}: Existing junction preserved ($($item.Target))"
            }
            return
        }
    }
    Write-Host "  ${Name}: Local ($Path)"
}

function Copy-IfMissing {
    param([string]$RepoUrl)
    $repoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl)
    if ($RepoUrl.EndsWith(".git")) {
        $repoName = [System.IO.Path]::GetFileNameWithoutExtension($RepoUrl.Substring(0, $RepoUrl.Length - 4))
    }

    $repoPath = Join-Path $CUSTOM_NODES_DIR $repoName
    $disabledRoot = Join-Path $CUSTOM_NODES_DIR ".disabled"
    $disabledMatch = if (Test-Path $disabledRoot) {
        Get-ChildItem -LiteralPath $disabledRoot -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq $repoName } | Select-Object -First 1
    } else { $null }
    $legacyDisabledMatch = Get-ChildItem -LiteralPath $CUSTOM_NODES_DIR -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "$repoName.disabled" } | Select-Object -First 1

    if (Test-Path (Join-Path $repoPath ".git")) {
        Write-Success "$repoName already exists"
    }
    elseif (Test-Path $repoPath) {
        Write-Warn "$repoName already exists but is not a Git checkout; preserving it as unmanaged"
    }
    elseif ($disabledMatch) {
        Write-Host " [--] $repoName is disabled by ComfyUI-Manager; leaving $($disabledMatch.FullName) untouched"
    }
    elseif ($legacyDisabledMatch) {
        Write-Host " [--] $repoName has a legacy .disabled directory; leaving $($legacyDisabledMatch.FullName) untouched"
    }
    else {
        Write-Step "Cloning $repoName..."
        git clone $RepoUrl $repoPath
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to clone $repoName"
        }
    }
}

# ============================================
# ============================================
# Interactive Prompts
# ============================================
function Normalize-RocmVariant {
    param([string]$Value)
    $normalized = $Value.ToLowerInvariant().Replace("rocm", "").Replace(".", "")
    switch ($normalized) {
        "72" { return "rocm7.2.1" }
        "721" { return "rocm7.2.1" }
        default { return $null }
    }
}

function Assert-AmdRocmWindowsCompatibility {
    if ($HARDWARE_BACKEND -ne "rocm") { return }

    $configuredPython = ($PYTHON_VERSION -split '\.')[0..1] -join '.'
    if ($configuredPython -ne $AMD_ROCM_REQUIRED_PYTHON) {
        throw "Windows ROCm $AMD_ROCM_VERSION requires Python $AMD_ROCM_REQUIRED_PYTHON; configured Python is $PYTHON_VERSION."
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "Windows ROCm $AMD_ROCM_VERSION requires 64-bit Windows 11."
    }

    try {
        $osBuild = [int](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).BuildNumber
    }
    catch {
        $osBuild = [Environment]::OSVersion.Version.Build
        Write-Warn "Could not query the Windows build through CIM; using environment build $osBuild."
    }
    if ($osBuild -lt 22000) {
        throw "Windows ROCm $AMD_ROCM_VERSION requires Windows 11 build 22000 or newer; detected build $osBuild."
    }

    $adapterNames = @()
    try {
        $adapterNames = @(Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -match '(?i)AMD|Radeon' } |
            ForEach-Object { $_.Name })
    }
    catch {
        Write-Warn "Could not inspect display adapters before installing ROCm."
    }
    if ($adapterNames.Count -eq 0) {
        Write-Warn "No AMD display adapter was detected. The install will stop if the ROCm runtime probe cannot access a supported GPU."
    }
    else {
        Write-Host "  Detected AMD adapter(s): $($adapterNames -join ', ')"
    }

    Write-Warn "Windows ROCm $AMD_ROCM_VERSION requires AMD Software: PyTorch on Windows Edition driver $AMD_ROCM_REQUIRED_DRIVER and hardware listed in AMD's support matrix."
    if ($COMFYUI_LAUNCH_ARGS -notmatch '(?:^|\s)--disable-pinned-memory(?:\s|$)') {
        Write-Warn "AMD recommends adding --disable-pinned-memory to ComfyUI launch arguments; --lowvram can also help on lower-memory systems."
    }
}

function Install-ManagedPyTorchStack {
    if ($HARDWARE_BACKEND -eq "rocm") {
        $activePython = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" | Select-Object -First 1
        if ($activePython) { $activePython = $activePython.Trim() }
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($activePython)) {
            throw "Could not inspect the active Python version before installing AMD ROCm."
        }
        if ($activePython -ne $AMD_ROCM_REQUIRED_PYTHON) {
            throw "The active environment uses Python $activePython; Windows ROCm $AMD_ROCM_VERSION wheels require Python $AMD_ROCM_REQUIRED_PYTHON."
        }

        Write-Step "Installing the official AMD ROCm $AMD_ROCM_VERSION SDK packages..."
        uv pip install @AMD_ROCM_SDK_PACKAGES
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install the official AMD ROCm $AMD_ROCM_VERSION SDK packages."
        }

        Write-Step "Installing the official AMD PyTorch $PYTORCH_FULL_VERSION packages..."
        uv pip install @AMD_ROCM_TORCH_PACKAGES
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install the official AMD PyTorch on Windows packages."
        }
    }
    else {
        uv pip install "torch==$PYTORCH_FULL_VERSION" "torchvision==$TORCHVISION_FULL_VERSION" "torchaudio==$TORCHAUDIO_FULL_VERSION" --index-url $PYTORCH_INDEX_URL
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install the managed PyTorch stack."
        }
    }
}

function Read-Default {
    param([string]$Label, [string]$Default)
    $answer = Read-Host "  $Label [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Read-Policy {
    param([string]$Label, [bool]$Default)
    $shownDefault = if ($Default) { "y" } else { "n" }
    while ($true) {
        $answer = Read-Default $Label $shownDefault
        switch -Regex ($answer.ToLowerInvariant()) {
            '^(y|yes|true)$' { return "true" }
            '^(n|no|false)$' { return "false" }
            '^-$' { return "preserve" }
            default { Write-Warn "Enter y, n, or - to preserve the installed state." }
        }
    }
}

function Normalize-CudaVariant {
    param([string]$Value)
    $normalized = $Value.ToLowerInvariant().Replace("cuda", "").Replace("cu", "").Replace(".", "")
    switch ($normalized) {
        "12" { return "cu128" }
        "13" { return "cu130" }
        "126" { return "cu126" }
        "128" { return "cu128" }
        "130" { return "cu130" }
        default { return $null }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ComfyUI Environment Setup (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration mode:"
Write-Host "  [E]asy (default) - ComfyUI, frontend, and launcher"
Write-Host "  [A]dvanced       - complete configuration questionnaire"
Write-Host "  [S]kip questions - use embedded defaults and select steps"
while ($true) {
    $modeAnswer = Read-Default "Mode" "E"
    switch -Regex ($modeAnswer) {
        '^(e|easy)$' { $CONFIG_MODE = "easy"; break }
        '^(a|advanced)$' { $CONFIG_MODE = "advanced"; break }
        '^(s|skip)$' { $CONFIG_MODE = "skip"; break }
        default { Write-Warn "Enter E, A, or S."; continue }
    }
    break
}
Write-Host ""

$INPUT_COMFYUI_VERSION = $DEFAULT_COMFYUI_VERSION
$INPUT_FRONTEND_VERSION = $DEFAULT_FRONTEND_VERSION
$INPUT_ALIAS = $DEFAULT_ALIAS

if ($CONFIG_MODE -eq "easy") {
    Write-Host "Easy configuration (Enter accepts the default; - preserves a setting):"
    $INPUT_COMFYUI_VERSION = Read-Default "ComfyUI version" $DEFAULT_COMFYUI_VERSION
    if ($INPUT_COMFYUI_VERSION -eq "-") {
        $Manage.Comfy = $false
        $INPUT_COMFYUI_VERSION = $DEFAULT_COMFYUI_VERSION
    }

    if ($INSTALL_COMFYUI_FRONTEND) {
        $INPUT_FRONTEND_VERSION = Read-Default "Frontend version" $DEFAULT_FRONTEND_VERSION
        if ($INPUT_FRONTEND_VERSION -eq "-") {
            $Manage.Frontend = $false
            $INPUT_FRONTEND_VERSION = $DEFAULT_FRONTEND_VERSION
        }
    }

    $SUGGESTED_ALIAS = Get-NextComfyAliasName
    $INPUT_ALIAS = Read-Default "Launcher name" $SUGGESTED_ALIAS
    if ($INPUT_ALIAS -eq "-") {
        $Manage.Launcher = $false
        $INPUT_ALIAS = $DEFAULT_ALIAS
    }
}
elseif ($CONFIG_MODE -eq "advanced") {
    Write-Host "Advanced configuration (Enter accepts the default):"
    Write-Host "  Hint: enter - to skip/ignore management for a setting and keep its installed state."
    $answer = Read-Default "Base path" $BASE_PATH
    if ($answer -eq "-") { $Manage.BasePath = $false } else { $BASE_PATH = $answer }

    $answer = Read-Default "Python version" $PYTHON_VERSION
    if ($answer -eq "-") { $Manage.Python = $false } else { $PYTHON_VERSION = $answer }

    $answer = Read-Default "PyTorch version" $PYTORCH_VERSION
    if ($answer -eq "-") { $Manage.Torch = $false } else { $PYTORCH_VERSION = $answer }

    $backendDefault = if ($PYTORCH_WHEEL_VARIANT.StartsWith("rocm")) { "amd" } elseif ($PYTORCH_WHEEL_VARIANT -eq "cpu") { "cpu" } else { "nvidia" }
    $backendAccepted = $false
    while (-not $backendAccepted) {
        $backend = (Read-Default "Hardware backend (NVIDIA/AMD/CPU)" $backendDefault).ToLowerInvariant()
        switch -Regex ($backend) {
            '^-$' {
                $Manage.Torch = $false
                $backendAccepted = $true
            }
            '^(n|nvidia)$' {
                $cudaDefault = if ($PYTORCH_WHEEL_VARIANT.StartsWith("cu")) { $PYTORCH_WHEEL_VARIANT } else { "cu128" }
                $cuda = Read-Default "CUDA version" $cudaDefault
                if ($cuda -eq "-") {
                    $Manage.Torch = $false
                    $backendAccepted = $true
                }
                else {
                    $variant = Normalize-CudaVariant $cuda
                    if (-not $variant) {
                        Write-Warn "Unsupported CUDA alias: $cuda. Use 12.6, 12.8, 13, or cu130."
                    }
                    else {
                        $PYTORCH_WHEEL_VARIANT = $variant
                        $backendAccepted = $true
                    }
                }
            }
            '^(c|cpu)$' {
                $PYTORCH_WHEEL_VARIANT = "cpu"
                $backendAccepted = $true
            }
            '^(a|amd|rocm|amd/rocm)$' {
                $rocmDefault = if ($PYTORCH_WHEEL_VARIANT.StartsWith("rocm")) { $PYTORCH_WHEEL_VARIANT } else { "rocm$AMD_ROCM_VERSION" }
                $rocm = Read-Default "ROCm version" $rocmDefault
                if ($rocm -eq "-") {
                    $Manage.Torch = $false
                    $backendAccepted = $true
                }
                else {
                    $variant = Normalize-RocmVariant $rocm
                    if (-not $variant) {
                        Write-Warn "Unsupported Windows ROCm alias: $rocm. Configured support: ROCm $AMD_ROCM_VERSION."
                    }
                    else {
                        $PYTORCH_WHEEL_VARIANT = $variant
                        $backendAccepted = $true
                    }
                }
            }
            default { Write-Warn "Enter NVIDIA, AMD, CPU, or -." }
        }
    }

    $answer = Read-Default "NumPy version" $NUMPY_VERSION
    if ($answer -eq "-") { $Manage.Numpy = $false } else { $NUMPY_VERSION = $answer }
    $answer = Read-Default "Transformers version" $TRANSFORMERS_VERSION
    if ($answer -eq "-") { $Manage.Transformers = $false } else { $TRANSFORMERS_VERSION = $answer }

    $INPUT_COMFYUI_VERSION = Read-Default "ComfyUI version" $DEFAULT_COMFYUI_VERSION
    if ($INPUT_COMFYUI_VERSION -eq "-") {
        $Manage.Comfy = $false
        $INPUT_COMFYUI_VERSION = $DEFAULT_COMFYUI_VERSION
    }

    switch (Read-Policy "Install Nunchaku library" $INSTALL_NUNCHAKU) {
        "true" { $INSTALL_NUNCHAKU = $true }
        "false" { $INSTALL_NUNCHAKU = $false }
        "preserve" { $Manage.Nunchaku = $false }
    }

    switch (Read-Policy "Manage ComfyUI frontend package" $INSTALL_COMFYUI_FRONTEND) {
        "true" {
            $INSTALL_COMFYUI_FRONTEND = $true
            $INPUT_FRONTEND_VERSION = Read-Default "Frontend version" $DEFAULT_FRONTEND_VERSION
            if ($INPUT_FRONTEND_VERSION -eq "-") {
                $Manage.Frontend = $false
                $INPUT_FRONTEND_VERSION = $DEFAULT_FRONTEND_VERSION
            }
            switch (Read-Policy "Pin frontend in launchers" $PIN_FRONTEND_VERSION_IN_ALIAS) {
                "true" { $PIN_FRONTEND_VERSION_IN_ALIAS = $true }
                "false" { $PIN_FRONTEND_VERSION_IN_ALIAS = $false }
                "preserve" { $Manage.Launcher = $false }
            }
        }
        "false" { $INSTALL_COMFYUI_FRONTEND = $false }
        "preserve" { $Manage.Frontend = $false }
    }

    $SUGGESTED_ALIAS = Get-NextComfyAliasName
    $INPUT_ALIAS = Read-Default "Launcher name" $SUGGESTED_ALIAS
    if ($INPUT_ALIAS -eq "-") { $Manage.Launcher = $false; $INPUT_ALIAS = $DEFAULT_ALIAS }
    $answer = Read-Default "Launcher arguments" $COMFYUI_LAUNCH_ARGS
    if ($answer -eq "-") { $Manage.Launcher = $false } else { $COMFYUI_LAUNCH_ARGS = $answer }

    foreach ($item in @(
        @("Models", "Share models", $SYMLINK_MODELS),
        @("Input", "Share input", $SYMLINK_INPUT),
        @("Output", "Share output", $SYMLINK_OUTPUT),
        @("User", "Share user data", $SYMLINK_USER),
        @("Nodes", "Share custom nodes", $SYMLINK_CUSTOM_NODES)
    )) {
        $policy = Read-Policy $item[1] $item[2]
        if ($policy -eq "preserve") {
            $Manage[$item[0]] = $false
        }
        else {
            $value = $policy -eq "true"
            switch ($item[0]) {
                "Models" { $SYMLINK_MODELS = $value }
                "Input" { $SYMLINK_INPUT = $value }
                "Output" { $SYMLINK_OUTPUT = $value }
                "User" { $SYMLINK_USER = $value }
                "Nodes" { $SYMLINK_CUSTOM_NODES = $value }
            }
        }
    }
}
else {
    Write-Host "Skip mode: using embedded defaults without configuration questions."
}
Write-Host ""

if ($Manage.Torch) {
    Resolve-PyTorchStack
    Assert-AmdRocmWindowsCompatibility
    if ($PYTHON_VERSION -notmatch '^3\.(10|11|12|13|14)(\.|$)') {
        throw "Python $PYTHON_VERSION is outside the configured 3.10-3.14 range."
    }
    if ($PYTHON_VERSION -match '^3\.14' -and $PYTORCH_VERSION -match '^2\.(6|7)\.') {
        throw "PyTorch $PYTORCH_VERSION is not configured for Python 3.14."
    }
}
else {
    $HARDWARE_BACKEND = "preserve"
    $INSTALL_NUNCHAKU = $false
    $NUNCHAKU_CUDA_VARIANT = ""
    $NUNCHAKU_SUPPORTED_TORCH_VERSIONS = @()
}
if ($HARDWARE_BACKEND -ne "nvidia") { $INSTALL_NUNCHAKU = $false }

$VENV_PATH = "$BASE_PATH\comfy_env"
$COMFYUI_PARENT_DIR = $BASE_PATH
$USER_MODELS_PATH = "$BASE_PATH\models"
$USER_INPUT_PATH = "$BASE_PATH\input"
$USER_OUTPUT_PATH = "$BASE_PATH\output"
$USER_USERDATA_PATH = "$BASE_PATH\user"
$USER_CUSTOM_NODES_PATH = "$BASE_PATH\custom_nodes"

$COMFYUI_VERSION = "v$INPUT_COMFYUI_VERSION"
$COMFYUI_DIR_NAME = "ComfyUI_$INPUT_COMFYUI_VERSION"
$COMFYUI_FRONTEND_VERSION = $INPUT_FRONTEND_VERSION
$COMFYUI_ALIAS = $INPUT_ALIAS
$COMFYUI_WAS_CLONED = $false


# Prevent unmanaged packages from being changed by dependency resolution.
$PACKAGE_EXCLUDE_FILE = $null
$ORIGINAL_UV_EXCLUDE = [Environment]::GetEnvironmentVariable("UV_EXCLUDE", "Process")
$packageExcludes = @()
if (-not $Manage.Frontend -or -not $INSTALL_COMFYUI_FRONTEND) { $packageExcludes += "comfyui-frontend-package" }
if (-not $Manage.Torch) { $packageExcludes += @("torch", "torchvision", "torchaudio") }
if (-not $Manage.Numpy) { $packageExcludes += "numpy" }
if (-not $Manage.Transformers) { $packageExcludes += "transformers" }
if ($packageExcludes.Count -gt 0) {
    $PACKAGE_EXCLUDE_FILE = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllLines($PACKAGE_EXCLUDE_FILE, [string[]]$packageExcludes)
    if ([string]::IsNullOrWhiteSpace($ORIGINAL_UV_EXCLUDE)) {
        $env:UV_EXCLUDE = $PACKAGE_EXCLUDE_FILE
    } else {
        $env:UV_EXCLUDE = "$ORIGINAL_UV_EXCLUDE $PACKAGE_EXCLUDE_FILE"
    }
}
try {

# ============================================
# ============================================
# Configuration Summary
# ============================================
function Get-SharingSummary {
    param([bool]$Enabled, [bool]$Managed, [string]$Path)
    if (-not $Managed) { return "Preserve existing entry" }
    if ($Enabled) { return "Shared ($Path)" }
    return "Local"
}

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "Resolved configuration ($CONFIG_MODE):"
Write-Host "  ComfyUI Version: $(if ($Manage.Comfy) { $COMFYUI_VERSION } else { "Preserved (location uses $COMFYUI_DIR_NAME)" })"
Write-Host "  ComfyUI Frontend: $(if (-not $Manage.Frontend) { "Preserved" } elseif ($INSTALL_COMFYUI_FRONTEND) { $COMFYUI_FRONTEND_VERSION } else { "Unmanaged" })"
Write-Host "  Python Version: $(if ($Manage.Python) { $PYTHON_VERSION } else { "Preserved" })"
if ($Manage.Torch) {
    Write-Host "  Hardware Backend: $HARDWARE_BACKEND"
    Write-Host "  PyTorch Stack: torch $PYTORCH_FULL_VERSION, torchvision $TORCHVISION_FULL_VERSION, torchaudio $TORCHAUDIO_FULL_VERSION"
} else {
    Write-Host "  PyTorch Stack: Preserved (installed metadata is inspected only when required)"
}
Write-Host "  NumPy Version: $(if ($Manage.Numpy) { $NUMPY_VERSION } else { "Preserved" })"
Write-Host "  Transformers Version: $(if ($Manage.Transformers) { $TRANSFORMERS_VERSION } else { "Preserved" })"
Write-Host "  Nunchaku: $(if (-not $Manage.Nunchaku) { "Preserved" } elseif ($INSTALL_NUNCHAKU) { "Enabled ($NUNCHAKU_VERSION, $NUNCHAKU_CUDA_VARIANT)" } else { "Disabled/unavailable for $HARDWARE_BACKEND" })"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion.ToString())"
Write-Host ""
Write-Host "  Base Path: $BASE_PATH$(if (-not $Manage.BasePath) { " (not saved)" })"
Write-Host "  ComfyUI Location: $COMFYUI_PARENT_DIR\$COMFYUI_DIR_NAME"
Write-Host "  Virtual Env: $VENV_PATH"
Write-Host "  Launcher: $(if ($Manage.Launcher) { "$COMFYUI_ALIAS (batch + PowerShell)" } else { "Preserved" })"
Write-Host "  Launch Arguments: $(if ([string]::IsNullOrWhiteSpace($COMFYUI_LAUNCH_ARGS)) { "None" } else { $COMFYUI_LAUNCH_ARGS })"
Write-Host ""
Write-Host "  Directory Sharing:"
Write-Host "    Models:       $(Get-SharingSummary $SYMLINK_MODELS $Manage.Models $USER_MODELS_PATH)"
Write-Host "    Input:        $(Get-SharingSummary $SYMLINK_INPUT $Manage.Input $USER_INPUT_PATH)"
Write-Host "    Output:       $(Get-SharingSummary $SYMLINK_OUTPUT $Manage.Output $USER_OUTPUT_PATH)"
Write-Host "    User Data:    $(Get-SharingSummary $SYMLINK_USER $Manage.User $USER_USERDATA_PATH)"
Write-Host "    Custom Nodes: $(Get-SharingSummary $SYMLINK_CUSTOM_NODES $Manage.Nodes $USER_CUSTOM_NODES_PATH)"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$configuredPythonTag = "cp$(($PYTHON_VERSION -split '\.')[0..1] -join '')"
$NUNCHAKU_AVAILABLE = $true
$NUNCHAKU_UNAVAILABLE_REASON = ""
if (-not $Manage.Nunchaku) {
    $NUNCHAKU_AVAILABLE = $false
    $NUNCHAKU_UNAVAILABLE_REASON = "installed Nunchaku state is preserved"
}
elseif (-not $INSTALL_NUNCHAKU) {
    $NUNCHAKU_AVAILABLE = $false
    $NUNCHAKU_UNAVAILABLE_REASON = "Nunchaku is disabled or the selected backend is not NVIDIA"
}
elseif (-not $NUNCHAKU_CUDA_VARIANT) {
    $NUNCHAKU_AVAILABLE = $false
    $NUNCHAKU_UNAVAILABLE_REASON = "no official $NUNCHAKU_VERSION wheel exists for $PYTORCH_WHEEL_VARIANT"
}
elseif ($NUNCHAKU_SUPPORTED_TORCH_VERSIONS -notcontains $PYTORCH_MAJOR_MINOR) {
    $NUNCHAKU_AVAILABLE = $false
    $NUNCHAKU_UNAVAILABLE_REASON = "no official wheel exists for PyTorch $PYTORCH_MAJOR_MINOR"
}
elseif ($NUNCHAKU_SUPPORTED_PYTHON_TAGS -notcontains $configuredPythonTag) {
    $NUNCHAKU_AVAILABLE = $false
    $NUNCHAKU_UNAVAILABLE_REASON = "no official wheel exists for $configuredPythonTag"
}

function ConvertTo-DefaultLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Save-InstallerDefaults {
    if ($CONFIG_MODE -eq "skip") { return }

    $answer = Read-Host "Save successful choices as new defaults? (y/N)"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer -notmatch '^[Yy]') { return }

    $attributes = [System.IO.File]::GetAttributes($InstallerScriptPath)
    if (($attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
        Write-Warn "Defaults were not saved because $InstallerScriptPath is read-only."
        return
    }

    $save = $Embedded.Clone()
    $packageWork = $Steps[2] -or $Steps[4] -or $Steps[5] -or $Steps[7] -or $Steps[9] -or $Steps[10]
    $anyWork = ($Steps.Values | Where-Object { $_ }).Count -gt 0

    if ($CONFIG_MODE -eq "easy") {
        if ($Steps[5] -and $Manage.Comfy) { $save.Comfy = $INPUT_COMFYUI_VERSION }
        if ($packageWork -and $Manage.Frontend) { $save.Frontend = $COMFYUI_FRONTEND_VERSION }
        if ($Steps[11] -and $Manage.Launcher) { $save.Alias = $COMFYUI_ALIAS }
    }
    else {
        if ($anyWork -and $Manage.BasePath) { $save.BasePath = $BASE_PATH }
        if ($Steps[1] -and $Manage.Python) { $save.Python = $PYTHON_VERSION }
        if (($Steps[2] -or $Steps[10]) -and $Manage.Torch) {
            $save.Torch = $PYTORCH_VERSION
            $save.Variant = $PYTORCH_WHEEL_VARIANT
        }
        if ($packageWork) {
            if ($Manage.Numpy) { $save.Numpy = $NUMPY_VERSION }
            if ($Manage.Transformers) { $save.Transformers = $TRANSFORMERS_VERSION }
            if ($Manage.Frontend) {
                $save.ManageFrontend = $INSTALL_COMFYUI_FRONTEND
                if ($INSTALL_COMFYUI_FRONTEND) { $save.Frontend = $COMFYUI_FRONTEND_VERSION }
            }
        }
        if ($Steps[5] -and $Manage.Comfy) { $save.Comfy = $INPUT_COMFYUI_VERSION }
        if ($Steps[3] -and $Manage.Nunchaku) { $save.Nunchaku = $INSTALL_NUNCHAKU }
        if ($Steps[11] -and $Manage.Launcher) {
            $save.Alias = $COMFYUI_ALIAS
            $save.Args = $COMFYUI_LAUNCH_ARGS
            $save.PinFrontend = $PIN_FRONTEND_VERSION_IN_ALIAS
        }
        if ($Steps[5]) {
            if ($Manage.Models) { $save.Models = $SYMLINK_MODELS }
            if ($Manage.Input) { $save.Input = $SYMLINK_INPUT }
            if ($Manage.Output) { $save.Output = $SYMLINK_OUTPUT }
            if ($Manage.User) { $save.User = $SYMLINK_USER }
            if ($Manage.Nodes) { $save.Nodes = $SYMLINK_CUSTOM_NODES }
        }
    }

    $newline = [Environment]::NewLine
    $block = @(
        "# BEGIN COMFYUI INSTALLER DEFAULTS"
        ('$BASE_PATH = ' + (ConvertTo-DefaultLiteral $save.BasePath))
        ('$PYTHON_VERSION = ' + (ConvertTo-DefaultLiteral $save.Python))
        ('$PYTORCH_VERSION = ' + (ConvertTo-DefaultLiteral $save.Torch))
        ('$PYTORCH_WHEEL_VARIANT = ' + (ConvertTo-DefaultLiteral $save.Variant))
        ('$NUMPY_VERSION = ' + (ConvertTo-DefaultLiteral $save.Numpy))
        ('$TRANSFORMERS_VERSION = ' + (ConvertTo-DefaultLiteral $save.Transformers))
        ('$DEFAULT_COMFYUI_VERSION = ' + (ConvertTo-DefaultLiteral $save.Comfy))
        ('$DEFAULT_FRONTEND_VERSION = ' + (ConvertTo-DefaultLiteral $save.Frontend))
        ('$DEFAULT_ALIAS = ' + (ConvertTo-DefaultLiteral $save.Alias))
        ('$COMFYUI_LAUNCH_ARGS = ' + (ConvertTo-DefaultLiteral $save.Args))
        ('$SYMLINK_MODELS = $' + $save.Models.ToString().ToLowerInvariant())
        ('$SYMLINK_INPUT = $' + $save.Input.ToString().ToLowerInvariant())
        ('$SYMLINK_OUTPUT = $' + $save.Output.ToString().ToLowerInvariant())
        ('$SYMLINK_USER = $' + $save.User.ToString().ToLowerInvariant())
        ('$SYMLINK_CUSTOM_NODES = $' + $save.Nodes.ToString().ToLowerInvariant())
        ('$INSTALL_NUNCHAKU = $' + $save.Nunchaku.ToString().ToLowerInvariant())
        ('$INSTALL_COMFYUI_FRONTEND = $' + $save.ManageFrontend.ToString().ToLowerInvariant())
        ('$PIN_FRONTEND_VERSION_IN_ALIAS = $' + $save.PinFrontend.ToString().ToLowerInvariant())
        "# END COMFYUI INSTALLER DEFAULTS"
    ) -join $newline
    $reader = New-Object System.IO.StreamReader($InstallerScriptPath, $true)
    try {
        $source = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    }
    finally { $reader.Dispose() }
    $pattern = '(?ms)^# BEGIN COMFYUI INSTALLER DEFAULTS\r?\n.*?^# END COMFYUI INSTALLER DEFAULTS$'
    if ([regex]::Matches($source, $pattern).Count -ne 1) {
        Write-Warn "Defaults were not saved because the marked block was missing or ambiguous."
        return
    }
    $candidateText = [regex]::Replace($source, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block })
    if ($env:COMFY_INSTALLER_FORCE_INVALID_CANDIDATE -eq "1") { $candidateText += "$newline if invalid candidate" }

    $candidate = "$InstallerScriptPath.candidate.$([guid]::NewGuid().ToString('N'))"
    $backup = "$candidate.backup"
    try {
        [System.IO.File]::WriteAllText($candidate, $candidateText, $encoding)
        $null = [scriptblock]::Create($candidateText)
        [System.IO.File]::SetAttributes($candidate, $attributes)
        [System.IO.File]::Replace($candidate, $InstallerScriptPath, $backup)
        Remove-Item $backup -Force -ErrorAction SilentlyContinue
        Write-Success "Saved successful choices in $InstallerScriptPath"
    }
    catch {
        Remove-Item $candidate, $backup -Force -ErrorAction SilentlyContinue
        Write-Warn "Installation succeeded, but defaults were not saved: $($_.Exception.Message)"
    }
}

# ============================================
# Step Selection
# ============================================
Write-Host "Select installation steps (numbers, ranges, or 'a' for all - e.g., 6-10 or 1 5 6-8 or 5,11):"
Write-Host ""
Write-Host "   1) Python environment (pyenv-win + venv)"
Write-Host "   2) PyTorch and base dependencies"
Write-Host "   3) Nunchaku acceleration library"
Write-Host "   4) Face recognition libraries"
Write-Host "   5) ComfyUI core"
Write-Host "   6) Clone custom nodes"
Write-Host "   7) Install custom node dependencies"
Write-Host "   8) Performance libraries (llama-cpp, sageattention)"
Write-Host "   9) Upgrade and pin package versions"
Write-Host "  10) Enforce final package versions"
Write-Host "  11) Create launcher scripts and PowerShell aliases ($COMFYUI_ALIAS)"
Write-Host "  12) Compatibility audit and curated repair"
Write-Host ""
Write-Host "Unavailable steps:"
if (-not $Manage.Python) { Write-Host "   1) Python version is preserved" }
if (-not $Manage.Torch) { Write-Host "   2) PyTorch stack is preserved" }
if (-not $NUNCHAKU_AVAILABLE) { Write-Host "   3) $NUNCHAKU_UNAVAILABLE_REASON" }
if (-not $Manage.Comfy) { Write-Host "   5) ComfyUI checkout is preserved" }
if (-not $Manage.Launcher) { Write-Host "  11) Launchers are preserved" }
Write-Host ""
Write-Host "   a) All steps (default)"
Write-Host ""
$STEP_SELECTION = Read-Host "Your selection [a]"
if ([string]::IsNullOrWhiteSpace($STEP_SELECTION)) { $STEP_SELECTION = "a" }
# Normalize commas to spaces so "5,11" and "5 11" both work
$STEP_SELECTION = $STEP_SELECTION -replace ',', ' '

# Initialize step flags
$Steps = @{}
for ($i = 1; $i -le 12; $i++) { $Steps[$i] = $false }

if ($STEP_SELECTION -eq "a") {
    for ($i = 1; $i -le 12; $i++) { $Steps[$i] = $true }
    if (-not $INSTALL_NUNCHAKU) { $Steps[3] = $false }
}
else {
    # Expand ranges (e.g., "6-10" → 6,7,8,9,10) and individual numbers
    $expanded = @()
    foreach ($token in ($STEP_SELECTION -split '\s+')) {
        if ($token -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end   = [int]$Matches[2]
            for ($i = $start; $i -le $end; $i++) { $expanded += $i }
        }
        else {
            $expanded += $token
        }
    }

    foreach ($num in $expanded) {
        $n = 0
        if ([int]::TryParse("$num", [ref]$n) -and $n -ge 1 -and $n -le 12) {
            $Steps[$n] = $true
        }
        else {
            Write-Warn "Unknown option: $num"
        }
    }
}

function Disable-Step {
    param([int]$Number, [string]$Reason)
    if ($Steps[$Number]) { Write-Warn "Step $Number unavailable: $Reason" }
    $Steps[$Number] = $false
}

if (-not $Manage.Python) { Disable-Step 1 "Python version is preserved" }
if (-not $Manage.Torch) { Disable-Step 2 "the installed PyTorch stack is preserved" }
if (-not $NUNCHAKU_AVAILABLE) { Disable-Step 3 $NUNCHAKU_UNAVAILABLE_REASON }
if (-not $Manage.Comfy) { Disable-Step 5 "ComfyUI checkout management is preserved" }
if (-not $Manage.Launcher) { Disable-Step 11 "launcher alias, arguments, or pinning are preserved" }

if (($Steps.Values | Where-Object { $_ }).Count -eq 0) {
    throw "No available steps remain after applying the configuration."
}

$needsVenvSteps = @(2..12)
$needsVenv = @($needsVenvSteps | Where-Object { $Steps[$_] }).Count -gt 0
$activateScriptForCheck = Join-Path $VENV_PATH "Scripts\Activate.ps1"
if ($needsVenv -and -not $Steps[1] -and -not (Test-Path $activateScriptForCheck) -and
    $env:COMFY_INSTALLER_TEST_VENV_PRESENT -ne "1") {
    throw "Selected steps require an existing virtual environment at $VENV_PATH because step 1 was omitted."
}

$needsComfy = @((6, 7, 8, 11) | Where-Object { $Steps[$_] }).Count -gt 0
$COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME
if ($needsComfy -and -not $Steps[5] -and -not (Test-Path $COMFYUI_DIR) -and
    $env:COMFY_INSTALLER_TEST_COMFYUI_PRESENT -ne "1") {
    throw "Selected steps require an existing ComfyUI checkout at $COMFYUI_DIR because step 5 was omitted."
}

# Display selected steps
Write-Host ""
Write-Host "Selected steps:" -ForegroundColor White
$stepNames = @{
    1 = "Python environment"
    2 = "PyTorch and base dependencies"
    3 = "Nunchaku"
    4 = "Face recognition libraries"
    5 = "ComfyUI core"
    6 = "Clone custom nodes"
    7 = "Custom node dependencies"
    8 = "Performance libraries"
    9 = "Upgrade/pin packages"
    10 = "Enforce final versions"
    11 = "Launcher scripts and aliases"
    12 = "Compatibility audit and curated repair"
}
foreach ($i in 1..12) {
    if ($Steps[$i]) {
        Write-Host "  [x] $($stepNames[$i])" -ForegroundColor Green
    }
}
Write-Host ""

$confirm = Read-Host "Continue with these steps? (y/N)"
if ($confirm -notmatch '^[Yy]') {
    Write-Host "Installation cancelled."
    exit 0
}
Write-Host ""

if ($env:COMFY_INSTALLER_TEST_MODE -eq "1") {
    Write-Host "Test mode: selected work completed without filesystem or network changes."
    Save-InstallerDefaults
    return
}

# ============================================
# Activate an existing venv for environment-dependent steps when step 1 is omitted
# ============================================
$COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME
$ACTIVATE_SCRIPT = Join-Path $VENV_PATH "Scripts\Activate.ps1"

if ((Test-Path $VENV_PATH) -and (Test-Path $ACTIVATE_SCRIPT) -and (-not $Steps[1])) {
    Write-Host "Found existing virtual environment at $VENV_PATH"
    Write-Step "Activating virtual environment..."
    & $ACTIVATE_SCRIPT
    Write-Success "Virtual environment activated"
    Write-Host ""
}

# ============================================================================
# [1/12] Python Environment Setup
# ============================================================================
if ($Steps[1]) {

    Write-Header "[1/12] Setting up Python Environment"

    # Check if pyenv-win is installed
    $pyenvInstalled = Test-CommandExists "pyenv"

    if (-not $pyenvInstalled) {
        Write-Step "pyenv-win not found. Installing pyenv-win..."

        # Install pyenv-win via PowerShell (official method)
        $pyenvHome = "$env:USERPROFILE\.pyenv\pyenv-win"
        if (-not (Test-Path $pyenvHome)) {
            Write-Step "Downloading pyenv-win..."
            # Use the official installer
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "$env:TEMP\install-pyenv-win.ps1"
            & "$env:TEMP\install-pyenv-win.ps1"
            Remove-Item "$env:TEMP\install-pyenv-win.ps1" -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Success "Found existing pyenv-win installation at $pyenvHome"
        }

        # Add pyenv-win to PATH for this session
        $env:PYENV = "$env:USERPROFILE\.pyenv\pyenv-win"
        $env:PYENV_HOME = $env:PYENV
        $env:PYENV_ROOT = $env:PYENV
        $env:PATH = "$env:PYENV\bin;$env:PYENV\shims;$env:PATH"

        # Verify pyenv is now available
        if (-not (Test-CommandExists "pyenv")) {
            Write-Host ""
            Write-Warn "pyenv-win installation may require a shell restart."
            Write-Host "  Please close this PowerShell window, open a new one, and re-run this script."
            Write-Host "  If pyenv-win is still not found, follow: https://github.com/pyenv-win/pyenv-win#installation"
            Write-Host ""
            Read-Host "Press Enter to exit"
            exit 1
        }

        Write-Success "pyenv-win configured successfully"
        Write-Host ""
    }
    else {
        Write-Success "pyenv-win is already installed"
        # Ensure pyenv paths are set for this session
        $env:PYENV = "$env:USERPROFILE\.pyenv\pyenv-win"
        $env:PYENV_HOME = $env:PYENV
        $env:PYENV_ROOT = $env:PYENV
    }

    # Check if the required Python version is installed
    $installedVersions = & pyenv versions --bare 2>$null
    if ($installedVersions -notcontains $PYTHON_VERSION) {
        Write-Step "Installing Python $PYTHON_VERSION via pyenv-win..."
        pyenv install $PYTHON_VERSION
        Write-Success "Python $PYTHON_VERSION installed"
    }
    else {
        Write-Success "Python $PYTHON_VERSION already installed"
    }

    # Set local Python version
    Write-Step "Setting Python version to $PYTHON_VERSION..."
    Push-Location $BASE_PATH
    if (-not (Test-Path $BASE_PATH)) { New-Item -ItemType Directory -Path $BASE_PATH -Force | Out-Null }
    pyenv local $PYTHON_VERSION
    pyenv rehash
    Pop-Location

    # Verify Python version
    $pythonCmd = & pyenv which python 2>$null
    if (-not $pythonCmd) {
        # Fallback: try shim
        $pythonCmd = "python"
    }
    $currentPython = & $pythonCmd --version 2>&1 | ForEach-Object { ($_ -split ' ')[1] }
    Write-Success "Using Python $currentPython"

    # Extract Python wheel tag (e.g., 3.12 -> cp312)
    $pyMajorMinor = ($PYTHON_VERSION -split '\.')[0..1] -join ''
    $PYTHON_WHEEL_TAG = "cp$pyMajorMinor"
    Write-Success "Python wheel tag: $PYTHON_WHEEL_TAG"

    # Validate Python version compatibility
    $supportedVersions = @("cp310", "cp311", "cp312", "cp313", "cp314")
    if ($supportedVersions -notcontains $PYTHON_WHEEL_TAG) {
        Write-Warn "Python $currentPython ($PYTHON_WHEEL_TAG) may not have prebuilt wheels"
        Write-Host "   Supported versions: Python 3.10, 3.11, 3.12, 3.13, 3.14"
        $reply = Read-Host "Continue anyway? (y/N)"
        if ($reply -notmatch '^[Yy]') {
            Write-Host "Installation cancelled."
            exit 1
        }
    }

    # Create venv if it doesn't exist
    if (-not (Test-Path $VENV_PATH)) {
        Write-Step "Creating virtual environment at $VENV_PATH..."
        & $pythonCmd -m venv $VENV_PATH
        Write-Success "Virtual environment created"
    }
    else {
        Write-Success "Virtual environment already exists at $VENV_PATH"
    }

    # Activate the virtual environment
    Write-Step "Activating virtual environment..."
    & "$VENV_PATH\Scripts\Activate.ps1"
    Write-Success "Virtual environment activated"

    # Install uv (ultra-fast pip replacement)
    Write-Step "Installing uv package manager..."
    pip install --upgrade uv
    Write-Success "uv installed successfully"

    # Configure uv to use copy mode
    $env:UV_LINK_MODE = "copy"

    # Store wheel tag for later steps
    $script:PYTHON_WHEEL_TAG = $PYTHON_WHEEL_TAG
}
else {
    # Compute wheel tag if not set by step 1
    $pyMajorMinor = ($PYTHON_VERSION -split '\.')[0..1] -join ''
    $script:PYTHON_WHEEL_TAG = "cp$pyMajorMinor"
}

# Ensure UV_LINK_MODE is set for all steps
$env:UV_LINK_MODE = "copy"

# ============================================================================
# Inspect unmanaged versions only when selected dependency work needs exact
# constraints. Missing preserved packages receive an impossible constraint.
function Get-InstalledDistributionVersion {
    param([string]$Distribution)
    $venvPython = Join-Path $VENV_PATH "Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        return "0+preserve"
    }
    $result = & $venvPython -c "import importlib.metadata,sys; print(importlib.metadata.version(sys.argv[1]))" $Distribution 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($result)) { return "0+preserve" }
    return ($result | Select-Object -First 1).Trim()
}

$metadataRequired = @((4, 5, 7, 8, 9, 10, 12) | Where-Object { $Steps[$_] }).Count -gt 0
if ($metadataRequired) {
    $script:PYTHON_WHEEL_TAG = (python -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')").Trim()
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect the active Python wheel tag." }
    if (-not $Manage.Torch) {
        $PYTORCH_FULL_VERSION = Get-InstalledDistributionVersion "torch"
        $TORCHVISION_FULL_VERSION = Get-InstalledDistributionVersion "torchvision"
        $TORCHAUDIO_FULL_VERSION = Get-InstalledDistributionVersion "torchaudio"
        $installedTorchBase = ($PYTORCH_FULL_VERSION -split '\+')[0]
        $PYTORCH_MAJOR_MINOR = ($installedTorchBase -split '\.')[0..1] -join '.'
        $backendMetadata = python -c "import torch; print(f'nvidia:{torch.version.cuda}' if torch.version.cuda else ('cpu' if not torch.version.hip else f'rocm:{torch.version.hip}'))" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($backendMetadata)) {
            $backendMetadata = "unknown"
        } else {
            $backendMetadata = ($backendMetadata | Select-Object -First 1).Trim()
        }
        switch -Regex ($backendMetadata) {
            '^nvidia:' {
                $HARDWARE_BACKEND = "nvidia"
                $installedCudaVersion = $backendMetadata.Substring(7)
                $PYTORCH_WHEEL_VARIANT = "cu$($installedCudaVersion.Replace('.', ''))"
                $PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/$PYTORCH_WHEEL_VARIANT"
            }
            '^rocm:' {
                $HARDWARE_BACKEND = "rocm"
                $installedVariant = ($PYTORCH_FULL_VERSION -split '\+', 2)[1]
                $PYTORCH_WHEEL_VARIANT = if ($installedVariant -match '^rocm') { $installedVariant } else { "rocm" }
                $PYTORCH_INDEX_URL = $AMD_ROCM_BASE_URL
            }
            '^cpu$' {
                $HARDWARE_BACKEND = "cpu"
                $PYTORCH_WHEEL_VARIANT = "cpu"
                $PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/cpu"
            }
            default { $HARDWARE_BACKEND = "unknown" }
        }
        Write-Host "   Preserving installed PyTorch metadata: $PYTORCH_FULL_VERSION"
        Write-Host "   Detected installed hardware backend: $HARDWARE_BACKEND"
    }
    if (-not $Manage.Numpy) {
        $NUMPY_VERSION = Get-InstalledDistributionVersion "numpy"
        Write-Host "   Preserving installed NumPy metadata: $NUMPY_VERSION"
    }
    if (-not $Manage.Transformers) {
        $TRANSFORMERS_VERSION = Get-InstalledDistributionVersion "transformers"
        Write-Host "   Preserving installed Transformers metadata: $TRANSFORMERS_VERSION"
    }
}

# [2/12] Install PyTorch
# ============================================================================
if ($Steps[2]) {

    Write-Header "[2/12] Installing PyTorch and Base Dependencies"

    Write-Step "Installing PyTorch ${PYTORCH_FULL_VERSION}..."
    Install-ManagedPyTorchStack
    if ($HARDWARE_BACKEND -eq "rocm") {
        if (Test-AmdRocmTorch) {
            $amdDeviceName = (python -c "import torch; print(torch.cuda.get_device_name(0))" | Select-Object -First 1)
            Write-Success "AMD ROCm GPU runtime probe: $amdDeviceName"
        }
        else {
            throw "AMD PyTorch installed, but ROCm could not access a supported GPU. Verify Windows 11, driver $AMD_ROCM_REQUIRED_DRIVER, and AMD's supported-hardware matrix."
        }
    }
}

# ============================================================================
# [3/12] Install Nunchaku
# ============================================================================
if ($Steps[3]) {
    Write-Header "[3/12] Installing Nunchaku Acceleration Library"

    $PYTHON_WHEEL_TAG = (python -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')").Trim()
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect the active Python wheel tag." }
    if (-not $NUNCHAKU_CUDA_VARIANT) {
        throw "Nunchaku $NUNCHAKU_VERSION has no official wheel for $PYTORCH_WHEEL_VARIANT."
    }
    if ($NUNCHAKU_SUPPORTED_TORCH_VERSIONS -notcontains $PYTORCH_MAJOR_MINOR) {
        throw "Nunchaku $NUNCHAKU_VERSION $NUNCHAKU_CUDA_VARIANT has no official wheel for PyTorch $PYTORCH_MAJOR_MINOR."
    }
    if ($NUNCHAKU_SUPPORTED_PYTHON_TAGS -notcontains $PYTHON_WHEEL_TAG) {
        throw "Nunchaku $NUNCHAKU_VERSION has no official wheel for $PYTHON_WHEEL_TAG."
    }

    $NUNCHAKU_WHEEL = "https://github.com/nunchaku-ai/nunchaku/releases/download/v$NUNCHAKU_VERSION/nunchaku-$NUNCHAKU_VERSION+${NUNCHAKU_CUDA_VARIANT}torch$PYTORCH_MAJOR_MINOR-$PYTHON_WHEEL_TAG-$PYTHON_WHEEL_TAG-win_amd64.whl"
    Write-Step "Installing official Nunchaku wheel ($NUNCHAKU_CUDA_VARIANT, torch $PYTORCH_MAJOR_MINOR, $PYTHON_WHEEL_TAG)..."
    uv pip install $NUNCHAKU_WHEEL
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install official Nunchaku wheel: $NUNCHAKU_WHEEL. No PyPI fallback was attempted."
    }
}

# ============================================================================
# [4/12] Install Face Recognition and Runtime Libraries
# ============================================================================
if ($Steps[4]) {

    Write-Header "[4/12] Installing Face Recognition and Runtime Libraries"

    # Create temporary constraints file to prevent torch downgrade
    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
torchvision==$TORCHVISION_FULL_VERSION
torchaudio==$TORCHAUDIO_FULL_VERSION
numpy==$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    Write-Step "Installing face recognition and runtime libraries..."
    Write-Host "   Using constraints to prevent torch/numpy/transformers downgrade"

    $packages = @(
        "facexlib",
        "insightface",
        "onnxruntime",
        "onnxruntime-gpu",
        "comfy-cli",
        "bitsandbytes>=0.46.1",
        "hf-xet",
        "requests",
        "pilgram",
        "facenet_pytorch"
    )

    foreach ($pkg in $packages) {
        Invoke-SafeCommand "Installing $pkg" {
            uv pip install --constraint $CONSTRAINTS_FILE $pkg
        } -Optional
    }

    # Note: tensorflow and tf-keras are often problematic on Windows
    # Attempt installation but don't fail
    Invoke-SafeCommand "Installing tensorflow" {
        uv pip install --constraint $CONSTRAINTS_FILE tensorflow
    } -Optional

    Invoke-SafeCommand "Installing tf-keras" {
        uv pip install --constraint $CONSTRAINTS_FILE tf-keras
    } -Optional

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [5/12] Install ComfyUI
# ============================================================================
if ($Steps[5]) {

    Write-Header "[5/12] Installing ComfyUI Core"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

    if (-not (Test-Path (Join-Path $COMFYUI_DIR ".git"))) {
        Write-Step "Cloning ComfyUI repository to $COMFYUI_DIR..."
        if (-not (Test-Path $COMFYUI_PARENT_DIR)) {
            New-Item -ItemType Directory -Path $COMFYUI_PARENT_DIR -Force | Out-Null
        }
        Push-Location $COMFYUI_PARENT_DIR
        git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_DIR_NAME
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $COMFYUI_DIR ".git"))) {
            throw "Failed to clone ComfyUI into $COMFYUI_DIR"
        }
        $COMFYUI_WAS_CLONED = $true

        if ($COMFYUI_VERSION) {
            Write-Step "Checking out ComfyUI version: $COMFYUI_VERSION"
            Set-Location $COMFYUI_DIR
            git checkout $COMFYUI_VERSION
        }
        Pop-Location
    }
    else {
        Write-Success "ComfyUI already exists at $COMFYUI_DIR"

        if ($COMFYUI_VERSION) {
            Push-Location $COMFYUI_DIR
            $currentCommit = git rev-parse HEAD
            $targetCommit = $null

            try {
                $targetCommit = git rev-parse --verify $COMFYUI_VERSION 2>$null
            }
            catch {
                Write-Step "Fetching updates to resolve version: $COMFYUI_VERSION"
                git fetch origin
                try {
                    $targetCommit = git rev-parse --verify $COMFYUI_VERSION 2>$null
                }
                catch { }
            }

            if (-not $targetCommit) {
                Write-Warn "Could not resolve version '$COMFYUI_VERSION'. Attempting checkout..."
                git checkout $COMFYUI_VERSION
            }
            elseif ($currentCommit -ne $targetCommit) {
                Write-Step "Checking out ComfyUI version: $COMFYUI_VERSION"
                git checkout $COMFYUI_VERSION
            }
            else {
                Write-Success "Already on version: $COMFYUI_VERSION"
            }
            Pop-Location
        }
    }

    # Install ComfyUI base requirements
    Write-Host ""
    Write-Step "Installing ComfyUI dependencies..."
    Push-Location $COMFYUI_DIR

    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
torchvision==$TORCHVISION_FULL_VERSION
torchaudio==$TORCHAUDIO_FULL_VERSION
numpy==$NUMPY_VERSION
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    Write-Host "   Using constraints to prevent torch/numpy downgrade"
    Install-UvRequirements -RequirementsFile "requirements.txt" -ConstraintFile $CONSTRAINTS_FILE
    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
    Pop-Location
}

# ============================================================================
# Configure Shared/Local ComfyUI Directories
# ============================================================================

Write-Header "Configuring Shared and Local Directories"

$COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

if ($Steps[5] -and $Manage.Models) { Set-ComfyDirectorySharing -Name "Models" -LocalPath (Join-Path $COMFYUI_DIR "models") -SharedPath $USER_MODELS_PATH -Enabled $SYMLINK_MODELS -NewInstall $COMFYUI_WAS_CLONED }
if ($Steps[5] -and $Manage.Input) { Set-ComfyDirectorySharing -Name "Input" -LocalPath (Join-Path $COMFYUI_DIR "input") -SharedPath $USER_INPUT_PATH -Enabled $SYMLINK_INPUT -NewInstall $COMFYUI_WAS_CLONED }
if ($Steps[5] -and $Manage.Output) { Set-ComfyDirectorySharing -Name "Output" -LocalPath (Join-Path $COMFYUI_DIR "output") -SharedPath $USER_OUTPUT_PATH -Enabled $SYMLINK_OUTPUT -NewInstall $COMFYUI_WAS_CLONED }
if ($Steps[5] -and $Manage.User) { Set-ComfyDirectorySharing -Name "User Data" -LocalPath (Join-Path $COMFYUI_DIR "user") -SharedPath $USER_USERDATA_PATH -Enabled $SYMLINK_USER -NewInstall $COMFYUI_WAS_CLONED }
if ($Steps[5] -and $Manage.Nodes) { Set-ComfyDirectorySharing -Name "Custom Nodes" -LocalPath (Join-Path $COMFYUI_DIR "custom_nodes") -SharedPath $USER_CUSTOM_NODES_PATH -Enabled $SYMLINK_CUSTOM_NODES -NewInstall $COMFYUI_WAS_CLONED }

# ============================================================================
# [6/12] Clone Custom Nodes
# ============================================================================
if ($Steps[6]) {

    Write-Header "[6/12] Cloning Custom Nodes"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME
    $CUSTOM_NODES_DIR = Join-Path $COMFYUI_DIR "custom_nodes"

    if (-not (Test-Path $CUSTOM_NODES_DIR)) {
        New-Item -ItemType Directory -Path $CUSTOM_NODES_DIR -Force | Out-Null
    }
    Push-Location $CUSTOM_NODES_DIR

    # Core Extensions
    Write-Host "Cloning core extensions..." -ForegroundColor White
    Copy-IfMissing "https://github.com/r-vage/ComfyUI_Eclipse.git"
    Copy-IfMissing "https://github.com/Comfy-Org/ComfyUI-Manager.git"

    # UI & Workflow Tools
    Write-Host ""
    Write-Host "Cloning UI & workflow tools..." -ForegroundColor White
    Copy-IfMissing "https://github.com/BobRandomNumber/ComfyUI-Crystools-MonitorOnly.git"
    Copy-IfMissing "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    Copy-IfMissing "https://github.com/rgthree/rgthree-comfy"
    Copy-IfMissing "https://github.com/yolain/ComfyUI-Easy-Use.git"
    Copy-IfMissing "https://github.com/cubiq/ComfyUI_essentials.git"
    Copy-IfMissing "https://github.com/MinorBoy/ComfyUI_essentials_mb.git"
    Copy-IfMissing "https://github.com/chrisgoringe/cg-image-filter.git"
    Copy-IfMissing "https://github.com/ashtar1984/comfyui-find-perfect-resolution"
    Copy-IfMissing "https://github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI"
    Copy-IfMissing "https://github.com/darksidewalker/ComfyUI-DaSiWa-Nodes"
    Copy-IfMissing "https://github.com/Comfy-Org/Nvidia_RTX_Nodes_ComfyUI"

    # Model Support & Optimization
    Write-Host ""
    Write-Host "Cloning model support & optimization..." -ForegroundColor White
    Copy-IfMissing "https://github.com/welltop-cn/ComfyUI-TeaCache.git"
    Copy-IfMissing "https://github.com/lldacing/ComfyUI_Patches_ll.git"

    # Sampling & Scheduling
    Write-Host ""
    Write-Host "Cloning sampling & scheduling..." -ForegroundColor White
    Copy-IfMissing "https://github.com/r-vage/RES4LYF.git"
    Copy-IfMissing "https://github.com/mcmonkeyprojects/sd-dynamic-thresholding.git"
    Copy-IfMissing "https://github.com/ChangeTheConstants/SeedVarianceEnhancer"
    Copy-IfMissing "https://github.com/wildminder/ComfyUI-DyPE"
    Copy-IfMissing "https://github.com/Artificial-Sweetener/comfyui-WhiteRabbit"

    # ControlNet & Advanced Control
    Write-Host ""
    Write-Host "Cloning ControlNet & advanced control..." -ForegroundColor White
    Copy-IfMissing "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet.git"
    Copy-IfMissing "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

    # Image Processing & Effects
    Write-Host ""
    Write-Host "Cloning image processing & effects..." -ForegroundColor White
    Copy-IfMissing "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"
    Copy-IfMissing "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git"
    Copy-IfMissing "https://github.com/chflame163/ComfyUI_LayerStyle.git"
    Copy-IfMissing "https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git"
    Copy-IfMissing "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-KJNodes.git"
    Copy-IfMissing "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git"
    Copy-IfMissing "https://github.com/SeanBRVFX/ComfyUI-CorridorKey"
    Copy-IfMissing "https://github.com/filliptm/ComfyUI_Fill-Nodes.git"
    Copy-IfMissing "https://github.com/shiimizu/ComfyUI-TiledDiffusion"

    # Specialized Models
    Write-Host ""
    Write-Host "Cloning specialized models..." -ForegroundColor White
    Copy-IfMissing "https://github.com/kijai/ComfyUI-SUPIR.git"
    Copy-IfMissing "https://github.com/lldacing/ComfyUI_BiRefNet_ll.git"
    Copy-IfMissing "https://github.com/r-vage/ComfyUI_PuLID_Flux_ll.git"
    Copy-IfMissing "https://github.com/lbouaraba/comfyui-krea2edit.git"
    Copy-IfMissing "https://github.com/capitan01R/ComfyUI-Krea2T-Enhancer.git"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-SCAIL-Pose.git"
    
    # Audio & Media
    Write-Host ""
    Write-Host "Cloning audio & media..." -ForegroundColor White
    Copy-IfMissing "https://github.com/kijai/ComfyUI-MMAudio"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-MelBandRoFormer"
    Copy-IfMissing "https://github.com/mattjohnpowell/comfyui-audio-expo"

    # Video Processing
    Write-Host ""
    Write-Host "Cloning video processing..." -ForegroundColor White
    Copy-IfMissing "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
    Copy-IfMissing "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-GIMM-VFI"
    Copy-IfMissing "https://github.com/GACLove/ComfyUI-VFI"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-WanVideoWrapper"
    Copy-IfMissing "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
    Copy-IfMissing "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git"
    Copy-IfMissing "https://github.com/stduhpf/ComfyUI-WanMoeKSampler.git"
    Copy-IfMissing "https://github.com/r-vage/ComfyUI-LTXVideo.git"

    Pop-Location
}

# ============================================================================
# [7/12] Install Custom Node Dependencies
# ============================================================================
if ($Steps[7]) {

    Write-Header "[7/12] Installing Custom Node Dependencies"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME
    $CUSTOM_NODES_DIR = Join-Path $COMFYUI_DIR "custom_nodes"

    # Create temporary constraints file
    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
torchvision==$TORCHVISION_FULL_VERSION
torchaudio==$TORCHAUDIO_FULL_VERSION
numpy==$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
numba>=0.58.0
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    Write-Host "Using constraints to prevent torch/numpy/transformers downgrade"
    Write-Host ""

    $disabledRoot = Join-Path $CUSTOM_NODES_DIR ".disabled"
    if (Test-Path $disabledRoot) {
        Write-Host " [--] Skipping ComfyUI-Manager disabled nodes in $disabledRoot"
    }
    $nodeDirs = Get-ChildItem -LiteralPath $CUSTOM_NODES_DIR -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ine ".disabled" -and -not $_.Name.EndsWith(".disabled", [System.StringComparison]::OrdinalIgnoreCase) }
    foreach ($nodeDir in $nodeDirs) {
        $reqFile = Join-Path $nodeDir.FullName "requirements.txt"
        if (Test-Path $reqFile) {
            Write-Host ""
            Invoke-SafeCommand "Installing dependencies for: $($nodeDir.Name)" {
                Install-UvRequirements -RequirementsFile $reqFile -ConstraintFile $CONSTRAINTS_FILE
            } -Optional
        }
    }
    $legacyDisabled = Get-ChildItem -LiteralPath $CUSTOM_NODES_DIR -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name.EndsWith(".disabled", [System.StringComparison]::OrdinalIgnoreCase) }
    foreach ($disabledNode in $legacyDisabled) {
        Write-Host " [--] Skipping legacy disabled node: $($disabledNode.Name)"
    }

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [8/12] Install Performance Libraries
# ============================================================================
if ($Steps[8]) {

    Write-Header "[8/12] Installing Performance Libraries"

    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
torchvision==$TORCHVISION_FULL_VERSION
torchaudio==$TORCHAUDIO_FULL_VERSION
numpy==$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    # Install llama-cpp-python
    Invoke-SafeCommand "Installing llama-cpp-python" {
        uv pip install --constraint $CONSTRAINTS_FILE "llama-cpp-python>=0.3.16"
    } -Optional

    if ($HARDWARE_BACKEND -eq "nvidia") {
        Write-Host ""
        Write-Warn "Upstream Flash Attention does not publish official Windows wheels for this configuration."
        Remove-FlashAttention
        Write-Host "   Flash Attention is disabled; ComfyUI will use PyTorch attention."
        if (-not (Test-PythonImport "import kornia")) {
            throw "Kornia still fails to import after removing Flash Attention."
        }

        Install-SageAttention -ConstraintFile $CONSTRAINTS_FILE
    }
    else {
        Write-Host ""
        Write-Warn "Removing CUDA-only attention accelerators for $HARDWARE_BACKEND"
        Remove-FlashAttention
        uv pip uninstall sageattention 2>$null | Out-Null
    }

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [9/12] Upgrade & Pin Package Versions
# ============================================================================
if ($Steps[9]) {
    Write-Header "[9/12] Upgrading & Pinning Package Versions"

    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    $constraintLines = @(
        "torch==$PYTORCH_FULL_VERSION"
        "torchvision==$TORCHVISION_FULL_VERSION"
        "torchaudio==$TORCHAUDIO_FULL_VERSION"
        "numpy==$NUMPY_VERSION"
        "transformers==$TRANSFORMERS_VERSION"
        "nvidia-ml-py>=12,<13"
    )
    [System.IO.File]::WriteAllLines($CONSTRAINTS_FILE, [string[]]$constraintLines)

    Invoke-SafeCommand "Upgrading selected direct packages without broadly upgrading their dependencies" {
        uv pip install --constraint $CONSTRAINTS_FILE --upgrade-package ultralytics --upgrade-package gguf ultralytics gguf
    } -Optional
    Write-Host "   Preserving AV, protobuf, OpenCV, inference, tokenizers, and other conflict-prone packages for step 12."

    uv pip install "mistral-common>=1.8.6"
    if ($Manage.Numpy) { uv pip install "numpy==$NUMPY_VERSION" }
    if ($Manage.Transformers) { uv pip install "transformers==$TRANSFORMERS_VERSION" }
    if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND) {
        uv pip install "comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
    }
    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [10/12] Enforce Configured Package Versions
# ============================================================================
if ($Steps[10]) {
    Write-Header "[10/12] Enforcing Configured Package Versions"

    if ($Manage.Torch) {
        Invoke-SafeCommand "Enforcing PyTorch $PYTORCH_FULL_VERSION" {
            Install-ManagedPyTorchStack
        } -Optional
    }
    else { Write-Host "   Preserving the installed PyTorch stack" }

    if ($Manage.Numpy) {
        Invoke-SafeCommand "Enforcing NumPy $NUMPY_VERSION" { uv pip install "numpy==$NUMPY_VERSION" } -Optional
    }
    if ($Manage.Transformers) {
        Invoke-SafeCommand "Enforcing Transformers $TRANSFORMERS_VERSION" { uv pip install "transformers==$TRANSFORMERS_VERSION" } -Optional
    }
    if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND) {
        Invoke-SafeCommand "Enforcing ComfyUI Frontend $COMFYUI_FRONTEND_VERSION" {
            uv pip install "comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
        } -Optional
    }
    else { Write-Host "   Preserving or leaving the ComfyUI frontend unmanaged" }

    Write-Success "Managed package versions enforced successfully"
}

# ============================================================================
# [11/12] Create Launcher Scripts and PowerShell Aliases
# ============================================================================
if ($Steps[11]) {

    Write-Header "[11/12] Creating Launcher Scripts and PowerShell Aliases"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

    # --- Create per-version .bat launcher (named after alias, e.g., comfyui.bat, comfy2.bat) ---
    $launcherBat = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.bat"
    $frontendBatSetup = if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND -and $PIN_FRONTEND_VERSION_IN_ALIAS) {
@"
echo Ensuring frontend version $COMFYUI_FRONTEND_VERSION...
"$VENV_PATH\Scripts\python.exe" -m uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION

"@
    } else {
        "REM Frontend package is managed externally`r`n"
    }
    @"
@echo off
REM ComfyUI Launcher: $COMFYUI_ALIAS -> $COMFYUI_DIR
REM Auto-generated by install_comfy_env.ps1

$frontendBatSetup
echo Starting ComfyUI...
cd /d "$COMFYUI_DIR"
"$VENV_PATH\Scripts\python.exe" main.py $COMFYUI_LAUNCH_ARGS %*
pause
"@ | Set-Content $launcherBat -Encoding ASCII
    Write-Success "Created launcher: $launcherBat"

    # --- Create per-version .ps1 launcher ---
    $launcherPs1 = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.ps1"
    $frontendPsSetup = if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND -and $PIN_FRONTEND_VERSION_IN_ALIAS) {
@"
Write-Host 'Ensuring frontend version $COMFYUI_FRONTEND_VERSION...' -ForegroundColor DarkGray
& "$VENV_PATH\Scripts\python.exe" -m uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION

"@
    } else {
        "# Frontend package is managed externally`r`n"
    }
    @"
# ComfyUI Launcher: $COMFYUI_ALIAS -> $COMFYUI_DIR
# Auto-generated by install_comfy_env.ps1

$frontendPsSetup
Write-Host 'Starting ComfyUI...' -ForegroundColor Cyan
& "$VENV_PATH\Scripts\Activate.ps1"
Set-Location "$COMFYUI_DIR"
python main.py $COMFYUI_LAUNCH_ARGS @args
"@ | Set-Content $launcherPs1 -Encoding UTF8
    Write-Success "Created launcher: $launcherPs1"

    # --- Create envact.bat (shared, only if it doesn't exist) ---
    $envactBat = Join-Path $COMFYUI_PARENT_DIR "envact.bat"
    if (-not (Test-Path $envactBat)) {
        @"
@echo off
REM Activate ComfyUI venv
REM Auto-generated by install_comfy_env.ps1

call "$VENV_PATH\Scripts\activate.bat"
"@ | Set-Content $envactBat -Encoding ASCII
        Write-Success "Created envact launcher: $envactBat"
    } else {
        Write-Success "envact.bat already exists — skipping"
    }

    # --- Add PowerShell profile functions (non-destructive, additive only) ---
    Write-Host ""
    Write-Step "Configuring PowerShell profile aliases..."

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not $profilePath) { $profilePath = $PROFILE }

    # Ensure profile directory and file exist
    $profileDir = Split-Path $profilePath -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
        Write-Success "Created PowerShell profile: $profilePath"
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if (-not $profileContent) { $profileContent = "" }

    # Show existing ComfyUI functions for context
    $existingFunctions = ($profileContent | Select-String -Pattern "^function (comfy|envact)" -AllMatches).Matches.Value
    if ($existingFunctions) {
        Write-Host "  Existing ComfyUI functions in profile:" -ForegroundColor DarkGray
        foreach ($fn in $existingFunctions) {
            Write-Host "    $fn" -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    $added = $false

    # Add launch function if it doesn't already exist
    if ($profileContent -match "function $COMFYUI_ALIAS\b") {
        Write-Success "Function '$COMFYUI_ALIAS' already exists in profile - skipping"
        if ((-not $Manage.Frontend) -or (-not $INSTALL_COMFYUI_FRONTEND) -or (-not $PIN_FRONTEND_VERSION_IN_ALIAS)) {
            Write-Warn "Existing function may still pin the frontend; remove it and rerun step 11 to regenerate it"
        }
        if (-not [string]::IsNullOrWhiteSpace($COMFYUI_LAUNCH_ARGS)) {
            Write-Warn "Existing function may not include the configured launch arguments; remove it and rerun step 11 to regenerate it"
        }
    } else {
        $frontendFunctionSetup = if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND -and $PIN_FRONTEND_VERSION_IN_ALIAS) {
            "    & `"$VENV_PATH\Scripts\python.exe`" -m uv pip install -q comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION`r`n"
        } else {
            ""
        }
        $funcBlock = @"

# ComfyUI: $COMFYUI_ALIAS -> $COMFYUI_DIR
function $COMFYUI_ALIAS {
$frontendFunctionSetup    & "$VENV_PATH\Scripts\Activate.ps1"
    Set-Location "$COMFYUI_DIR"
    python main.py $COMFYUI_LAUNCH_ARGS @args
}
"@
        Add-Content $profilePath $funcBlock -Encoding UTF8
        Write-Success "Added function '$COMFYUI_ALIAS' to profile"
        $added = $true
    }

    # Add envact function if it doesn't already exist (shared across installs)
    if ($profileContent -match "function envact\b") {
        Write-Success "Function 'envact' already exists in profile - skipping"
    } else {
        $envactBlock = @"

# ComfyUI: envact -> $VENV_PATH
function envact {
    & "$VENV_PATH\Scripts\Activate.ps1"
}
"@
        Add-Content $profilePath $envactBlock -Encoding UTF8
        Write-Success "Added function 'envact' to profile"
        $added = $true
    }

    if (-not $added) {
        Write-Host "  No changes needed in profile"
    }

    Write-Host ""
    Write-Host ("=" * 67) -ForegroundColor Cyan
    Write-Host "Launcher and alias configuration complete!" -ForegroundColor Cyan
    if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND -and $PIN_FRONTEND_VERSION_IN_ALIAS) {
        Write-Host "  - $COMFYUI_ALIAS : activate environment, pin frontend, launch ComfyUI"
    } elseif ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND) {
        Write-Host "  - $COMFYUI_ALIAS : activate environment and launch ComfyUI (frontend managed, alias pin disabled)"
    } else {
        Write-Host "  - $COMFYUI_ALIAS : activate environment and launch ComfyUI (frontend unmanaged)"
    }
    Write-Host "  - envact  : activate environment only"
    Write-Host ""
    Write-Host "  Batch files:"
    Write-Host "    $launcherBat"
    Write-Host "    $envactBat"
    Write-Host ""
    Write-Host "To use the PowerShell aliases, either:"
    Write-Host "  - Restart PowerShell"
    Write-Host "  - Or run: . `$PROFILE"
    Write-Host ("=" * 67) -ForegroundColor Cyan
}

# ============================================================================
# [12/12] Compatibility Audit and Curated Repair
# ============================================================================
if ($Steps[12]) {
    Write-Header "[12/12] Compatibility Audit and Curated Repair"

    $pipBefore = @(uv pip check 2>&1)
    $pipBeforeExit = $LASTEXITCODE
    if ($pipBeforeExit -eq 0) {
        Write-Success "pip check found no declared dependency conflicts"
    }
    else {
        Write-Warn "Declared dependency conflicts before curated repair:"
        $pipBefore | ForEach-Object { Write-Host "   $_" }
    }
    $pipBeforeText = $pipBefore -join "`n"

    $curatedRepairs = @()
    # Prefer versions shared by active inference packages and the wider runtime.
    if ($pipBeforeText -match "(?i)(inference|inference-gpu).*requires.*filelock") { $curatedRepairs += "filelock==3.16.1" }
    if ($pipBeforeText -match "(?i)(inference|inference-gpu).*requires.*opencv-python") { $curatedRepairs += "opencv-python==4.10.0.84" }
    if ($pipBeforeText -match "(?i)(inference|inference-gpu).*requires.*packaging") { $curatedRepairs += "packaging==24.2" }
    if ($pipBeforeText -match "(?i)(inference|inference-gpu).*requires.*rich") { $curatedRepairs += "rich==13.9.4" }
    if ($pipBeforeText -match "(?i)(inference|inference-cli|inference-gpu).*requires.*nvidia-ml-py") { $curatedRepairs += "nvidia-ml-py==12.575.51" }
    if ($pipBeforeText -match "(?i)aiortc.*requires.*av") { $curatedRepairs += "av==17.0.0" }

    # Restore the modern managed side if an older installer run downgraded it.
    # The legacy inference packages have mutually exclusive requirements here,
    # so their remaining declarations are reported instead of winning by count.
    if ($pipBeforeText -match "(?i)huggingface-hub.*requires.*click") { $curatedRepairs += "click==8.4.2" }
    if ($pipBeforeText -match "(?i)(typing-inspection|google-genai|runwayml|onnx).*requires.*typing-extensions") { $curatedRepairs += "typing-extensions==4.16.0" }
    if ($pipBeforeText -match "(?i)inference-cli.*requires.*aiohttp") { $curatedRepairs += "aiohttp==3.14.3" }
    if ($pipBeforeText -match "(?i)inference-cli.*requires.*pillow") { $curatedRepairs += "pillow==12.3.0" }

    if ($curatedRepairs.Count -gt 0) {
        $repairConstraints = [System.IO.Path]::GetTempFileName()
        $auditTorchVersion = Get-InstalledDistributionVersion "torch"
        $auditTorchVisionVersion = Get-InstalledDistributionVersion "torchvision"
        $auditTorchAudioVersion = Get-InstalledDistributionVersion "torchaudio"
        $auditNumpyVersion = Get-InstalledDistributionVersion "numpy"
        $auditTransformersVersion = Get-InstalledDistributionVersion "transformers"
        [System.IO.File]::WriteAllLines($repairConstraints, [string[]]@(
            "torch==$auditTorchVersion"
            "torchvision==$auditTorchVisionVersion"
            "torchaudio==$auditTorchAudioVersion"
            "numpy==$auditNumpyVersion"
            "transformers==$auditTransformersVersion"
            "nvidia-ml-py>=12,<13"
        ))
        Write-Step ("Dry-running curated compatibility repairs: " + ($curatedRepairs -join ", "))
        uv pip install --constraint $repairConstraints --dry-run @curatedRepairs
        if ($LASTEXITCODE -eq 0) {
            Invoke-SafeCommand "Applying curated compatibility repairs" {
                uv pip install --constraint $repairConstraints @curatedRepairs
            } -Optional | Out-Null
        }
        else {
            Write-Warn "Curated repairs were skipped because the complete candidate set was not resolvable."
        }
        Remove-Item $repairConstraints -Force -ErrorAction SilentlyContinue
    }

    if ((Test-DistributionInstalled "flash-attn") -and -not (Test-PythonImport "import flash_attn")) {
        Write-Warn "Flash Attention has a native-extension ABI failure."
        Remove-FlashAttention
    }
    if (-not (Test-PythonImport "import kornia")) {
        Remove-FlashAttention
    }
    if ($HARDWARE_BACKEND -eq "nvidia" -and (Test-DistributionInstalled "sageattention") -and -not (Test-SageAttention)) {
        Write-Warn "SageAttention failed verification; replacing it with $SAGEATTENTION_FALLBACK_VERSION."
        uv pip uninstall sageattention 2>$null | Out-Null
        Invoke-SafeCommand "Installing SageAttention $SAGEATTENTION_FALLBACK_VERSION fallback" {
            uv pip install --reinstall "sageattention==$SAGEATTENTION_FALLBACK_VERSION"
        } -Optional | Out-Null
    }

    $coreImportFailure = $false
    if (Test-PythonImport "import bz2") {
        Write-Success "Python standard-library bz2 import"
    }
    else {
        Write-Warn "Python cannot import bz2. Reinstall this Python version after installing bzip2 development support; no library workaround was created."
        $coreImportFailure = $true
    }
    if (Test-PythonImport "import torch, torchvision, torchaudio") {
        Write-Success "PyTorch, TorchVision, and TorchAudio imports"
    }
    else {
        Write-Warn "The managed PyTorch stack failed its runtime import probe."
        $coreImportFailure = $true
    }
    if ($HARDWARE_BACKEND -eq "rocm") {
        if (Test-AmdRocmTorch) {
            $amdDeviceName = (python -c "import torch; print(torch.cuda.get_device_name(0))" | Select-Object -First 1)
            Write-Success "AMD ROCm GPU runtime: $amdDeviceName"
        }
        else {
            Write-Warn "PyTorch reports ROCm, but the HIP runtime cannot access a supported AMD GPU."
            $coreImportFailure = $true
        }
    }
    if (Test-PythonImport "import kornia") {
        Write-Success "Kornia import"
    }
    else {
        Write-Warn "Kornia still fails to import without Flash Attention."
        $coreImportFailure = $true
    }
    if (Test-DistributionInstalled "nunchaku") {
        if (Test-PythonImport "import nunchaku") { Write-Success "Nunchaku import" }
        else { Write-Warn "Nunchaku is installed but failed its import probe." }
    }
    if (Test-DistributionInstalled "sageattention") {
        if (Test-SageAttention) { Write-Success "SageAttention verification" }
        else { Write-Warn "SageAttention remains unavailable; ComfyUI can use PyTorch attention." }
    }

    $pipAfter = @(uv pip check 2>&1)
    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip check is clean after curated repair"
    }
    else {
        Write-Warn "Remaining tolerated or irreconcilable dependency conflicts:"
        $pipAfter | ForEach-Object { Write-Host "   $_" }
        Write-Host "   No broad resolver was run; working custom-node ecosystems were left in place."
    }

    if ($coreImportFailure) {
        throw "Compatibility audit failed because a ComfyUI core runtime import is broken."
    }
    Write-Success "Compatibility audit completed; optional unresolved conflicts are listed above"
}

# ============================================================================
# Installation Complete
# ============================================================================
$COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

Write-Host ""
Write-Host ("=" * 67) -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host ("=" * 67) -ForegroundColor Green
Write-Host ""
$summaryTorchVersion = Get-InstalledDistributionVersion "torch"
$summaryNumpyVersion = Get-InstalledDistributionVersion "numpy"
$summaryTransformersVersion = Get-InstalledDistributionVersion "transformers"
Write-Host "Installed Environment Versions:"
Write-Host "  PyTorch: $summaryTorchVersion"
Write-Host "  NumPy: $summaryNumpyVersion"
Write-Host "  Transformers: $summaryTransformersVersion"
Write-Host ""
Write-Host "Environment: $VENV_PATH"
$comfyContextSelected = @((5, 6, 7, 8, 11) | Where-Object { $Steps[$_] }).Count -gt 0
if ($comfyContextSelected) {
    Write-Host "ComfyUI Location: $COMFYUI_DIR"
Write-Host "Directory Storage:"
Write-ComfyDirectoryState -Name "Models" -Path (Join-Path $COMFYUI_DIR "models") -Enabled $SYMLINK_MODELS
Write-ComfyDirectoryState -Name "Input" -Path (Join-Path $COMFYUI_DIR "input") -Enabled $SYMLINK_INPUT
Write-ComfyDirectoryState -Name "Output" -Path (Join-Path $COMFYUI_DIR "output") -Enabled $SYMLINK_OUTPUT
Write-ComfyDirectoryState -Name "User Data" -Path (Join-Path $COMFYUI_DIR "user") -Enabled $SYMLINK_USER
Write-ComfyDirectoryState -Name "Custom Nodes" -Path (Join-Path $COMFYUI_DIR "custom_nodes") -Enabled $SYMLINK_CUSTOM_NODES
} else {
    Write-Host "ComfyUI Checkout: not modified (configured location: $COMFYUI_DIR)"
}
Write-Host ""
Write-Host "Available start methods for the configured checkout:"
Write-Host ""

$launcherBat = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.bat"
$launcherPs1 = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.ps1"

if (Test-Path $launcherBat) {
    Write-Host "  Batch launcher: $launcherBat" -ForegroundColor White
}
if (Test-Path $launcherPs1) {
    Write-Host "  PowerShell launcher: $launcherPs1" -ForegroundColor White
}

if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match "function $COMFYUI_ALIAS\b") {
        Write-Host "  PowerShell alias (after reloading profile):" -ForegroundColor White
        if ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND -and $PIN_FRONTEND_VERSION_IN_ALIAS) {
            Write-Host "    $COMFYUI_ALIAS          # Pin frontend + launch ComfyUI"
        } elseif ($Manage.Frontend -and $INSTALL_COMFYUI_FRONTEND) {
            Write-Host "    $COMFYUI_ALIAS          # Launch ComfyUI (frontend managed)"
        } else {
            Write-Host "    $COMFYUI_ALIAS          # Launch ComfyUI (frontend unmanaged)"
        }
        Write-Host "    envact           # Activate env only"
        Write-Host ""
        Write-Host "  Manual activation:" -ForegroundColor White
    }
    else {
        Write-Host "  Manual activation:" -ForegroundColor White
    }
}
else {
    Write-Host "  Manual activation:" -ForegroundColor White
}
if ((Test-Path (Join-Path $VENV_PATH "Scripts\python.exe")) -and (Test-Path (Join-Path $COMFYUI_DIR "main.py"))) {
    Write-Host "    & `"$VENV_PATH\Scripts\Activate.ps1`"; cd `"$COMFYUI_DIR`"; python main.py $COMFYUI_LAUNCH_ARGS"
} else {
    Write-Host "  No verified launcher for the configured checkout was found in this run."
}
Write-Host ""

Save-InstallerDefaults
Write-Host ""
Read-Host "Press Enter to exit"
}
finally {
    if ($null -eq $ORIGINAL_UV_EXCLUDE) {
        Remove-Item Env:UV_EXCLUDE -ErrorAction SilentlyContinue
    } else {
        $env:UV_EXCLUDE = $ORIGINAL_UV_EXCLUDE
    }
    if ($PACKAGE_EXCLUDE_FILE -and (Test-Path $PACKAGE_EXCLUDE_FILE)) {
        Remove-Item $PACKAGE_EXCLUDE_FILE -Force -ErrorAction SilentlyContinue
    }
}
