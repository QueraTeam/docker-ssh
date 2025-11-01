#!/bin/sh

log() {
    echo -e "$@"
}

# Ensure the script is not run by the "root" user.
if [ "$(id -u)" == "0" ]; then
    log "This image should not be run as the 'root' user. Exiting..."
    exit 1
fi

USERNAME="${SSH_USER:-sshuser}"

# We want to be able to run as an arbitrary user via `--user` on `docker run`.
# So we don't depend on the existence of a real user and a home directory.
# We make things work by creating a "fake" home directory, and using nss_wrapper
# to "fake" /etc/passwd contents, so "openssh" thinks the user exists.
# https://cwrap.org/nss_wrapper.html
export HOME="/tmp/${USERNAME}"
echo "${USERNAME}:x:$(id -u):$(id -g):SSH User:${HOME}:/bin/false" >/tmp/passwd
echo "${USERNAME}:x:$(id -g):${USERNAME}" >/tmp/group
export LD_PRELOAD=/usr/lib/libnss_wrapper.so NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
mkdir -p "${HOME}/.ssh"
chmod -R 700 "${HOME}"

log "\033[1;34mWelcome to docker-ssh/client!\033[0m"
log "\033[1;32m   Alpine: \033[0m $(cat /etc/alpine-release)"
log "\033[1;32m  OpenSSH: \033[0m $(ssh -V 2>&1)"
log "\033[1;32m    Rsync: \033[0m $(rsync --version | head -n 1)"

if [ -z "${SSH_HOSTNAME}" ]; then
    log "SSH_HOSTNAME is not set. Exiting..."
    exit 1
fi

################################
# setup keys                   #
################################
# Variables with `_ED25519` in their names are kept for backward compatibility.
CLIENT_PRIVATE_KEY_FILE="${CLIENT_PRIVATE_KEY_FILE:-${CLIENT_ED25519_PRIVATE_KEY_FILE}}"
CLIENT_PRIVATE_KEY_BASE64="${CLIENT_PRIVATE_KEY_BASE64:-${CLIENT_ED25519_PRIVATE_KEY_BASE64}}"
SERVER_PUBLIC_KEY="${SERVER_PUBLIC_KEY:-${SERVER_ED25519_PUBLIC_KEY}}"

if [ -n "${CLIENT_PRIVATE_KEY_FILE}" ]; then
    if [ -r "${CLIENT_PRIVATE_KEY_FILE}" ]; then
        if [ "${CLIENT_PRIVATE_KEY_FILE}" != "${HOME}/.ssh/client_key" ]; then
            cp "${CLIENT_PRIVATE_KEY_FILE}" "${HOME}/.ssh/client_key"
            chmod 600 "${HOME}/.ssh/client_key"
            log "Installed private key from key file."
        fi
    else
        log "'${CLIENT_PRIVATE_KEY_FILE}' is not readable. Exiting..."
        exit 1
    fi
elif [ -n "${CLIENT_PRIVATE_KEY_BASE64}" ]; then
    echo "${CLIENT_PRIVATE_KEY_BASE64}" | base64 -d >"${HOME}/.ssh/client_key"
    chmod 600 "${HOME}/.ssh/client_key"
    log "Installed private key from env var."
else
    log "No private key provided. Exiting..."
    exit 1
fi

if [ -n "${SERVER_PUBLIC_KEY}" ]; then
    if [ "${SSH_PORT:-22}" = "22" ]; then
        echo "${SSH_HOSTNAME} ${SERVER_PUBLIC_KEY}" >"${HOME}/.ssh/known_hosts"
    else
        echo "[${SSH_HOSTNAME}]:${SSH_PORT:-22} ${SERVER_PUBLIC_KEY}" >"${HOME}/.ssh/known_hosts"
    fi
    chmod 600 "${HOME}/.ssh/known_hosts"
else
    log "Server public key is not set. Exiting..."
    exit 1
fi

################################
# ssh_config options           #
################################
printf "\
Hostname ${SSH_HOSTNAME}
Port ${SSH_PORT:-22}
User ${USERNAME}
IdentityFile ${HOME}/.ssh/client_key
ServerAliveInterval ${SSH_SERVER_ALIVE_INTERVAL:-10}
ServerAliveCountMax ${SSH_SERVER_ALIVE_COUNT_MAX:-3}
ExitOnForwardFailure ${SSH_EXIT_ON_FORWARD_FAILURE:-yes}
SessionType ${SSH_SESSION_TYPE:-none}
RequestTTY no
" >"${HOME}/.ssh/config"
if [ -n "${SSH_REMOTE_FORWARD}" ]; then
    echo "${SSH_REMOTE_FORWARD}" | tr ',' '\n' | while IFS= read -r remote_forward; do
        echo "RemoteForward ${remote_forward}" >>"${HOME}/.ssh/config"
    done
fi
if [ -n "${SSH_LOCAL_FORWARD}" ]; then
    echo "${SSH_LOCAL_FORWARD}" | tr ',' '\n' | while IFS= read -r local_forward; do
        echo "LocalForward ${local_forward}" >>"${HOME}/.ssh/config"
    done
fi

################################
# autossh options              #
################################
export AUTOSSH_PORT="${AUTOSSH_PORT:-0}"
export AUTOSSH_GATETIME="${AUTOSSH_GATETIME:-0}"
export AUTOSSH_POLL="${AUTOSSH_POLL:-30}"

################################
# run/schedule the command     #
################################
if [ -n "${SCHEDULE}" ]; then
    log "Scheduling command..."
    echo "${SCHEDULE} ${SCHEDULE_CMD}" >"${HOME}/crontab"
    exec supercronic "${HOME}/crontab"
else
    log "Running $1..."
    exec "$@"
fi
