FROM alpine:3.20

# Install openssh-client and autossh
RUN apk add --no-cache openssh-client autossh rsync supercronic tzdata nss_wrapper

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# "dummyhost" has no effect.
# Actual hostname is set by SSH_HOSTNAME environment variable.
CMD [ "/usr/bin/autossh", "dummyhost" ]