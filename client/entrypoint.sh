#!/bin/sh

# Ensure script is run by "tunnel" user
if [ "$(id -un)" != "tunnel" ]; then
    echo "This script must be run as the 'tunnel' user. Exiting..."
    exit 1
fi

mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

if [ -z "$SSH_HOSTNAME" ]; then
    echo "SSH_HOSTNAME is not set. Exiting..."
    exit 1
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
