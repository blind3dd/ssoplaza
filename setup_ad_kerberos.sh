#!/bin/bash

# Active Directory Kerberos Setup Script
# This script helps configure Kerberos for Active Directory authentication

set -e

echo "🔐 Active Directory Kerberos Setup"
echo "=================================="

# Get AD domain from user
read -p "Enter your Active Directory domain (e.g., company.com): " AD_DOMAIN
read -p "Enter your AD username: " AD_USERNAME
read -p "Enter your AD server IP or hostname: " AD_SERVER

echo ""
echo "🔧 Configuring Kerberos for AD domain: $AD_DOMAIN"
echo "   Username: $AD_USERNAME"
echo "   Server: $AD_SERVER"

# Create kerberos config directory
mkdir -p ~/.config/kerberos

# Generate krb5.conf for Active Directory
cat > ~/.config/kerberos/krb5.conf << KRBCONF
[libdefaults]
    default_realm = ${AD_DOMAIN^^}
    dns_lookup_realm = true
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    default_ccache_name = KEYRING:persistent:%{uid}

[realms]
    ${AD_DOMAIN^^} = {
        kdc = $AD_SERVER
        admin_server = $AD_SERVER
        default_domain = $AD_DOMAIN
    }

[domain_realm]
    .$AD_DOMAIN = ${AD_DOMAIN^^}
    $AD_DOMAIN = ${AD_DOMAIN^^}
KRBCONF

echo "✅ Created Kerberos configuration: ~/.config/kerberos/krb5.conf"

# Set environment variable
export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"

echo ""
echo "🔧 Testing Kerberos configuration..."

# Test kinit
echo "Attempting to get Kerberos ticket for $AD_USERNAME@${AD_DOMAIN^^}..."
if kinit "$AD_USERNAME@${AD_DOMAIN^^}"; then
    echo "✅ Kerberos authentication successful!"
    echo ""
    echo "📋 Current tickets:"
    klist
else
    echo "❌ Kerberos authentication failed"
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "1. Verify the AD server is reachable: ping $AD_SERVER"
    echo "2. Check if the domain resolves: nslookup $AD_DOMAIN"
    echo "3. Verify your username and password"
    echo "4. Check if your machine is joined to the domain"
fi

echo ""
echo "💡 To use this configuration:"
echo "   export KRB5_CONFIG=\"\$HOME/.config/kerberos/krb5.conf\""
echo "   kinit $AD_USERNAME@${AD_DOMAIN^^}"
