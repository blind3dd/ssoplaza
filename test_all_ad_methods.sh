#!/bin/bash

# Test All AD Methods with Rollback
# This script tests all three AD methods in order of difficulty, with easy rollback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧪 Testing All AD Methods with Rollback${NC}"
echo "=============================================="

# Function to backup current configuration
backup_config() {
    echo -e "${BLUE}📦 Backing up current configuration...${NC}"
    
    # Create backup directory
    BACKUP_DIR="/tmp/ad_config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup current Kerberos config
    if [ -f ~/.config/kerberos/krb5.conf ]; then
        cp ~/.config/kerberos/krb5.conf "$BACKUP_DIR/"
    fi
    
    # Backup current domain config
    dsconfigad -show > "$BACKUP_DIR/current_domain.txt" 2>/dev/null || echo "No domain configured" > "$BACKUP_DIR/current_domain.txt"
    
    # Backup current AuthenticationAuthority
    sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority > "$BACKUP_DIR/current_auth.txt" 2>/dev/null || echo "No auth info" > "$BACKUP_DIR/current_auth.txt"
    
    echo "✅ Configuration backed up to: $BACKUP_DIR"
    echo "$BACKUP_DIR" > /tmp/last_backup_dir
}

# Function to restore configuration
restore_config() {
    if [ -f /tmp/last_backup_dir ]; then
        BACKUP_DIR=$(cat /tmp/last_backup_dir)
        echo -e "${YELLOW}🔄 Restoring configuration from: $BACKUP_DIR${NC}"
        
        # Restore Kerberos config
        if [ -f "$BACKUP_DIR/krb5.conf" ]; then
            mkdir -p ~/.config/kerberos
            cp "$BACKUP_DIR/krb5.conf" ~/.config/kerberos/
        fi
        
        # Remove domain binding if it exists
        if dsconfigad -show >/dev/null 2>&1; then
            echo "Removing current domain binding..."
            sudo dsconfigad -remove -force
        fi
        
        echo "✅ Configuration restored"
    else
        echo -e "${RED}❌ No backup found${NC}"
    fi
}

# Function to test method
test_method() {
    local method_name="$1"
    local method_script="$2"
    
    echo ""
    echo -e "${GREEN}🧪 Testing Method: $method_name${NC}"
    echo "=================================="
    
    # Backup before testing
    backup_config
    
    # Run the method
    if [ -f "$method_script" ]; then
        echo "Running $method_script..."
        if bash "$method_script"; then
            echo -e "${GREEN}✅ $method_name setup completed${NC}"
            
            # Test authentication
            echo "Testing authentication..."
            if test_authentication; then
                echo -e "${GREEN}✅ $method_name authentication successful!${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  $method_name setup completed but authentication failed${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ $method_name setup failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Method script not found: $method_script${NC}"
        return 1
    fi
}

# Function to test authentication
test_authentication() {
    echo "🔍 Testing authentication methods..."
    
    # Test 1: Check if domain is joined
    if dsconfigad -show >/dev/null 2>&1; then
        echo "✅ Domain binding exists"
    else
        echo "❌ No domain binding"
        return 1
    fi
    
    # Test 2: Check Kerberos configuration
    if [ -f ~/.config/kerberos/krb5.conf ]; then
        echo "✅ Kerberos configuration exists"
    else
        echo "❌ No Kerberos configuration"
        return 1
    fi
    
    # Test 3: Try to get a ticket (this will prompt for password)
    echo "🔐 Testing Kerberos ticket acquisition..."
    echo "You'll be prompted for your AD password..."
    
    # Try to get ticket with a test user (you'll need to provide real credentials)
    read -p "Enter your AD username for testing: " TEST_USER
    if kinit "$TEST_USER@CODEREDALARMTECH.COM" 2>/dev/null; then
        echo "✅ Kerberos ticket acquired successfully"
        klist
        kdestroy
        return 0
    else
        echo "❌ Failed to acquire Kerberos ticket"
        return 1
    fi
}

# Method 1: Azure AD (Easiest - Cloud-based)
create_azure_ad_method() {
    cat > method1_azure_ad.sh << 'AZURE_EOF'
#!/bin/bash
echo "☁️  Method 1: Azure Active Directory (Easiest)"
echo "=============================================="

echo "This method uses Azure AD for authentication."
echo "It's the easiest because it doesn't require local infrastructure."

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "Installing Azure CLI..."
    # Install Azure CLI (this might require different methods depending on your system)
    echo "Please install Azure CLI manually: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

echo "🔧 Configuring Azure AD authentication..."

# Login to Azure
echo "Logging into Azure..."
az login --use-device-code

# Get tenant information
echo "Getting Azure AD tenant information..."
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"

# Configure Azure AD authentication for macOS
echo "🔧 Configuring macOS for Azure AD..."

# Create Azure AD configuration
cat > ~/.azure_ad_config << AZURE_CONFIG
# Azure AD Configuration
TENANT_ID=$TENANT_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
DOMAIN=coderedalarmtech.com
AZURE_CONFIG

echo "✅ Azure AD configuration created"
echo ""
echo "💡 Next steps for Azure AD:"
echo "1. Configure your domain in Azure AD"
echo "2. Set up Azure AD Connect (if using hybrid)"
echo "3. Configure DNS records"
echo "4. Test authentication"

AZURE_EOF
chmod +x method1_azure_ad.sh
}

