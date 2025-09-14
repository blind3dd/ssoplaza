#!/bin/bash

# Active Directory Domain Join Script
# This script helps join your Mac to an Active Directory domain

set -e

echo "🔐 Active Directory Domain Join"
echo "==============================="

# Get AD domain information
read -p "Enter your Active Directory domain (e.g., company.com): " AD_DOMAIN
read -p "Enter your AD admin username: " AD_ADMIN
read -s -p "Enter your AD admin password: " AD_PASSWORD
echo ""

echo ""
echo "🔧 Joining domain: $AD_DOMAIN"

# Join the domain using dsconfigad
if sudo dsconfigad -add "$AD_DOMAIN" -username "$AD_ADMIN" -password "$AD_PASSWORD" -mobile enable -mobileconfirm disable -localhome enable -useuncpath disable -groups "Domain Admins,Enterprise Admins" -alldomains enable -packetsign allow -packetencrypt allow -passinterval 0; then
    echo "✅ Successfully joined domain: $AD_DOMAIN"
    echo ""
    echo "�� Verifying domain join..."
    dsconfigad -show
else
    echo "❌ Failed to join domain"
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "1. Verify the domain name is correct"
    echo "2. Check if you have admin credentials"
    echo "3. Ensure network connectivity to domain controllers"
    echo "4. Check if the domain allows Mac joins"
fi

echo ""
echo "💡 After joining the domain:"
echo "1. Restart your Mac"
echo "2. Login with your AD credentials"
echo "3. Run the Kerberos setup script"
