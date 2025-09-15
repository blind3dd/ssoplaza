#!/bin/bash

# Setup Active Directory Infrastructure
# This script helps you set up AD services and domain configuration

set -e

echo "🔐 Setting Up Active Directory Infrastructure"
echo "============================================="

# Current status analysis
echo "📊 Current Status Analysis:"
echo "✅ Mac is configured with local Kerberos (LKDC)"
echo "✅ DNS search domain: coderedalarmtech.com"
echo "❌ No AD domain controllers found on local network"
echo "❌ Domain coderedalarmtech.com doesn't resolve"

echo ""
echo "🔧 AD Infrastructure Setup Options:"
echo ""

# Option 1: Set up local AD server
echo "Option 1: Set up local Active Directory server"
echo "----------------------------------------------"
echo "This would install and configure AD services on a local machine."
echo ""

# Option 2: Configure for remote AD
echo "Option 2: Configure for remote Active Directory"
echo "-----------------------------------------------"
echo "This would configure your Mac to connect to a remote AD server."
echo ""

# Option 3: Set up Azure AD
echo "Option 3: Set up Azure Active Directory"
echo "---------------------------------------"
echo "This would configure Azure AD integration."
echo ""

read -p "Choose option (1/2/3): " OPTION

case $OPTION in
    1)
        echo ""
        echo "🔧 Setting up local Active Directory server..."
        echo ""
        echo "This requires:"
        echo "1. A Windows Server machine"
        echo "2. Active Directory Domain Services role"
        echo "3. DNS server configuration"
        echo ""
        echo "Would you like to:"
        echo "a) Get instructions for setting up Windows AD server"
        echo "b) Set up Samba AD (Linux-based AD server)"
        echo "c) Cancel"
        read -p "Choose (a/b/c): " SUBOPTION
        
        case $SUBOPTION in
            a)
                echo ""
                echo "📋 Windows Server AD Setup Instructions:"
                echo "1. Install Windows Server 2019/2022"
                echo "2. Add 'Active Directory Domain Services' role"
                echo "3. Promote to Domain Controller"
                echo "4. Create domain: coderedalarmtech.com"
                echo "5. Configure DNS to resolve the domain"
                echo "6. Create user accounts"
                echo ""
                echo "After setup, run this script again with Option 2"
                ;;
            b)
                echo ""
                echo "🐧 Samba AD Setup (Linux-based):"
                echo "1. Install Ubuntu/CentOS server"
                echo "2. Install Samba and related packages"
                echo "3. Configure Samba as AD Domain Controller"
                echo "4. Set up DNS with BIND"
                echo "5. Create domain: coderedalarmtech.com"
                echo ""
                echo "Would you like me to create a Samba AD setup script? (y/n)"
                read -p "Create Samba setup script? " CREATE_SAMBA
                if [ "$CREATE_SAMBA" = "y" ]; then
                    cat > setup_samba_ad.sh << 'SAMBA_EOF'
#!/bin/bash
# Samba Active Directory Setup Script
# Run this on a Linux server to create an AD domain controller

echo "🐧 Setting up Samba Active Directory Domain Controller"
echo "====================================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Install required packages
echo "📦 Installing required packages..."
apt update
apt install -y samba winbind krb5-user krb5-config libpam-winbind libnss-winbind

# Configure Kerberos
echo "🔧 Configuring Kerberos..."
cat > /etc/krb5.conf << KRBCONF
[libdefaults]
    default_realm = CODEREDALARMTECH.COM
    dns_lookup_realm = true
    dns_lookup_kdc = true

[realms]
    CODEREDALARMTECH.COM = {
        kdc = localhost
        admin_server = localhost
    }

[domain_realm]
    .coderedalarmtech.com = CODEREDALARMTECH.COM
    coderedalarmtech.com = CODEREDALARMTECH.COM
KRBCONF

