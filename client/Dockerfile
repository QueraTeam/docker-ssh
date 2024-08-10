FROM alpine:3.20

# Install openssh-client and autossh
RUN apk add --no-cache openssh-client autossh

# Create tunnel user
ARG TUNNEL_USER=tunnel
RUN adduser -D $TUNNEL_USER
RUN chmod 750 /home/$TUNNEL_USER

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER tunnel

ENTRYPOINT ["/entrypoint.sh"]