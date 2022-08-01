docker run -d -p 9100:9100 \
  --net="host" \
  --pid="host" \
  -v "/proc:/host/proc:ro" \
  -v "/sys:/host/sys:ro" \
  -v "/:/host:ro,rslave" \
  --log-driver "json-file" \
  --log-opt max-size=10m --log-opt max-file=10 \
  prom/node-exporter \
  --path.rootfs=/host \
  --collector.netdev.address-info
