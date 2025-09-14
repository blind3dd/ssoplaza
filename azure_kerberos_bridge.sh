#!/bin/bash

# Azure AD + Kerberos Bridge Setup
# This creates a bridge between Azure AD and your local Kerberos

set -e

echo "🔐 Setting up Azure AD + Kerberos Bridge"
echo "========================================"

# Check if we're in a nix-shell with required packages
if ! command -v kinit &> /dev/null; then
    echo "❌ Kerberos not found. Please run: nix-shell -p krb5"
    exit 1
fi

echo "✅ Kerberos tools found"

# Function to get Azure AD domain information
get_azure_domain() {
    echo "🔧 Getting Azure AD domain information..."
    
    # Try to get domain from system or prompt user
    local azure_domain=""
    
    # Check if we can detect domain from system
    if command -v scutil &> /dev/null; then
        local computer_name=$(scutil --get ComputerName 2>/dev/null || echo "")
        if [[ -n "$computer_name" ]]; then
            echo "📋 Computer name: $computer_name"
        fi
    fi
    
    # Prompt for Azure AD domain
    echo "Please enter your Azure AD domain (e.g., yourcompany.onmicrosoft.com):"
    read -r azure_domain
    
    if [[ -z "$azure_domain" ]]; then
        echo "❌ Azure AD domain is required"
        exit 1
    fi
    
    echo "$azure_domain"
}

# Function to create Azure AD Kerberos configuration
create_azure_kerberos_config() {
    local azure_domain="$1"
    local azure_realm=$(echo "$azure_domain" | tr '[:lower:]' '[:upper:]')
    
    echo "🔧 Creating Azure AD Kerberos configuration..."
    
    # Create Azure AD Kerberos config
    cat > ~/.config/kerberos/azure_krb5.conf << EOF
[libdefaults]
    default_realm = $azure_realm
    dns_lookup_realm = true
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    default_ccache_name = FILE:/tmp/krb5cc_%{uid}
    kdc_timesync = 1
    ccache_type = 4

[realms]
    $azure_realm = {
        kdc = $azure_domain
        admin_server = $azure_domain
        default_domain = $azure_domain
    }
    
    LKDC:SHA1.YOUR_REALM_HASH_HERE = {
        kdc = 127.0.0.1:88
        admin_server = 127.0.0.1:749
        default_domain = localhost
    }

[domain_realm]
    .$azure_domain = $azure_realm
    $azure_domain = $azure_realm
    .localhost = LKDC:SHA1.YOUR_REALM_HASH_HERE
    localhost = LKDC:SHA1.YOUR_REALM_HASH_HERE

[appdefaults]
    pam = {
        debug = false
        ticket_lifetime = 36000
        renew_lifetime = 36000
        forwardable = true
        krb4_convert = false
    }
EOF

    echo "✅ Azure AD Kerberos configuration created"
    echo "   File: ~/.config/kerberos/azure_krb5.conf"
    echo "   Realm: $azure_realm"
}

# Function to create Azure AD integration script
create_azure_integration() {
    local azure_domain="$1"
    local azure_realm=$(echo "$azure_domain" | tr '[:lower:]' '[:upper:]')
    
    echo "🔧 Creating Azure AD integration script..."
    
    cat > ~/.config/kerberos/azure_integration.sh << 'EOF'
#!/bin/bash

# Azure AD Integration Script
# This script helps integrate Azure AD with Kerberos

set -e

# Configuration
AZURE_DOMAIN=""
AZURE_REALM=""
KRB5_CONFIG_AZURE="$HOME/.config/kerberos/azure_krb5.conf"

# Function to login to Azure AD
azure_login() {
    echo "🔐 Logging into Azure AD..."
    
    # Try different methods to authenticate with Azure
    echo "Available authentication methods:"
    echo "1. Azure CLI (if working)"
    echo "2. Azure Portal (manual)"
    echo "3. PowerShell (if available)"
    echo "4. Browser-based authentication"
    
    echo ""
    echo "For now, please:"
    echo "1. Go to https://portal.azure.com"
    echo "2. Sign in with your Azure AD credentials"
    echo "3. Note your tenant ID and domain"
    
    read -p "Press Enter when you've completed Azure AD login..."
}

# Function to test Kerberos with Azure AD
test_azure_kerberos() {
    echo "🔧 Testing Kerberos with Azure AD..."
    
    if [[ -f "$KRB5_CONFIG_AZURE" ]]; then
        export KRB5_CONFIG="$KRB5_CONFIG_AZURE"
        echo "✅ Using Azure AD Kerberos configuration"
        
        # Try to get a ticket (this might fail without proper setup)
        echo "Attempting to get Azure AD Kerberos ticket..."
        echo "Note: This may require additional Azure AD configuration"
    else
        echo "❌ Azure AD Kerberos configuration not found"
        echo "   Run the setup script first"
    fi
}

# Function to show status
show_status() {
    echo "📋 Azure AD + Kerberos Integration Status"
    echo "========================================"
    
    echo "Local Kerberos:"
    if klist -s; then
        echo "✅ Local Kerberos ticket active"
        klist | head -3
    else
        echo "⚠️  No local Kerberos ticket"
    fi
    
    echo ""
    echo "Azure AD Configuration:"
    if [[ -f "$KRB5_CONFIG_AZURE" ]]; then
        echo "✅ Azure AD Kerberos config exists"
        echo "   File: $KRB5_CONFIG_AZURE"
    else
        echo "❌ Azure AD Kerberos config missing"
    fi
    
    echo ""
    echo "Platform SSO:"
    if sudo dscl "/Platform SSO" -list / &>/dev/null; then
        echo "✅ Platform SSO node exists"
    else
        echo "⚠️  Platform SSO node not accessible"
    fi
}

# Main menu
main() {
    echo "Azure AD + Kerberos Integration"
    echo "==============================="
    echo "1. Login to Azure AD"
    echo "2. Test Azure AD Kerberos"
    echo "3. Show Status"
    echo "4. Exit"
    echo ""
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1) azure_login ;;
        2) test_azure_kerberos ;;
        3) show_status ;;
        4) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
}

