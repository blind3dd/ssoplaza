# Nix configuration for SSO/Kerberos/Azure AD setup
# Usage: nix-shell nix-sso-setup.nix

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Core Kerberos (macOS compatible)
    krb5
    krb5Full
    
    # Azure CLI (with workaround for compatibility issues)
    azure-cli
    
    # Network and authentication tools
    opensshWithKerberos
    curl
    jq
    
    # Development tools
    git
    vim
    
    # Network diagnostics
    nmap
    bind.dnsutils
  ];

  shellHook = ''
    echo "🔐 SSO/Kerberos/Azure AD Development Environment"
    echo "================================================"
    echo ""
    echo "Available tools:"
    echo "  • Kerberos: kinit, klist, kdestroy"
    echo "  • Azure: az login (may need manual workaround)"
    echo "  • SSH: ssh with Kerberos support"
    echo "  • Python: kerberos, requests-kerberos libraries"
    echo ""
    echo "Quick setup commands:"
    echo "  1. kinit <principal>"
    echo "  2. az login --use-device-code"
    echo "  3. ssh -K <host> (with Kerberos)"
    echo ""
    echo "Configuration files:"
    echo "  • Kerberos: ~/.config/kerberos/krb5.conf"
    echo ""
    
    # Set up environment
    export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
    
    # Create config directory if it doesn't exist
    mkdir -p ~/.config/kerberos
    
    echo "Environment ready! 🚀"
  '';
}
