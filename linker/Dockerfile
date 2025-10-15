FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    inotify-tools \
    coreutils \
    bash \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