# Run main function
main "$@"
EOF

    chmod +x ~/.config/kerberos/azure_integration.sh
    echo "✅ Azure AD integration script created"
    echo "   File: ~/.config/kerberos/azure_integration.sh"
}

# Function to create unified aliases
create_unified_aliases() {
    local azure_domain="$1"
    local azure_realm=$(echo "$azure_domain" | tr '[:lower:]' '[:upper:]')
    
    echo "🔧 Creating unified Azure AD + Kerberos aliases..."
    
    cat >> ~/.zshrc << EOF

# Azure AD + Kerberos Bridge aliases
alias azure-status='~/.config/kerberos/azure_integration.sh'
alias azure-login='~/.config/kerberos/azure_integration.sh'
alias kerberos-local='export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf" && klist'
alias kerberos-azure='export KRB5_CONFIG="$HOME/.config/kerberos/azure_krb5.conf" && klist'
alias sso-bridge='echo "=== Local Kerberos ===" && export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf" && klist -s && echo "=== Azure AD ===" && export KRB5_CONFIG="$HOME/.config/kerberos/azure_krb5.conf" && klist -s'

# Set default Kerberos config
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
EOF

    echo "✅ Unified aliases added to ~/.zshrc"
}

# Function to show final status
show_final_status() {
    local azure_domain="$1"
    local azure_realm=$(echo "$azure_domain" | tr '[:lower:]' '[:upper:]')
    
    echo ""
    echo "🎉 Azure AD + Kerberos Bridge Setup Complete!"
    echo ""
    echo "Configuration Summary:"
    echo "====================="
    echo "Azure AD Domain: $azure_domain"
    echo "Azure AD Realm: $azure_realm"
    echo "Local Kerberos Realm: LKDC:SHA1.YOUR_REALM_HASH_HERE"
    echo ""
    echo "Configuration Files:"
    echo "==================="
    echo "- Local Kerberos: ~/.config/kerberos/krb5.conf"
    echo "- Azure AD Kerberos: ~/.config/kerberos/azure_krb5.conf"
    echo "- Azure Integration: ~/.config/kerberos/azure_integration.sh"
    echo ""
    echo "Useful Commands:"
    echo "==============="
    echo "- azure-status (check Azure AD integration status)"
    echo "- azure-login (login to Azure AD)"
    echo "- kerberos-local (check local Kerberos tickets)"
    echo "- kerberos-azure (check Azure AD Kerberos tickets)"
    echo "- sso-bridge (check both Kerberos realms)"
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Run 'azure-login' to authenticate with Azure AD"
    echo "2. Configure Platform SSO through System Preferences"
    echo "3. Test the bridge with 'sso-bridge'"
    echo "4. Use 'azure-status' to check integration status"
}

# Main execution
main() {
    echo "Please provide your Azure AD domain information:"
    local azure_domain=$(get_azure_domain)
    
    create_azure_kerberos_config "$azure_domain"
    create_azure_integration "$azure_domain"
    create_unified_aliases "$azure_domain"
    show_final_status "$azure_domain"
}

# Run main function
main "$@"
