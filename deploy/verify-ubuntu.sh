#!/usr/bin/env bash
set -Eeuo pipefail

check_url() {
  local name="$1"
  local url="$2"
  curl --fail --silent --show-error --max-time 15 --output /dev/null "${url}"
  printf 'OK  %s  %s\n' "${name}" "${url}"
}

for service in markdown-evaluation markdown-dataset-builder markdown-syntax-api nginx; do
  systemctl is-active --quiet "${service}"
  printf 'OK  service  %s\n' "${service}"
done

check_url "portal" "http://127.0.0.1/"
check_url "evaluation" "http://127.0.0.1/evaluation/"
check_url "evaluation datasets" "http://127.0.0.1/api/evaluation/datasets"
check_url "dataset builder" "http://127.0.0.1/dataset-builder/"
check_url "dataset builder health" "http://127.0.0.1/api/dataset-builder/health"
check_url "syntax frontend" "http://127.0.0.1/syntax-check/"
check_url "syntax API" "http://127.0.0.1/api/syntax/health"
