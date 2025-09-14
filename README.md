# SSO Plaza - Kerberos + Azure AD + SSO Integration

A complete Nix-based setup for Kerberos, Azure AD, and SSO integration on macOS.

## 🚀 Quick Start

### Option 1: Full Setup (Recommended)
```bash
./quick-setup.sh
```

### Option 2: One-Liner (Minimal)
```bash
./one-liner-setup.sh
```

### Option 3: Manual Nix Commands
```bash
# Install Nix (if not present)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- --no-confirm

# Enter the environment
nix-shell nix-sso-setup.nix
```

This will:
- Install Nix if not present
- Set up all necessary packages (Kerberos, Azure CLI, SSH with Kerberos, etc.)
- Create a development environment with all tools

## 📦 What's Included

### Core Packages
- **krb5** - MIT Kerberos 5 implementation
- **azure-cli** - Azure command-line interface
- **opensshWithKerberos** - SSH with Kerberos authentication support

### Development Tools
- **curl, jq, git, vim** - Essential development tools
- **nmap, bind.dnsutils** - Network diagnostics

## 🛠️ Usage

### Start the Environment
```bash
nix-shell nix-sso-setup.nix
```

### Common Commands

#### Kerberos Authentication
```bash
# Get a ticket
kinit username@REALM.COM

# List current tickets
klist

# Destroy tickets
kdestroy
```

#### Azure AD Integration
```bash
# Login to Azure (may need manual workaround)
az login --use-device-code

# Check Azure status
az account show
```

#### SSH with Kerberos
```bash
# SSH with Kerberos authentication
ssh -K username@hostname

# SSH with Kerberos ticket forwarding
ssh -K -A username@hostname
```

## 🔧 Configuration Files

The setup creates and manages these configuration files:

- `~/.config/kerberos/krb5.conf` - Kerberos configuration
- `~/.azure/` - Azure CLI configuration

## 🎯 Integration Options

### Option 1: Direct Kerberos Authentication
- Use `kinit` to get Kerberos tickets
- SSH with Kerberos authentication (`ssh -K`)
- Works with any Kerberos-enabled service

### Option 2: Azure AD + Kerberos Bridge
- Configure Azure AD as identity provider
- Use Kerberos for local authentication
- Bridge between cloud and local auth

### Option 3: Platform SSO (macOS)
- Leverage macOS's built-in Platform SSO
- Integrate with Azure AD via GUI configuration
- Modern, secure approach for macOS

## 🐛 Troubleshooting

### Azure CLI Issues
If you get `claims_challenge` errors with Azure CLI:
```bash
# Use device code login instead
az login --use-device-code

# Or try interactive login
az login
```

### Kerberos Ticket Issues
```bash
# Check KDC connectivity
kinit -V username@REALM.COM

# Verify realm configuration
cat ~/.config/kerberos/krb5.conf
```

### SSH Kerberos Issues
```bash
# Check Kerberos configuration
klist -e

# Test SSH with verbose output
ssh -K -v username@hostname

# Check SSH configuration
ssh -F /dev/null -o PreferredAuthentications=gssapi-with-mic username@hostname
```

## 📚 Advanced Configuration

### Custom Kerberos Configuration
Edit `~/.config/kerberos/krb5.conf` for custom realm settings.

### SSH Configuration
Configure `~/.ssh/config` for automatic Kerberos authentication.

### Azure AD App Registration
For custom Azure AD integration, you may need to:
1. Register an application in Azure AD
2. Configure redirect URIs
3. Set up certificate-based authentication

## 🤝 Contributing

This setup is designed to be easily extensible. Feel free to:
- Add new packages to `nix-sso-setup.nix`
- Improve the setup scripts
- Add configuration templates
- Document additional integration patterns

## 📄 License

This project is open source and available under the MIT License.
