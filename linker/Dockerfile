FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    inotify-tools \
    coreutils \
    bash \
    dos2unix \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh

# Fix line endings and make executable
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]