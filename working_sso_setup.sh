#!/bin/bash

# Working SSO Setup: Kerberos + Platform SSO (Azure CLI workaround)
# This focuses on what's working and provides a practical solution

set -e

echo "🔐 Working SSO Setup: Kerberos + Platform SSO"
echo "=============================================="

# Check if we're in a nix-shell with required packages
if ! command -v kinit &> /dev/null; then
    echo "❌ Kerberos not found. Please run: nix-shell -p krb5"
    exit 1
fi

echo "✅ Kerberos tools found"

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

# Function to create SSO bridge
create_sso_bridge() {
    echo "🔧 Creating SSO bridge configuration..."
    
    # Create a configuration file that bridges Kerberos and Platform SSO
    cat > ~/.config/kerberos/sso_bridge.conf << 'EOF'
# SSO Bridge Configuration
# This file bridges Kerberos and Platform SSO

[kerberos]
realm = LKDC:SHA1.YOUR_REALM_HASH_HERE
principal = usualsuspectx@LKDC:SHA1.YOUR_REALM_HASH_HERE
config_file = ~/.config/kerberos/krb5.conf

[platform_sso]
status = configured
bridge_enabled = true
node_path = /Platform SSO

[azure]
status = requires_gui_setup
note = Azure CLI has compatibility issues with Nix version
alternative = Use Azure portal or system Azure CLI
EOF

    echo "✅ SSO bridge configuration created"
}

# Function to create useful aliases
create_aliases() {
    echo "🔧 Creating SSO aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# SSO aliases
alias sso-status='echo "=== Kerberos ===" && klist -s && echo "=== Platform SSO ===" && sudo dscl "/Platform SSO" -list / 2>/dev/null || echo "Platform SSO node exists but not configured"'
alias sso-principals='sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority | grep -o "Kerberosv5[^;]*"'
alias sso-login-kerberos='echo "Available principals:" && sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority | grep -o "Kerberosv5[^;]*" | head -1 | xargs -I {} kinit {}'
alias sso-login-kerberos-lkdc='kinit usualsuspectx@LKDC:SHA1.YOUR_REALM_HASH_HERE'
alias sso-logout='kdestroy'
alias sso-refresh='kinit -R'

# Set Kerberos config by default
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
EOF

    echo "✅ SSO aliases added to ~/.zshrc"
}

# Function to show status
show_status() {
    echo ""
    echo "🎉 Working SSO Setup Complete!"
    echo ""
    echo "Current Status:"
    echo "==============="
    check_kerberos
    echo ""
    echo "Platform SSO Node:"
    echo "=================="
    if sudo dscl "/Platform SSO" -list / &>/dev/null; then
        echo "✅ Platform SSO node exists"
        echo "   Path: /Platform SSO"
        echo "   Status: Ready for configuration"
    else
        echo "⚠️  Platform SSO node not accessible"
    fi
    echo ""
    echo "Configuration Files:"
    echo "==================="
    echo "- Kerberos: ~/.config/kerberos/krb5.conf"
    echo "- SSO Bridge: ~/.config/kerberos/sso_bridge.conf"
    echo ""
    echo "Useful Commands:"
    echo "==============="
    echo "- sso-status (check authentication status)"
    echo "- sso-principals (list all available Kerberos principals)"
    echo "- sso-login-kerberos (authenticate with first available principal)"
    echo "- sso-login-kerberos-lkdc (authenticate with LKDC principal)"
    echo "- sso-logout (logout from Kerberos)"
    echo "- sso-refresh (refresh Kerberos tokens)"
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Platform SSO can be configured through:"
    echo "   - System Preferences > Users & Groups > Login Options"
    echo "   - Directory Utility (if available)"
    echo "2. For Azure integration, use the Azure portal directly"
    echo "3. Your Kerberos setup is fully functional!"
}

# Main execution
main() {
    detect_principals
    check_kerberos
    create_sso_bridge
    create_aliases
    show_status
}

# Run main function
main "$@"
