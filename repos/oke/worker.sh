#!/bin/sh
# Placeholder oke worker. Reads queue name from QUEUE env var, defaults to test-queue.
# Pulls items off a Redis list and "processes" them with a short sleep.

set -eu

QUEUE="${QUEUE:-test-queue}"
REDIS_HOST="${REDIS_HOST:-redis.oke.svc.cluster.local}"

echo "[oke-worker] build=${BUILD_SHA:-unknown} queue=${QUEUE} redis=${REDIS_HOST}"

while true; do
  ITEM="$(redis-cli -h "$REDIS_HOST" LPOP "$QUEUE")"
  if [ -n "$ITEM" ]; then
    echo "[oke-worker] processing $ITEM"
    sleep 3
  else
    sleep 2
  fi
done
