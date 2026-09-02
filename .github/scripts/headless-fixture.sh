#!/usr/bin/env bash
set -euo pipefail

api="https://api.1ecomm.com/operations/headless/e2e-fixtures"
state="${RUNNER_TEMP:-/tmp}/headless-fixture-lease.json"
token="${HEADLESS_E2E_ALLOCATOR_TOKEN:-}"
[ -n "$token" ] || { echo "HEADLESS_E2E_ALLOCATOR_TOKEN is required" >&2; exit 1; }

if [ "${1:-}" = "allocate" ]; then
  response="$(curl --fail --silent --show-error --retry 2 \
    -H "x-fixture-allocator-token: $token" \
    -H 'content-type: application/json' \
    --data "$(jq -cn --arg runId "${GITHUB_REPOSITORY:-local}:${GITHUB_RUN_ID:-0}:${GITHUB_RUN_ATTEMPT:-0}" '{runId:$runId,ttlMinutes:45,inventory:20}')" \
    "$api/allocate")"
  printf '%s' "$response" > "$state"
  chmod 600 "$state"
  for field in leaseId leaseToken storeId publishableKey productId variantId; do jq -er ".$field | strings | select(length > 0)" "$state" >/dev/null; done
  echo "::add-mask::$(jq -r '.leaseToken' "$state")"
  echo "::add-mask::$(jq -r '.publishableKey' "$state")"
  {
    echo "HEADLESS_LEASE_ID=$(jq -r '.leaseId' "$state")"
    echo "HEADLESS_LEASE_TOKEN=$(jq -r '.leaseToken' "$state")"
    echo "HEADLESS_STORE_ID=$(jq -r '.storeId' "$state")"
    echo "HEADLESS_PUBLISHABLE_KEY=$(jq -r '.publishableKey' "$state")"
    echo "HEADLESS_PRODUCT_ID=$(jq -r '.productId' "$state")"
    echo "HEADLESS_VARIANT_ID=$(jq -r '.variantId' "$state")"
    echo "HEADLESS_API_URL=https://api.1ecomm.com"
  } >> "$GITHUB_ENV"
  echo "Allocated isolated fixture lease $(jq -r '.leaseId' "$state")"
elif [ "${1:-}" = "release" ]; then
  [ -s "$state" ] || { echo "No fixture lease state found; nothing to release"; exit 0; }
  curl --fail --silent --show-error --retry 2 \
    -H "x-fixture-allocator-token: $token" \
    -H "x-fixture-lease-token: $(jq -r '.leaseToken' "$state")" \
    -H 'content-type: application/json' \
    --data "$(jq -c '{leaseId}' "$state")" \
    "$api/release" >/dev/null
  echo "Released isolated fixture lease $(jq -r '.leaseId' "$state")"
  rm -f "$state"
else
  echo "usage: $0 allocate|release" >&2
  exit 2
fi
