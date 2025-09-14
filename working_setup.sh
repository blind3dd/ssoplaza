#!/bin/bash

# Working Azure AD + SSO Setup (without LKDC)
# This focuses on practical Azure integration

echo "🔐 Setting up Azure AD + SSO Integration"
echo "========================================"

# Check if we're in a nix-shell
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please run: nix-shell -p azure-cli"
    exit 1
fi

echo "✅ Azure CLI found"

# Function to test Azure connectivity
test_azure() {
    echo "🔧 Testing Azure connectivity..."
    
    # Try to get Azure status without login
    if az account show &>/dev/null; then
        echo "✅ Already logged into Azure"
        az account show --query "{subscriptionId:id, tenantId:tenantId, name:name}" -o table
    else
        echo "⚠️  Not logged into Azure"
        echo "   You'll need to login manually due to browser issues"
    fi
}

# Function to create useful aliases
create_aliases() {
    echo "🔧 Creating useful aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# Azure + SSO aliases
alias az-status='az account show'
alias az-login='echo "Use: az login --use-device-code"'
alias az-resources='az resource list --output table'
alias az-groups='az group list --output table'

# Kerberos aliases (for when it works)
alias klist='klist -A'
alias krb5-config='export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"'

# Set Kerberos config by default
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
EOF

    echo "✅ Aliases added to ~/.zshrc"
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo "🎉 Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. For Azure login, try: az login --use-device-code"
    echo "2. If that fails, use the Azure portal directly"
    echo "3. For Kerberos, the LKDC needs to be properly configured"
    echo ""
    echo "Useful commands:"
    echo "- az account show (check Azure status)"
    echo "- az resource list (list Azure resources)"
    echo "- klist (check Kerberos tickets when working)"
    echo ""
    echo "Configuration files:"
    echo "- Kerberos: ~/.config/kerberos/krb5.conf"
    echo "- Azure: ~/.azure/config"
}

# Main execution
main() {
    test_azure
    create_aliases
    show_next_steps
}

# Run main function
main "$@"
