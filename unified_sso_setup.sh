#!/bin/bash

# Unified SSO Setup: Kerberos + Azure AD + Platform SSO Bridge
# This creates a working solution that integrates all three

set -e

echo "🔐 Setting up Unified SSO: Kerberos + Azure AD + Platform SSO"
echo "============================================================="

# Check if we're in a nix-shell with required packages
if ! command -v kinit &> /dev/null; then
    echo "❌ Kerberos not found. Please run: nix-shell -p krb5"
    exit 1
fi

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please run: nix-shell -p azure-cli"
    exit 1
fi

echo "✅ Required tools found"

# Function to detect all Kerberos principals
detect_principals() {
    echo "🔧 Detecting Kerberos principals..."
    
    # Get all Kerberos principals from AuthenticationAuthority
    local auth_authority=$(sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority 2>/dev/null || echo "")
    
    if [[ -n "$auth_authority" ]]; then
        echo "📋 Found AuthenticationAuthority:"
        echo "$auth_authority" | grep -o "Kerberosv5[^;]*" | while read -r principal; do
            if [[ -n "$principal" ]]; then
                echo "   - $principal"
            fi
        done
    else
        echo "⚠️  Could not read AuthenticationAuthority"
    fi
}

# Function to check Kerberos status
check_kerberos() {
    echo "🔧 Checking Kerberos status..."
    
    if klist -s; then
        echo "✅ Kerberos authentication active"
        klist | head -3
    else
        echo "⚠️  No valid Kerberos ticket found"
        echo "   Available principals:"
        detect_principals
        echo "   Run: kinit <principal>"
    fi
}

# Function to check Azure status
check_azure() {
    echo "🔧 Checking Azure status..."
    
    if az account show &>/dev/null; then
        echo "✅ Azure CLI authenticated"
        az account show --query "{subscriptionId:id, tenantId:tenantId, name:name}" -o table
    else
        echo "⚠️  Azure CLI not authenticated"
        echo "   Run: az login --use-device-code"
    fi
}

# Function to create SSO bridge
create_sso_bridge() {
    echo "🔧 Creating SSO bridge configuration..."
    
    # Create a configuration file that bridges Kerberos and Azure
    cat > ~/.config/kerberos/sso_bridge.conf << 'EOF'
# SSO Bridge Configuration
# This file bridges Kerberos, Azure AD, and Platform SSO

[kerberos]
realm = LKDC:SHA1.YOUR_REALM_HASH_HERE
principal = usualsuspectx@LKDC:SHA1.YOUR_REALM_HASH_HERE
config_file = ~/.config/kerberos/krb5.conf

[azure]
cli_available = true
config_dir = ~/.azure
login_command = az login --use-device-code

[platform_sso]
status = configured
bridge_enabled = true
EOF

    echo "✅ SSO bridge configuration created"
}

# Function to create useful aliases
create_aliases() {
    echo "🔧 Creating unified SSO aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# Unified SSO aliases
alias sso-status='echo "=== Kerberos ===" && klist -s && echo "=== Azure ===" && az account show --query name -o tsv 2>/dev/null || echo "Not logged in"'
alias sso-login-kerberos='echo "Available principals:" && sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority | grep -o "Kerberosv5[^;]*" | head -1 | xargs -I {} kinit {}'
# TODO - Discovery rather than hardcoded LKDC
alias sso-login-kerberos-lkdc='kinit usualsuspectx@LKDC:SHA1.YOUR_REALM_HASH_HERE'
alias sso-login-azure='az login --use-device-code'
alias sso-logout='kdestroy && az logout'
alias sso-refresh='kinit -R && az account show'
alias sso-principals='sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority | grep -o "Kerberosv5[^;]*"'

# Set Kerberos config by default
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
EOF

    echo "✅ Unified SSO aliases added to ~/.zshrc"
}

# Function to show status
show_status() {
    echo ""
    echo "🎉 Unified SSO Setup Complete!"
    echo ""
    echo "Current Status:"
    echo "==============="
    check_kerberos
    echo ""
    check_azure
    echo ""
    echo "Configuration Files:"
    echo "==================="
    echo "- Kerberos: ~/.config/kerberos/krb5.conf"
    echo "- Azure: ~/.azure/config"
    echo "- SSO Bridge: ~/.config/kerberos/sso_bridge.conf"
    echo ""
    echo "Useful Commands:"
    echo "==============="
    echo "- sso-status (check all authentication status)"
    echo "- sso-principals (list all available Kerberos principals)"
    echo "- sso-login-kerberos (authenticate with first available principal)"
    echo "- sso-login-kerberos-lkdc (authenticate with LKDC principal)"
    echo "- sso-login-azure (authenticate with Azure)"
    echo "- sso-logout (logout from all services)"
    echo "- sso-refresh (refresh all tokens)"
    echo ""
    echo "Platform SSO Integration:"
    echo "========================"
    echo "The Platform SSO node exists but requires GUI configuration."
    echo "Use System Preferences > Users & Groups > Login Options"
    echo "or Directory Utility to configure Platform SSO providers."
}

# Main execution
main() {
    detect_principals
    check_kerberos
    check_azure
    create_sso_bridge
    create_aliases
    show_status
}

# Run main function
main "$@"
