# DevBox Lite - Optimized Multi-stage Dockerfile
# Focused on: Laravel, Next.js, React, Python
FROM ubuntu:24.04 AS base

LABEL maintainer="Mojtaba"
LABEL project="DevBox"
LABEL version="lite-1.0.0"

# Version pins as ARGs (cache-busts only when value changes, not on .env file edit)
ARG PHP_VERSION=8.4
ARG NODE_VERSION=22
ARG PYTHON_VERSION=3.12
ARG COMPOSER_VERSION=2.8.8
ARG BUN_VERSION=1.2.17
ARG PNPM_VERSION=9.15.9
ARG LARAVEL_VERSION=latest
ARG PEST_VERSION=latest
ARG APT_MIRROR=""
ARG PIP_MIRROR=""

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/root/.config/composer/vendor/bin:${PATH}"
# Export ARGs as ENV so install scripts can read them from shell
ENV PHP_VERSION=${PHP_VERSION}
ENV NODE_VERSION=${NODE_VERSION}
ENV PYTHON_VERSION=${PYTHON_VERSION}
ENV COMPOSER_VERSION=${COMPOSER_VERSION}
ENV BUN_VERSION=${BUN_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}
ENV LARAVEL_VERSION=${LARAVEL_VERSION}
ENV PEST_VERSION=${PEST_VERSION}
ENV PIP_MIRROR=${PIP_MIRROR}

WORKDIR /workspace

# Configure apt mirror (if APT_MIRROR build arg is provided)
RUN if [ -n "$APT_MIRROR" ]; then \
      UBUNTU_CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME) && \
      echo "deb $APT_MIRROR $UBUNTU_CODENAME main restricted universe multiverse" > /etc/apt/sources.list && \
      echo "deb $APT_MIRROR $UBUNTU_CODENAME-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
      echo "deb $APT_MIRROR $UBUNTU_CODENAME-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
      echo "deb $APT_MIRROR $UBUNTU_CODENAME-security main restricted universe multiverse" >> /etc/apt/sources.list && \
      echo "Using mirror: $APT_MIRROR"; \
    else \
      echo "Using default Ubuntu mirrors"; \
    fi && \
    apt-get update -qq

# Copy common.sh and .env ONCE (inherited by all child stages)
COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/base/system.sh /tmp/install/system.sh
RUN chmod +x /tmp/common.sh /tmp/install/system.sh && /tmp/install/system.sh

# Languages + Frameworks + Extensions layer (merged for better caching)
FROM base AS languages

COPY install/base/python.sh /tmp/install/python.sh
COPY install/base/python-tools.sh /tmp/install/python-tools.sh
COPY install/base/node.sh /tmp/install/node.sh
COPY install/base/bun.sh /tmp/install/bun.sh
COPY install/base/php.sh /tmp/install/php.sh
COPY install/base/composer.sh /tmp/install/composer.sh
COPY install/frameworks/laravel.sh /tmp/install/laravel.sh
COPY install/extensions/xdebug.sh /tmp/install/xdebug.sh
COPY install/extensions/pest.sh /tmp/install/pest.sh

RUN chmod +x /tmp/install/*.sh && \
    /tmp/install/python.sh && \
    /tmp/install/python-tools.sh && \
    /tmp/install/node.sh && \
    /tmp/install/bun.sh && \
    /tmp/install/php.sh && \
    /tmp/install/composer.sh && \
    /tmp/install/laravel.sh && \
    /tmp/install/xdebug.sh && \
    /tmp/install/pest.sh && \
    rm -rf /tmp/install /tmp/.env \
           /root/.cache/pip /root/.npm/_cacache /root/.local/share/pip/cache \
           /root/.cache/pipx /root/.pm2/logs /root/.pm2/pids \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/*

# Tools + Cleanup layer (merged for better caching)
# Install order: stable tools first, frequently-changing last
FROM languages AS tools

# Single apt-get update for all tools (scripts no longer call it individually)
RUN apt-get update -qq

COPY install/common.sh /tmp/install/common.sh
COPY install/tools/database.sh /tmp/install/database.sh
COPY install/tools/github.sh /tmp/install/github.sh
COPY install/tools/docker.sh /tmp/install/docker.sh
COPY install/tools/server.sh /tmp/install/server.sh
COPY install/tools/bruno.sh /tmp/install/bruno.sh
COPY install/cleanup.sh /tmp/install/cleanup.sh

RUN chmod +x /tmp/install/*.sh && \
    /tmp/install/database.sh && \
    /tmp/install/github.sh && \
    /tmp/install/docker.sh && \
    /tmp/install/server.sh && \
    /tmp/install/bruno.sh && \
    /tmp/install/cleanup.sh && \
    rm -rf /tmp/install

# Final runtime image
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/root/.config/composer/vendor/bin:${PATH}"

WORKDIR /workspace

# Copy /usr subdirectories (exclude /usr/include which is build-time only)
COPY --from=tools /usr/bin /usr/bin
COPY --from=tools /usr/sbin /usr/sbin
COPY --from=tools /usr/local /usr/local
COPY --from=tools /usr/lib /usr/lib
COPY --from=tools /usr/libexec /usr/libexec
COPY --from=tools /usr/share /usr/share

# Copy root home (exclude caches)
COPY --from=tools /root/.bun /root/.bun
COPY --from=tools /root/.config /root/.config
COPY --from=tools /root/.local /root/.local
COPY --from=tools /root/.bashrc /root/.bashrc

# Copy system configs
COPY --from=tools /etc/apt /etc/apt
COPY --from=tools /etc/ssl /etc/ssl
COPY --from=tools /etc/alternatives /etc/alternatives
COPY --from=tools /etc/php /etc/php
COPY --from=tools /etc/timezone /etc/timezone
COPY --from=tools /etc/localtime /etc/localtime
COPY --from=tools /etc/passwd /etc/passwd
COPY --from=tools /etc/group /etc/group
COPY --from=tools /etc/shadow /etc/shadow
COPY --from=tools /etc/ld.so.conf /etc/ld.so.conf
COPY --from=tools /etc/ld.so.conf.d /etc/ld.so.conf.d
COPY --from=tools /var/lib/dpkg /var/lib/dpkg

# Copy GUI applications
COPY --from=tools /opt /opt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Database management short commands (like VS Code helper scripts)
RUN echo '' >> /root/.bashrc && \
    echo '# Database management shortcuts' >> /root/.bashrc && \
    echo 'create() { /workspace/scripts/db-manager.sh create "$1"; }' >> /root/.bashrc && \
    echo 'start() { /workspace/scripts/db-manager.sh start "$1"; }' >> /root/.bashrc && \
    echo 'stop() { /workspace/scripts/db-manager.sh stop "$1"; }' >> /root/.bashrc && \
    echo 'connect() { /workspace/scripts/db-manager.sh connect "$1"; }' >> /root/.bashrc && \
    echo 'phpmyadmin() { /workspace/scripts/db-manager.sh phpmyadmin; }' >> /root/.bashrc && \
    echo 'adminer() { /workspace/scripts/db-manager.sh adminer; }' >> /root/.bashrc && \
    echo 'pgadmin() { /workspace/scripts/db-manager.sh pgadmin; }' >> /root/.bashrc && \
    echo 'setup-deps() { /workspace/scripts/setup-deps.sh "$@"; }' >> /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo '# API testing shortcuts' >> /root/.bashrc && \
    echo 'bruno() { /usr/local/bin/start-bruno "$@"; }' >> /root/.bashrc

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
