# ComfyUI Environment Installation Script for Windows (PowerShell)
# Installs packages in specific order to avoid dependency conflicts
#
# Usage: Run in PowerShell 5.1+ or PowerShell 7+
#   .\install_comfy_env.ps1
#
# Requirements:
#   - Windows 10/11
#   - Git installed and in PATH
#   - Internet connection
#   - NVIDIA GPU with CUDA support (for GPU acceleration)
#
# Note: Run PowerShell as Administrator if you want to create directory symlinks.
#       Without admin, the script uses directory junctions (which work for most cases).

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ============================================
# Configuration Variables - Adjust as needed
# ============================================

# Base directory configuration
# All paths will be derived from this base path
$BASE_PATH = "D:\AI"                          # Parent directory for ComfyUI, venv, models, input, output, user, custom_nodes

# Recommended Python versions: 3.10.x, 3.11.x, 3.12.x, 3.13.x, 3.14.x
# These versions have prebuilt wheels for PyTorch, nunchaku, and flash-attn
$PYTHON_VERSION = "3.12.10"                   # Python version to install via pyenv-win

# PyTorch version configuration
$PYTORCH_VERSION = "2.9"                      # PyTorch major.minor version for wheel URLs (e.g., 2.9, 2.10)
$PYTORCH_FULL_VERSION = "2.9.1+cu128"         # Full PyTorch version for package installation
$PYTORCH_INDEX_URL = "https://download.pytorch.org/whl/cu128"  # PyTorch index URL (cu128, cu121, cpu)

# Critical package versions (enforced at end to override custom node dependencies)
$NUMPY_VERSION = "2.2.6"                      # NumPy version (2.2.x compatible with PyTorch 2.9+)
$TRANSFORMERS_VERSION = "4.57.3"              # Transformers version
$COMFYUI_FRONTEND_VERSION = "1.45.21"         # Default ComfyUI frontend version (overridden by interactive prompt)

# ComfyUI installation defaults (overridden by interactive prompts below)
$DEFAULT_COMFYUI_VERSION = "0.28.0"            # Default ComfyUI version (numeric, e.g., 0.28.0)
$DEFAULT_FRONTEND_VERSION = $COMFYUI_FRONTEND_VERSION  # Default frontend version
$DEFAULT_ALIAS = "comfy"                       # Alias base; auto-increments when the prompt is left empty
$COMFYUI_LAUNCH_ARGS = "--disable-pinned-memory"  # Arguments appended to python main.py

# Shared-directory configuration (set individual paths to $false to keep them local)
$SYMLINK_MODELS = $true                       # Share models across ComfyUI installations
$SYMLINK_INPUT = $true                        # Share input across ComfyUI installations
$SYMLINK_OUTPUT = $true                       # Share output across ComfyUI installations
$SYMLINK_USER = $true                         # Share user settings, workflows, and templates
$SYMLINK_CUSTOM_NODES = $true                 # Share custom_nodes across ComfyUI installations

