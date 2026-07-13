#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Laravel Development Tools"

composer global require laravel/installer

laravel --version
