#!/bin/sh

# Ensure the script is not run by the "root" user.
if [ "$(id -u)" = "0" ]; then
    echo "This image should not be run as the 'root' user. Exiting..."
    exit 1
fi

if [ -z "$SSH_HOSTNAME" ]; then
    echo "SSH_HOSTNAME is not set. Exiting..."
    exit 1
fi

# We don't want to depend on the existence of a real user and a home directory,
# so we can run the container as any non-root user with any uid and gid.
# We achieve this by creating a "fake" home directory,
# and using nss_wrapper to "fake" /etc/passwd contents, so "ssh" thinks the user exists.
# https://cwrap.org/nss_wrapper.html
export HOME="/tmp/tunnel"
echo "tunnel:x:$(id -u):$(id -g):Tunnel User:${HOME}:/bin/false" >/tmp/passwd
echo "tunnel:x:$(id -g):tunnel" >/tmp/group
export LD_PRELOAD=/usr/lib/libnss_wrapper.so NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
mkdir -p "$HOME/.ssh"
chmod -R 700 "$HOME"

################################
# read private key from file   #
################################
if [ -n "${CLIENT_ED25519_PRIVATE_KEY_BASE64_FILE:-}" ]; then
    if [ -r "${CLIENT_ED25519_PRIVATE_KEY_BASE64_FILE:-}" ]; then
        CLIENT_ED25519_PRIVATE_KEY_BASE64="$(cat "${CLIENT_ED25519_PRIVATE_KEY_BASE64_FILE}")"
    else
        echo "'${CLIENT_ED25519_PRIVATE_KEY_BASE64_FILE:-}' is not readable."
    fi
fi

################################
# setup keys                   #
################################
if [ -z "$CLIENT_ED25519_PRIVATE_KEY_BASE64" ]; then
    echo "CLIENT_ED25519_PRIVATE_KEY_BASE64 is not set. Exiting..."
    exit 1
else
    echo "$CLIENT_ED25519_PRIVATE_KEY_BASE64" | base64 -d >$HOME/.ssh/id_ed25519
    chmod 600 $HOME/.ssh/id_ed25519
fi

if [ -z "$SERVER_ED25519_PUBLIC_KEY" ]; then
    echo "SERVER_ED25519_PUBLIC_KEY is not set. Exiting..."
    exit 1
else
    echo "[$SSH_HOSTNAME]:${SSH_PORT:-22} $SERVER_ED25519_PUBLIC_KEY" >$HOME/.ssh/known_hosts
    chmod 600 $HOME/.ssh/known_hosts
fi

################################
# ssh_config options           #
################################
printf "\
Port ${SSH_PORT:-22}
User tunnel
ServerAliveInterval ${SSH_SERVER_ALIVE_INTERVAL:-10}
ServerAliveCountMax ${SSH_SERVER_ALIVE_COUNT_MAX:-3}
ExitOnForwardFailure ${SSH_EXIT_ON_FORWARD_FAILURE:-yes}
SessionType ${SSH_SESSION_TYPE:-none}
" >$HOME/.ssh/config

################################
# autossh options              #
################################
export AUTOSSH_PORT=${AUTOSSH_PORT:-0}
export AUTOSSH_GATETIME=${AUTOSSH_GATETIME:-0}
export AUTOSSH_POLL=${AUTOSSH_POLL:-30}

################################
# start the SSH tunnel         #
################################
exec /usr/bin/autossh -T $SSH_CLI_OPTIONS $SSH_HOSTNAME
