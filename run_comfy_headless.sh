#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

run_as_root() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
fi

SMB_ENABLED="${SMB_ENABLED:-false}"
if [[ "$SMB_ENABLED" == "true" || "$SMB_ENABLED" == "1" || "$SMB_ENABLED" == "yes" ]]; then
  SMB_SERVER="${SMB_SERVER:?SMB_SERVER is required when SMB_ENABLED=true}"
  SMB_SHARE="${SMB_SHARE:?SMB_SHARE is required when SMB_ENABLED=true}"
  SMB_MOUNT_POINT="${SMB_MOUNT_POINT:?SMB_MOUNT_POINT is required when SMB_ENABLED=true}"
  SMB_USERNAME="${SMB_USERNAME:?SMB_USERNAME is required when SMB_ENABLED=true}"
  SMB_PASSWORD="${SMB_PASSWORD:?SMB_PASSWORD is required when SMB_ENABLED=true}"
  SMB_VERSION="${SMB_VERSION:-3.0}"
  SMB_DOMAIN="${SMB_DOMAIN:-}"
  SMB_UID="${SMB_UID:-$(id -u)}"
  SMB_GID="${SMB_GID:-$(id -g)}"
  SMB_READ_ONLY="${SMB_READ_ONLY:-true}"

  run_as_root mkdir -p "$SMB_MOUNT_POINT"
  if ! mountpoint -q "$SMB_MOUNT_POINT"; then
    creds_file="$(mktemp /tmp/comfyui-smb-creds.XXXXXX)"
    chmod 600 "$creds_file"
    {
      echo "username=$SMB_USERNAME"
      echo "password=$SMB_PASSWORD"
      if [ -n "$SMB_DOMAIN" ]; then
        echo "domain=$SMB_DOMAIN"
      fi
    } > "$creds_file"

    mount_opts="credentials=$creds_file,vers=$SMB_VERSION,uid=$SMB_UID,gid=$SMB_GID,file_mode=0644,dir_mode=0755"
    if [[ "$SMB_READ_ONLY" == "true" || "$SMB_READ_ONLY" == "1" || "$SMB_READ_ONLY" == "yes" ]]; then
      mount_opts="$mount_opts,ro"
    else
      mount_opts="$mount_opts,rw"
    fi

    run_as_root mount -t cifs "//$SMB_SERVER/$SMB_SHARE" "$SMB_MOUNT_POINT" -o "$mount_opts"
    rm -f "$creds_file"
  fi
fi

docker compose up -d
