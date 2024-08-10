#!/bin/sh

# Setup host key
if [ -z "$SERVER_ED25519_PRIVATE_KEY_BASE64" ]; then
    echo "SERVER_ED25519_PRIVATE_KEY_BASE64 is not set. Exiting..."
    exit 1
else
    echo "Setting up the host key from the environment variable..."
    echo "$SERVER_ED25519_PRIVATE_KEY_BASE64" | base64 -d >/etc/ssh/ssh_host_ed25519_key
    chmod 600 /etc/ssh/ssh_host_ed25519_key
fi
if [ -n "$SERVER_ED25519_PUBLIC_KEY" ]; then
    echo "$SERVER_ED25519_PUBLIC_KEY" >/etc/ssh/ssh_host_ed25519_key.pub
    chmod 644 /etc/ssh/ssh_host_ed25519_key
fi

# Configure authorized_keys
if [ -z "$CLIENT_AUTHORIZED_KEYS" ]; then
    echo "CLIENT_AUTHORIZED_KEYS is not set. Exiting..."
    exit 1
else
    mkdir -p /home/tunnel/.ssh
    chmod 700 /home/tunnel/.ssh
    # Split the CLIENT_AUTHORIZED_KEYS variable by semicolon and add each to authorized_keys
    echo "$CLIENT_AUTHORIZED_KEYS" | tr ';' '\n' | while IFS= read -r key; do
        # Process each key here
        echo "$key" >>/home/tunnel/.ssh/authorized_keys
    done
    chmod 600 /home/tunnel/.ssh/authorized_keys
    chown -R tunnel:tunnel /home/tunnel/.ssh
fi

# Default values for environment variables
SSHD_PORT=${SSHD_PORT:-22}
SSHD_PERMIT_ROOT_LOGIN=${SSHD_PERMIT_ROOT_LOGIN:-no}
SSHD_PERMIT_EMPTY_PASSWORDS=${SSHD_PERMIT_EMPTY_PASSWORDS:-no}
SSHD_PASSWORD_AUTHENTICATION=${SSHD_PASSWORD_AUTHENTICATION:-no}
SSHD_AUTHENTICATION_METHODS=${SSHD_AUTHENTICATION_METHODS:-publickey}
SSHD_CLIENT_ALIVE_INTERVAL=${SSHD_CLIENT_ALIVE_INTERVAL:-10}
SSHD_CLIENT_ALIVE_COUNT_MAX=${SSHD_CLIENT_ALIVE_COUNT_MAX:-30}
SSHD_LOGIN_GRACE_TIME=${SSHD_LOGIN_GRACE_TIME:-30}
SSHD_GATEWAY_PORTS=${SSHD_GATEWAY_PORTS:-clientspecified}
SSHD_PERMIT_TUNNEL=${SSHD_PERMIT_TUNNEL:-no}
SSHD_PERMIT_TTY=${SSHD_PERMIT_TTY:-no}
SSHD_PERMIT_USER_RC=${SSHD_PERMIT_USER_RC:-no}
SSHD_ALLOW_TCP_FORWARDING=${SSHD_ALLOW_TCP_FORWARDING:-remote}
SSHD_ALLOW_STREAM_LOCAL_FORWARDING=${SSHD_ALLOW_STREAM_LOCAL_FORWARDING:-no}
SSHD_X11_FORWARDING=${SSHD_X11_FORWARDING:-no}
SSHD_ALLOW_AGENT_FORWARDING=${SSHD_ALLOW_AGENT_FORWARDING:-no}
SSHD_FORCE_COMMAND=${SSHD_FORCE_COMMAND:-"/sbin/nologin"}
SSHD_ALLOW_USERS=${SSHD_ALLOW_USERS:-tunnel}

# Generate the SSHD configuration
cat <<EOF >/etc/ssh/sshd_config.d/tunnel.conf
Port $SSHD_PORT
PermitRootLogin $SSHD_PERMIT_ROOT_LOGIN
PermitEmptyPasswords $SSHD_PERMIT_EMPTY_PASSWORDS
PasswordAuthentication $SSHD_PASSWORD_AUTHENTICATION
AuthenticationMethods $SSHD_AUTHENTICATION_METHODS
ClientAliveInterval $SSHD_CLIENT_ALIVE_INTERVAL
ClientAliveCountMax $SSHD_CLIENT_ALIVE_COUNT_MAX
LoginGraceTime $SSHD_LOGIN_GRACE_TIME
GatewayPorts $SSHD_GATEWAY_PORTS
PermitTunnel $SSHD_PERMIT_TUNNEL
PermitTTY $SSHD_PERMIT_TTY
PermitUserRC $SSHD_PERMIT_USER_RC
AllowTcpForwarding $SSHD_ALLOW_TCP_FORWARDING
AllowStreamLocalForwarding $SSHD_ALLOW_STREAM_LOCAL_FORWARDING
X11Forwarding $SSHD_X11_FORWARDING
AllowAgentForwarding $SSHD_ALLOW_AGENT_FORWARDING
ForceCommand $SSHD_FORCE_COMMAND
AllowUsers $SSHD_ALLOW_USERS
EOF

# Start SSHD
exec /usr/sbin/sshd -D -e
