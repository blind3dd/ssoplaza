#!/bin/bash

# Azure Active Directory Setup Script
# This script sets up Azure AD integration with your existing domain

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}☁️  Azure Active Directory Setup${NC}"
echo "=================================="

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${YELLOW}⚠️  Azure CLI not found. Installing...${NC}"
    
    # Install Azure CLI on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install azure-cli
        else
            echo -e "${RED}❌ Homebrew not found. Please install Azure CLI manually:${NC}"
            echo "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
            exit 1
        fi
    else
        echo -e "${RED}❌ Unsupported OS. Please install Azure CLI manually.${NC}"
        exit 1
    fi
fi

echo "✅ Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"

# Check if we're already logged in
if az account show >/dev/null 2>&1; then
    echo "✅ Already logged into Azure"
    CURRENT_ACCOUNT=$(az account show --query name -o tsv)
    echo "   Current account: $CURRENT_ACCOUNT"
else
    echo -e "${BLUE}🔐 Logging into Azure...${NC}"
    az login --use-device-code
fi

# Get Azure tenant information
echo -e "${BLUE}📊 Getting Azure tenant information...${NC}"
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_DOMAIN=$(az account show --query user.name -o tsv | cut -d'@' -f2)

echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant Domain: $TENANT_DOMAIN"

# Check if custom domain exists
echo -e "${BLUE}🔍 Checking for custom domain: coderedalarmtech.com${NC}"
if az ad domain list --query "[?id=='coderedalarmtech.com'].id" -o tsv | grep -q "coderedalarmtech.com"; then
    echo "✅ Custom domain 'coderedalarmtech.com' found in Azure AD"
    CUSTOM_DOMAIN="coderedalarmtech.com"
else
    echo -e "${YELLOW}⚠️  Custom domain 'coderedalarmtech.com' not found${NC}"
    echo "Available domains:"
    az ad domain list --query "[].id" -o tsv
    
    read -p "Enter your custom domain (or press Enter to use default): " CUSTOM_DOMAIN
    if [ -z "$CUSTOM_DOMAIN" ]; then
        CUSTOM_DOMAIN="$TENANT_DOMAIN"
    fi
fi

echo "Using domain: $CUSTOM_DOMAIN"

# Create Azure AD configuration
echo -e "${BLUE}🔧 Creating Azure AD configuration...${NC}"

# Create configuration directory
mkdir -p ~/.config/azure_ad

# Save Azure AD configuration
cat > ~/.config/azure_ad/config << AZURE_CONFIG
# Azure AD Configuration
TENANT_ID=$TENANT_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
TENANT_DOMAIN=$TENANT_DOMAIN
CUSTOM_DOMAIN=$CUSTOM_DOMAIN
AZURE_CONFIG

echo "✅ Azure AD configuration saved to ~/.config/azure_ad/config"

# Configure macOS for Azure AD
echo -e "${BLUE}�� Configuring macOS for Azure AD...${NC}"

# Create Azure AD authentication script
cat > ~/.config/azure_ad/azure_auth.sh << 'AUTH_SCRIPT'
#!/bin/bash

# Azure AD Authentication Script
# This script handles Azure AD authentication for macOS

# Source configuration
if [ -f ~/.config/azure_ad/config ]; then
    source ~/.config/azure_ad/config
else
    echo "❌ Azure AD configuration not found"
    exit 1
fi

# Function to authenticate with Azure AD
azure_auth() {
    echo "🔐 Authenticating with Azure AD..."
    
    # Login to Azure
    az login --use-device-code
    
    # Get access token
    ACCESS_TOKEN=$(az account get-access-token --query accessToken -o tsv)
    
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "✅ Azure AD authentication successful"
        return 0
    else
        echo "❌ Azure AD authentication failed"
        return 1
    fi
}

# Function to get user info
get_user_info() {
    echo "📊 Getting user information..."
    
    USER_INFO=$(az ad signed-in-user show --query '{displayName:displayName,mail:mail,userPrincipalName:userPrincipalName}' -o json)
    echo "$USER_INFO"
}

