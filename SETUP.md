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
