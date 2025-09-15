#!/bin/bash

# Manual Active Directory Setup Script
# Use this when you have the correct domain information

set -e

echo "🔐 Manual Active Directory Setup"
echo "================================"

echo "This script will help you set up AD when you have the correct domain information."
echo ""

# Get domain information
read -p "Enter the correct AD domain (e.g., company.local): " AD_DOMAIN
read -p "Enter the domain controller IP address: " DC_IP
read -p "Enter your AD username: " AD_USERNAME
read -p "Enter your AD admin username (for domain join): " AD_ADMIN
read -s -p "Enter your AD admin password: " AD_PASSWORD
echo ""

echo ""
echo "🔧 Testing connectivity to domain controller..."

# Test connectivity to DC
if ping -c 3 "$DC_IP" >/dev/null 2>&1; then
    echo "✅ Domain controller $DC_IP is reachable"
else
    echo "❌ Cannot reach domain controller $DC_IP"
    echo "Please check the IP address and network connectivity"
    exit 1
fi

# Test LDAP connectivity
echo "Testing LDAP connectivity..."
if timeout 5 bash -c "echo >/dev/tcp/$DC_IP/389" 2>/dev/null; then
    echo "✅ LDAP port 389 is open on $DC_IP"
else
    echo "❌ LDAP port 389 is not accessible on $DC_IP"
fi

# Test Kerberos connectivity
echo "Testing Kerberos connectivity..."
if timeout 5 bash -c "echo >/dev/tcp/$DC_IP/88" 2>/dev/null; then
    echo "✅ Kerberos port 88 is open on $DC_IP"
else
    echo "❌ Kerberos port 88 is not accessible on $DC_IP"
fi

echo ""
echo "🔧 Joining domain: $AD_DOMAIN"

# Join the domain
if sudo dsconfigad -add "$AD_DOMAIN" -username "$AD_ADMIN" -password "$AD_PASSWORD" -mobile enable -mobileconfirm disable -localhome enable -useuncpath disable -groups "Domain Admins,Enterprise Admins" -alldomains enable -packetsign allow -packetencrypt allow -passinterval 0; then
    echo "✅ Successfully joined domain: $AD_DOMAIN"
    
    echo ""
    echo "🔧 Configuring Kerberos..."
    
    # Create kerberos config
    mkdir -p ~/.config/kerberos
    
    cat > ~/.config/kerberos/krb5.conf << KRBCONF
[libdefaults]
    default_realm = ${AD_DOMAIN^^}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${AD_DOMAIN^^} = {
        kdc = $DC_IP
        admin_server = $DC_IP
        default_domain = $AD_DOMAIN
    }

[domain_realm]
    .$AD_DOMAIN = ${AD_DOMAIN^^}
    $AD_DOMAIN = ${AD_DOMAIN^^}
KRBCONF

    export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
    
    echo "✅ Kerberos configuration created"
    
    echo ""
    echo "🔧 Testing authentication..."
    if kinit "$AD_USERNAME@${AD_DOMAIN^^}"; then
        echo "✅ Authentication successful!"
        klist
    else
        echo "❌ Authentication failed"
    fi
    
else
    echo "❌ Failed to join domain"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "1. Verify domain name and admin credentials"
    echo "2. Check if the domain controller is accessible"
    echo "3. Ensure your Mac is on the same network as the domain"
    echo "4. Check if the domain allows Mac joins"
fi

echo ""
echo "💡 Next steps:"
echo "1. Restart your Mac"
echo "2. Login with your AD credentials"
echo "3. Test Kerberos authentication"
