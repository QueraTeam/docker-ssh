# Docker SSH tunnel

This project provides Docker images for setting up an SSH tunnel
between two containers on different servers.

## Images

- `ghcr.io/querateam/docker-ssh-tunnel/server`
- `ghcr.io/querateam/docker-ssh-tunnel/client`

## Configuration

### Server image

Main variables:

- `SERVER_ED25519_PRIVATE_KEY_BASE64` (**required**):
  The server's host private key (ed25519).
  The client needs to have the corresponding public key in `known_hosts`.
- `SERVER_ED25519_PUBLIC_KEY` (**optional**):
  The server's host public key (ed25519).
- `CLIENT_AUTHORIZED_KEYS` (**required**):
  The client public keys authorized to connect as `tunnel` user.
  The keys should be separated by semicolons (`;`).

Optional parameters for `sshd_config`:

| Environment Variable                 | Default Value     |
| ------------------------------------ | ----------------- |
| `SSHD_PORT`                          | `22`              |
| `SSHD_PERMIT_ROOT_LOGIN`             | `no`              |
| `SSHD_PERMIT_EMPTY_PASSWORDS`        | `no`              |
| `SSHD_PASSWORD_AUTHENTICATION`       | `no`              |
| `SSHD_AUTHENTICATION_METHODS`        | `publickey`       |
| `SSHD_CLIENT_ALIVE_INTERVAL`         | `10`              |
| `SSHD_CLIENT_ALIVE_COUNT_MAX`        | `30`              |
| `SSHD_LOGIN_GRACE_TIME`              | `30`              |
| `SSHD_GATEWAY_PORTS`                 | `clientspecified` |
| `SSHD_PERMIT_TUNNEL`                 | `no`              |
| `SSHD_PERMIT_TTY`                    | `no`              |
| `SSHD_PERMIT_USER_RC`                | `no`              |
| `SSHD_ALLOW_TCP_FORWARDING`          | `remote`          |
| `SSHD_ALLOW_STREAM_LOCAL_FORWARDING` | `no`              |
| `SSHD_X11_FORWARDING`                | `no`              |
| `SSHD_ALLOW_AGENT_FORWARDING`        | `no`              |
| `SSHD_FORCE_COMMAND`                 | `/sbin/nologin`   |
| `SSHD_ALLOW_USERS`                   | `tunnel`          |

### Client image

Environment Variables:

- `SERVER_ED25519_PUBLIC_KEY`:
  The server's host public key (ed25519).
  This key will be added to `known_hosts`.
- `CLIENT_ED25519_PRIVATE_KEY_BASE64`:
  The client's SSH private key.
- `SERVER_HOST`:
  The server's hostname or IP address.
- `SERVER_PORT`:
  The server's SSH port.
- `PORT_FORWARDING_RULE`:
  The SSH port forwarding rule.
  Examples: `-R remote_port:local_host:local_port`, `-R remote_host:remote_port:local_host:local_port`.

## Key generation

```shell
ssh-keygen -t ed25519 -N '' -C key1-$(date -I) -f key1
cat key1 | base64 -w 0 > key1.base64

ssh-keygen -t ed25519 -N '' -C key2-$(date -I) -f key2
cat key2 | base64 -w 0 > key2.base64
```

## Example usage

In this example, both client and server containers are run on the same host.
But in a real-world scenario,
the client and server containers should be run on different hosts.

Start server and client services:

```shell
KEY1_BASE64=$(cat key1.base64)
KEY2_PUB=$(cat key2.pub)
docker run --name tunnel-server --rm -it --init \
  -e SERVER_ED25519_PRIVATE_KEY_BASE64="$KEY1_BASE64" \
  -e CLIENT_AUTHORIZED_KEYS="$KEY2_PUB" \
  -p 2222:22 \
  -p 127.0.0.1:4444:4444 \
  ghcr.io/querateam/docker-ssh-tunnel/server
```

```shell
KEY2_BASE64=$(cat key2.base64)
KEY1_PUB=$(cat key1.pub)
docker run --name tunnel-client --rm -it --init --add-host=host.docker.internal:host-gateway \
  -e SERVER_ED25519_PUBLIC_KEY="$KEY1_PUB" \
  -e CLIENT_ED25519_PRIVATE_KEY_BASE64="$KEY2_BASE64" \
  -e SERVER_HOST="host.docker.internal" \
  -e SERVER_PORT="2222" \
  -e PORT_FORWARDING_RULE="-R 0.0.0.0:4444:127.0.0.1:6666" \
  ghcr.io/querateam/docker-ssh-tunnel/client
```

Test the tunnel using `nc`:

```shell
docker exec -it tunnel-client /usr/bin/nc -l -s 127.0.0.1 -p 6666
nc 127.0.0.1 4444
```

## Docker compose example

```yaml
services:
  tunnel-server:
    image: ghcr.io/querateam/docker-ssh-tunnel/server
    restart: always
    environment:
      SERVER_ED25519_PRIVATE_KEY_BASE64: ... value of key1.base64 ...
      CLIENT_AUTHORIZED_KEYS: ... value of key2.pub ...
    ports:
      - 2222:22
      - 127.0.0.1:4444:4444

  tunnel-client:
    image: ghcr.io/querateam/docker-ssh-tunnel/client
    restart: always
    environment:
      SERVER_ED25519_PUBLIC_KEY: ... value of key1.pub ...
      CLIENT_ED25519_PRIVATE_KEY_BASE64: ... value of key2.base64 ...
      SERVER_HOST: host.docker.internal
      SERVER_PORT: 2222
      PORT_FORWARDING_RULE: -R 0.0.0.0:4444:127.0.0.1:6666
    extra_hosts:
      - host.docker.internal:host-gateway
```

Test the tunnel using `nc`:

```shell
docker compose exec -it tunnel-client /usr/bin/nc -l -s 127.0.0.1 -p 6666
nc 127.0.0.1 4444
```
