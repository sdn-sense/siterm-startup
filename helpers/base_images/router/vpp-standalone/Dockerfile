FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                iproute2 \
                iputils-ping \
                python3-pip \
                supervisor ethtool && rm -rf /var/lib/apt/lists/*


WORKDIR /vpp
RUN curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | bash
RUN apt-get update && apt-get install -y vpp vpp-plugin-core vpp-plugin-devtools vpp-plugin-dpdk python3-vpp-api vpp-dbg vpp-dev && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /var/log/vpp

COPY etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY root/run.sh /root/run.sh
COPY root/run-monitoring.sh /root/run-monitoring.sh
COPY root/run-routeadd.sh /root/run-routeadd.sh

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]