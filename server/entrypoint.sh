#!/bin/sh

################################
# setup host key               #
################################
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

################################
# configure authorized_keys    #
################################
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

################################
# sshd_config options          #
################################
printf "\
Port ${SSHD_PORT:-22}
PermitRootLogin ${SSHD_PERMIT_ROOT_LOGIN:-no}
PermitEmptyPasswords ${SSHD_PERMIT_EMPTY_PASSWORDS:-no}
PasswordAuthentication ${SSHD_PASSWORD_AUTHENTICATION:-no}
AuthenticationMethods ${SSHD_AUTHENTICATION_METHODS:-publickey}
ClientAliveInterval ${SSHD_CLIENT_ALIVE_INTERVAL:-10}
ClientAliveCountMax ${SSHD_CLIENT_ALIVE_COUNT_MAX:-30}
LoginGraceTime ${SSHD_LOGIN_GRACE_TIME:-30}
GatewayPorts ${SSHD_GATEWAY_PORTS:-clientspecified}
PermitTunnel ${SSHD_PERMIT_TUNNEL:-no}
PermitTTY ${SSHD_PERMIT_TTY:-no}
PermitUserRC ${SSHD_PERMIT_USER_RC:-no}
${SSHD_PERMIT_OPEN:+PermitOpen ${SSHD_PERMIT_OPEN}\n}\
${SSHD_PERMIT_LISTEN:+PermitListen ${SSHD_PERMIT_LISTEN}\n}\
AllowTcpForwarding ${SSHD_ALLOW_TCP_FORWARDING:-remote}
AllowStreamLocalForwarding ${SSHD_ALLOW_STREAM_LOCAL_FORWARDING:-no}
X11Forwarding ${SSHD_X11_FORWARDING:-no}
AllowAgentForwarding ${SSHD_ALLOW_AGENT_FORWARDING:-no}
ForceCommand ${SSHD_FORCE_COMMAND:-"/sbin/nologin"}
AllowUsers ${SSHD_ALLOW_USERS:-tunnel}
" >/etc/ssh/sshd_config.d/tunnel.conf

################################
# Start sshd                   #
################################
exec /usr/sbin/sshd -D -e
