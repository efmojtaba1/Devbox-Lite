#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Xdebug"

# NOTE: PPA already added in php.sh, apt-get update done at stage start
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
