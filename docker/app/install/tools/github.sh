#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing GitHub CLI"

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list

apt-get update -qq
apt-get install -y --no-install-recommends gh

# Remove apt source after install (no longer needed)
rm -f /etc/apt/sources.list.d/github-cli.list

gh --version
