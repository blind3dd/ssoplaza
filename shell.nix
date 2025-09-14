{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Kerberos authentication
    krb5
    
    # Azure CLI for cloud integration
    azure-cli
    
    # Additional useful tools
    curl
    jq
    openssl
    
    # Development tools
    git
    vim
    htop
    
    # Network tools
    nmap
    dig
    bind.dnsutils
  ];

  shellHook = ''
    echo "🔐 Kerberos + Azure + SSO Development Environment"
    echo "================================================="
    echo ""
    echo "Available tools:"
    echo "  kinit, klist, kdestroy - Kerberos authentication"
    echo "  az - Azure CLI"
    echo "  curl, jq - HTTP and JSON tools"
    echo "  git, vim - Development tools"
    echo ""
    echo "Configuration:"
    echo "  Kerberos config: ~/.config/kerberos/krb5.conf"
    echo "  Setup script: ~/.config/kerberos/setup_azure_sso.sh"
    echo ""
    echo "Quick start:"
    echo "  1. Run: ~/.config/kerberos/setup_azure_sso.sh"
    echo "  2. Update krb5.conf with your domain"
    echo "  3. Get keytab from AD admin"
    echo "  4. Run: kinit username@YOURDOMAIN.COM"
    echo ""
    
    # Set Kerberos configuration
    export KRB5_CONFIG="$HOME/.config/kerberos/krb5.conf"
    
    # Set Azure CLI configuration
    export AZURE_CONFIG_DIR="$HOME/.azure"
  '';
}
