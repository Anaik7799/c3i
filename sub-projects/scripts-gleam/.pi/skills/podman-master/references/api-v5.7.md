# Podman API v5.7 Reference (Libpod)

This reference covers the Libpod-specific extensions beyond the Docker-compatible API.

## 1. Pod Management
- `GET /v5.7.0/libpod/pods/json`: List all pods.
- `POST /v5.7.0/libpod/pods/create`: Create a new pod.
- `GET /v5.7.0/libpod/pods/{name}/json`: Inspect a specific pod.
- `POST /v5.7.0/libpod/pods/{name}/start`: Start all containers in a pod.
- `POST /v5.7.0/libpod/pods/{name}/stop`: Stop all containers in a pod.

## 2. Kubernetes Integration
- `GET /v5.7.0/libpod/generate/kube`: Generate Kubernetes YAML from a pod/container.
- `POST /v5.7.0/libpod/play/kube`: Create pods/containers from a Kubernetes YAML.

## 3. Volume & Storage
- `GET /v5.7.0/libpod/volumes/json`: List volumes.
- `POST /v5.7.0/libpod/volumes/create`: Create a volume with specific driver options.

## 4. System & Info
- `GET /v5.7.0/libpod/info`: Detailed system information including rootless status and storage driver details.
- `GET /v5.7.0/libpod/events`: Stream system events.
