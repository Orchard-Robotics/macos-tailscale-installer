#!/bin/bash

set -e

echo "=== macOS Tailscale + Trayscale Setup Script ==="
echo ""

# 1. Check for and install Xcode Command Line Tools
echo "[1/8] Checking Xcode Command Line Tools..."
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
echo "[2/8] Installing Nix package manager..."
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
echo "[3/8] Installing trayscale via Nix..."
nix-shell -p trayscale --run "echo '  ✓ Trayscale installed successfully'"

# 4. Install Tailscale from Homebrew
echo ""
echo "[4/8] Installing Tailscale from Homebrew..."
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
echo "[5/8] Starting Tailscale service..."
sudo brew services start tailscale
echo "  ✓ Tailscale service started"

# 6. Run tailscale up
echo ""
echo "[6/8] Connecting to Tailscale..."
sudo tailscale up
echo "  ✓ Tailscale connected"

# 7. Set current user as operator and accept routes
echo ""
echo "[7/8] Configuring Tailscale settings..."
sudo tailscale set --operator="$USER"
echo "  ✓ $USER set as operator"
sudo tailscale set --accept-routes=true
echo "  ✓ Accept routes enabled"

# 8. Configure DNS resolver for MagicDNS
echo ""
echo "[8/8] Configuring DNS resolver for MagicDNS..."
sudo mkdir -p /etc/resolver
DNS_DOMAIN=$(tailscale dns status | grep "Search Domains:" -A 1 | tail -n 1 | sed 's/  - //g')
echo "  Found DNS domain: $DNS_DOMAIN"

sudo tee /etc/resolver/search.tailscale > /dev/null << EOF
# Added by tailscaled
search $DNS_DOMAIN
EOF
echo "  ✓ Created /etc/resolver/search.tailscale"

sudo tee /etc/resolver/magicdns.tailscale > /dev/null << EOF
domain $DNS_DOMAIN
nameserver 100.100.100.100
EOF
echo "  ✓ Created /etc/resolver/magicdns.tailscale"

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "  ✓ DNS cache flushed"

# 9. Create Trayscale.app in Applications
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
