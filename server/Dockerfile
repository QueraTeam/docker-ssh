# Inspired by https://docs.linuxserver.io/images/docker-openssh-server/
FROM alpine:3.20

# Install openssh-server
RUN apk add --no-cache openssh-server rsync tzdata nss_wrapper

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]