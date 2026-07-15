#!/usr/bin/env bash
set -Eeuo pipefail

readonly INSTALL_ROOT="/opt/markdown-quality-platform"
readonly SERVICE_USER="md-platform"
readonly SERVICE_HOME="/var/lib/md-platform"
readonly DATASET_DIR="/srv/markdown-quality-platform/datasets"
readonly DOC_EVAL_DATASET_LINK="${INSTALL_ROOT}/services/doc-eval/datasets"
readonly HTTPS_IP="${HTTPS_IP:-10.240.210.208}"
readonly TLS_DIR="/etc/ssl/markdown-quality-platform"
readonly TLS_CERT_FILE="${TLS_DIR}/selfsigned.crt"
readonly TLS_KEY_FILE="${TLS_DIR}/selfsigned.key"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this installer as root: sudo bash deploy/install-ubuntu.sh" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${ROOT_DIR}" != "${INSTALL_ROOT}" ]]; then
  echo "Clone the repository to ${INSTALL_ROOT}; current path is ${ROOT_DIR}." >&2
  exit 1
fi

PYTHON_BIN="${PYTHON_BIN:-python3.12}"
for command in git node npm nginx openssl "${PYTHON_BIN}" uv runuser systemctl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done

install -d -m 0700 -o root -g root "${TLS_DIR}"
if [[ ! -s "${TLS_CERT_FILE}" ]] ||
   [[ ! -s "${TLS_KEY_FILE}" ]] ||
   ! openssl x509 -checkend 2592000 -noout -in "${TLS_CERT_FILE}" >/dev/null 2>&1 ||
   ! openssl x509 -noout -ext subjectAltName -in "${TLS_CERT_FILE}" 2>/dev/null |
     grep -Fq "IP Address:${HTTPS_IP}"; then
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 365 \
    -keyout "${TLS_KEY_FILE}" \
    -out "${TLS_CERT_FILE}" \
    -subj "/CN=${HTTPS_IP}" \
    -addext "subjectAltName=IP:${HTTPS_IP}" \
    -addext "extendedKeyUsage=serverAuth"
fi
chmod 0644 "${TLS_CERT_FILE}"
chmod 0600 "${TLS_KEY_FILE}"

node_major="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
if (( node_major < 22 )); then
  echo "Node.js 22 or newer is required; found $(node --version)." >&2
  exit 1
fi

if ! id -u "${SERVICE_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${SERVICE_HOME}" --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${DATASET_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}"

run_as_service() {
  runuser -u "${SERVICE_USER}" -- env HOME="${SERVICE_HOME}" PATH="${PATH}" "$@"
}

run_as_service git -C "${INSTALL_ROOT}" submodule sync --recursive
run_as_service git -C "${INSTALL_ROOT}" submodule update --init --recursive

if [[ -e "${DOC_EVAL_DATASET_LINK}" && ! -L "${DOC_EVAL_DATASET_LINK}" ]]; then
  echo "Expected ${DOC_EVAL_DATASET_LINK} to be absent or a symbolic link." >&2
  echo "Move any existing datasets to ${DATASET_DIR}, then rerun the installer." >&2
  exit 1
fi
ln -sfn "${DATASET_DIR}" "${DOC_EVAL_DATASET_LINK}"
chown -h "${SERVICE_USER}:${SERVICE_USER}" "${DOC_EVAL_DATASET_LINK}"

run_as_service npm --prefix "${INSTALL_ROOT}" ci
run_as_service npm --prefix "${INSTALL_ROOT}" run build

run_as_service bash -c 'cd "$1" && uv sync --locked --extra server' _ \
  "${INSTALL_ROOT}/services/doc-eval"

if [[ ! -x "${INSTALL_ROOT}/services/dataset-builder/.venv/bin/python" ]]; then
  run_as_service "${PYTHON_BIN}" -m venv \
    "${INSTALL_ROOT}/services/dataset-builder/.venv"
fi
run_as_service "${INSTALL_ROOT}/services/dataset-builder/.venv/bin/python" -m pip install \
  --disable-pip-version-check -r \
  "${INSTALL_ROOT}/services/dataset-builder/requirements.txt"

run_as_service npm --prefix "${INSTALL_ROOT}/services/grammar-check/backend" ci
run_as_service npm --prefix "${INSTALL_ROOT}/services/grammar-check/backend" run build
run_as_service npm --prefix "${INSTALL_ROOT}/services/grammar-check/frontend" ci
run_as_service npm --prefix "${INSTALL_ROOT}/services/grammar-check/frontend" run build

install -m 0644 "${INSTALL_ROOT}/deploy/systemd/markdown-evaluation.service" \
  /etc/systemd/system/markdown-evaluation.service
install -m 0644 "${INSTALL_ROOT}/deploy/systemd/markdown-dataset-builder.service" \
  /etc/systemd/system/markdown-dataset-builder.service
install -m 0644 "${INSTALL_ROOT}/deploy/systemd/markdown-syntax-api.service" \
  /etc/systemd/system/markdown-syntax-api.service
if [[ "${SKIP_NGINX_SITE:-0}" != "1" ]]; then
  install -m 0644 "${INSTALL_ROOT}/deploy/nginx/ubuntu.conf" \
    /etc/nginx/sites-available/markdown-quality-platform

  if [[ -e /etc/nginx/sites-enabled/default ]]; then
    if [[ "${REPLACE_DEFAULT_NGINX_SITE:-0}" == "1" ]]; then
      rm -f /etc/nginx/sites-enabled/default
    else
      echo "Ubuntu's default Nginx site is still enabled." >&2
      echo "On a dedicated server rerun with REPLACE_DEFAULT_NGINX_SITE=1." >&2
      echo "On a shared server merge deploy/nginx/ubuntu.conf and use SKIP_NGINX_SITE=1." >&2
      exit 1
    fi
  fi

  ln -sfn /etc/nginx/sites-available/markdown-quality-platform \
    /etc/nginx/sites-enabled/markdown-quality-platform
fi

systemctl daemon-reload
nginx -t

cat <<'EOF'
Installation and build completed. Services were not started automatically.

Start and enable them individually:
  sudo systemctl enable --now markdown-evaluation
  sudo systemctl enable --now markdown-dataset-builder
  sudo systemctl enable --now markdown-syntax-api
  sudo systemctl enable --now nginx

Then run:
  sudo bash /opt/markdown-quality-platform/deploy/verify-ubuntu.sh
EOF