# Main function
main() {
    case "$1" in
        "auth")
            azure_auth
            ;;
        "info")
            get_user_info
            ;;
        "status")
            if az account show >/dev/null 2>&1; then
                echo "✅ Logged into Azure AD"
                az account show --query name -o tsv
            else
                echo "❌ Not logged into Azure AD"
            fi
            ;;
        *)
            echo "Usage: $0 {auth|info|status}"
            ;;
    esac
}

main "$@"
AUTH_SCRIPT

chmod +x ~/.config/azure_ad/azure_auth.sh

# Create Azure AD aliases
echo -e "${BLUE}🔧 Creating Azure AD aliases...${NC}"

cat > ~/.azure_ad_aliases << 'ALIASES'
# Azure AD Aliases
alias azure-auth='~/.config/azure_ad/azure_auth.sh auth'
alias azure-info='~/.config/azure_ad/azure_auth.sh info'
alias azure-status='~/.config/azure_ad/azure_auth.sh status'
alias azure-login='az login --use-device-code'
alias azure-logout='az logout'
ALIASES

echo "✅ Azure AD aliases created in ~/.azure_ad_aliases"

# Test Azure AD authentication
echo -e "${BLUE}🧪 Testing Azure AD authentication...${NC}"

if ~/.config/azure_ad/azure_auth.sh status; then
    echo "✅ Azure AD authentication test successful"
    
    # Get user information
    echo "📊 User information:"
    ~/.config/azure_ad/azure_auth.sh info
else
    echo -e "${YELLOW}⚠️  Azure AD authentication test failed${NC}"
    echo "You may need to run: azure-auth"
fi

# Create hybrid configuration (if needed)
echo -e "${BLUE}🔧 Setting up hybrid configuration...${NC}"

cat > ~/.config/azure_ad/hybrid_setup.md << 'HYBRID_SETUP'
# Azure AD Hybrid Configuration

## Prerequisites
1. Azure AD tenant with custom domain
2. On-premises Active Directory
3. Azure AD Connect server

## Setup Steps

### 1. Configure Custom Domain
```bash
# Add custom domain to Azure AD
az ad domain create --domain-name coderedalarmtech.com
```

### 2. Set up Azure AD Connect
1. Download Azure AD Connect
2. Install on Windows Server
3. Configure hybrid authentication
4. Enable password hash synchronization

### 3. Configure DNS
Add these DNS records to your domain:
- TXT record for domain verification
- MX record for mail routing
- CNAME records for Azure services

### 4. Test Authentication
```bash
# Test Azure AD authentication
azure-auth
azure-info
```

## Troubleshooting
- Check Azure AD Connect sync status
- Verify DNS records
- Check firewall settings
- Review Azure AD logs
HYBRID_SETUP

echo "✅ Hybrid configuration guide created: ~/.config/azure_ad/hybrid_setup.md"

# Final setup summary
echo ""
echo -e "${GREEN}🎉 Azure AD Setup Complete!${NC}"
echo "=========================="
echo ""
echo "📋 What was configured:"
echo "✅ Azure CLI authentication"
echo "✅ Azure AD configuration"
echo "✅ macOS integration scripts"
echo "✅ Authentication aliases"
echo "✅ Hybrid setup guide"
echo ""
echo "🚀 Available commands:"
echo "   azure-auth    - Authenticate with Azure AD"
echo "   azure-info    - Get user information"
echo "   azure-status  - Check authentication status"
echo "   azure-login   - Login to Azure"
echo "   azure-logout  - Logout from Azure"
echo ""
echo "💡 Next steps:"
echo "1. Source the aliases: source ~/.azure_ad_aliases"
echo "2. Test authentication: azure-auth"
echo "3. Check user info: azure-info"
echo "4. For hybrid setup, follow: ~/.config/azure_ad/hybrid_setup.md"
echo ""
echo "🔧 To integrate with your existing domain:"
echo "1. Add 'coderedalarmtech.com' as custom domain in Azure AD"
echo "2. Set up Azure AD Connect for hybrid authentication"
echo "3. Configure DNS records"
echo "4. Test authentication"

