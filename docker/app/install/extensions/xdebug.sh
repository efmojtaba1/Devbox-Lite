#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Xdebug"

# Ensure ondrej/php PPA is available (may not exist in this stage)
add-apt-repository ppa:ondrej/php -y 2>/dev/null || true
apt-get update -qq

apt-get install -y --no-install-recommends php${PHP_VERSION}-xdebug

mkdir -p /etc/php/${PHP_VERSION}/mods-available

cat > /etc/php/${PHP_VERSION}/mods-available/xdebug.ini <<EOF
zend_extension=xdebug

xdebug.mode=develop,debug
xdebug.start_with_request=trigger
xdebug.client_host=host.docker.internal
xdebug.client_port=9003

xdebug.log=/tmp/xdebug.log
EOF

php -v

php -m | grep xdebug
