#!/bin/sh

# Ensure the script is not run by the "root" user.
if [ "$(id -u)" == "0" ]; then
    echo "This image should not be run as the 'root' user. Exiting..."
    exit 1
fi

if [ -z "${SSH_HOSTNAME}" ]; then
    echo "SSH_HOSTNAME is not set. Exiting..."
    exit 1
fi

# We want to be able to run as an arbitrary user via `--user` on `docker run`.
# So we don't depend on the existence of a real user and a home directory.
# We make things work by creating a "fake" home directory, and using nss_wrapper
# to "fake" /etc/passwd contents, so "openssh" thinks the user exists.
# https://cwrap.org/nss_wrapper.html
export HOME="/tmp/sshuser"
echo "sshuser:x:$(id -u):$(id -g):SSH User:${HOME}:/bin/false" >/tmp/passwd
echo "sshuser:x:$(id -g):sshuser" >/tmp/group
export LD_PRELOAD=/usr/lib/libnss_wrapper.so NSS_WRAPPER_PASSWD=/tmp/passwd NSS_WRAPPER_GROUP=/tmp/group
mkdir -p "${HOME}/.ssh"
chmod -R 700 "${HOME}"

################################
# setup keys                   #
################################
if [ -n "${CLIENT_ED25519_PRIVATE_KEY_FILE}" ]; then
    if [ -r "${CLIENT_ED25519_PRIVATE_KEY_FILE}" ]; then
        if [ "${CLIENT_ED25519_PRIVATE_KEY_FILE}" != "${HOME}/.ssh/id_ed25519" ]; then
            cp "${CLIENT_ED25519_PRIVATE_KEY_FILE}" "${HOME}/.ssh/id_ed25519"
            chmod 600 "${HOME}/.ssh/id_ed25519"
        fi
        echo "Installed private key from key file."
    else
        echo "'${CLIENT_ED25519_PRIVATE_KEY_FILE}' is not readable. Exiting..."
        exit 1
    fi
elif [ -n "${CLIENT_ED25519_PRIVATE_KEY_BASE64}" ]; then
    echo "${CLIENT_ED25519_PRIVATE_KEY_BASE64}" | base64 -d >"${HOME}/.ssh/id_ed25519"
    chmod 600 "${HOME}/.ssh/id_ed25519"
    echo "Installed private key from env var."
else
    echo "No private key provided. Exiting..."
    exit 1
fi

if [ -n "${SERVER_ED25519_PUBLIC_KEY}" ]; then
    if [ "${SSH_PORT:-22}" = "22" ]; then
        echo "${SSH_HOSTNAME} ${SERVER_ED25519_PUBLIC_KEY}" >"${HOME}/.ssh/known_hosts"
    else
        echo "[${SSH_HOSTNAME}]:${SSH_PORT:-22} ${SERVER_ED25519_PUBLIC_KEY}" >"${HOME}/.ssh/known_hosts"
    fi
    chmod 600 "${HOME}/.ssh/known_hosts"
else
    echo "SERVER_ED25519_PUBLIC_KEY is not set. Exiting..."
    exit 1
fi

################################
# ssh_config options           #
################################
printf "\
Hostname ${SSH_HOSTNAME}
Port ${SSH_PORT:-22}
User sshuser
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
    echo "${SCHEDULE} ${SCHEDULE_CMD}" >"${HOME}/crontab"
    exec supercronic "${HOME}/crontab"
else
    exec "$@"
fi
