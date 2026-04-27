#!/bin/bash
# One-time system packages needed to build Erlang/OTP from source via mise,
# plus Rust build essentials and general dev tools.
# Run as root inside Ubuntu 22.04 (WSL).
set -euo pipefail

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/01-apt.log
mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

echo "[$(date -Is)] apt update"
apt-get update -y

echo "[$(date -Is)] installing build deps"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  build-essential \
  autoconf \
  m4 \
  libncurses5-dev \
  libssl-dev \
  libwxgtk3.0-gtk3-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libpng-dev \
  libssh-dev \
  unixodbc-dev \
  xsltproc \
  fop \
  libxml2-utils \
  pkg-config \
  ca-certificates \
  curl \
  git \
  unzip \
  xz-utils \
  file

echo "[$(date -Is)] done"
