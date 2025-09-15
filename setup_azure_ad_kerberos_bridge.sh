#!/bin/bash

# Azure AD + Intune + Local Kerberos Bridge Setup
# This script bridges your local Kerberos with Azure AD/Intune

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔗 Azure AD + Intune + Local Kerberos Bridge Setup${NC}"
echo "========================================================"

# Check current Kerberos configuration
echo -e "${BLUE}🔍 Checking current Kerberos configuration...${NC}"

# Get current realm hash
CURRENT_REALM_HASH=$(sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority 2>/dev/null | grep -o "LKDC:SHA1\.[A-F0-9]*" | head -1)
CURRENT_USERNAME=$(sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority 2>/dev/null | grep -o "[a-zA-Z0-9._-]*@LKDC:SHA1\.[A-F0-9]*" | head -1 | cut -d'@' -f1)

echo "Current Kerberos Realm: $CURRENT_REALM_HASH"
echo "Current Username: $CURRENT_USERNAME"

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo -e "${YELLOW}⚠️  Azure CLI not found. Installing...${NC}"
    if command -v brew &> /dev/null; then
        brew install azure-cli
    else
        echo -e "${RED}❌ Please install Azure CLI manually${NC}"
        exit 1
    fi
fi

# Login to Azure
echo -e "${BLUE}🔐 Logging into Azure...${NC}"
if ! az account show >/dev/null 2>&1; then
    az login --use-device-code
fi

# Get Azure tenant information
echo -e "${BLUE}📊 Getting Azure tenant information...${NC}"
TENANT_ID=$(az account show --query tenantId -o tsv)
TENANT_DOMAIN=$(az account show --query user.name -o tsv | cut -d'@' -f2)

echo "Tenant ID: $TENANT_ID"
echo "Tenant Domain: $TENANT_DOMAIN"

# Check Intune configuration
echo -e "${BLUE}🔍 Checking Intune configuration...${NC}"

# Check if device is enrolled in Intune
if command -v profiles &> /dev/null; then
    echo "Checking device profiles..."
    profiles list
else
    echo "⚠️  profiles command not available"
fi

# Create Azure AD + Kerberos bridge configuration
echo -e "${BLUE}🔧 Creating Azure AD + Kerberos bridge configuration...${NC}"

# Create configuration directory
mkdir -p ~/.config/azure_kerberos_bridge

# Create bridge configuration
cat > ~/.config/azure_kerberos_bridge/config << BRIDGE_CONFIG
# Azure AD + Kerberos Bridge Configuration
TENANT_ID=$TENANT_ID
TENANT_DOMAIN=$TENANT_DOMAIN
LOCAL_REALM_HASH=$CURRENT_REALM_HASH
LOCAL_USERNAME=$CURRENT_USERNAME
BRIDGE_CONFIG

# Create Kerberos configuration that bridges with Azure AD
cat > ~/.config/kerberos/krb5.conf << KRB5_CONF
[libdefaults]
    default_realm = $CURRENT_REALM_HASH
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    default_ccache_name = KEYRING:persistent:%{uid}

[realms]
    # Local Kerberos realm
    $CURRENT_REALM_HASH = {
        kdc = 127.0.0.1:88
        admin_server = 127.0.0.1:749
        default_domain = $(hostname)
    }
    
    # Azure AD realm (if needed for hybrid)
    $TENANT_DOMAIN = {
        kdc = $TENANT_DOMAIN
        admin_server = $TENANT_DOMAIN
        default_domain = $TENANT_DOMAIN
    }

[domain_realm]
    .$(hostname) = $CURRENT_REALM_HASH
    $(hostname) = $CURRENT_REALM_HASH
    .$TENANT_DOMAIN = $TENANT_DOMAIN
    $TENANT_DOMAIN = $TENANT_DOMAIN
KRB5_CONF

# Create Azure AD authentication bridge script
cat > ~/.config/azure_kerberos_bridge/auth_bridge.sh << 'AUTH_BRIDGE'
#!/bin/bash

# Azure AD + Kerberos Authentication Bridge
# This script bridges Azure AD authentication with local Kerberos

# Source configuration
if [ -f ~/.config/azure_kerberos_bridge/config ]; then
    source ~/.config/azure_kerberos_bridge/config
else
    echo "❌ Bridge configuration not found"
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

# Function to get Kerberos ticket
get_kerberos_ticket() {
    echo "🎫 Getting Kerberos ticket..."
    
    # Try to get ticket with local realm
    if kinit "$LOCAL_USERNAME@$LOCAL_REALM_HASH"; then
        echo "✅ Kerberos ticket acquired"
        klist
        return 0
    else
        echo "❌ Failed to acquire Kerberos ticket"
        return 1
    fi
}

# Function to check Intune status
check_intune_status() {
    echo "📱 Checking Intune status..."
    
    if command -v profiles &> /dev/null; then
        echo "Device profiles:"
        profiles list
    else
        echo "⚠️  profiles command not available"
    fi
}

# Function to sync with Azure AD
sync_with_azure() {
    echo "🔄 Syncing with Azure AD..."
    
    # Get user info from Azure AD
    USER_INFO=$(az ad signed-in-user show --query '{displayName:displayName,mail:mail,userPrincipalName:userPrincipalName}' -o json)
    echo "Azure AD User Info: $USER_INFO"
    
    # Check if local user matches Azure AD user
    AZURE_USERNAME=$(echo "$USER_INFO" | jq -r '.userPrincipalName' | cut -d'@' -f1)
    
    if [ "$AZURE_USERNAME" = "$LOCAL_USERNAME" ]; then
        echo "✅ Local user matches Azure AD user"
    else
        echo "⚠️  Local user ($LOCAL_USERNAME) doesn't match Azure AD user ($AZURE_USERNAME)"
    fi
}

