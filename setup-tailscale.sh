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
set +e
echo ""
echo "[3/8] Installing trayscale via Nix..."
nix-shell -p trayscale --run "echo '  ✓ Trayscale installed successfully'"
sudo rm -f /etc/bashrc.backup-before-nix
sudo rm -f /etc/zshrc.backup-before-nix
set -e
nix-shell -p trayscale --run "echo '  ✓ Trayscale installation verified'"

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

if brew list --formula glib &>/dev/null; then
    echo "  ✓ glib already installed"
else
    brew install --formula glib
    echo "  ✓ glib installed"
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

trayscale_bin=$(nix-shell -p trayscale --run "which trayscale")
trayscale_bin_folder=$(dirname -- "$trayscale_bin")
trayscale_folder=$(dirname -- "$trayscale_bin_folder")

# Generate icns from PNG
output_path=/tmp/trayscale.iconset
input_logo=/tmp/trayscale_icon_256x256.png
rm -rf $output_path
mkdir -p $output_path

rm -f "$input_logo"
cp "$trayscale_folder/share/icons/hicolor/256x256/apps/dev.deedles.Trayscale.png" "$input_logo"
chmod 777 "$input_logo"

for size in 16 32 64 128 256 512; do
  double="$(($size * 2))"
  sips $input_logo -Z $size --out $output_path/icon_${size}x${size}.png > /dev/null
  sips $input_logo -Z $double --out $output_path/icon_${size}x${size}@2x.png > /dev/null
done

iconutil -c icns $output_path

# Create app bundle structure
APP_PATH="/Applications/Trayscale.app"
sudo rm -rf "$APP_PATH"
sudo mkdir -p "$APP_PATH/Contents/MacOS"
sudo mkdir -p "$APP_PATH/Contents/Resources"

# Create executable
sudo tee "$APP_PATH/Contents/MacOS/Trayscale" > /dev/null << 'EOF'
#!/bin/bash
export XDG_DATA_DIRS="/opt/homebrew/share:/usr/local/share:/usr/share"
exec "/opt/homebrew/libexec/trayscale"
EOF
sudo chmod +x "$APP_PATH/Contents/MacOS/Trayscale"

# Copy icon
sudo cp /tmp/trayscale.icns "$APP_PATH/Contents/Resources/Trayscale.icns"

# Create Info.plist
sudo tee "$APP_PATH/Contents/Info.plist" > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Trayscale</string>
    <key>CFBundleIconFile</key>
    <string>Trayscale</string>
    <key>CFBundleIdentifier</key>
    <string>dev.deedles.Trayscale</string>
    <key>CFBundleName</key>
    <string>Trayscale</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
EOF

echo "  ✓ Trayscale.app created in /Applications"

# Install trayscale to Homebrew prefix
pushd "$trayscale_folder"

# Install binary to libexec (actual executable)
sudo install -m744 -d "$HOMEBREW_PREFIX/libexec"
sudo install -m744 bin/trayscale "$HOMEBREW_PREFIX/libexec/"

# Install wrapper to bin (what users will run)
cat > /tmp/trayscale.wrapper << EOF
#!/bin/bash
export XDG_DATA_DIRS="$HOMEBREW_PREFIX/share:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
exec "$HOMEBREW_PREFIX/libexec/trayscale"
EOF
sudo install -m744 /tmp/trayscale.wrapper "$HOMEBREW_PREFIX/bin/trayscale"

schema_dir="$HOMEBREW_PREFIX/share/glib-2.0/schemas"
nix_schemas_dir=$(find . -type d -name 'schemas' -print -quit)
sudo install -m744 -d "$schema_dir"
sudo install -m744 "$nix_schemas_dir/dev.deedles.Trayscale.gschema.xml" "$schema_dir/"
sudo glib-compile-schemas "$schema_dir"

share_dir="$HOMEBREW_PREFIX/share"
sudo install -m744 -d "$share_dir/applications"
sudo install -m744 share/applications/dev.deedles.Trayscale.desktop "$share_dir/applications/"

sudo install -m744 -d "$share_dir/icons/hicolor/256x256/apps"
sudo install -m744 share/icons/hicolor/256x256/apps/dev.deedles.Trayscale.png "$share_dir/icons/hicolor/256x256/apps/"

popd

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now:"
echo "  - Launch Trayscale from /Applications/Trayscale.app"
echo "  - Use 'tailscale' command directly (as operator)"
echo ""
