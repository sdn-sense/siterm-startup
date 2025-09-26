#!/usr/bin/env bash
echo "Starting default-route.sh script..."
echo "ENV_DEFAULT_ROUTE is set to: ${ENV_DEFAULT_ROUTE}"
if [[ -z "${ENV_DEFAULT_ROUTE}" ]]; then
  echo "ERROR: ENV_DEFAULT_ROUTE is not set. Exiting."
  exit 1
fi
echo "Waiting 60 seconds before first check... to allow VPP/FRR to initialize"
sleep 60

while true; do
  current_default=$(ip -6 route show default | awk '{print $3}' | head -n1 || true)
  if [[ "${current_default}" != "${ENV_DEFAULT_ROUTE}" ]]; then
    echo "Default route mismatch (current: ${current_default:-none}, expected: ${ENV_DEFAULT_ROUTE})"
    echo "Removing existing IPv6 default routes..."
    ip -6 route show default | while read -r line; do
      sudo ip -6 route del ${line}
    done
    echo "Adding IPv6 default route via ${ENV_DEFAULT_ROUTE}"
    sudo ip -6 route add default via "${ENV_DEFAULT_ROUTE}"
  else
    echo "IPv6 default route already set correctly: ${current_default}"
  fi
  sleep 60
done