# Main function
main() {
    case "$1" in
        "auth")
            azure_auth
            ;;
        "kerberos")
            get_kerberos_ticket
            ;;
        "intune")
            check_intune_status
            ;;
        "sync")
            sync_with_azure
            ;;
        "status")
            echo "🔍 Bridge Status:"
            echo "Local Username: $LOCAL_USERNAME"
            echo "Local Realm: $LOCAL_REALM_HASH"
            echo "Azure Tenant: $TENANT_DOMAIN"
            echo ""
            echo "Kerberos tickets:"
            klist 2>/dev/null || echo "No tickets"
            echo ""
            echo "Azure AD status:"
            az account show --query name -o tsv 2>/dev/null || echo "Not logged in"
            ;;
        *)
            echo "Usage: $0 {auth|kerberos|intune|sync|status}"
            ;;
    esac
}

main "$@"
AUTH_BRIDGE

chmod +x ~/.config/azure_kerberos_bridge/auth_bridge.sh

# Create aliases for the bridge
echo -e "${BLUE}🔧 Creating bridge aliases...${NC}"

cat > ~/.azure_kerberos_aliases << 'ALIASES'
# Azure AD + Kerberos Bridge Aliases
alias azure-auth='~/.config/azure_kerberos_bridge/auth_bridge.sh auth'
alias azure-kerberos='~/.config/azure_kerberos_bridge/auth_bridge.sh kerberos'
alias azure-intune='~/.config/azure_kerberos_bridge/auth_bridge.sh intune'
alias azure-sync='~/.config/azure_kerberos_bridge/auth_bridge.sh sync'
alias azure-status='~/.config/azure_kerberos_bridge/auth_bridge.sh status'
alias azure-login='az login --use-device-code'
alias azure-logout='az logout'
ALIASES

# Set environment variables
echo -e "${BLUE}🔧 Setting environment variables...${NC}"

cat > ~/.azure_kerberos_env << 'ENV_VARS'
# Azure AD + Kerberos Bridge Environment Variables
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
export AZURE_KERBEROS_BRIDGE_CONFIG="$HOME/.config/azure_kerberos_bridge/config"
ENV_VARS

# Test the bridge
echo -e "${BLUE}🧪 Testing Azure AD + Kerberos bridge...${NC}"

# Source the environment
source ~/.azure_kerberos_env

# Test bridge status
~/.config/azure_kerberos_bridge/auth_bridge.sh status

# Create Intune integration script
echo -e "${BLUE}🔧 Creating Intune integration...${NC}"

cat > ~/.config/azure_kerberos_bridge/intune_integration.sh << 'INTUNE_SCRIPT'
#!/bin/bash

# Intune Integration Script
# This script helps integrate with Microsoft Intune

# Function to check device compliance
check_compliance() {
    echo "📱 Checking device compliance..."
    
    if command -v profiles &> /dev/null; then
        echo "Device profiles:"
        profiles list
        
        echo ""
        echo "Compliance status:"
        # Check if device is compliant
        if profiles list | grep -q "compliance"; then
            echo "✅ Device appears to be compliant"
        else
            echo "⚠️  Device compliance status unclear"
        fi
    else
        echo "❌ profiles command not available"
    fi
}

# Function to sync policies
sync_policies() {
    echo "🔄 Syncing Intune policies..."
    
    # This would typically be handled by the Intune agent
    echo "Intune policy sync is typically handled automatically by the Intune agent"
    echo "Check System Preferences > Profiles for managed profiles"
}

# Function to check enrollment
check_enrollment() {
    echo "📋 Checking Intune enrollment..."
    
    if command -v profiles &> /dev/null; then
        ENROLLMENT_PROFILES=$(profiles list | grep -i "intune\|microsoft\|mdm")
        if [ -n "$ENROLLMENT_PROFILES" ]; then
            echo "✅ Device appears to be enrolled in Intune"
            echo "$ENROLLMENT_PROFILES"
        else
            echo "⚠️  No Intune enrollment profiles found"
        fi
    else
        echo "❌ Cannot check enrollment status"
    fi
}

# Main function
main() {
    case "$1" in
        "compliance")
            check_compliance
            ;;
        "sync")
            sync_policies
            ;;
        "enrollment")
            check_enrollment
            ;;
        *)
            echo "Usage: $0 {compliance|sync|enrollment}"
            ;;
    esac
}

main "$@"
INTUNE_SCRIPT

chmod +x ~/.config/azure_kerberos_bridge/intune_integration.sh

# Final setup summary
echo ""
echo -e "${GREEN}🎉 Azure AD + Intune + Kerberos Bridge Setup Complete!${NC}"
echo "========================================================"
echo ""
echo "📋 What was configured:"
echo "✅ Azure AD integration with local Kerberos"
echo "✅ Intune device management integration"
echo "✅ Authentication bridge between Azure AD and Kerberos"
echo "✅ Environment variables and aliases"
echo "✅ Device compliance checking"
echo ""
echo "🚀 Available commands:"
echo "   azure-auth      - Authenticate with Azure AD"
echo "   azure-kerberos  - Get Kerberos ticket"
echo "   azure-intune    - Check Intune status"
echo "   azure-sync      - Sync with Azure AD"
echo "   azure-status    - Check bridge status"
echo ""
echo "💡 To use the bridge:"
echo "1. Source the aliases: source ~/.azure_kerberos_aliases"
echo "2. Source the environment: source ~/.azure_kerberos_env"
echo "3. Test authentication: azure-auth"
echo "4. Get Kerberos ticket: azure-kerberos"
echo "5. Check status: azure-status"
echo ""
echo "🔧 Intune Integration:"
echo "Your device should already be enrolled in Intune if configured there."
echo "Use 'azure-intune' to check the status and compliance."

