#!/bin/bash
# One-liner SSO setup - just run this single command!

curl -sSL https://raw.githubusercontent.com/nixos/nix/master/scripts/install-nix | sh -s -- --no-confirm && nix-shell -p krb5 azure-cli opensshWithKerberos curl jq git vim nmap bind.dnsutils --run "echo '🔐 SSO environment ready! Use: kinit, az login, ssh -K'"