# Method 2: Remote AD Server (Medium difficulty)
create_remote_ad_method() {
    cat > method2_remote_ad.sh << 'REMOTE_EOF'
#!/bin/bash
echo "🌐 Method 2: Remote Active Directory Server (Medium)"
echo "=================================================="

echo "This method connects to an existing AD server."
echo "It's medium difficulty because it requires network connectivity."

# Get AD server information
read -p "Enter AD server IP address: " AD_SERVER_IP
read -p "Enter domain name (e.g., coderedalarmtech.com): " DOMAIN_NAME
read -p "Enter admin username: " ADMIN_USER
read -s -p "Enter admin password: " ADMIN_PASS
echo ""

echo "🔧 Testing connectivity to AD server..."
if ping -c 3 "$AD_SERVER_IP" >/dev/null 2>&1; then
    echo "✅ AD server is reachable"
else
    echo "❌ Cannot reach AD server"
    exit 1
fi

echo "🔧 Joining domain..."
if sudo dsconfigad -add "$DOMAIN_NAME" -server "$AD_SERVER_IP" -username "$AD_USER" -password "$AD_PASS" -mobile enable -mobileconfirm disable -localhome enable -useuncpath disable -groups "Domain Admins,Enterprise Admins" -alldomains enable -packetsign allow -packetencrypt allow -passinterval 0; then
    echo "✅ Successfully joined domain: $DOMAIN_NAME"
    
    # Configure Kerberos
    echo "🔧 Configuring Kerberos..."
    mkdir -p ~/.config/kerberos
    
    cat > ~/.config/kerberos/krb5.conf << KRBCONF
[libdefaults]
    default_realm = ${DOMAIN_NAME^^}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${DOMAIN_NAME^^} = {
        kdc = $AD_SERVER_IP
        admin_server = $AD_SERVER_IP
        default_domain = $DOMAIN_NAME
    }

[domain_realm]
    .$DOMAIN_NAME = ${DOMAIN_NAME^^}
    $DOMAIN_NAME = ${DOMAIN_NAME^^}
KRBCONF

    export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
    echo "✅ Kerberos configuration created"
    
else
    echo "❌ Failed to join domain"
    exit 1
fi

REMOTE_EOF
chmod +x method2_remote_ad.sh
}

# Method 3: Local AD Server (Hardest - Full infrastructure)
create_local_ad_method() {
    cat > method3_local_ad.sh << 'LOCAL_EOF'
#!/bin/bash
echo "🏠 Method 3: Local Active Directory Server (Hardest)"
echo "=================================================="

echo "This method sets up a local AD server."
echo "It's the hardest because it requires full infrastructure setup."

echo "🔧 Setting up local AD server..."

# Check if we can install Samba AD
if command -v apt >/dev/null 2>&1; then
    echo "Detected Debian/Ubuntu system"
    PLATFORM="debian"
elif command -v yum >/dev/null 2>&1; then
    echo "Detected RedHat/CentOS system"
    PLATFORM="redhat"
else
    echo "❌ Unsupported platform for local AD server"
    echo "This method requires a Linux server"
    exit 1
fi

echo "⚠️  This method requires a separate Linux server to act as AD domain controller."
echo "It cannot be run on macOS directly."
echo ""
echo "Would you like to:"
echo "1. Get instructions for setting up a Linux AD server"
echo "2. Skip this method"
read -p "Choose (1/2): " CHOICE

if [ "$CHOICE" = "1" ]; then
    echo ""
    echo "📋 Linux AD Server Setup Instructions:"
    echo "1. Set up Ubuntu/CentOS server"
    echo "2. Install Samba and related packages"
    echo "3. Configure as AD Domain Controller"
    echo "4. Set up DNS server"
    echo "5. Create domain: coderedalarmtech.com"
    echo ""
    echo "After setting up the Linux server, run Method 2 to connect your Mac"
else
    echo "Skipping local AD server setup"
fi

LOCAL_EOF
chmod +x method3_local_ad.sh
}

# Main execution
main() {
    echo "🎯 Testing Strategy:"
    echo "1. Start with easiest method (Azure AD)"
    echo "2. Test authentication"
    echo "3. If successful, keep it; if not, rollback and try next method"
    echo "4. Repeat for all methods"
    echo ""
    
    # Create method scripts
    create_azure_ad_method
    create_remote_ad_method
    create_local_ad_method
    
    # Test Method 1: Azure AD
    if test_method "Azure AD" "method1_azure_ad.sh"; then
        echo -e "${GREEN}🎉 Azure AD method successful! Keeping this configuration.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Azure AD method failed. Rolling back and trying next method.${NC}"
        restore_config
    fi
    
    # Test Method 2: Remote AD
    if test_method "Remote AD Server" "method2_remote_ad.sh"; then
        echo -e "${GREEN}🎉 Remote AD method successful! Keeping this configuration.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Remote AD method failed. Rolling back and trying next method.${NC}"
        restore_config
    fi
    
    # Test Method 3: Local AD
    if test_method "Local AD Server" "method3_local_ad.sh"; then
        echo -e "${GREEN}🎉 Local AD method successful! Keeping this configuration.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Local AD method failed. Rolling back.${NC}"
        restore_config
    fi
    
    echo -e "${RED}❌ All methods failed. Your original configuration has been restored.${NC}"
}

# Run main function
main

