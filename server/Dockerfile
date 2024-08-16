# Inspired by https://docs.linuxserver.io/images/docker-openssh-server/
FROM alpine:3.20

# Install common packages between server and client images
RUN apk add --no-cache rsync tzdata nss_wrapper

# Install server-specific packages
RUN apk add --no-cache openssh-server

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]