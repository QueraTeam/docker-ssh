#!/bin/sh

# Ensure script is run by "tunnel" user
if [ "$(id -un)" != "tunnel" ]; then
    echo "This script must be run as the 'tunnel' user. Exiting..."
    exit 1
fi

mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

if [ -z "$SERVER_HOST" ]; then
    echo "SERVER_HOST is not set. Exiting..."
    exit 1
fi
if [ -z "$SERVER_PORT" ]; then
    echo "SERVER_PORT is not set. Exiting..."
    exit 1
fi

# Configure private key
if [ -z "$CLIENT_ED25519_PRIVATE_KEY_BASE64" ]; then
    echo "CLIENT_ED25519_PRIVATE_KEY_BASE64 is not set. Exiting..."
    exit 1
else
    echo "$CLIENT_ED25519_PRIVATE_KEY_BASE64" | base64 -d >$HOME/.ssh/id_ed25519
    chmod 600 $HOME/.ssh/id_ed25519
fi

# Configure known_hosts
if [ -z "$SERVER_ED25519_PUBLIC_KEY" ]; then
    echo "SERVER_ED25519_PUBLIC_KEY is not set. Exiting..."
    exit 1
else
    echo "[$SERVER_HOST]:$SERVER_PORT $SERVER_ED25519_PUBLIC_KEY" >$HOME/.ssh/known_hosts
    chmod 600 $HOME/.ssh/known_hosts
fi

chown -R tunnel:tunnel $HOME/.ssh

export AUTOSSH_GATETIME=0
export AUTOSSH_POLL=30

# Keep container running
exec /usr/bin/autossh -M 0 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N -T -p $SERVER_PORT $PORT_FORWARDING_RULE tunnel@$SERVER_HOST
