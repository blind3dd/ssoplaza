#!/bin/bash

# Configure Platform SSO for Azure AD Integration
# This script configures the /Platform SSO node for Azure AD

set -e

echo "🔐 Configuring Platform SSO for Azure AD Integration"
echo "===================================================="

# Function to check Platform SSO node status
check_platform_sso() {
    echo "🔧 Checking Platform SSO node status..."
    
    if sudo dscl "/Platform SSO" -list / &>/dev/null; then
        echo "✅ Platform SSO node exists and is accessible"
        return 0
    else
        echo "❌ Platform SSO node not accessible"
        return 1
    fi
}

# Function to create Platform SSO configuration
create_platform_sso_config() {
    local azure_domain="$1"
    local azure_realm=$(echo "$azure_domain" | tr '[:lower:]' '[:upper:]')
    
    echo "🔧 Creating Platform SSO configuration for Azure AD..."
    
    # Create Config directory if it doesn't exist
    if ! sudo dscl "/Platform SSO" -read /Config &>/dev/null; then
        echo "Creating Config directory..."
        sudo dscl "/Platform SSO" -create /Config
    fi
    
    # Create Azure AD provider configuration
    echo "Creating Azure AD provider configuration..."
    sudo dscl "/Platform SSO" -create /Config/AzureAD
    sudo dscl "/Platform SSO" -create /Config/AzureAD/Provider "Microsoft Azure AD"
    sudo dscl "/Platform SSO" -create /Config/AzureAD/Domain "$azure_domain"
    sudo dscl "/Platform SSO" -create /Config/AzureAD/Realm "$azure_realm"
    sudo dscl "/Platform SSO" -create /Config/AzureAD/Enabled "true"
    
    # Create Kerberos bridge configuration
    echo "Creating Kerberos bridge configuration..."
    sudo dscl "/Platform SSO" -create /Config/KerberosBridge
    sudo dscl "/Platform SSO" -create /Config/KerberosBridge/LocalRealm "LKDC:SHA1.YOUR_REALM_HASH_HERE"
    sudo dscl "/Platform SSO" -create /Config/KerberosBridge/AzureRealm "$azure_realm"
    sudo dscl "/Platform SSO" -create /Config/KerberosBridge/Enabled "true"
    
    # Create SSO policies
    echo "Creating SSO policies..."
    sudo dscl "/Platform SSO" -create /Config/SSOPolicies
    sudo dscl "/Platform SSO" -create /Config/SSOPolicies/AllowKerberos "true"
    sudo dscl "/Platform SSO" -create /Config/SSOPolicies/AllowAzureAD "true"
    sudo dscl "/Platform SSO" -create /Config/SSOPolicies/AllowCrossRealm "true"
    
    echo "✅ Platform SSO configuration created"
}

# Function to create Platform SSO users structure
create_platform_sso_users() {
    echo "🔧 Creating Platform SSO users structure..."
    
    # Create Users directory if it doesn't exist
    if ! sudo dscl "/Platform SSO" -read /Users &>/dev/null; then
        echo "Creating Users directory..."
        sudo dscl "/Platform SSO" -create /Users
    fi
    
    # Create a template user entry
    local current_user=$(whoami)
    echo "Creating user entry for $current_user..."
    sudo dscl "/Platform SSO" -create /Users/$current_user
    sudo dscl "/Platform SSO" -create /Users/$current_user/RealName "$current_user"
    sudo dscl "/Platform SSO" -create /Users/$current_user/RecordName "$current_user"
    sudo dscl "/Platform SSO" -create /Users/$current_user/UniqueID "501"
    sudo dscl "/Platform SSO" -create /Users/$current_user/PrimaryGroupID "20"
    sudo dscl "/Platform SSO" -create /Users/$current_user/UserShell "/bin/zsh"
    sudo dscl "/Platform SSO" -create /Users/$current_user/NFSHomeDirectory "/Users/$current_user"
    
    echo "✅ Platform SSO users structure created"
}

