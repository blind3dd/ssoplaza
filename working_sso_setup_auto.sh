#!/bin/bash

# Working SSO Setup with Auto-Discovery: Kerberos + Platform SSO
# This version automatically discovers system configuration instead of using hardcoded values

set -e

# Source the auto-discovery functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/auto-discovery.sh"

echo "🔐 Working SSO Setup with Auto-Discovery: Kerberos + Platform SSO"
echo "=================================================================="

# Check if we're in a nix-shell with required packages
if ! command -v kinit &> /dev/null; then
    echo "❌ Kerberos not found. Please run: nix-shell -p krb5"
    exit 1
fi

echo "✅ Kerberos tools found"

# Run auto-discovery first
echo ""
echo "🔍 Running auto-discovery..."
discover_hostnames
discover_kerberos_realm
discover_platform_sso
discover_azure_config
discover_network_config

# Function to check Kerberos status
check_kerberos() {
    echo "🔧 Checking Kerberos status..."
    
    if klist -s; then
        echo "✅ Kerberos authentication active"
        klist | head -3
    else
        echo "⚠️  No valid Kerberos ticket found"
        echo "   Available principals: ${DISCOVERED_PRINCIPALS:-'Not discovered'}"
        echo "   Run: kinit <principal>"
    fi
}

# Function to create SSO bridge with auto-discovered values
create_sso_bridge() {
    echo "🔧 Creating SSO bridge configuration..."
    
    # Create kerberos config directory
    mkdir -p ~/.config/kerberos
    
    # Generate dynamic krb5.conf
    cat > ~/.config/kerberos/krb5.conf << EOF
[libdefaults]
    default_realm = ${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE} = {
        kdc = 127.0.0.1:88
        admin_server = 127.0.0.1:749
        default_domain = ${DISCOVERED_HOSTNAME:-localhost}
    }

[domain_realm]
    .${DISCOVERED_HOSTNAME:-localhost} = ${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE}
    ${DISCOVERED_HOSTNAME:-localhost} = ${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE}
EOF

    # Generate dynamic sso_bridge.conf
    cat > sso_bridge.conf << EOF
# SSO Bridge Configuration (Auto-Generated)
# This file bridges Kerberos and Platform SSO

[kerberos]
realm = ${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE}
principal = ${DISCOVERED_USERNAME:-${USER}}@${DISCOVERED_REALM_HASH:-LKDC:SHA1.YOUR_REALM_HASH_HERE}
config_file = ~/.config/kerberos/krb5.conf

[platform_sso]
status = ${PLATFORM_SSO_CONFIGURED:-unknown}
bridge_enabled = true
node_path = /Platform SSO

[azure]
status = ${AZURE_LOGGED_IN:-false}
account_name = ${AZURE_ACCOUNT_NAME:-none}
note = Azure CLI has compatibility issues with Nix version
alternative = Use Azure portal or system Azure CLI

[system]
hostname = ${DISCOVERED_HOSTNAME:-unknown}
computer_name = ${DISCOVERED_COMPUTER_NAME:-unknown}
local_hostname = ${DISCOVERED_LOCAL_HOSTNAME:-unknown}
primary_interface = ${DISCOVERED_PRIMARY_INTERFACE:-unknown}
local_ips = ${DISCOVERED_LOCAL_IPS:-unknown}
EOF

    echo "✅ SSO bridge configuration created with auto-discovered values"
}

# Function to create dynamic aliases
create_aliases() {
    echo "🔧 Creating dynamic SSO aliases..."
    
    # Create aliases file
    cat > ~/.sso_aliases << EOF
# SSO Aliases (Auto-Generated)
# Generated on: $(date)

# Status aliases
alias sso-status='echo "=== Kerberos ===" && klist -s && echo "=== Platform SSO ===" && sudo dscl "/Platform SSO" -list / 2>/dev/null || echo "Platform SSO node exists but not configured"'

# Principal discovery
alias sso-principals='sudo dscl /Search -read /Users/\$(whoami) AuthenticationAuthority | grep -o "[a-zA-Z0-9._-]*@LKDC:SHA1\.[A-F0-9]*"'

# Dynamic login aliases
alias sso-login-kerberos='echo "Available principals:" && sudo dscl /Search -read /Users/\$(whoami) AuthenticationAuthority | grep -o "[a-zA-Z0-9._-]*@LKDC:SHA1\.[A-F0-9]*" | head -1 | xargs -I {} kinit {}'

# Auto-discovered LKDC login (if realm hash is available)
EOF

    # Add LKDC login alias if realm hash is discovered
    if [[ -n "$DISCOVERED_REALM_HASH" && -n "$DISCOVERED_USERNAME" ]]; then
        echo "alias sso-login-kerberos-lkdc='kinit ${DISCOVERED_USERNAME}@${DISCOVERED_REALM_HASH}'" >> ~/.sso_aliases
        echo "✅ LKDC login alias created: sso-login-kerberos-lkdc"
    else
        echo "# LKDC login alias not available - realm hash or username not discovered" >> ~/.sso_aliases
        echo "⚠️  LKDC login alias not created - missing realm hash or username"
    fi

    cat >> ~/.sso_aliases << EOF

# Other aliases
alias sso-logout='kdestroy'
alias sso-refresh='kinit -R'

# Azure aliases (if available)
alias sso-login-azure='az login --use-device-code'
alias sso-azure-status='az account show --query name -o tsv 2>/dev/null || echo "Not logged in"'

# Network aliases
alias sso-network-info='echo "Hostname: ${DISCOVERED_HOSTNAME:-unknown}" && echo "Primary Interface: ${DISCOVERED_PRIMARY_INTERFACE:-unknown}" && echo "Local IPs: ${DISCOVERED_LOCAL_IPS:-unknown}"'
EOF

    echo "✅ Dynamic aliases created in ~/.sso_aliases"
    echo "   Source with: source ~/.sso_aliases"
}

# Function to show status
show_status() {
    echo ""
    echo "📊 SSO Setup Status"
    echo "==================="
    echo "Hostname: ${DISCOVERED_HOSTNAME:-'Not discovered'}"
    echo "Username: ${DISCOVERED_USERNAME:-'Not discovered'}"
    echo "Realm Hash: ${DISCOVERED_REALM_HASH:-'Not discovered'}"
    echo "Platform SSO: ${PLATFORM_SSO_CONFIGURED:-'Unknown'}"
    echo "Azure Status: ${AZURE_LOGGED_IN:-'Unknown'}"
    echo ""
    
    check_kerberos
    echo ""
    
    echo "📋 Available Commands:"
    echo "- sso-status (check authentication status)"
    echo "- sso-principals (list available principals)"
    echo "- sso-login-kerberos (authenticate with first available principal)"
    if [[ -n "$DISCOVERED_REALM_HASH" && -n "$DISCOVERED_USERNAME" ]]; then
        echo "- sso-login-kerberos-lkdc (authenticate with LKDC principal)"
    fi
    echo "- sso-refresh (refresh Kerberos tokens)"
    echo "- sso-network-info (show network information)"
    echo ""
    echo "💡 To use aliases: source ~/.sso_aliases"
}

# Set Kerberos config by default
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"

# Main execution
main() {
    check_kerberos
    create_sso_bridge
    create_aliases
    show_status
}

# Run main function
main
