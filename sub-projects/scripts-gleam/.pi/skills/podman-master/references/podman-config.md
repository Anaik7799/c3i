# Podman Configuration Reference

## 1. containers.conf
Located at `/etc/containers/containers.conf` or `~/.config/containers/containers.conf`.
- `[containers]`: Default resource limits, environment variables, and capabilities.
- `[network]`: Default network backend (`netavark` recommended) and DNS settings.
- `[engine]`: Path to OCI runtime (`crun`, `runc`), log levels, and event backends.

## 2. registries.conf
Located at `/etc/containers/registries.conf`.
- `unqualified-search-registries`: List of registries to search for images (e.g., `docker.io`, `quay.io`).
- `[[registry]]`: Configure mirrors, insecure status, or prefix-based redirects.

## 3. policy.json
Located at `/etc/containers/policy.json`.
- Manages signature verification policies for images. Default is usually `default: [{type: "insecureAcceptAnything"}]` for development.