# Function to create Platform SSO groups structure
create_platform_sso_groups() {
    echo "🔧 Creating Platform SSO groups structure..."
    
    # Create Groups directory if it doesn't exist
    if ! sudo dscl "/Platform SSO" -read /Groups &>/dev/null; then
        echo "Creating Groups directory..."
        sudo dscl "/Platform SSO" -create /Groups
    fi
    
    # Create admin group
    echo "Creating admin group..."
    sudo dscl "/Platform SSO" -create /Groups/admin
    sudo dscl "/Platform SSO" -create /Groups/admin/RealName "Administrators"
    sudo dscl "/Platform SSO" -create /Groups/admin/RecordName "admin"
    sudo dscl "/Platform SSO" -create /Groups/admin/UniqueID "80"
    sudo dscl "/Platform SSO" -create /Groups/admin/PrimaryGroupID "80"
    
    # Create staff group
    echo "Creating staff group..."
    sudo dscl "/Platform SSO" -create /Groups/staff
    sudo dscl "/Platform SSO" -create /Groups/staff/RealName "Staff"
    sudo dscl "/Platform SSO" -create /Groups/staff/RecordName "staff"
    sudo dscl "/Platform SSO" -create /Groups/staff/UniqueID "20"
    sudo dscl "/Platform SSO" -create /Groups/staff/PrimaryGroupID "20"
    
    echo "✅ Platform SSO groups structure created"
}

# Function to verify Platform SSO configuration
verify_platform_sso() {
    echo "🔧 Verifying Platform SSO configuration..."
    
    echo "Configuration:"
    sudo dscl "/Platform SSO" -read /Config/AzureAD 2>/dev/null || echo "Azure AD config not found"
    echo ""
    
    echo "Users:"
    sudo dscl "/Platform SSO" -list /Users 2>/dev/null || echo "No users found"
    echo ""
    
    echo "Groups:"
    sudo dscl "/Platform SSO" -list /Groups 2>/dev/null || echo "No groups found"
    echo ""
    
    echo "SSO Policies:"
    sudo dscl "/Platform SSO" -read /Config/SSOPolicies 2>/dev/null || echo "SSO policies not found"
}

# Function to create Platform SSO management script
create_platform_sso_management() {
    local azure_domain="$1"
    
    echo "🔧 Creating Platform SSO management script..."
    
    cat > ~/.config/kerberos/platform_sso_management.sh << 'EOF'
#!/bin/bash

# Platform SSO Management Script
# This script helps manage Platform SSO configuration

set -e

# Function to show Platform SSO status
show_status() {
    echo "📋 Platform SSO Status"
    echo "======================"
    
    echo "Node Status:"
    if sudo dscl "/Platform SSO" -list / &>/dev/null; then
        echo "✅ Platform SSO node accessible"
    else
        echo "❌ Platform SSO node not accessible"
        return 1
    fi
    
    echo ""
    echo "Configuration:"
    sudo dscl "/Platform SSO" -read /Config/AzureAD 2>/dev/null || echo "Azure AD config not found"
    
    echo ""
    echo "Users:"
    sudo dscl "/Platform SSO" -list /Users 2>/dev/null || echo "No users found"
    
    echo ""
    echo "Groups:"
    sudo dscl "/Platform SSO" -list /Groups 2>/dev/null || echo "No groups found"
}

# Function to add user to Platform SSO
add_user() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        echo "Usage: add_user <username>"
        return 1
    fi
    
    echo "Adding user $username to Platform SSO..."
    sudo dscl "/Platform SSO" -create /Users/$username
    sudo dscl "/Platform SSO" -create /Users/$username/RealName "$username"
    sudo dscl "/Platform SSO" -create /Users/$username/RecordName "$username"
    sudo dscl "/Platform SSO" -create /Users/$username/UniqueID "501"
    sudo dscl "/Platform SSO" -create /Users/$username/PrimaryGroupID "20"
    sudo dscl "/Platform SSO" -create /Users/$username/UserShell "/bin/zsh"
    sudo dscl "/Platform SSO" -create /Users/$username/NFSHomeDirectory "/Users/$username"
    
    echo "✅ User $username added to Platform SSO"
}

