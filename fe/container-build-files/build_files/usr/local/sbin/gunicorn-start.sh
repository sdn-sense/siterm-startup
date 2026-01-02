#!/bin/bash
set -a
source /etc/environment || true
set +a

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting gunicorn server"
# Include fast api script location
export PYTHONPATH="/var/www/wsgi-scripts/:$PYTHONPATH"

# Default values if not defined in /etc/environment
GU_WORKERS="${GU_WORKERS:-2}"
GU_THREADS="${GU_THREADS:-1}"
GU_MAX_REQUESTS="${GU_MAX_REQUESTS:-30000}"
GU_MAX_REQUESTS_JITTER="${GU_MAX_REQUESTS_JITTER:-5000}"
GU_TIMEOUT="${GU_TIMEOUT:-120}"
GU_GRACEFUL_TIMEOUT="${GU_GRACEFUL_TIMEOUT:-30}"
GU_KEEP_ALIVE="${GU_KEEP_ALIVE:-5}"
GU_LIMIT_REQUEST_LINE="${GU_LIMIT_REQUEST_LINE:-8190}"
GU_LIMIT_REQUEST_FIELDS="${GU_LIMIT_REQUEST_FIELDS:-32768}"
GU_LIMIT_REQUEST_BODY="${GU_LIMIT_REQUEST_BODY:-104857600}"
GU_LOG_LEVEL="${LOG_LEVEL:-info}"

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Gunicorn configuration:"
echo "  Workers:                $GU_WORKERS"
echo "  Threads:                $GU_THREADS"
echo "  Max requests:           $GU_MAX_REQUESTS"
echo "  Max requests jitter:    $GU_MAX_REQUESTS_JITTER"
echo "  Timeout:                $GU_TIMEOUT"
echo "  Graceful timeout:       $GU_GRACEFUL_TIMEOUT"
echo "  Keep alive:             $GU_KEEP_ALIVE"
echo "  Limit request line:     $GU_LIMIT_REQUEST_LINE"
echo "  Limit request fields:   $GU_LIMIT_REQUEST_FIELDS"
echo "  Limit request body:     $GU_LIMIT_REQUEST_BODY"
echo "  Log level:              $GU_LOG_LEVEL"

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
