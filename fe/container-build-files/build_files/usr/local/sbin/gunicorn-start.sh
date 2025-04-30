#!/bin/bash
set -a
source /etc/environment || true
set +a

# Default values if not defined in /etc/environment
WORKERS="${WORKERS:-3}"
THREADS="${THREADS:-1}"
MAX_REQUESTS="${MAX_REQUESTS:-800}"
MAX_REQUESTS_JITTER="${MAX_REQUESTS_JITTER:-100}"
TIMEOUT="${TIMEOUT:-120}"
GRACEFUL_TIMEOUT="${GRACEFUL_TIMEOUT:-60}"
KEEP_ALIVE="${KEEP_ALIVE:-10}"

# Start gunicorn
exec gunicorn sitefe:application \
  -k uvicorn.workers.UvicornWorker \
  --workers "$WORKERS" \
  --threads "$THREADS" \
  --max-requests "$MAX_REQUESTS" \
  --max-requests-jitter "$MAX_REQUESTS_JITTER" \
  --timeout "$TIMEOUT" \
  --graceful-timeout "$GRACEFUL_TIMEOUT" \
  --keep-alive "$KEEP_ALIVE" \
  --bind 127.0.0.1:8080