# Function to list all Platform SSO data
list_all() {
    echo "📋 All Platform SSO Data"
    echo "========================"
    
    echo "Full node structure:"
    sudo dscl "/Platform SSO" -list / 2>/dev/null || echo "No data found"
    
    echo ""
    echo "Detailed configuration:"
    sudo dscl "/Platform SSO" -read /Config 2>/dev/null || echo "No config found"
}

# Main menu
main() {
    echo "Platform SSO Management"
    echo "======================="
    echo "1. Show Status"
    echo "2. Add User"
    echo "3. List All Data"
    echo "4. Exit"
    echo ""
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1) show_status ;;
        2) 
            read -p "Enter username: " username
            add_user "$username"
            ;;
        3) list_all ;;
        4) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
}

# Run main function
main "$@"
EOF

    chmod +x ~/.config/kerberos/platform_sso_management.sh
    echo "✅ Platform SSO management script created"
    echo "   File: ~/.config/kerberos/platform_sso_management.sh"
}

# Function to create aliases for Platform SSO
create_platform_sso_aliases() {
    echo "🔧 Creating Platform SSO aliases..."
    
    cat >> ~/.zshrc << 'EOF'

# Platform SSO aliases
alias platform-sso-status='~/.config/kerberos/platform_sso_management.sh'
alias platform-sso-list='sudo dscl "/Platform SSO" -list /'
alias platform-sso-config='sudo dscl "/Platform SSO" -read /Config'
alias platform-sso-users='sudo dscl "/Platform SSO" -list /Users'
alias platform-sso-groups='sudo dscl "/Platform SSO" -list /Groups'
alias platform-sso-azure='sudo dscl "/Platform SSO" -read /Config/AzureAD'
EOF

    echo "✅ Platform SSO aliases added to ~/.zshrc"
}

# Function to show final status
show_final_status() {
    local azure_domain="$1"
    
    echo ""
    echo "🎉 Platform SSO Configuration Complete!"
    echo ""
    echo "Platform SSO Node: /Platform SSO"
    echo "Azure AD Domain: $azure_domain"
    echo ""
    echo "Configuration Files:"
    echo "==================="
    echo "- Platform SSO Management: ~/.config/kerberos/platform_sso_management.sh"
    echo "- Azure Kerberos Config: ~/.config/kerberos/azure_krb5.conf"
    echo "- Local Kerberos Config: ~/.config/kerberos/krb5.conf"
    echo ""
    echo "Useful Commands:"
    echo "==============="
    echo "- platform-sso-status (manage Platform SSO)"
    echo "- platform-sso-list (list all Platform SSO data)"
    echo "- platform-sso-config (view Platform SSO configuration)"
    echo "- platform-sso-users (list Platform SSO users)"
    echo "- platform-sso-groups (list Platform SSO groups)"
    echo "- platform-sso-azure (view Azure AD configuration)"
    echo ""
    echo "Next Steps:"
    echo "==========="
    echo "1. Run 'platform-sso-status' to manage Platform SSO"
    echo "2. Test the configuration with 'platform-sso-list'"
    echo "3. Integrate with your Azure AD tenant"
    echo "4. Configure cross-realm trust if needed"
}

# Main execution
main() {
    echo "Please provide your Azure AD domain:"
    read -p "Azure AD Domain (e.g., yourcompany.onmicrosoft.com): " azure_domain
    
    if [[ -z "$azure_domain" ]]; then
        echo "❌ Azure AD domain is required"
        exit 1
    fi
    
    if ! check_platform_sso; then
        echo "❌ Cannot access Platform SSO node"
        exit 1
    fi
    
    create_platform_sso_config "$azure_domain"
    create_platform_sso_users
    create_platform_sso_groups
    create_platform_sso_management "$azure_domain"
    create_platform_sso_aliases
    verify_platform_sso
    show_final_status "$azure_domain"
}

# Run main function
main "$@"
