# DevBox Lite - Optimized Multi-stage Dockerfile
# Focused on: Laravel, Next.js, React, Python
FROM ubuntu:24.04 AS base

LABEL maintainer="Mojtaba"
LABEL project="DevBox"
LABEL version="lite-1.0.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/root/.config/composer/vendor/bin:${PATH}"

WORKDIR /workspace

COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/base/system.sh /tmp/install/system.sh
RUN chmod +x /tmp/common.sh /tmp/install/system.sh && /tmp/install/system.sh

# Languages layer (PHP, Node, Python only)
FROM base AS languages

COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/base/python.sh /tmp/install/python.sh
COPY install/base/python-tools.sh /tmp/install/python-tools.sh
COPY install/base/node.sh /tmp/install/node.sh
COPY install/base/bun.sh /tmp/install/bun.sh
COPY install/base/php.sh /tmp/install/php.sh
COPY install/base/composer.sh /tmp/install/composer.sh

RUN chmod +x /tmp/common.sh /tmp/install/*.sh && \
    /tmp/install/python.sh && \
    /tmp/install/python-tools.sh && \
    /tmp/install/node.sh && \
    /tmp/install/bun.sh && \
    /tmp/install/php.sh && \
    /tmp/install/composer.sh && \
    rm -rf /tmp/install /tmp/common.sh /tmp/.env \
           /root/.cache/pip /root/.npm/_cacache /root/.local/share/pip/cache \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/*

# Frameworks layer (Laravel only)
FROM languages AS frameworks

COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/frameworks/laravel.sh /tmp/install/laravel.sh

RUN chmod +x /tmp/common.sh /tmp/install/*.sh && \
    /tmp/install/laravel.sh && \
    rm -rf /tmp/install /tmp/common.sh /tmp/.env

# Tools layer (database, github, docker, server, bruno, postman)
FROM frameworks AS tools

COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/tools/database.sh /tmp/install/database.sh
COPY install/tools/github.sh /tmp/install/github.sh
COPY install/tools/docker.sh /tmp/install/docker.sh
COPY install/tools/server.sh /tmp/install/server.sh
COPY install/tools/bruno.sh /tmp/install/bruno.sh
COPY install/tools/postman-vnc.sh /tmp/install/postman-vnc.sh

RUN chmod +x /tmp/common.sh /tmp/install/*.sh && \
    /tmp/install/database.sh && \
    /tmp/install/github.sh && \
    /tmp/install/docker.sh && \
    /tmp/install/server.sh && \
    /tmp/install/bruno.sh && \
    /tmp/install/postman-vnc.sh && \
    rm -rf /tmp/install /tmp/common.sh /tmp/.env \
           /root/.cache/pip /root/.npm/_cacache /root/.local/share/pip/cache \
           /root/.cache/pipx /root/.pm2/logs /root/.pm2/pids \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/*

# Extensions layer (Xdebug + Pest)
FROM tools AS extensions

COPY install/common.sh /tmp/common.sh
COPY .env /tmp/.env

COPY install/extensions/xdebug.sh /tmp/install/xdebug.sh
COPY install/extensions/pest.sh /tmp/install/pest.sh

RUN chmod +x /tmp/common.sh /tmp/install/*.sh && \
    /tmp/install/xdebug.sh && \
    /tmp/install/pest.sh && \
    rm -rf /tmp/install /tmp/common.sh /tmp/.env

# Cleanup layer
FROM extensions AS cleanup

COPY install/common.sh /tmp/install/common.sh
COPY install/cleanup.sh /tmp/install/cleanup.sh

RUN chmod +x /tmp/install/common.sh /tmp/install/*.sh && \
    /tmp/install/cleanup.sh && \
    rm -rf /tmp/install

# Final runtime image
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.local/bin:/root/.cargo/bin:/root/.config/composer/vendor/bin:${PATH}"

WORKDIR /workspace

COPY --from=cleanup /usr /usr
COPY --from=cleanup /root /root
COPY --from=cleanup /etc/apt /etc/apt
COPY --from=cleanup /etc/alternatives /etc/alternatives
COPY --from=cleanup /etc/php /etc/php
COPY --from=cleanup /opt /opt

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
    echo 'bruno() { /usr/local/bin/start-bruno "$@"; }' >> /root/.bashrc && \
    echo 'postman() { /usr/local/bin/start-postman "$@"; }' >> /root/.bashrc

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
