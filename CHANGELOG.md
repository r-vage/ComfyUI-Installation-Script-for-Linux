# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.2] - 2026-08-07

### Added
- Independent `PIN_FRONTEND_VERSION_IN_ALIAS` control for enabling or disabling launch-time frontend pinning in generated Bash, Zsh, Fish, and PowerShell profile aliases while keeping installation-time frontend management enabled

### Changed
- PyTorch configuration now separates the base `PYTORCH_VERSION` from `PYTORCH_WHEEL_VARIANT`; both installers derive the index URL and compatible TorchVision and TorchAudio versions from those settings
- Compatibility maps now cover stable PyTorch releases through `2.13.0` and reject unavailable version/channel combinations before installation; Torch `2.12+` correctly uses the forward-compatible final TorchAudio `2.11.0` release

### Fixed
- Linux and Windows installation and dependency constraints now enforce matching `torch 2.9.1+cu128`, `torchvision 0.24.1+cu128`, and `torchaudio 2.9.1+cu128` builds to prevent native-extension ABI errors

**Changed files:** `install_comfy_env.sh`, `install_comfy_env_win.ps1`, `README.md`, `CHANGELOG.md`, `pyproject.toml`

---

## [0.12.1] - 2026-08-06

### Fixed
- New ComfyUI checkout files missing from shared directories are merged without overwriting existing files before enabled checkout folders are removed and replaced by symlinks or junctions
- Previous incomplete sharing setups are repaired when their local folders still contain only pristine ComfyUI checkout files

**Changed files:** `install_comfy_env.sh`, `install_comfy_env_win.ps1`, `README.md`, `CHANGELOG.md`, `pyproject.toml`

---

## [0.12.0] - 2026-08-06

### Added
- Optional frontend management through `INSTALL_COMFYUI_FRONTEND` on Linux and Windows
- Independent sharing controls for `models`, `input`, `output`, `user`, and `custom_nodes`
- Actual shared/local directory state in the installation summary
- Configurable `COMFYUI_LAUNCH_ARGS`, applied to every generated alias and launcher
- Automatic default alias selection (`comfy`, `comfy1`, `comfy2`, ...) when the alias prompt is left empty
- New custom nodes: `comfyui-krea2edit`, `ComfyUI-Krea2T-Enhancer`, `ComfyUI-CorridorKey`, `ComfyUI_Fill-Nodes`, `ComfyUI-TiledDiffusion`, and `WhatDreamsCost-ComfyUI`

### Changed
- Default ComfyUI version: `0.23.0` → `0.28.0` (Linux + Windows)
- Default frontend version: `1.44.19` → `1.45.21` (Linux + Windows)
- Frontend management can be disabled without ComfyUI or custom-node requirements reinstalling `comfyui-frontend-package`
- Directory migration now copies populated local data only into an empty shared target and preserves both locations when they conflict
- Existing links are preserved with a warning when sharing is disabled
- `ComfyUI_PuLID_Flux_ll` now clones from the `r-vage` fork
- Custom-node documentation and repository links synchronized with the shared `custom_nodes` installation

### Removed
- Global `CREATE_SYMLINKS` switch, replaced by the five independent `SYMLINK_*` settings
- Standalone `ComfyUI-GGUF` and `ComfyUI-Florence2` clones, because Eclipse supplies them through its external-node integration

### Fixed
- Prevented populated local model, input, output, user, or custom-node directories from being silently removed during sharing setup
- Generated aliases and launchers no longer overwrite a custom frontend when frontend management is disabled
- Linux alias setup no longer exits early when a shell configuration contains no existing ComfyUI aliases

**Changed files:** `install_comfy_env.sh`, `install_comfy_env_win.ps1`, `README.md`, `CHANGELOG.md`, `pyproject.toml`

---

## [0.11.3] - 2026-06-03

### Added
- New **Audio & Media** clone category: `ComfyUI-MMAudio`, `ComfyUI-MelBandRoFormer`, `comfyui-audio-expo`
- New nodes: `ComfyUI-DaSiWa-Nodes`, `comfyui-find-perfect-resolution`, `Nvidia_RTX_Nodes_ComfyUI`, `comfyui-WhiteRabbit`, `ComfyUI-SCAIL-Pose`, `ComfyUI-YOLO`, `ComfyUI-VFI`, `ComfyUI-WanAnimatePreprocess`, `ComfyUI-LTXVideo`

