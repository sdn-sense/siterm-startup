#!/bin/bash
set -a
source /etc/environment || true
set +a

# Default values if not defined in /etc/environment
GU_WORKERS="${WORKERS:-3}"
GU_THREADS="${THREADS:-1}"
GU_MAX_REQUESTS="${MAX_REQUESTS:-800}"
GU_MAX_REQUESTS_JITTER="${MAX_REQUESTS_JITTER:-100}"
GU_TIMEOUT="${TIMEOUT:-120}"
GU_GRACEFUL_TIMEOUT="${GRACEFUL_TIMEOUT:-30}"
GU_KEEP_ALIVE="${KEEP_ALIVE:-5}"
GU_LIMIT_REQUEST_LINE="${GU_LIMIT_REQUEST_LINE:-8190}"
GU_LIMIT_REQUEST_FIELDS="${GU_LIMIT_REQUEST_FIELDS:-32768}"
GU_LIMIT_REQUEST_BODY="${GU_LIMIT_REQUEST_BODY:-104857600}"

# Start gunicorn
exec gunicorn sitefe:application \
  -k uvicorn.workers.UvicornWorker \
  --workers "$GU_WORKERS" \
  --threads "$GU_THREADS" \
  --max-requests "$GU_MAX_REQUESTS" \
  --max-requests-jitter "$GU_MAX_REQUESTS_JITTER" \
  --timeout "$GU_TIMEOUT" \
  --graceful-timeout "$GU_GRACEFUL_TIMEOUT" \
  --keep-alive "$GU_KEEP_ALIVE" \
  --limit-request-line "$GU_LIMIT_REQUEST_LINE" \
  --limit-request-fields "$GU_LIMIT_REQUEST_FIELDS" \
  --bind 127.0.0.1:8080