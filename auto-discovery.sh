#!/bin/bash

# Auto-Discovery Functions for SSO Plaza
# Automatically detects system configuration instead of hardcoding values

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to discover system hostname information
discover_hostnames() {
    echo -e "${BLUE}🔍 Discovering hostname information...${NC}"
    
    local computer_name=$(scutil --get ComputerName 2>/dev/null || echo "")
    local host_name=$(scutil --get HostName 2>/dev/null || echo "")
    local local_host_name=$(scutil --get LocalHostName 2>/dev/null || echo "")
    local system_hostname=$(hostname 2>/dev/null || echo "")
    
    echo "📋 Hostname Information:"
    echo "   ComputerName: ${computer_name:-'Not set'}"
    echo "   HostName: ${host_name:-'Not set'}"
    echo "   LocalHostName: ${local_host_name:-'Not set'}"
    echo "   System hostname: ${system_hostname:-'Not set'}"
    
    # Export the primary hostname (prefer ComputerName, fallback to hostname)
    export DISCOVERED_HOSTNAME="${computer_name:-$system_hostname}"
    export DISCOVERED_COMPUTER_NAME="$computer_name"
    export DISCOVERED_LOCAL_HOSTNAME="$local_host_name"
    
    echo "✅ Primary hostname: $DISCOVERED_HOSTNAME"
}

# Function to discover Kerberos realm and principals
discover_kerberos_realm() {
    echo -e "${BLUE}🔍 Discovering Kerberos realm and principals...${NC}"
    
    # Get AuthenticationAuthority from current user
    local auth_authority=$(sudo dscl /Search -read /Users/$(whoami) AuthenticationAuthority 2>/dev/null || echo "")
    
    if [[ -n "$auth_authority" ]]; then
        echo "📋 Found AuthenticationAuthority:"
        echo "$auth_authority"
        
        # Extract Kerberos realm hash
        local realm_hash=$(echo "$auth_authority" | grep -o "LKDC:SHA1\.[A-F0-9]*" | head -1)
        if [[ -n "$realm_hash" ]]; then
            export DISCOVERED_REALM_HASH="$realm_hash"
            echo "✅ Discovered realm hash: $realm_hash"
        else
            echo -e "${YELLOW}⚠️  No LKDC realm hash found in AuthenticationAuthority${NC}"
        fi
        
        # Extract all Kerberos principals (look for username@realm pattern)
        local principals=$(echo "$auth_authority" | grep -o "[a-zA-Z0-9._-]*@LKDC:SHA1\.[A-F0-9]*" | tr '\n' ' ')
        if [[ -n "$principals" ]]; then
            export DISCOVERED_PRINCIPALS="$principals"
            echo "✅ Discovered principals: $principals"
        else
            echo -e "${YELLOW}⚠️  No Kerberos principals found${NC}"
        fi
        
        # Extract username from first principal
        local first_principal=$(echo "$auth_authority" | grep -o "[a-zA-Z0-9._-]*@LKDC:SHA1\.[A-F0-9]*" | head -1)
        if [[ -n "$first_principal" ]]; then
            local username=$(echo "$first_principal" | cut -d'@' -f1)
            export DISCOVERED_USERNAME="$username"
            echo "✅ Discovered username: $username"
        fi
        
    else
        echo -e "${RED}❌ Could not read AuthenticationAuthority${NC}"
        return 1
    fi
}

# Function to discover Platform SSO configuration
discover_platform_sso() {
    echo -e "${BLUE}🔍 Discovering Platform SSO configuration...${NC}"
    
    # Check if Platform SSO node exists
    local platform_sso_exists=$(sudo dscl "/Platform SSO" -list / 2>/dev/null || echo "")
    
    if [[ -n "$platform_sso_exists" ]]; then
        echo "✅ Platform SSO node exists"
        
        # Try to read Platform SSO configuration
        local platform_config=$(sudo dscl "/Platform SSO" -read /Config 2>/dev/null || echo "")
        if [[ -n "$platform_config" ]]; then
            echo "📋 Platform SSO Config:"
            echo "$platform_config"
            export PLATFORM_SSO_CONFIGURED="true"
        else
            echo "📋 Platform SSO node exists but not configured"
            export PLATFORM_SSO_CONFIGURED="false"
        fi
    else
        echo "📋 Platform SSO node does not exist"
        export PLATFORM_SSO_CONFIGURED="false"
    fi
}