# Optional features
$INSTALL_NUNCHAKU = $false                    # Set to $false to skip Nunchaku (NVIDIA GPU required)
$INSTALL_COMFYUI_FRONTEND = $true             # Set to $false to preserve a custom/existing frontend package

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

    if ((Test-Path (Join-Path $COMFYUI_PARENT_DIR "$Candidate.bat")) -or
        (Test-Path (Join-Path $COMFYUI_PARENT_DIR "$Candidate.ps1"))) {
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

function Install-UvRequirements {
    param(
        [string]$RequirementsFile,
        [string]$ConstraintFile
    )

    $installRequirements = $RequirementsFile
    $filteredRequirements = $null
    try {
        if (-not $INSTALL_COMFYUI_FRONTEND) {
            $filteredRequirements = [System.IO.Path]::GetTempFileName()
            $filteredLines = @(
                Get-Content $RequirementsFile | Where-Object {
                    $_ -notmatch '^\s*comfyui[-_.]frontend[-_.]package(?:[^A-Za-z0-9_-].*)?$'
                }
            )
            [System.IO.File]::WriteAllLines($filteredRequirements, [string[]]$filteredLines)
            $installRequirements = $filteredRequirements
        }

        if ([string]::IsNullOrWhiteSpace($ConstraintFile)) {
            uv pip install -r $installRequirements
        } else {
            uv pip install --constraint $ConstraintFile -r $installRequirements
        }
    }
    finally {
        if ($filteredRequirements -and (Test-Path $filteredRequirements)) {
            Remove-Item $filteredRequirements -Force -ErrorAction SilentlyContinue
        }
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
    if (Test-Path (Join-Path $repoPath ".git")) {
        Write-Success "$repoName already exists"
    }
    else {
        Write-Step "Cloning $repoName..."
        # Don't redirect stderr (2>&1) — git writes progress to stderr and
        # PowerShell with $ErrorActionPreference="Stop" treats it as a
        # terminating error.  Without redirection stderr flows directly to
        # the console and $LASTEXITCODE still catches real failures.
        git clone $RepoUrl
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to clone $repoName"
        }
    }
}

# ============================================
# Interactive Prompts — collect per-install values
# ============================================
# These change frequently when testing new ComfyUI versions.
# Static config (Python, PyTorch, numpy, transformers) stays at the top of the script.
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "ComfyUI Environment Setup (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Enter values for this installation (press Enter for defaults):" -ForegroundColor White
Write-Host ""

$INPUT_COMFYUI_VERSION = Read-Host "  ComfyUI version [$DEFAULT_COMFYUI_VERSION]"
if ([string]::IsNullOrWhiteSpace($INPUT_COMFYUI_VERSION)) { $INPUT_COMFYUI_VERSION = $DEFAULT_COMFYUI_VERSION }

if ($INSTALL_COMFYUI_FRONTEND) {
    $INPUT_FRONTEND_VERSION = Read-Host "  Frontend version [$DEFAULT_FRONTEND_VERSION]"
    if ([string]::IsNullOrWhiteSpace($INPUT_FRONTEND_VERSION)) { $INPUT_FRONTEND_VERSION = $DEFAULT_FRONTEND_VERSION }
} else {
    $INPUT_FRONTEND_VERSION = ""
}

$SUGGESTED_ALIAS = Get-NextComfyAliasName
$INPUT_ALIAS = Read-Host "  Launcher name [$SUGGESTED_ALIAS]"
if ([string]::IsNullOrWhiteSpace($INPUT_ALIAS)) { $INPUT_ALIAS = $SUGGESTED_ALIAS }

Write-Host ""

# Derive all values from inputs
$COMFYUI_VERSION = "v$INPUT_COMFYUI_VERSION"                               # e.g., v0.18.0
$COMFYUI_DIR_NAME = "ComfyUI_$INPUT_COMFYUI_VERSION"                          # e.g., ComfyUI_0.18.2 (full version)
$COMFYUI_FRONTEND_VERSION = $INPUT_FRONTEND_VERSION                         # e.g., 1.41.21
$COMFYUI_ALIAS = $INPUT_ALIAS                                              # e.g., comfyui or comfy2
$COMFYUI_WAS_CLONED = $false                                               # Set after a new clone completes in this run

# Exclude the official frontend package from every uv resolution when the user
# manages a custom frontend. This also covers ComfyUI/custom-node requirements.
$FRONTEND_EXCLUDE_FILE = $null
$ORIGINAL_UV_EXCLUDE = [Environment]::GetEnvironmentVariable("UV_EXCLUDE", "Process")
if (-not $INSTALL_COMFYUI_FRONTEND) {
    $FRONTEND_EXCLUDE_FILE = [System.IO.Path]::GetTempFileName()
    "comfyui-frontend-package" | Set-Content $FRONTEND_EXCLUDE_FILE -Encoding ASCII
    if ([string]::IsNullOrWhiteSpace($ORIGINAL_UV_EXCLUDE)) {
        $env:UV_EXCLUDE = $FRONTEND_EXCLUDE_FILE
    } else {
        $env:UV_EXCLUDE = "$ORIGINAL_UV_EXCLUDE $FRONTEND_EXCLUDE_FILE"
    }
}

try {

# ============================================
# Configuration Summary
# ============================================
Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "Configuration:"
if ($COMFYUI_VERSION) {
    Write-Host "  ComfyUI Version: $COMFYUI_VERSION"
} else {
    Write-Host "  ComfyUI Version: Latest (default branch)"
}
if ($INSTALL_COMFYUI_FRONTEND) {
    Write-Host "  ComfyUI Frontend Version: $COMFYUI_FRONTEND_VERSION"
} else {
    Write-Host "  ComfyUI Frontend: Unmanaged (preserving custom/existing package)"
}
Write-Host "  Python Version: $PYTHON_VERSION"
Write-Host "  PyTorch Version: $PYTORCH_FULL_VERSION (torchvision/torchaudio auto-selected)"
Write-Host "  NumPy Version: $NUMPY_VERSION"
Write-Host "  Transformers Version: $TRANSFORMERS_VERSION"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion.ToString())"
if ($INSTALL_NUNCHAKU) {
    Write-Host "  Nunchaku: Enabled"
} else {
    Write-Host "  Nunchaku: Disabled (custom node will be skipped)"
}
Write-Host ""
Write-Host "  Base Path: $BASE_PATH"
Write-Host "  ComfyUI Location: $COMFYUI_PARENT_DIR\$COMFYUI_DIR_NAME"
Write-Host "  Virtual Env: $VENV_PATH"
Write-Host "  Launcher: $COMFYUI_ALIAS (batch file + PS alias)"
Write-Host "  Launch Arguments: $(if ([string]::IsNullOrWhiteSpace($COMFYUI_LAUNCH_ARGS)) { "None" } else { $COMFYUI_LAUNCH_ARGS })"
Write-Host ""
Write-Host "  Directory Sharing:"
Write-Host "    Models:       $(if ($SYMLINK_MODELS) { "Shared ($USER_MODELS_PATH)" } else { "Local" })"
Write-Host "    Input:        $(if ($SYMLINK_INPUT) { "Shared ($USER_INPUT_PATH)" } else { "Local" })"
Write-Host "    Output:       $(if ($SYMLINK_OUTPUT) { "Shared ($USER_OUTPUT_PATH)" } else { "Local" })"
Write-Host "    User Data:    $(if ($SYMLINK_USER) { "Shared ($USER_USERDATA_PATH)" } else { "Local" })"
Write-Host "    Custom Nodes: $(if ($SYMLINK_CUSTOM_NODES) { "Shared ($USER_CUSTOM_NODES_PATH)" } else { "Local" })"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

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
Write-Host ""
Write-Host "   a) All steps (default)"
Write-Host ""
$STEP_SELECTION = Read-Host "Your selection [a]"
if ([string]::IsNullOrWhiteSpace($STEP_SELECTION)) { $STEP_SELECTION = "a" }
# Normalize commas to spaces so "5,11" and "5 11" both work
$STEP_SELECTION = $STEP_SELECTION -replace ',', ' '

# Initialize step flags
$Steps = @{}
for ($i = 1; $i -le 11; $i++) { $Steps[$i] = $false }

if ($STEP_SELECTION -eq "a") {
    for ($i = 1; $i -le 11; $i++) { $Steps[$i] = $true }
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
        if ([int]::TryParse("$num", [ref]$n) -and $n -ge 1 -and $n -le 11) {
            $Steps[$n] = $true
        }
        else {
            Write-Warn "Unknown option: $num"
        }
    }
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
}
foreach ($i in 1..11) {
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

# ============================================
# Activate existing venv if present (for steps 2-10 without step 1)
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
# [1/11] Python Environment Setup
# ============================================================================
if ($Steps[1]) {

    Write-Header "[1/11] Setting up Python Environment"

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
# [2/11] Install PyTorch
# ============================================================================
if ($Steps[2]) {

    Write-Header "[2/11] Installing PyTorch and Base Dependencies"

    Write-Step "Installing PyTorch ${PYTORCH_FULL_VERSION}..."
    uv pip install "torch==$PYTORCH_FULL_VERSION" torchvision torchaudio --index-url $PYTORCH_INDEX_URL
}

# ============================================================================
# [3/11] Install Nunchaku
# ============================================================================
if ($Steps[3]) {

    Write-Header "[3/11] Installing Nunchaku Acceleration Library"

    $PYTHON_WHEEL_TAG = $script:PYTHON_WHEEL_TAG
    Write-Step "Installing nunchaku 1.2.1 for PyTorch ${PYTORCH_VERSION} (Python ${PYTHON_WHEEL_TAG})..."
    $NUNCHAKU_WHEEL = "https://github.com/nunchaku-ai/nunchaku/releases/download/v1.2.1/nunchaku-1.2.1+cu12.8torch${PYTORCH_VERSION}-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-win_amd64.whl"

    try {
        uv pip install $NUNCHAKU_WHEEL
    }
    catch {
        Write-Warn "Prebuilt nunchaku wheel not found for PyTorch ${PYTORCH_VERSION} / Python ${PYTHON_WHEEL_TAG}"
        Write-Step "Trying to install from source or latest compatible version..."
        try {
            uv pip install nunchaku
        }
        catch {
            Write-Warn "Nunchaku installation failed (optional)"
        }
    }
}

# ============================================================================
# [4/11] Install Face Recognition and Runtime Libraries
# ============================================================================
if ($Steps[4]) {

    Write-Header "[4/11] Installing Face Recognition and Runtime Libraries"

    # Create temporary constraints file to prevent torch downgrade
    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
numpy>=$NUMPY_VERSION
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
# [5/11] Install ComfyUI
# ============================================================================
if ($Steps[5]) {

    Write-Header "[5/11] Installing ComfyUI Core"

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
numpy>=$NUMPY_VERSION
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

Set-ComfyDirectorySharing -Name "Models" -LocalPath (Join-Path $COMFYUI_DIR "models") -SharedPath $USER_MODELS_PATH -Enabled $SYMLINK_MODELS -NewInstall $COMFYUI_WAS_CLONED
Set-ComfyDirectorySharing -Name "Input" -LocalPath (Join-Path $COMFYUI_DIR "input") -SharedPath $USER_INPUT_PATH -Enabled $SYMLINK_INPUT -NewInstall $COMFYUI_WAS_CLONED
Set-ComfyDirectorySharing -Name "Output" -LocalPath (Join-Path $COMFYUI_DIR "output") -SharedPath $USER_OUTPUT_PATH -Enabled $SYMLINK_OUTPUT -NewInstall $COMFYUI_WAS_CLONED
Set-ComfyDirectorySharing -Name "User Data" -LocalPath (Join-Path $COMFYUI_DIR "user") -SharedPath $USER_USERDATA_PATH -Enabled $SYMLINK_USER -NewInstall $COMFYUI_WAS_CLONED
Set-ComfyDirectorySharing -Name "Custom Nodes" -LocalPath (Join-Path $COMFYUI_DIR "custom_nodes") -SharedPath $USER_CUSTOM_NODES_PATH -Enabled $SYMLINK_CUSTOM_NODES -NewInstall $COMFYUI_WAS_CLONED

# ============================================================================
# [6/11] Clone Custom Nodes
# ============================================================================
if ($Steps[6]) {

    Write-Header "[6/11] Cloning Custom Nodes"

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
    Copy-IfMissing "https://github.com/r-vage/ComfyUI-Raffle"
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
    Copy-IfMissing "https://github.com/Lightricks/ComfyUI-LTXVideo"

    Pop-Location
}

# ============================================================================
# [7/11] Install Custom Node Dependencies
# ============================================================================
if ($Steps[7]) {

    Write-Header "[7/11] Installing Custom Node Dependencies"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME
    $CUSTOM_NODES_DIR = Join-Path $COMFYUI_DIR "custom_nodes"

    # Create temporary constraints file
    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
numpy>=$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
numba>=0.58.0
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    Write-Host "Using constraints to prevent torch/numpy/transformers downgrade"
    Write-Host ""

    $nodeDirs = Get-ChildItem $CUSTOM_NODES_DIR -Directory -ErrorAction SilentlyContinue
    foreach ($nodeDir in $nodeDirs) {
        $reqFile = Join-Path $nodeDir.FullName "requirements.txt"
        if (Test-Path $reqFile) {
            Write-Host ""
            Invoke-SafeCommand "Installing dependencies for: $($nodeDir.Name)" {
                Install-UvRequirements -RequirementsFile $reqFile -ConstraintFile $CONSTRAINTS_FILE
            } -Optional
        }
    }

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [8/11] Install Performance Libraries
# ============================================================================
if ($Steps[8]) {

    Write-Header "[8/11] Installing Performance Libraries"

    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
numpy>=$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    # Install llama-cpp-python
    Invoke-SafeCommand "Installing llama-cpp-python" {
        uv pip install --constraint $CONSTRAINTS_FILE "llama-cpp-python>=0.3.16"
    } -Optional

    # Flash Attention - try prebuilt wheel from Eclipse releases first, then PyPI
    $PYTHON_WHEEL_TAG = $script:PYTHON_WHEEL_TAG
    # Extract CUDA version from index URL (e.g., "cu128" from ".../whl/cu128")
    $CUDA_VERSION = ($PYTORCH_INDEX_URL -split '/')[-1]
    $FLASH_ATTN_VERSION = "2.8.3"
    $FLASH_ATTN_WHEEL = "https://github.com/r-vage/ComfyUI_Eclipse/releases/download/wheels/flash_attn-${FLASH_ATTN_VERSION}+${CUDA_VERSION}torch${PYTORCH_VERSION}-${PYTHON_WHEEL_TAG}-${PYTHON_WHEEL_TAG}-win_amd64.whl"

    Write-Host ""
    Write-Step "Attempting Flash Attention from prebuilt wheel (${PYTHON_WHEEL_TAG}, ${CUDA_VERSION}, torch${PYTORCH_VERSION})..."
    $flashInstalled = Invoke-SafeCommand "Installing flash-attn ${FLASH_ATTN_VERSION} (prebuilt wheel)" {
        uv pip install --constraint $CONSTRAINTS_FILE $FLASH_ATTN_WHEEL
    } -Optional

    if (-not $flashInstalled) {
        Write-Step "Prebuilt wheel not available for this configuration. Trying PyPI..."
        $flashInstalled = Invoke-SafeCommand "Installing flash-attn from PyPI (may require Visual Studio Build Tools)" {
            uv pip install --constraint $CONSTRAINTS_FILE flash-attn --no-build-isolation
        } -Optional
    }

    if (-not $flashInstalled) {
        Write-Warn "Flash Attention could not be installed automatically."
        Write-Host "   You can find prebuilt wheels for other configurations at:"
        Write-Host "   https://github.com/r-vage/ComfyUI_Eclipse/releases/tag/wheels"
        Write-Host "   https://github.com/mjun0812/flash-attention-prebuild-wheels/releases"
        Write-Host "   Download the matching .whl file and install with:  uv pip install <path-to-wheel>"
    }

    # SageAttention
    Write-Host ""
    Invoke-SafeCommand "Installing Sage Attention" {
        uv pip install --constraint $CONSTRAINTS_FILE sageattention
    } -Optional

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [9/11] Upgrade & Pin Package Versions
# ============================================================================
if ($Steps[9]) {

    Write-Header "[9/11] Upgrading & Pinning Package Versions"

    $CONSTRAINTS_FILE = [System.IO.Path]::GetTempFileName()
    @"
torch==$PYTORCH_FULL_VERSION
numpy>=$NUMPY_VERSION
transformers==$TRANSFORMERS_VERSION
"@ | Set-Content $CONSTRAINTS_FILE -Encoding UTF8

    Write-Step "Upgrading packages to latest versions..."
    $upgradePackages = @("av", "ultralytics", "onnxruntime", "onnxruntime-gpu", "opencv-python", "gguf")
    foreach ($pkg in $upgradePackages) {
        Invoke-SafeCommand "Upgrading $pkg" {
            uv pip install --constraint $CONSTRAINTS_FILE --upgrade $pkg
        } -Optional
    }

    # Optional upgrades
    foreach ($pkg in @("inference", "inference-gpu", "inference-cli")) {
        Invoke-SafeCommand "Upgrading $pkg" {
            uv pip install --constraint $CONSTRAINTS_FILE --upgrade $pkg
        } -Optional
    }

    Write-Step "Pinning critical package versions..."
    uv pip install "mistral-common>=1.8.6"
    uv pip install "numpy>=$NUMPY_VERSION"
    uv pip install "transformers==$TRANSFORMERS_VERSION"

    Remove-Item $CONSTRAINTS_FILE -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# [10/11] Enforce Configured Package Versions
# ============================================================================
if ($Steps[10]) {

    Write-Header "[10/11] Enforcing Configured Package Versions"

    Write-Host "Note: Custom nodes may have installed incompatible versions."
    if ($INSTALL_COMFYUI_FRONTEND) {
        Write-Host "      Ensuring PyTorch ${PYTORCH_FULL_VERSION}, NumPy ${NUMPY_VERSION}, Transformers ${TRANSFORMERS_VERSION}, Frontend ${COMFYUI_FRONTEND_VERSION}"
    } else {
        Write-Host "      Ensuring PyTorch ${PYTORCH_FULL_VERSION}, NumPy ${NUMPY_VERSION}, and Transformers ${TRANSFORMERS_VERSION}"
        Write-Host "      Leaving the ComfyUI frontend unmanaged"
    }
    Write-Host ""

    # Ensure PyTorch
    Invoke-SafeCommand "Enforcing PyTorch $PYTORCH_FULL_VERSION" {
        uv pip install "torch==$PYTORCH_FULL_VERSION" torchvision torchaudio --index-url $PYTORCH_INDEX_URL
    } -Optional

    # Ensure NumPy
    Invoke-SafeCommand "Enforcing NumPy $NUMPY_VERSION" {
        uv pip install "numpy==$NUMPY_VERSION"
    } -Optional

    # Ensure Transformers
    Invoke-SafeCommand "Enforcing Transformers $TRANSFORMERS_VERSION" {
        uv pip install "transformers==$TRANSFORMERS_VERSION"
    } -Optional

    # Ensure ComfyUI Frontend when managed
    if ($INSTALL_COMFYUI_FRONTEND) {
        Invoke-SafeCommand "Enforcing ComfyUI Frontend $COMFYUI_FRONTEND_VERSION" {
            uv pip install "comfyui-frontend-package==$COMFYUI_FRONTEND_VERSION"
        } -Optional
    } else {
        Write-Host "   Skipping ComfyUI frontend enforcement (INSTALL_COMFYUI_FRONTEND = `$false)"
    }

    Write-Success "Package versions enforced successfully"
}

# ============================================================================
# [11/11] Create Launcher Scripts and PowerShell Aliases
# ============================================================================
if ($Steps[11]) {

    Write-Header "[11/11] Creating Launcher Scripts and PowerShell Aliases"

    $COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

    # --- Create per-version .bat launcher (named after alias, e.g., comfyui.bat, comfy2.bat) ---
    $launcherBat = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.bat"
    $frontendBatSetup = if ($INSTALL_COMFYUI_FRONTEND) {
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
    $frontendPsSetup = if ($INSTALL_COMFYUI_FRONTEND) {
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
        if (-not $INSTALL_COMFYUI_FRONTEND) {
            Write-Warn "Existing function may still pin the frontend; remove it and rerun step 11 to regenerate it"
        }
        if (-not [string]::IsNullOrWhiteSpace($COMFYUI_LAUNCH_ARGS)) {
            Write-Warn "Existing function may not include the configured launch arguments; remove it and rerun step 11 to regenerate it"
        }
    } else {
        $frontendFunctionSetup = if ($INSTALL_COMFYUI_FRONTEND) {
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
    if ($INSTALL_COMFYUI_FRONTEND) {
        Write-Host "  - $COMFYUI_ALIAS : activate environment, pin frontend, launch ComfyUI"
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
# Installation Complete
# ============================================================================
$COMFYUI_DIR = Join-Path $COMFYUI_PARENT_DIR $COMFYUI_DIR_NAME

Write-Host ""
Write-Host ("=" * 67) -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host ("=" * 67) -ForegroundColor Green
Write-Host ""
Write-Host "Installed Versions:"
Write-Host "  PyTorch: $PYTORCH_FULL_VERSION (with compatible torchvision/torchaudio)"
Write-Host "  NumPy: $NUMPY_VERSION"
Write-Host "  Transformers: $TRANSFORMERS_VERSION"
Write-Host ""
Write-Host "Environment: $VENV_PATH"
Write-Host "ComfyUI Location: $COMFYUI_DIR"
Write-Host "Directory Storage:"
Write-ComfyDirectoryState -Name "Models" -Path (Join-Path $COMFYUI_DIR "models") -Enabled $SYMLINK_MODELS
Write-ComfyDirectoryState -Name "Input" -Path (Join-Path $COMFYUI_DIR "input") -Enabled $SYMLINK_INPUT
Write-ComfyDirectoryState -Name "Output" -Path (Join-Path $COMFYUI_DIR "output") -Enabled $SYMLINK_OUTPUT
Write-ComfyDirectoryState -Name "User Data" -Path (Join-Path $COMFYUI_DIR "user") -Enabled $SYMLINK_USER
Write-ComfyDirectoryState -Name "Custom Nodes" -Path (Join-Path $COMFYUI_DIR "custom_nodes") -Enabled $SYMLINK_CUSTOM_NODES
Write-Host ""
Write-Host "To start ComfyUI:"
Write-Host ""

$launcherBat = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.bat"
$launcherPs1 = Join-Path $COMFYUI_PARENT_DIR "$COMFYUI_ALIAS.ps1"

Write-Host "  Option 1 - Double-click batch launcher:" -ForegroundColor White
Write-Host "    $launcherBat"
Write-Host ""
Write-Host "  Option 2 - PowerShell launcher:" -ForegroundColor White
Write-Host "    $launcherPs1"
Write-Host ""

if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match "function $COMFYUI_ALIAS\b") {
        Write-Host "  Option 3 - PowerShell alias (after reloading profile):" -ForegroundColor White
        if ($INSTALL_COMFYUI_FRONTEND) {
            Write-Host "    $COMFYUI_ALIAS          # Pin frontend + launch ComfyUI"
        } else {
            Write-Host "    $COMFYUI_ALIAS          # Launch ComfyUI (frontend unmanaged)"
        }
        Write-Host "    envact           # Activate env only"
        Write-Host ""
        Write-Host "  Option 4 - Manual activation:" -ForegroundColor White
    }
    else {
        Write-Host "  Option 3 - Manual activation:" -ForegroundColor White
    }
}
else {
    Write-Host "  Option 3 - Manual activation:" -ForegroundColor White
}
Write-Host "    & `"$VENV_PATH\Scripts\Activate.ps1`"; cd `"$COMFYUI_DIR`"; python main.py $COMFYUI_LAUNCH_ARGS"
Write-Host ""

Read-Host "Press Enter to exit"
}
finally {
    if ($null -eq $ORIGINAL_UV_EXCLUDE) {
        Remove-Item Env:UV_EXCLUDE -ErrorAction SilentlyContinue
    } else {
        $env:UV_EXCLUDE = $ORIGINAL_UV_EXCLUDE
    }
    if ($FRONTEND_EXCLUDE_FILE -and (Test-Path $FRONTEND_EXCLUDE_FILE)) {
        Remove-Item $FRONTEND_EXCLUDE_FILE -Force -ErrorAction SilentlyContinue
    }
}
