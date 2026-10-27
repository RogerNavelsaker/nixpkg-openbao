# OpenBao CLI and OCI image

Nix-built x86_64 Linux OCI image and bao CLI from pinned Nixpkgs OpenBao 2.7.1. The standalone CLI is the same OpenBao derivation included in the image.

## Build

```sh
nix flake check
nix build .#bao
nix build .#image
```

## Upstream Dockerfile baseline

The version-matched [Dockerfile](https://raw.githubusercontent.com/openbao/openbao/v2.7.1/Dockerfile) provides `bao` (and a `vault` compatibility alias), prepares `/openbao/config`, `/openbao/file`, and `/openbao/logs`, exposes TCP 8200, and has flavor-specific entrypoints. Its default command includes dev-server behavior.

This image keeps the executable path, directories, and port, but omits the compatibility alias and intentionally does not inherit dev-mode defaults. Its small entrypoint disables core dumps and execs `bao server -config=/openbao/config` under `dumb-init`; supply an external server configuration and persistent storage. It runs as UID/GID `10001:10001` and omits root ownership repair, `BAO_LOCAL_CONFIG` generation, and shell-based interface discovery.

## Runtime contract

- Entrypoint: `dumb-init -- /entrypoint.sh`; the wrapper disables core dumps and execs `/usr/bin/bao`. Command: `server -config=/openbao/config`.
- Mount configuration at `/openbao/config`; mount persistent storage at `/openbao/file` and logs at `/openbao/logs`.
- TCP port: 8200. No development server or default insecure listener is configured.
- Config and data paths must be writable/readable by UID/GID `10001:10001` as required by the chosen storage backend.
- If the server config enables memory locking, grant `IPC_LOCK`; otherwise explicitly configure `disable_mlock = true` and understand the reduced protection against secret material being paged to disk.
- Provide TLS/listener settings explicitly in the mounted config. The image does not contain configuration, credentials, or secrets.