# Function to discover Azure configuration
discover_azure_config() {
    echo -e "${BLUE}🔍 Discovering Azure configuration...${NC}"
    
    # Check if Azure CLI is available
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI found"
        
        # Check if logged in
        local az_account=$(az account show --query name -o tsv 2>/dev/null || echo "")
        if [[ -n "$az_account" ]]; then
            echo "✅ Azure account: $az_account"
            export AZURE_LOGGED_IN="true"
            export AZURE_ACCOUNT_NAME="$az_account"
        else
            echo "📋 Azure CLI available but not logged in"
            export AZURE_LOGGED_IN="false"
        fi
    else
        echo "📋 Azure CLI not found"
        export AZURE_LOGGED_IN="false"
    fi
}

# Function to discover network configuration
discover_network_config() {
    echo -e "${BLUE}🔍 Discovering network configuration...${NC}"
    
    # Get local IP addresses
    local local_ips=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | tr '\n' ' ')
    if [[ -n "$local_ips" ]]; then
        export DISCOVERED_LOCAL_IPS="$local_ips"
        echo "✅ Local IP addresses: $local_ips"
    fi
    
    # Get primary network interface
    local primary_interface=$(route get default | grep interface | awk '{print $2}' | head -1)
    if [[ -n "$primary_interface" ]]; then
        export DISCOVERED_PRIMARY_INTERFACE="$primary_interface"
        echo "✅ Primary network interface: $primary_interface"
    fi
}

# Function to generate dynamic configuration
generate_dynamic_config() {
    echo -e "${BLUE}🔧 Generating dynamic configuration...${NC}"
    
    # Generate krb5.conf content
    cat > /tmp/dynamic_krb5.conf << EOF
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

    # Generate sso_bridge.conf content
    cat > /tmp/dynamic_sso_bridge.conf << EOF
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

    echo "✅ Generated dynamic configuration files:"
    echo "   - /tmp/dynamic_krb5.conf"
    echo "   - /tmp/dynamic_sso_bridge.conf"
}

# Function to show discovery summary
show_discovery_summary() {
    echo -e "${GREEN}📊 Discovery Summary${NC}"
    echo "=================="
    echo "Hostname: ${DISCOVERED_HOSTNAME:-'Not discovered'}"
    echo "Username: ${DISCOVERED_USERNAME:-'Not discovered'}"
    echo "Realm Hash: ${DISCOVERED_REALM_HASH:-'Not discovered'}"
    echo "Principals: ${DISCOVERED_PRINCIPALS:-'Not discovered'}"
    echo "Platform SSO: ${PLATFORM_SSO_CONFIGURED:-'Unknown'}"
    echo "Azure Status: ${AZURE_LOGGED_IN:-'Unknown'}"
    echo "Primary Interface: ${DISCOVERED_PRIMARY_INTERFACE:-'Not discovered'}"
    echo "Local IPs: ${DISCOVERED_LOCAL_IPS:-'Not discovered'}"
    echo ""
    
    if [[ -n "$DISCOVERED_REALM_HASH" && -n "$DISCOVERED_USERNAME" ]]; then
        echo -e "${GREEN}✅ Ready for dynamic configuration!${NC}"
        echo "You can now use these discovered values instead of hardcoded ones."
    else
        echo -e "${YELLOW}⚠️  Some required values not discovered. Manual configuration may be needed.${NC}"
    fi
}

# Main discovery function
main_discovery() {
    echo -e "${GREEN}🚀 Starting Auto-Discovery for SSO Plaza${NC}"
    echo "=============================================="
    
    discover_hostnames
    echo ""
    
    discover_kerberos_realm
    echo ""
    
    discover_platform_sso
    echo ""
    
    discover_azure_config
    echo ""
    
    discover_network_config
    echo ""
    
    generate_dynamic_config
    echo ""
    
    show_discovery_summary
}

# Export functions for use in other scripts
export -f discover_hostnames
export -f discover_kerberos_realm
export -f discover_platform_sso
export -f discover_azure_config
export -f discover_network_config
export -f generate_dynamic_config
export -f show_discovery_summary

# Run main discovery if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_discovery
fi
