#!/usr/bin/env bash
set -Eeuo pipefail

readonly INSTALL_ROOT="/opt/markdown-quality-platform"
readonly SERVICE_USER="md-platform"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo bash ${INSTALL_ROOT}/deploy/update-ubuntu.sh" >&2
  exit 1
fi

if [[ -n "$(git -C "${INSTALL_ROOT}" status --porcelain)" ]]; then
  echo "Deployment checkout has local changes; update aborted." >&2
  exit 1
fi

runuser -u "${SERVICE_USER}" -- git -C "${INSTALL_ROOT}" pull --ff-only
runuser -u "${SERVICE_USER}" -- git -C "${INSTALL_ROOT}" submodule sync --recursive
runuser -u "${SERVICE_USER}" -- git -C "${INSTALL_ROOT}" submodule update --init --recursive

SKIP_NGINX_SITE="${SKIP_NGINX_SITE:-0}" \
  bash "${INSTALL_ROOT}/deploy/install-ubuntu.sh"

systemctl restart markdown-evaluation
systemctl restart markdown-dataset-builder
systemctl restart markdown-syntax-api
systemctl reload nginx

bash "${INSTALL_ROOT}/deploy/verify-ubuntu.sh"
