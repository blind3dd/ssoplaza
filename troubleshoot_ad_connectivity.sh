#!/bin/bash

# Active Directory Connectivity Troubleshooting Script
# This script helps diagnose AD connectivity issues

set -e

echo "🔍 Active Directory Connectivity Troubleshooting"
echo "================================================"

# Check network connectivity
echo "📡 Checking network connectivity..."
echo "Current IP: $(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)"
echo "Gateway: $(route -n get default | grep gateway | awk '{print $2}')"
echo "DNS Server: $(scutil --dns | grep nameserver | head -1 | awk '{print $3}')"

echo ""
echo "🔍 Checking for common AD domain patterns..."

# Common AD domain patterns to check
DOMAINS=(
    "coderedalarmtech.local"
    "coderedalarmtech.internal"
    "corp.coderedalarmtech.com"
    "ad.coderedalarmtech.com"
    "dc.coderedalarmtech.com"
    "internal.coderedalarmtech.com"
)

echo "Testing common AD domain variations:"
for domain in "${DOMAINS[@]}"; do
    echo -n "  Testing $domain... "
    if nslookup "$domain" >/dev/null 2>&1; then
        echo "✅ RESOLVES"
        echo "    IP: $(nslookup "$domain" | grep 'Address:' | tail -1 | awk '{print $2}')"
    else
        echo "❌ No resolution"
    fi
done

echo ""
echo "🔍 Checking for Active Directory services..."

# Check for common AD ports on local network
echo "Scanning local network for AD services..."
LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1 | cut -d. -f1-3)
echo "Scanning $LOCAL_IP.0/24 for AD services..."

# Check for LDAP (389) and Kerberos (88) ports
for i in {1..254}; do
    ip="$LOCAL_IP.$i"
    if timeout 1 bash -c "echo >/dev/tcp/$ip/389" 2>/dev/null; then
        echo "  ✅ Found LDAP service at $ip:389"
    fi
    if timeout 1 bash -c "echo >/dev/tcp/$ip/88" 2>/dev/null; then
        echo "  ✅ Found Kerberos service at $ip:88"
    fi
done

echo ""
echo "🔍 Manual domain discovery options:"
echo "1. Check with your IT administrator for the correct domain name"
echo "2. Look for domain controllers in your network"
echo "3. Check if you need to be on a VPN to access the domain"
echo "4. Verify if the domain uses a different naming convention"

echo ""
echo "💡 Common solutions:"
echo "- Try adding '.local' to your domain: coderedalarmtech.local"
echo "- Check if you need to be on company VPN"
echo "- Ask IT for the correct domain controller IP address"
echo "- Verify if the domain is actually 'coderedalarmtech.com' or something else"

