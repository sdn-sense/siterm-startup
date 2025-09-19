FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# This is copy of FRR installation.

# Update and install build requirements.
RUN apt update && apt upgrade -y && \
    # Basic build requirements from documentation
    apt-get install -y \
            autoconf \
            automake \
            bison \
            build-essential \
            flex \
            git \
            install-info \
            libc-ares-dev \
            libcap-dev \
            libelf-dev \
            libjson-c-dev \
            libpam0g-dev \
            libreadline-dev \
            libsnmp-dev \
            libsqlite3-dev \
            lsb-release \
            libtool \
            lcov \
            make \
            perl \
            pkg-config \
            python3-dev \
            python3-sphinx \
            screen \
            texinfo \
            tmux \
            iptables \
    && \
    # Protobuf build requirements
    apt-get install -y \
        libprotobuf-c-dev \
        protobuf-c-compiler \
    && \
    # Libyang2 extra build requirements
    apt-get install -y \
        cmake \
        libpcre2-dev \
    && \
    # GRPC extra build requirements
    apt-get install -y \
        libgrpc-dev \
        libgrpc++-dev \
        protobuf-compiler-grpc \
    && \
    # Runtime/triage/testing requirements
    apt-get install -y \
        curl \
        gdb \
        kmod \
        iproute2 \
        iputils-ping \
        liblua5.3-dev \
        libssl-dev \
        lua5.3 \
        net-tools \
        python3 \
        python3-pip \
        snmp \
        snmp-mibs-downloader \
        snmpd \
        ssmping \
        sudo \
        time \
        tshark \
        valgrind \
        yodl \
      && \
    download-mibs && \
    wget --tries=5 --waitretry=10 --retry-connrefused https://raw.githubusercontent.com/FRRouting/frr-mibs/main/iana/IANA-IPPM-METRICS-REGISTRY-MIB -O /usr/share/snmp/mibs/iana/IANA-IPPM-METRICS-REGISTRY-MIB && \
    wget --tries=5 --waitretry=10 --retry-connrefused https://raw.githubusercontent.com/FRRouting/frr-mibs/main/ietf/SNMPv2-PDU -O /usr/share/snmp/mibs/ietf/SNMPv2-PDU && \
    wget --tries=5 --waitretry=10 --retry-connrefused https://raw.githubusercontent.com/FRRouting/frr-mibs/main/ietf/IPATM-IPMC-MIB -O /usr/share/snmp/mibs/ietf/IPATM-IPMC-MIB && \
    rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED && \
    python3 -m pip install wheel && \
    bash -c "PV=($(pkg-config --modversion protobuf | tr '.' ' ')); if (( PV[0] == 3 && PV[1] < 19 )); then python3 -m pip install 'protobuf<4' grpcio grpcio-tools; else python3 -m pip install 'protobuf>=4' grpcio grpcio-tools; fi" && \
    python3 -m pip install 'pytest>=6.2.4' 'pytest-xdist>=3.6.1' 'pytest-asyncio>=0.25.3' && \
    python3 -m pip install 'scapy>=2.4.5' && \
    python3 -m pip install pyyaml && \
    python3 -m pip install xmltodict && \
    python3 -m pip install git+https://github.com/Exa-Networks/exabgp@0659057837cd6c6351579e9f0fa47e9fb7de7311

ARG UID=1010
RUN groupadd -r -g 92 frr && \
      groupadd -r -g 85 frrvty && \
      adduser --system --ingroup frr --home /home/frr \
              --gecos "FRR suite" -u $UID --shell /bin/bash frr && \
      usermod -a -G frrvty frr && \
      useradd -d /var/run/exabgp/ -s /bin/false exabgp && \
      echo 'frr ALL = NOPASSWD: ALL' | tee /etc/sudoers.d/frr && \
      mkdir -p /home/frr && chown frr.frr /home/frr

# Install FRR built packages
RUN mkdir -p /etc/apt/keyrings && \
    curl -s -o /etc/apt/keyrings/frrouting.gpg https://deb.frrouting.org/frr/keys.gpg && \
    echo deb '[signed-by=/etc/apt/keyrings/frrouting.gpg]' https://deb.frrouting.org/frr \
        $(lsb_release -s -c) "frr-stable" > /etc/apt/sources.list.d/frr.list && \
    apt-get update && apt-get install -y librtr-dev libyang2-dev libyang2-tools && rm -rf /var/lib/apt/lists/*

# ===========================================================================
# This part is for VPP installation, mostly copy of vpp-standalone Dockerfile
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
COPY etc/vpp/startup.conf-template /etc/vpp/startup.conf-template
COPY etc/vpp/startup.gate /etc/vpp/startup.gate


# TODO: Need supervisor config to start both FRR
# ===========================================================================
# Build FRR from source
COPY usr/lib/frr/docker-start /usr/lib/frr/docker-start
RUN mkdir -p /var/log/frr /var/run/frr /etc/frr/ /var/lib/frr/ && chown frr:frr /var/log/frr /var/run/frr /var/lib/frr/ /etc/frr/
COPY --chown=frr:frr etc/frr/daemons /etc/frr/daemons
USER frr:frr

#COPY --chown=frr:frr . /home/frr/frr/ # This is commented out to avoid copying the whole repo
WORKDIR /home/frr/
RUN wget https://github.com/FRRouting/frr/archive/refs/tags/frr-10.4.1.tar.gz && tar -xvzf frr-10.4.1.tar.gz && mv frr-frr-10.4.1 frr

RUN cd ~/frr && ls -l * && \
    ./bootstrap.sh && \
    ./configure \
       --prefix=/usr \
       --sysconfdir=/etc \
       --localstatedir=/var \
       --sbindir=/usr/lib/frr \
       --enable-gcov \
       --enable-dev-build \
       --enable-mgmtd-test-be-client \
       --enable-rpki \
       --enable-sharpd \
       --enable-multipath=256 \
       --enable-user=frr \
       --enable-group=frr \
       --enable-config-rollbacks \
       --enable-grpc \
       --enable-protobuf \
       --enable-vty-group=frrvty \
       --enable-snmp \
       --enable-scripting \
       --with-pkg-extra-version=-my-manual-build && \
    make -j $(nproc) && \
    sudo make install

RUN cd ~/frr && make check || true

# switch back to root for runtime
USER root:root

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
