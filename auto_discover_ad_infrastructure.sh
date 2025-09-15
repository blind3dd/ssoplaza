#!/bin/bash

# Auto-Discover Active Directory Infrastructure
# Comprehensive scan for AD services and domain controllers

set -e

echo "🔍 Auto-Discovering Active Directory Infrastructure"
echo "=================================================="

# Get network information
LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
NETWORK=$(echo $LOCAL_IP | cut -d. -f1-3)
GATEWAY=$(route -n get default | grep gateway | awk '{print $2}')

echo "📡 Network Information:"
echo "   Local IP: $LOCAL_IP"
echo "   Network: $NETWORK.0/24"
echo "   Gateway: $GATEWAY"
echo ""

# Function to check if port is open
check_port() {
    local ip=$1
    local port=$2
    local service=$3
    if timeout 2 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
        echo "  ✅ $service ($port) - $ip"
        return 0
    fi
    return 1
}

# Function to get service info
get_service_info() {
    local ip=$1
    local port=$2
    
    # Try to get service banner
    if command -v nc >/dev/null 2>&1; then
        echo -n "    Banner: "
        timeout 3 nc -w1 "$ip" "$port" 2>/dev/null | head -1 || echo "No banner"
    fi
}

echo "🔍 Scanning for Active Directory Services..."
echo "Scanning $NETWORK.0/24 for AD services..."

# Arrays to store found services
declare -a AD_SERVERS=()
declare -a LDAP_SERVERS=()
declare -a KERBEROS_SERVERS=()

# Scan common AD ports
for i in {1..254}; do
    ip="$NETWORK.$i"
    
    # Skip our own IP
    if [ "$ip" = "$LOCAL_IP" ]; then
        continue
    fi
    
    # Check LDAP (389)
    if check_port "$ip" 389 "LDAP"; then
        LDAP_SERVERS+=("$ip")
        get_service_info "$ip" 389
    fi
    
    # Check Kerberos (88)
    if check_port "$ip" 88 "Kerberos"; then
        KERBEROS_SERVERS+=("$ip")
        get_service_info "$ip" 88
    fi
    
    # Check LDAPS (636)
    if check_port "$ip" 636 "LDAPS"; then
        echo "  ✅ LDAPS (636) - $ip"
    fi
    
    # Check Global Catalog (3268)
    if check_port "$ip" 3268 "Global Catalog"; then
        echo "  ✅ Global Catalog (3268) - $ip"
    fi
    
    # Check RPC Endpoint Mapper (135)
    if check_port "$ip" 135 "RPC Endpoint Mapper"; then
        echo "  ✅ RPC Endpoint Mapper (135) - $ip"
    fi
    
    # Check NetBIOS (139)
    if check_port "$ip" 139 "NetBIOS"; then
        echo "  ✅ NetBIOS (139) - $ip"
    fi
    
    # Check SMB (445)
    if check_port "$ip" 445 "SMB"; then
        echo "  ✅ SMB (445) - $ip"
    fi
done

echo ""
echo "📋 Found Active Directory Services:"

if [ ${#LDAP_SERVERS[@]} -gt 0 ]; then
    echo "LDAP Servers:"
    for server in "${LDAP_SERVERS[@]}"; do
        echo "  - $server"
    done
else
    echo "❌ No LDAP servers found"
fi

if [ ${#KERBEROS_SERVERS[@]} -gt 0 ]; then
    echo "Kerberos Servers:"
    for server in "${KERBEROS_SERVERS[@]}"; do
        echo "  - $server"
    done
else
    echo "❌ No Kerberos servers found"
fi

echo ""
echo "🔍 Attempting to discover domain information..."

# Try to get domain info from LDAP servers
for server in "${LDAP_SERVERS[@]}"; do
    echo "Querying LDAP server: $server"
    
    # Try to get root DSE
    if command -v ldapsearch >/dev/null 2>&1; then
        echo "  Attempting LDAP query..."
        timeout 10 ldapsearch -H "ldap://$server" -x -s base -b "" "(objectclass=*)" defaultNamingContext 2>/dev/null | grep defaultNamingContext || echo "  No domain info available"
    else
        echo "  ldapsearch not available, skipping LDAP query"
    fi
done

echo ""
echo "🔍 Checking for existing domain configuration..."

# Check if already joined to a domain
if dsconfigad -show 2>/dev/null; then
    echo "✅ Already joined to a domain"
else
    echo "❌ Not currently joined to any domain"
fi

echo ""
echo "🔍 Checking DNS configuration..."

# Check DNS servers
echo "DNS Servers:"
scutil --dns | grep nameserver | head -5

# Check for domain suffixes
echo "Search Domains:"
scutil --dns | grep search | head -5

echo ""
echo "💡 Recommendations:"

if [ ${#LDAP_SERVERS[@]} -gt 0 ]; then
    echo "1. Found LDAP servers - these are likely your domain controllers"
    echo "2. Try joining domain with one of these IPs as the server"
    echo "3. Common domain names to try:"
    echo "   - coderedalarmtech.local"
    echo "   - coderedalarmtech.internal"
    echo "   - corp.coderedalarmtech.com"
    
    echo ""
    echo "🚀 Quick domain join command (replace DOMAIN and IP):"
    echo "sudo dsconfigad -add DOMAIN -server $(echo ${LDAP_SERVERS[0]}) -username admin -password password"
else
    echo "1. No AD servers found on local network"
    echo "2. Check if you need VPN connection"
    echo "3. Verify AD services are running"
    echo "4. Check firewall settings"
fi

