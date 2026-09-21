FROM mcr.microsoft.com/devcontainers/base:ubuntu

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-client \
        curl \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["sleep", "infinity"]