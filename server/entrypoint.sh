#!/bin/sh

# Ensure the script is not run by the "root" user.
if [ "$(id -u)" == "0" ]; then
    echo "This image should not be run as the 'root' user. Exiting..."
    exit 1
fi

# We want to be able to run as an arbitrary user via `--user` on `docker run`.
# So we don't depend on the existence of a real user and a home directory.
# We make things work by creating a "fake" home directory, and using nss_wrapper
# to "fake" /etc/passwd contents, so "openssh" thinks the user exists.
# https://cwrap.org/nss_wrapper.html
export HOME="/tmp/tunnel"
echo "tunnel:x:$(id -u):$(id -g):Tunnel User:${HOME}:/bin/false" >/tmp/passwd
echo "tunnel:x:$(id -g):tunnel" >/tmp/group
export LD_PRELOAD=/usr/lib/libnss_wrapper.so NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
mkdir -p "${HOME}/sshd" "${HOME}/.ssh"
chmod -R 700 "${HOME}"

################################
# setup host key               #
################################
if [ -n "${SERVER_ED25519_PRIVATE_KEY_FILE}" ]; then
    if [ -r "${SERVER_ED25519_PRIVATE_KEY_FILE}" ]; then
        if [ "${SERVER_ED25519_PRIVATE_KEY_FILE}" != "${HOME}/sshd/ssh_host_ed25519_key" ]; then
            cp "${SERVER_ED25519_PRIVATE_KEY_FILE}" "${HOME}/sshd/ssh_host_ed25519_key"
            chmod 600 "${HOME}/sshd/ssh_host_ed25519_key"
        fi
        echo "Installed host key from key file."
    else
        echo "'${SERVER_ED25519_PRIVATE_KEY_FILE}' is not readable. Exiting..."
        exit 1
    fi
elif [ -n "${SERVER_ED25519_PRIVATE_KEY_BASE64}" ]; then
    echo "${SERVER_ED25519_PRIVATE_KEY_BASE64}" | base64 -d >"${HOME}/sshd/ssh_host_ed25519_key"
    chmod 600 "${HOME}/sshd/ssh_host_ed25519_key"
    echo "Installed host key from env var."
else
    echo "No private key provided. Exiting..."
    exit 1
fi

if [ -n "${SERVER_ED25519_PUBLIC_KEY}" ]; then
    echo "${SERVER_ED25519_PUBLIC_KEY}" >"${HOME}/sshd/ssh_host_ed25519_key.pub"
    chmod 644 "${HOME}/sshd/ssh_host_ed25519_key.pub"
fi

################################
# configure authorized_keys    #
################################
if [ -z "${CLIENT_AUTHORIZED_KEYS}" ]; then
    echo "CLIENT_AUTHORIZED_KEYS is not set. Exiting..."
    exit 1
else
    # Split the CLIENT_AUTHORIZED_KEYS variable by semicolon and add each to authorized_keys
    echo "${CLIENT_AUTHORIZED_KEYS}" | tr ';' '\n' | while IFS= read -r key; do
        echo "${key}" >>"${HOME}/.ssh/authorized_keys"
    done
    chmod 600 "${HOME}/.ssh/authorized_keys"
fi

################################
# sshd_config options          #
################################
printf "\
AuthorizedKeysFile .ssh/authorized_keys
HostKey ${HOME}/sshd/ssh_host_ed25519_key
PidFile none
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
" >"${HOME}/sshd/sshd.conf"

################################
# Start sshd                   #
################################
exec /usr/sbin/sshd -D -e -f "${HOME}/sshd/sshd.conf"
