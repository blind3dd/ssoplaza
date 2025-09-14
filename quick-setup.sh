#!/bin/bash
# Quick SSO setup script - just run this!

set -e

echo "🚀 Quick SSO/Kerberos/Azure AD Setup"
echo "===================================="
echo ""

# Check if Nix is installed
if ! command -v nix &> /dev/null; then
    echo "❌ Nix not found. Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- --no-confirm
    echo "✅ Nix installed! Please restart your shell and run this script again."
    exit 0
fi

echo "✅ Nix found!"

# Create the development environment
echo "📦 Setting up SSO development environment..."
nix-shell nix-sso-setup.nix --run "echo 'Environment created successfully!'"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "To use the environment, run:"
echo "  nix-shell nix-sso-setup.nix"
echo ""
echo "Or add this to your shell profile:"
echo "  export PATH=\"/nix/var/nix/profiles/default/bin:\$PATH\""
echo ""
echo "Available commands:"
echo "  • realm discover <domain>  - Discover AD domain"
echo "  • realm join <domain>      - Join AD domain"
echo "  • kinit <principal>        - Get Kerberos ticket"
echo "  • az login                 - Login to Azure"
echo "  • sssctl status            - Check SSSD status"
