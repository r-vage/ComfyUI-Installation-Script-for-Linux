#!/bin/bash
# g810-led Installation and Configuration Script
# Installs g810-led and sets up LED profile
# Supports Fedora/RHEL (via Copr) and Debian/Ubuntu/Mint (build from source)

set -e  # Exit on error

echo "========================================="
echo "g810-led Installation & Setup"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Please run this script as a normal user (not root)"
   echo "You'll be prompted for sudo password when needed"
   exit 1
fi

# Detect package manager and OS
echo "Detecting operating system..."
if command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt-get"
    OS_TYPE="debian"
    echo "Detected: Debian/Ubuntu/Mint"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    OS_TYPE="fedora"
    echo "Detected: Fedora/RHEL"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    OS_TYPE="fedora"
    echo "Detected: CentOS/RHEL"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    OS_TYPE="arch"
    echo "Detected: Arch Linux"
else
    echo "Error: Unsupported package manager"
    echo "This script supports Debian/Ubuntu/Mint, Fedora/RHEL, and Arch Linux"
    exit 1
fi
echo ""

# Install g810-led based on OS
echo "Step 1: Installing g810-led..."
echo ""

if [ "$OS_TYPE" = "fedora" ]; then
    # Fedora/RHEL: Use Copr repository
    echo "Installing from Copr repository..."
    sudo $PKG_MANAGER copr enable lkiesow/g810-led -y
    sudo $PKG_MANAGER install g810-led -y
    
elif [ "$OS_TYPE" = "debian" ]; then
    # Debian/Ubuntu/Mint: Build from source
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y git build-essential libhidapi-dev libusb-1.0-0-dev
    
    echo "Cloning g810-led repository..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    git clone https://github.com/MatMoul/g810-led.git
    cd g810-led
    
    echo "Applying C++11 compatibility fix..."
    # Fix enum syntax for modern C++ compilers - convert to old-style enum
    cat > /tmp/fix_enum.patch << 'ENDPATCH'
