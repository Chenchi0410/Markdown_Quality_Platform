#!/usr/bin/env bash
set -Eeuo pipefail

readonly HTTPS_BASE_URL="${HTTPS_BASE_URL:-https://127.0.0.1}"

check_url() {
  local name="$1"
  local url="$2"
  curl --insecure --fail --silent --show-error --max-time 15 --output /dev/null "${url}"
  printf 'OK  %s  %s\n' "${name}" "${url}"
}

check_http_redirect() {
  local headers
  headers="$(curl --silent --show-error --max-time 15 --head http://127.0.0.1/)"
  grep -Eq '^HTTP/[^ ]+ 308' <<<"${headers}"
  grep -Eiq '^Location: https://' <<<"${headers}"
  printf 'OK  redirect  http://127.0.0.1/ -> HTTPS\n'
}

for service in markdown-evaluation markdown-dataset-builder markdown-syntax-api nginx; do
  systemctl is-active --quiet "${service}"
  printf 'OK  service  %s\n' "${service}"
done

check_http_redirect
check_url "portal" "${HTTPS_BASE_URL}/"
check_url "evaluation" "${HTTPS_BASE_URL}/evaluation/"
check_url "evaluation datasets" "${HTTPS_BASE_URL}/api/evaluation/datasets"
check_url "dataset builder" "${HTTPS_BASE_URL}/dataset-builder/"
check_url "dataset builder health" "${HTTPS_BASE_URL}/api/dataset-builder/health"
check_url "syntax frontend" "${HTTPS_BASE_URL}/syntax-check/"
check_url "syntax API" "${HTTPS_BASE_URL}/api/syntax/health"