### Removed
- Deprecated `ComfyUI_SmartLML` (superseded by Eclipse)
- `ComfyUI-nunchaku` conditional clone block
- `ComfyUI_IPAdapter_plus`, `Comfyui_TTP_Toolset`, `ComfyUI-VAE-Utils`, `was-node-suite-comfyui`, `comfy_mtb`, `ComfyUI-ReActor`

### Changed
- Updated fork URLs to upstream where applicable: `rgthree-comfy`, `ComfyUI-TeaCache`, `ComfyUI_Patches_ll`, `ComfyUI-Raffle`, `ComfyUI-Crystools-MonitorOnly`

**Changed files:** `install_comfy_env.sh`, `install_comfy_env_win.ps1`

---

## [0.11.2] - 2026-06-03

### Fixed
- Step selection now accepts comma-separated input (e.g. `5,11` or `1,5,6-8`) in addition to space-separated and ranges (Linux + Windows)

### Changed
- Default ComfyUI version: `0.19.3` → `0.23.0` (Linux + Windows)
- Default frontend version: `1.42.11` → `1.44.19` (Linux + Windows)

**Changed files:** `install_comfy_env.sh`, `install_comfy_env_win.ps1`

---

## [0.11.0] - 2026-04-30

### Added
- Shared `input/` folder across ComfyUI installations (`USER_INPUT_PATH`)
- Shared `user/` folder (settings, workflows, templates) across ComfyUI installations (`USER_USERDATA_PATH`)
  — cross-version safe: `comfy.settings.json` is merged against frontend defaults at runtime
- `pyproject.toml` with project metadata for ComfyUI Registry compatibility
- This `CHANGELOG.md`

### Changed
- Default ComfyUI version: `0.18.0` → `0.19.3`
- Default frontend version: `1.41.21` → `1.42.11` (Linux); `1.39.14` → `1.42.11` (Windows)

## [0.10.0] - 2026-04-03

### Added
- Step range selection (e.g. `6-10` or `1 5 6-8`) for partial re-runs

### Fixed
- Use full version (e.g. `0.18.2`) in ComfyUI folder name instead of major.minor only
- `UV_LINK_MODE=copy` exported at top of script to suppress hardlink warnings

### Changed
- README updates

## [0.9.0] - 2026-04-03

### Added
- Interactive prompts for ComfyUI version, frontend version, launcher alias
- Frontend version pinning to specific release
- Lowercase folder cloning
- Custom node list synchronization

## [0.8.0] - 2026-02-27

### Added
- PowerShell installation script for Windows (`install_comfy_env_win.ps1`)

### Fixed
- Suppress `git clone` stderr noise
- Use prebuilt flash-attn wheels instead of source compilation

## [0.7.0] - 2026-02-12

### Changed
- Centralized `BASE_PATH` configuration — single variable derives all paths
- Reorganized configuration summary output for better readability

## [0.6.0] - 2026-02-11

### Added
- `uv` package manager integration for faster pip operations
- Python 3.12 compatibility fixes

### Fixed
- `dnf5` compatibility for Fedora 43+
- Handle existing pyenv installations without re-prompting

## [0.5.0] - 2026-02-11

### Added
- Frontend version pinning support
- Symlink support for `custom_nodes/` (shared across installations)
- Documentation for multiple parallel ComfyUI installations

### Fixed
- Quoting and copy syntax for `custom_nodes` symlink
- Error handling for `custom_nodes` copy operations

## [0.4.0] - 2026-02-11

### Added
- ComfyUI version selection feature
- Version comparison logic with fallback for unresolvable versions

## [0.3.0] - 2026-02-09

### Changed
- Only clone `ComfyUI-nunchaku` when `INSTALL_NUNCHAKU=true`
- Moved nodes into correct category (video processing)

## [0.2.0] - 2026-02-09

### Changed
- README update

## [0.1.0] - 2026-02-09

### Added
- Initial release — Linux bash installer for isolated ComfyUI environments
- Pyenv + venv setup with PyTorch, transformers, numpy version pinning
- Symlinks for shared `models/` and `output/` folders
