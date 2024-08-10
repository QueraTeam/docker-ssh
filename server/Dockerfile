# Inspired by https://docs.linuxserver.io/images/docker-openssh-server/
FROM alpine:3.20

# Install openssh-server
RUN apk add --no-cache openssh-server

# Create tunnel user
ARG TUNNEL_USER=tunnel
RUN adduser -D $TUNNEL_USER
# https://github.com/camptocamp/puppet-accounts/issues/35#issuecomment-366412237
RUN sed -i s/$TUNNEL_USER:!/"$TUNNEL_USER:*"/g /etc/shadow
RUN chmod 750 /home/$TUNNEL_USER

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]