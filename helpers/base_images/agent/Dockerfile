FROM almalinux:8
# Architecture argument: amd64 ppc64le
ARG ARCH

RUN mkdir -p /var/log/siterm-agent/Agent && \
    mkdir -p /var/log/siterm-agent/Debugger/ && \
    mkdir -p /var/log/siterm-agent/Ruler/ && \
    mkdir -p /var/log/siterm-agent/QOS/ && \
    mkdir -p /var/log/siterm-agent/contentdb/ && \
    mkdir -p /opt/siterm/config && \
    mkdir -p sitermcode && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /etc/supervisord.d/ && \
    mkdir -p /usr/local/sbin/ && \
    mkdir -p /usr/src/ && mkdir -p /etc/cron.d/

RUN yum -y install epel-release && yum clean all

RUN yum -y install git autoconf automake sudo libcurl-devel libffi-devel python3-lxml openssl-devel curl gcc traceroute libuuid-devel lm_sensors ipset make nc pkgconfig python39 python39-pyyaml zlib-devel python39-devel wget tcpdump jq iproute cronie python39-pip wireshark iperf3 iproute-tc diffutils fetch-crl procps-ng mariadb-devel libxml2-devel libxslt-devel lldpd && yum clean all

# Install supervisord and superlance to run service, monitor mem usage
RUN pip3 install --no-cache-dir --upgrade setuptools pip && \
    pip3 install --no-cache-dir supervisor superlance

# Install iprange
RUN git clone https://github.com/firehol/iprange.git /usr/src/iprange.git
WORKDIR /usr/src/iprange.git/
RUN ./autogen.sh && ./configure --prefix=/usr CFLAGS="-O2" --disable-man && \
    make clean && make && make install && rm -rf /usr/src/iprange.git

# Install firehol
RUN git clone https://github.com/firehol/firehol.git /usr/src/firehol.git
WORKDIR /usr/src/firehol.git
RUN ./autogen.sh && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-man --disable-doc && \
    make clean && make && make install && rm -rf /usr/src/firehol.git

RUN touch /etc/firehol/fireqos.conf

# Configure Supervisord
COPY build_files/etc/supervisord.conf /etc/

# Install CA Certs
# RUN rpm -i https://repo.opensciencegrid.org/osg/23-main/el8/release/x86_64/osg-ca-certs-1.117-1.osg23.el8.noarch.rpm
RUN rpm -i https://mirror.grid.uchicago.edu/pub/osg/23-main/el8/release/x86_64/osg-ca-certs-1.118-1.osg23.el8.noarch.rpm

# Install crons to fetch CA Certs
COPY build_files/etc/cron.d/fetch-crl /etc/cron.d/fetch-crl
COPY build_files/etc/cron.d/fetch-crl-reboot /etc/cron.d/fetch-crl-reboot
