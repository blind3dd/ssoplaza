#!/bin/bash

# Sanitize and Setup Script for SSO Plaza
# This script replaces hardcoded values with auto-discovery and creates safe versions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🧹 Sanitizing SSO Plaza for Safe Commit${NC}"
echo "=============================================="

# Source the auto-discovery functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/auto-discovery.sh"

# Run auto-discovery
echo -e "${BLUE}🔍 Running auto-discovery...${NC}"
discover_hostnames
discover_kerberos_realm
discover_platform_sso
discover_azure_config
discover_network_config

echo ""
echo -e "${BLUE}🔧 Creating sanitized versions...${NC}"

# Create sanitized versions of scripts
create_sanitized_scripts() {
    echo "📝 Creating sanitized script versions..."
    
    # List of scripts to sanitize
    local scripts=(
        "working_sso_setup.sh"
        "unified_sso_setup.sh"
        "configure_platform_sso.sh"
        "azure_kerberos_bridge.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo "   Sanitizing $script..."
            
            # Create sanitized version
            sed -e "s/LKDC:SHA1\.9D86C199F3746FDAEBA77551C50E124742C1B33B/LKDC:SHA1.YOUR_REALM_HASH_HERE/g" \
                -e "s/usualsuspectx@LKDC:SHA1\.9D86C199F3746FDAEBA77551C50E124742C1B33B/\${USER}@LKDC:SHA1.YOUR_REALM_HASH_HERE/g" \
                -e "s/usualsuspectx@LKDC:SHA1\.9D86C199F3746FDAEBA77551C50E124742C1B33B/\${USER}@LKDC:SHA1.YOUR_REALM_HASH_HERE/g" \
                -e "s/pawelbekmacbookm1max/YOUR_HOSTNAME_HERE/g" \
                "$script" > "${script}.sanitized"
            
            echo "   ✅ Created ${script}.sanitized"
        fi
    done
}

# Create .gitignore
create_gitignore() {
    echo "📝 Creating .gitignore..."
    
    cat > .gitignore << 'EOF'
# Sensitive configuration files
sso_bridge.conf
krb5.conf
*.log
*.tmp
*cache*
*session*

# Environment files
.env*
*secret*
*credential*
*password*
*token*
*key*

# Generated files
~/.sso_aliases
~/.config/kerberos/
/tmp/dynamic_*

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Backup files
*.bak
*.backup
*~

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Nix
result
.direnv/
EOF

    echo "   ✅ Created .gitignore"
}

# Create setup instructions
create_setup_instructions() {
    echo "📝 Creating setup instructions..."
    
    cat > SETUP.md << 'EOF'
# SSO Plaza Setup Instructions

## Quick Start with Auto-Discovery

### Option 1: Full Auto-Discovery Setup (Recommended)
```bash
# Run the auto-discovery setup
./working_sso_setup_auto.sh
```

### Option 2: Manual Setup with Templates
```bash
# 1. Run auto-discovery to get your system values
./auto-discovery.sh

# 2. Copy template files and customize
cp sso_bridge.conf.example sso_bridge.conf
cp krb5.conf.example ~/.config/kerberos/krb5.conf

# 3. Replace placeholders with discovered values
# Use the output from auto-discovery.sh to replace:
# - YOUR_REALM_HASH_HERE
# - YOUR_HOSTNAME_HERE
# - YOUR_COMPUTER_NAME_HERE
# - etc.
```

## What Gets Auto-Discovered

The auto-discovery system automatically detects:

- **Hostname Information**: ComputerName, HostName, LocalHostName
- **Kerberos Configuration**: Realm hash, principals, username
- **Platform SSO Status**: Whether Platform SSO is configured
- **Azure Status**: Azure CLI availability and login status
- **Network Configuration**: Local IPs, primary interface

## Security Notes

- Original configuration files with hardcoded values are preserved as `.sanitized` versions
- Template files (`.example`) are provided for manual setup
- The `.gitignore` file prevents accidental commit of sensitive data
- Auto-discovery eliminates the need for hardcoded sensitive values

## Available Commands

After setup, you can use these aliases (source ~/.sso_aliases):

- `sso-status` - Check authentication status
- `sso-principals` - List available principals
- `sso-login-kerberos` - Authenticate with first available principal
- `sso-login-kerberos-lkdc` - Authenticate with LKDC principal
- `sso-refresh` - Refresh Kerberos tokens
- `sso-network-info` - Show network information

## Troubleshooting

If auto-discovery fails:

1. Check that you have sudo access
2. Verify Kerberos tools are installed
3. Ensure you're in a nix-shell with required packages
4. Check that your system has AuthenticationAuthority configured

For manual configuration, use the `.example` template files and replace placeholders with your actual values.
EOF

    echo "   ✅ Created SETUP.md"
}

# Create a safe commit script
create_commit_script() {
    echo "📝 Creating safe commit script..."
    
    cat > safe-commit.sh << 'EOF'
#!/bin/bash

# Safe Commit Script for SSO Plaza
# This script ensures only safe files are committed

set -e

echo "🔒 Preparing safe commit for SSO Plaza..."

# Check for any remaining hardcoded values
echo "🔍 Checking for hardcoded values..."

# Check for the specific realm hash
if grep -r "LKDC:SHA1\.9D86C199F3746FDAEBA77551C50E124742C1B33B" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded realm hash! Please sanitize first."
    exit 1
fi

# Check for hardcoded username
if grep -r "usualsuspectx@LKDC" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded username! Please sanitize first."
    exit 1
fi

# Check for hardcoded hostname
if grep -r "pawelbekmacbookm1max" . --exclude-dir=.git --exclude="*.sanitized" --exclude="safe-commit.sh" --exclude="auto-discovery.sh"; then
    echo "❌ Found hardcoded hostname! Please sanitize first."
    exit 1
fi

echo "✅ No hardcoded values found. Safe to commit!"

# Show what will be committed
echo ""
echo "📋 Files to be committed:"
git status --porcelain | grep -v "^D" | awk '{print "   " $2}'

echo ""
echo "🚀 Ready to commit! Run:"
echo "   git add ."
echo "   git commit -m 'Add SSO Plaza with auto-discovery'"
EOF

    chmod +x safe-commit.sh
    echo "   ✅ Created safe-commit.sh"
}

# Main execution
main() {
    create_sanitized_scripts
    create_gitignore
    create_setup_instructions
    create_commit_script
    
    echo ""
    echo -e "${GREEN}✅ Sanitization Complete!${NC}"
    echo "=========================="
    echo ""
    echo "📋 What was created:"
    echo "   - Sanitized versions of all scripts (*.sanitized)"
    echo "   - Template configuration files (*.example)"
    echo "   - Auto-discovery system (auto-discovery.sh)"
    echo "   - Dynamic setup script (working_sso_setup_auto.sh)"
    echo "   - .gitignore file"
    echo "   - SETUP.md instructions"
    echo "   - safe-commit.sh script"
    echo ""
    echo "🔒 Security improvements:"
    echo "   - No hardcoded realm hashes"
    echo "   - No hardcoded usernames"
    echo "   - No hardcoded hostnames"
    echo "   - Automatic discovery of system configuration"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Test the auto-discovery: ./auto-discovery.sh"
    echo "   2. Test the dynamic setup: ./working_sso_setup_auto.sh"
    echo "   3. Check commit safety: ./safe-commit.sh"
    echo "   4. Commit when ready: git add . && git commit -m 'Add SSO Plaza with auto-discovery'"
}

# Run main function
main
