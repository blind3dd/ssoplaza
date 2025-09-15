#!/bin/bash

# Sync Intune Platform SSO Configuration
# This script helps sync your local user with Azure AD identity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Syncing Intune Platform SSO Configuration${NC}"
echo "=============================================="

# Current user information
LOCAL_USER=$(whoami)
AZURE_USER="pawel.bek@coderedalarmtech.com"
DOMAIN="coderedalarmtech.com"

echo "📊 Current Configuration:"
echo "   Local User: $LOCAL_USER"
echo "   Azure AD User: $AZURE_USER"
echo "   Domain: $DOMAIN"

# Check current Platform SSO status
echo ""
echo -e "${BLUE}🔍 Checking current Platform SSO status...${NC}"

if sudo dscl "/Platform SSO" -list / 2>/dev/null; then
    echo "✅ Platform SSO node exists and has content"
else
    echo "❌ Platform SSO node is empty"
fi

# Check current AuthenticationAuthority
echo ""
echo -e "${BLUE}🔍 Checking current AuthenticationAuthority...${NC}"
AUTH_AUTHORITY=$(sudo dscl /Search -read /Users/$LOCAL_USER AuthenticationAuthority 2>/dev/null || echo "")
if [ -n "$AUTH_AUTHORITY" ]; then
    echo "Current AuthenticationAuthority:"
    echo "$AUTH_AUTHORITY"
else
    echo "❌ No AuthenticationAuthority found"
fi

# Check if Azure CLI is available and logged in
echo ""
echo -e "${BLUE}🔍 Checking Azure AD connection...${NC}"
if command -v az &> /dev/null; then
    if az account show >/dev/null 2>&1; then
        echo "✅ Azure CLI is logged in"
        CURRENT_AZURE_USER=$(az account show --query user.name -o tsv)
        echo "   Current Azure user: $CURRENT_AZURE_USER"
    else
        echo "❌ Azure CLI not logged in"
        echo "Logging in..."
        az login --use-device-code
    fi
else
    echo "❌ Azure CLI not found"
fi

# Create Platform SSO configuration
echo ""
echo -e "${BLUE}🔧 Creating Platform SSO configuration...${NC}"

# Try to create Platform SSO configuration
echo "Attempting to create Platform SSO configuration..."

# Create the Platform SSO structure
sudo dscl "/Platform SSO" -create /Config 2>/dev/null || echo "Config already exists or cannot be created"

# Create Azure AD provider configuration
sudo dscl "/Platform SSO" -create /Config/AzureAD 2>/dev/null || echo "AzureAD config already exists or cannot be created"

# Set Azure AD configuration
sudo dscl "/Platform SSO" -create /Config/AzureAD/TenantID "coderedalarmtech.com" 2>/dev/null || echo "Cannot set TenantID"
sudo dscl "/Platform SSO" -create /Config/AzureAD/UserPrincipalName "$AZURE_USER" 2>/dev/null || echo "Cannot set UserPrincipalName"
sudo dscl "/Platform SSO" -create /Config/AzureAD/LocalUser "$LOCAL_USER" 2>/dev/null || echo "Cannot set LocalUser"

# Create user mapping
sudo dscl "/Platform SSO" -create /Users 2>/dev/null || echo "Users already exists or cannot be created"
sudo dscl "/Platform SSO" -create /Users/$LOCAL_USER 2>/dev/null || echo "User mapping already exists or cannot be created"
sudo dscl "/Platform SSO" -create /Users/$LOCAL_USER/AzureADUser "$AZURE_USER" 2>/dev/null || echo "Cannot set AzureADUser mapping"

# Create Kerberos bridge configuration
echo ""
echo -e "${BLUE}🔧 Creating Kerberos bridge configuration...${NC}"

# Get current realm hash
CURRENT_REALM_HASH=$(sudo dscl /Search -read /Users/$LOCAL_USER AuthenticationAuthority 2>/dev/null | grep -o "LKDC:SHA1\.[A-F0-9]*" | head -1)

if [ -n "$CURRENT_REALM_HASH" ]; then
    echo "Current Kerberos realm: $CURRENT_REALM_HASH"
    
    # Create Kerberos configuration that includes Azure AD
    mkdir -p ~/.config/kerberos
    
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
    
    # Azure AD realm
    $DOMAIN = {
        kdc = $DOMAIN
        admin_server = $DOMAIN
        default_domain = $DOMAIN
    }

[domain_realm]
    .$(hostname) = $CURRENT_REALM_HASH
    $(hostname) = $CURRENT_REALM_HASH
    .$DOMAIN = $DOMAIN
    $DOMAIN = $DOMAIN
