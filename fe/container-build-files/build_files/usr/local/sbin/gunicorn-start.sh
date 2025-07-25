#!/bin/bash
set -a
source /etc/environment || true
set +a

# Include fast api script location
export PYTHONPATH="/var/www/wsgi-scripts/:$PYTHONPATH"

# Default values if not defined in /etc/environment
GU_WORKERS="${GU_WORKERS:-2}"
GU_THREADS="${GU_THREADS:-1}"
GU_MAX_REQUESTS="${GU_MAX_REQUESTS:-3000}"
GU_MAX_REQUESTS_JITTER="${GU_MAX_REQUESTS_JITTER:-500}"
GU_TIMEOUT="${GU_TIMEOUT:-120}"
GU_GRACEFUL_TIMEOUT="${GU_GRACEFUL_TIMEOUT:-30}"
GU_KEEP_ALIVE="${GU_KEEP_ALIVE:-5}"
GU_LIMIT_REQUEST_LINE="${GU_LIMIT_REQUEST_LINE:-8190}"
GU_LIMIT_REQUEST_FIELDS="${GU_LIMIT_REQUEST_FIELDS:-32768}"
GU_LIMIT_REQUEST_BODY="${GU_LIMIT_REQUEST_BODY:-104857600}"
GU_LOG_LEVEL="${LOG_LEVEL:-info}"

# Start gunicorn
exec gunicorn sitefe:app \
  -k uvicorn.workers.UvicornWorker \
  --preload \
  --workers "$GU_WORKERS" \
  --threads "$GU_THREADS" \
  --max-requests "$GU_MAX_REQUESTS" \
  --max-requests-jitter "$GU_MAX_REQUESTS_JITTER" \
  --timeout "$GU_TIMEOUT" \
  --graceful-timeout "$GU_GRACEFUL_TIMEOUT" \
  --keep-alive "$GU_KEEP_ALIVE" \
  --limit-request-line "$GU_LIMIT_REQUEST_LINE" \
  --limit-request-fields "$GU_LIMIT_REQUEST_FIELDS" \
  --access-logfile "-" \
  --error-logfile "-" \
  --log-level "$GU_LOG_LEVEL" \
  --bind 127.0.0.1:8080
