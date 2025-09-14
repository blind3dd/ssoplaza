#!/bin/bash
# Azure Entra ID Login Setup for macOS
# This script helps configure Azure Entra ID login on macOS

set -e

echo "🔐 Azure Entra ID Login Setup for macOS"
echo "======================================"
echo ""

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "📱 macOS Version: $MACOS_VERSION"

if [[ $(echo "$MACOS_VERSION" | cut -d. -f1) -lt 14 ]]; then
    echo "⚠️  Warning: Platform SSO requires macOS 14 Sonoma or later"
    echo "   Current version: $MACOS_VERSION"
    echo ""
fi

echo "🎯 Available Options:"
echo ""
echo "1. Platform SSO (macOS 14+) - Official Microsoft/Apple solution"
echo "2. Manual Azure AD Integration - Using our Kerberos setup"
echo "3. Check current configuration"
echo ""

read -p "Choose option (1-3): " choice

case $choice in
    1)
        echo ""
        echo "🚀 Platform SSO Setup (macOS 14+)"
        echo "================================="
        echo ""
        echo "Prerequisites:"
        echo "• macOS 14 Sonoma or later"
        echo "• Microsoft Intune Company Portal app"
        echo "• Mac enrolled in Microsoft Intune"
        echo "• IT administrator configured Platform SSO"
        echo ""
        echo "Steps:"
        echo "1. Install Microsoft Intune Company Portal from App Store"
        echo "2. Enroll your Mac with Microsoft Intune"
        echo "3. Register device when prompted"
        echo "4. At login screen, select 'Other...'"
        echo "5. Enter your Azure UPN (email) and password"
        echo ""
        echo "📱 Opening App Store to install Company Portal..."
        open "https://apps.apple.com/app/microsoft-intune-company-portal/id1113153706"
        ;;
        
    2)
        echo ""
        echo "🔧 Manual Azure AD Integration"
        echo "============================="
        echo ""
        echo "This uses our existing Kerberos setup with Azure AD bridge."
        echo ""
        
        # Check if we're in nix-shell
        if [[ -n "$NIX_SHELL" ]]; then
            echo "✅ Nix environment detected"
        else
            echo "📦 Starting Nix environment..."
            echo "Run: nix-shell nix-sso-setup.nix"
            echo "Then run this script again from within the Nix shell"
            exit 0
        fi
        
        echo ""
        echo "Available commands:"
        echo "• az login --use-device-code  # Login to Azure"
        echo "• kinit <principal>           # Get Kerberos ticket"
        echo "• ssh -K <host>               # SSH with Kerberos"
        echo ""
        echo "Configuration files:"
        echo "• ~/.config/kerberos/krb5.conf"
        echo "• ~/.azure/"
        ;;
        
    3)
        echo ""
        echo "🔍 Current Configuration Check"
        echo "============================="
        echo ""
        
        # Check Platform SSO status
        echo "Platform SSO Status:"
        if dscl /Search -read /Config/PlatformSSO 2>/dev/null | grep -q "PlatformSSO"; then
            echo "✅ Platform SSO node exists"
        else
            echo "❌ Platform SSO node not found"
        fi
        
        # Check Company Portal
        echo ""
        echo "Company Portal App:"
        if [ -d "/Applications/Company Portal.app" ]; then
            echo "✅ Company Portal installed"
        else
            echo "❌ Company Portal not installed"
        fi
        
        # Check Azure CLI
        echo ""
        echo "Azure CLI Status:"
        if command -v az &> /dev/null; then
            echo "✅ Azure CLI available"
            az account show --query name -o tsv 2>/dev/null || echo "❌ Not logged in"
        else
            echo "❌ Azure CLI not available"
        fi
        
        # Check Kerberos
        echo ""
        echo "Kerberos Status:"
        if command -v kinit &> /dev/null; then
            echo "✅ Kerberos tools available"
            klist -s 2>/dev/null && echo "✅ Active tickets" || echo "❌ No active tickets"
        else
            echo "❌ Kerberos tools not available"
        fi
        ;;
        
    *)
        echo "❌ Invalid option. Please choose 1-3."
        exit 1
        ;;
esac

echo ""
echo "📚 Additional Resources:"
echo "• Microsoft Platform SSO Documentation: https://learn.microsoft.com/en-us/entra/identity/devices/device-join-macos-platform-single-sign-on"
echo "• Apple Platform SSO Guide: https://support.apple.com/guide/deployment/platform-single-sign-on-overview-depa0b888d6d/web"
echo ""
echo "🎉 Setup complete!"