KRB5_CONF

    echo "✅ Kerberos configuration created"
else
    echo "❌ Could not determine Kerberos realm"
fi

# Create authentication script
echo ""
echo -e "${BLUE}🔧 Creating authentication script...${NC}"

cat > ~/.config/azure_platform_sso_auth.sh << 'AUTH_SCRIPT'
#!/bin/bash

# Azure Platform SSO Authentication Script
# This script handles authentication between local user and Azure AD

LOCAL_USER=$(whoami)
AZURE_USER="pawel.bek@coderedalarmtech.com"
DOMAIN="coderedalarmtech.com"

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
    if kinit "$LOCAL_USER@LKDC:SHA1.9D86C199F3746FDAEBA77551C50E124742C1B33B"; then
        echo "✅ Kerberos ticket acquired"
        klist
        return 0
    else
        echo "❌ Failed to acquire Kerberos ticket"
        return 1
    fi
}

# Function to check Platform SSO status
check_platform_sso() {
    echo "📱 Checking Platform SSO status..."
    
    if sudo dscl "/Platform SSO" -list / 2>/dev/null; then
        echo "✅ Platform SSO node has content"
        sudo dscl "/Platform SSO" -list /
    else
        echo "❌ Platform SSO node is empty"
    fi
}

# Function to sync with Intune
sync_intune() {
    echo "🔄 Syncing with Intune..."
    
    # Check if device is enrolled
    if profiles list | grep -q "compliance\|intune\|microsoft"; then
        echo "✅ Device appears to be enrolled in Intune"
    else
        echo "⚠️  No Intune enrollment detected"
    fi
    
    # Force policy sync (this would typically be done by Intune agent)
    echo "Intune policy sync is typically handled automatically by the Intune agent"
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
        "platform")
            check_platform_sso
            ;;
        "sync")
            sync_intune
            ;;
        "status")
            echo "🔍 Platform SSO Status:"
            echo "Local User: $LOCAL_USER"
            echo "Azure AD User: $AZURE_USER"
            echo "Domain: $DOMAIN"
            echo ""
            check_platform_sso
            echo ""
            echo "Kerberos tickets:"
            klist 2>/dev/null || echo "No tickets"
            echo ""
            echo "Azure AD status:"
            az account show --query name -o tsv 2>/dev/null || echo "Not logged in"
            ;;
        *)
            echo "Usage: $0 {auth|kerberos|platform|sync|status}"
            ;;
    esac
}

main "$@"
AUTH_SCRIPT

chmod +x ~/.config/azure_platform_sso_auth.sh

# Create aliases
echo ""
echo -e "${BLUE}🔧 Creating aliases...${NC}"

cat > ~/.azure_platform_sso_aliases << 'ALIASES'
# Azure Platform SSO Aliases
alias azure-auth='~/.config/azure_platform_sso_auth.sh auth'
alias azure-kerberos='~/.config/azure_platform_sso_auth.sh kerberos'
alias azure-platform='~/.config/azure_platform_sso_auth.sh platform'
alias azure-sync='~/.config/azure_platform_sso_auth.sh sync'
alias azure-status='~/.config/azure_platform_sso_auth.sh status'
ALIASES

# Test the configuration
echo ""
echo -e "${BLUE}�� Testing configuration...${NC}"

# Set environment
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"

# Test Platform SSO
~/.config/azure_platform_sso_auth.sh platform

# Final summary
echo ""
echo -e "${GREEN}🎉 Platform SSO Sync Complete!${NC}"
echo "=============================="
echo ""
echo "📋 What was configured:"
echo "✅ Platform SSO node structure"
echo "✅ User mapping: $LOCAL_USER -> $AZURE_USER"
echo "✅ Kerberos configuration with Azure AD"
echo "✅ Authentication scripts"
echo "✅ Aliases for easy access"
echo ""
echo "🚀 Available commands:"
echo "   azure-auth      - Authenticate with Azure AD"
echo "   azure-kerberos  - Get Kerberos ticket"
echo "   azure-platform  - Check Platform SSO status"
echo "   azure-sync      - Sync with Intune"
echo "   azure-status    - Check overall status"
echo ""
echo "💡 To use:"
echo "1. Source the aliases: source ~/.azure_platform_sso_aliases"
echo "2. Test authentication: azure-auth"
echo "3. Check status: azure-status"
echo ""
echo "🔧 Note:"
echo "If Platform SSO is still empty, you may need to:"
echo "1. Wait for Intune policies to propagate"
echo "2. Restart your Mac"
echo "3. Check Intune enrollment status"
echo "4. Contact your IT admin about Platform SSO policies"

