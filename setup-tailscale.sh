#!/bin/bash

set -e

echo "=== macOS Tailscale + Trayscale Setup Script ==="
echo ""

# 1. Check for and install Xcode Command Line Tools
echo "[1/7] Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    echo "  ✓ Xcode Command Line Tools already installed"
else
    echo "  Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "  Waiting for Xcode Command Line Tools installation to complete..."
    echo "  Please complete the installation dialog, then press Enter to continue."
    read -r
fi

# 2. Install Nix package manager
echo ""
echo "[2/7] Installing Nix package manager..."
if command -v nix &>/dev/null; then
    echo "  ✓ Nix already installed"
else
    echo "  Downloading and installing Nix..."
    curl -L https://nixos.org/nix/install | sh
    # Source nix for current session
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    echo "  ✓ Nix installed"
fi

# 3. Install trayscale via nix-shell
echo ""
echo "[3/7] Installing trayscale via Nix..."
nix-shell -p trayscale --run "echo '  ✓ Trayscale installed successfully'"

# 4. Install Tailscale from Homebrew
echo ""
echo "[4/7] Installing Tailscale from Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "  Error: Homebrew is not installed. Please install it first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

if brew list --formula tailscale &>/dev/null; then
    echo "  ✓ Tailscale already installed"
else
    brew install --formula tailscale
    echo "  ✓ Tailscale installed"
fi

# 5. Start the Tailscale service
echo ""
echo "[5/7] Starting Tailscale service..."
sudo brew services start tailscale
echo "  ✓ Tailscale service started"

# 6. Run tailscale up
echo ""
echo "[6/7] Connecting to Tailscale..."
sudo tailscale up
echo "  ✓ Tailscale connected"

# 7. Set current user as operator
echo ""
echo "[7/7] Setting $USER as Tailscale operator..."
sudo tailscale set --operator="$USER"
echo "  ✓ $USER set as operator"

# 8. Create Trayscale.app in Applications
echo ""
echo "[Bonus] Creating Trayscale.app..."
echo 'do shell script "/nix/var/nix/profiles/default/bin/nix-shell -p trayscale --run trayscale > /dev/null 2>&1 &"' | osacompile -o /Applications/Trayscale.app
echo "  ✓ Trayscale.app created in /Applications"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now:"
echo "  - Launch Trayscale from /Applications/Trayscale.app"
echo "  - Use 'tailscale' command directly (as operator)"
echo ""
