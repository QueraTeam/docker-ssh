FROM alpine:3.20

# Install common packages between server and client images
RUN apk add --no-cache rsync tzdata nss_wrapper tini

# Install client-specific packages
RUN apk add --no-cache openssh-client autossh supercronic

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

# "dummyhost" has no effect.
# Actual hostname is set by SSH_HOSTNAME environment variable.
CMD ["/usr/bin/autossh", "dummyhost"]