--- a/src/helpers/help.h
+++ b/src/helpers/help.h
@@ -21,7 +21,7 @@
 
 namespace help{
 	
-	enum class KeyboardFeatures : uint16_t {
+	enum KeyboardFeatures {
 		none = 0,
 		commit = 1 << 0,
 		setall = 1 << 1,
ENDPATCH
    patch -p1 < /tmp/fix_enum.patch
    
    echo "Building g810-led..."
    make
    
    echo "Installing g810-led..."
    sudo make install
    
    echo "Setting up udev rules..."
    # Install udev rules if they exist (make install-udev doesn't exist in all versions)
    if [ -f udev/g810-led.rules ]; then
        sudo cp udev/g810-led.rules /etc/udev/rules.d/
        echo "✓ Udev rules installed"
    elif make -n install-udev &>/dev/null; then
        sudo make install-udev
        echo "✓ Udev rules installed via make"
    else
        echo "⚠ No udev rules found (this is normal, they may be installed with the binary)"
    fi
    
    # Clean up
    cd ~
    rm -rf "$TEMP_DIR"
    
elif [ "$OS_TYPE" = "arch" ]; then
    # Arch Linux: Use AUR or build from source
    echo "Installing build dependencies..."
    sudo pacman -Syu --needed --noconfirm git base-devel hidapi libusb
    
    echo "Cloning g810-led repository..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    git clone https://github.com/MatMoul/g810-led.git
    cd g810-led
    
    echo "Applying C++11 compatibility fix..."
    # Fix enum syntax for modern C++ compilers - convert to old-style enum
    cat > /tmp/fix_enum.patch << 'ENDPATCH'
--- a/src/helpers/help.h
+++ b/src/helpers/help.h
@@ -21,7 +21,7 @@
 
 namespace help{
 	
-	enum class KeyboardFeatures : uint16_t {
+	enum KeyboardFeatures {
 		none = 0,
 		commit = 1 << 0,
 		setall = 1 << 1,
ENDPATCH
    patch -p1 < /tmp/fix_enum.patch
    
    echo "Building g810-led..."
    make
    
    echo "Installing g810-led..."
    sudo make install
    
    echo "Setting up udev rules..."
    # Install udev rules if they exist (make install-udev doesn't exist in all versions)
    if [ -f udev/g810-led.rules ]; then
        sudo cp udev/g810-led.rules /etc/udev/rules.d/
        echo "✓ Udev rules installed"
    elif make -n install-udev &>/dev/null; then
        sudo make install-udev
        echo "✓ Udev rules installed via make"
    else
        echo "⚠ No udev rules found (this is normal, they may be installed with the binary)"
    fi
    
    # Clean up
    cd ~
    rm -rf "$TEMP_DIR"
fi

echo ""
echo "✓ g810-led installed successfully"
echo ""

# Reload udev rules
echo "Step 2: Reloading udev rules..."
sudo udevadm control --reload-rules
sudo udevadm trigger

echo ""
echo "✓ Udev rules reloaded"
echo ""
echo "Note: You may need to unplug and replug your keyboard for the"
echo "      udev rules to take effect, or reboot your system."
echo ""

# Ask user for LED mode preference
echo "Step 3: Configure LED profile"
echo ""
echo "Choose your LED mode:"
echo "  1) Static color (fixed color, no effects)"
echo "  2) Breathing effect"
echo "  3) Color cycle"
echo "  4) Wave effects"
echo ""
read -p "Enter choice [1-4]: " mode_choice

# Ask for color
echo ""
echo "Choose a color (hex format, e.g., ff0000 for red):"
echo "  Examples: ff0000 (red), 00ff00 (green), 0000ff (blue), ffffff (white), ff00ff (magenta)"
read -p "Enter hex color (6 digits): " color

# Validate color input
if ! [[ $color =~ ^[0-9A-Fa-f]{6}$ ]]; then
    echo "Invalid color format. Using white (ffffff) as default."
    color="ffffff"
fi

# Create profile directory if it doesn't exist
sudo mkdir -p /etc/g810-led

# Create profile based on choice
echo ""
echo "Creating profile at /etc/g810-led/profile..."
case $mode_choice in
    1)
        # Static color
        sudo tee /etc/g810-led/profile > /dev/null <<EOF
# Static color profile
fx color all $color
c
EOF
        echo "✓ Profile created: Static color ($color)"
        ;;
    2)
        # Breathing effect
        read -p "Enter breathing speed (01-64 in hex, default 0a): " speed
        speed=${speed:-0a}
        sudo tee /etc/g810-led/profile > /dev/null <<EOF
# Breathing effect profile
fx breathing all $color $speed
c
EOF
        echo "✓ Profile created: Breathing effect ($color, speed $speed)"
        ;;
    3)
        # Color cycle
        read -p "Enter cycle speed (01-64 in hex, default 0a): " speed
        speed=${speed:-0a}
        sudo tee /etc/g810-led/profile > /dev/null <<EOF
# Color cycle profile
fx cycle all $speed
c
EOF
        echo "✓ Profile created: Color cycle (speed $speed)"
        ;;
    4)
        # Wave effects
        echo "Choose wave type:"
        echo "  1) Horizontal wave"
        echo "  2) Vertical wave"
        echo "  3) Center wave"
        read -p "Enter wave type [1-3]: " wave_type
        read -p "Enter wave speed (01-64 in hex, default 0a): " speed
        speed=${speed:-0a}
        
        case $wave_type in
            1) wave="hwave" ;;
            2) wave="vwave" ;;
            3) wave="cwave" ;;
            *) wave="hwave" ;;
        esac
        
        sudo tee /etc/g810-led/profile > /dev/null <<EOF
# Wave effect profile
fx $wave all $speed
c
EOF
        echo "✓ Profile created: ${wave} effect (speed $speed)"
        ;;
    *)
        # Default to static color
        sudo tee /etc/g810-led/profile > /dev/null <<EOF
# Static color profile (default)
fx color all $color
c
EOF
        echo "✓ Profile created: Static color ($color) [default]"
        ;;
esac

echo ""
echo "Step 4: Enabling systemd service for automatic startup..."

# Check if systemd service exists
if systemctl list-unit-files | grep -q "g810-led-reboot.service"; then
    sudo systemctl enable g810-led-reboot.service
    sudo systemctl start g810-led-reboot.service
    echo ""
    echo "✓ Systemd service enabled and started"
    echo "  LED profile will automatically apply on system boot"
else
    echo ""
    echo "⚠ Systemd service not found (g810-led-reboot.service)"
    echo "  You can manually apply the profile on boot by adding this to your startup applications:"
    echo "  g810-led -p /etc/g810-led/profile"
fi
echo ""

# Apply the profile immediately
echo "Step 5: Applying LED profile now..."
sudo g810-led -p /etc/g810-led/profile

echo ""
echo "========================================="
echo "✓ Setup Complete!"
echo "========================================="
echo ""
echo "Your LED settings have been applied and will persist after reboot."
echo ""
echo "Useful commands:"
echo "  - Change settings: sudo nano /etc/g810-led/profile"
echo "  - Apply profile:   g810-led -p /etc/g810-led/profile"
echo "  - Quick color:     g810-led -fx color all RRGGBB"
echo "  - View help:       g810-led --help"
echo ""
echo "If LEDs don't respond, try:"
echo "  1. Unplug and replug your keyboard"
echo "  2. Reboot your system"
echo "  3. Run manually: g810-led -p /etc/g810-led/profile"
echo ""
