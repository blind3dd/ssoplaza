#!/bin/bash

# Azure AD + Kerberos + SSO Setup Script
# This script helps configure Azure AD integration with Kerberos for SSO

set -e

echo "🔐 Setting up Azure AD + Kerberos + SSO Integration"
echo "=================================================="

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

# Function to configure Kerberos
configure_kerberos() {
    echo "🔧 Configuring Kerberos..."
    
    # Set environment variables
    export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
    
    echo "📝 Please update the following in ~/.config/kerberos/krb5.conf:"
    echo "   - Replace YOURDOMAIN.COM with your actual domain"
    echo "   - Replace yourdomain.com with your actual domain"
    echo "   - Update KDC and admin_server addresses"
    
    read -p "Have you updated the krb5.conf file? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please update krb5.conf and run this script again"
        exit 1
    fi
}

# Function to configure Azure CLI
configure_azure() {
    echo "🔧 Configuring Azure CLI..."
    
    # Login to Azure
    echo "🔑 Logging into Azure..."
    az login
    
    # Get tenant information
    echo "📋 Getting tenant information..."
    az account show --query "{subscriptionId:id, tenantId:tenantId, name:name}" -o table
    
    # Set default subscription if multiple
    echo "🎯 Setting default subscription..."
    az account set --subscription "$(az account show --query id -o tsv)"
}

# Function to set up SSO
setup_sso() {
    echo "🔧 Setting up SSO..."
    
    # Create keytab file (you'll need to get this from your AD admin)
    echo "📝 To complete SSO setup:"
    echo "   1. Contact your AD administrator to get a keytab file"
    echo "   2. Place the keytab file at ~/.config/kerberos/user.keytab"
    echo "   3. Run: kinit -kt ~/.config/kerberos/user.keytab username@YOURDOMAIN.COM"
    
    # Test Kerberos authentication
    echo "🧪 Testing Kerberos authentication..."
    if klist -s; then
        echo "✅ Kerberos authentication successful!"
        klist
    else
        echo "⚠️  No valid Kerberos ticket found"
        echo "   Run: kinit username@YOURDOMAIN.COM"
    fi
}

# Function to create useful aliases
create_aliases() {
    echo "🔧 Creating useful aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# Kerberos + Azure + SSO aliases
alias klist='klist -A'
alias kinit-azure='kinit -kt ~/.config/kerberos/user.keytab'
alias az-login='az login'
alias az-status='az account show'
alias krb5-config='export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"'

# Set Kerberos config by default
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
EOF

    echo "✅ Aliases added to ~/.zshrc"
    echo "   Run: source ~/.zshrc to activate"
}

# Main execution
main() {
    configure_kerberos
    configure_azure
    setup_sso
    create_aliases
    
    echo ""
    echo "🎉 Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update ~/.config/kerberos/krb5.conf with your domain details"
    echo "2. Get a keytab file from your AD administrator"
    echo "3. Run: source ~/.zshrc"
    echo "4. Test with: kinit username@YOURDOMAIN.COM"
    echo ""
    echo "For Azure integration:"
    echo "- Use 'az login' to authenticate"
    echo "- Use 'az account show' to check status"
}

# Run main function
main "$@"