# Configure Samba
echo "🔧 Configuring Samba..."
cat > /etc/samba/smb.conf << SMBCONF
[global]
    workgroup = CODEREDALARMTECH
    realm = CODEREDALARMTECH.COM
    server role = active directory domain controller
    dns forwarder = 8.8.8.8
    idmap_ldb:use rfc2307 = yes
    template shell = /bin/bash
    template homedir = /home/%U

[netlogon]
    path = /var/lib/samba/sysvol/coderedalarmtech.com/scripts
    read only = No

[sysvol]
    path = /var/lib/samba/sysvol
    read only = No
SMBCONF

# Provision the domain
echo "🔧 Provisioning Active Directory domain..."
samba-tool domain provision --realm=CODEREDALARMTECH.COM --domain=CODEREDALARMTECH --server-role=dc --dns-backend=SAMBA_INTERNAL --adminpass=AdminPassword123! --use-rfc2307

# Start services
echo "🚀 Starting services..."
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "✅ Samba AD Domain Controller setup complete!"
echo ""
echo "Domain: coderedalarmtech.com"
echo "Admin password: AdminPassword123!"
echo ""
echo "Next steps:"
echo "1. Configure DNS on this server to resolve coderedalarmtech.com"
echo "2. Update your Mac's DNS to point to this server"
echo "3. Run the Mac domain join script"
SAMBA_EOF
                    chmod +x setup_samba_ad.sh
                    echo "✅ Created setup_samba_ad.sh"
                fi
                ;;
            c)
                echo "Cancelled."
                exit 0
                ;;
        esac
        ;;
    2)
        echo ""
        echo "🔧 Configuring for remote Active Directory..."
        echo ""
        read -p "Enter the AD server IP address: " AD_SERVER_IP
        read -p "Enter the domain name (e.g., coderedalarmtech.com): " DOMAIN_NAME
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
        if sudo dsconfigad -add "$DOMAIN_NAME" -server "$AD_SERVER_IP" -username "$ADMIN_USER" -password "$ADMIN_PASS" -mobile enable -mobileconfirm disable -localhome enable -useuncpath disable -groups "Domain Admins,Enterprise Admins" -alldomains enable -packetsign allow -packetencrypt allow -passinterval 0; then
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
            
            echo ""
            echo "💡 Next steps:"
            echo "1. Restart your Mac"
            echo "2. Login with your AD credentials"
            echo "3. Test authentication with: kinit username@${DOMAIN_NAME^^}"
            
        else
            echo "❌ Failed to join domain"
        fi
        ;;
    3)
        echo ""
        echo "🔧 Setting up Azure Active Directory..."
        echo ""
        echo "This requires:"
        echo "1. Azure AD tenant"
        echo "2. Azure AD Connect (if using hybrid setup)"
        echo "3. Proper DNS configuration"
        echo ""
        echo "Would you like to:"
        echo "a) Set up Azure AD Connect for hybrid authentication"
        echo "b) Configure Azure AD-only authentication"
        echo "c) Get setup instructions"
        read -p "Choose (a/b/c): " AZURE_OPTION
        
        case $AZURE_OPTION in
            a)
                echo "🔧 Azure AD Connect setup requires a Windows server with Azure AD Connect installed."
                echo "This is typically done by your IT team on a dedicated server."
                ;;
            b)
                echo "🔧 Azure AD-only authentication setup..."
                echo "This would configure your Mac for Azure AD authentication without on-premises AD."
                ;;
            c)
                echo "📋 Azure AD Setup Instructions:"
                echo "1. Create Azure AD tenant"
                echo "2. Configure custom domain (coderedalarmtech.com)"
                echo "3. Set up Azure AD Connect (for hybrid)"
                echo "4. Configure DNS records"
                echo "5. Set up user accounts"
                ;;
        esac
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "🎯 Summary:"
echo "You need to set up Active Directory infrastructure before your Mac can authenticate with AD users."
echo "The most common approaches are:"
echo "1. Set up a local AD server (Windows or Samba)"
echo "2. Connect to an existing remote AD server"
echo "3. Use Azure AD with proper configuration"

