FROM almalinux:8
# Architecture argument: amd64 ppc64le
ARG ARCH

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

MAINTAINER Justas Balcas <jbalcas@caltech.edu>

RUN mkdir -p /var/log/dtnrm-agent/{Agent,Debugger,Ruler,contentdb}/
RUN mkdir -p /opt/siterm/{config,dtnrmcode}

RUN yum -y install epel-release

RUN yum -y install git autoconf automake sudo libcurl-devel libffi-devel python3-lxml openssl-devel curl gcc traceroute libuuid-devel lm_sensors ipset make nc pkgconfig python38 python38-pyyaml zlib-devel python38-devel wget tcpdump jq iproute cronie python38-pip wireshark iperf3 iproute-tc diffutils fetch-crl procps-ng mariadb-devel libxml2-devel libxslt-devel

RUN mkdir -p /usr/src/
# Install iprange
RUN git clone https://github.com/firehol/iprange.git /usr/src/iprange.git
RUN cd /usr/src/iprange.git/ && ./autogen.sh
RUN cd /usr/src/iprange.git/ && ./configure --prefix=/usr CFLAGS="-O2" --disable-man 
RUN cd /usr/src/iprange.git/ && make clean && make && make install
RUN rm -rf /usr/src/iprange.git

# Install firehol
RUN git clone https://github.com/firehol/firehol.git /usr/src/firehol.git
RUN cd /usr/src/firehol.git/ && ./autogen.sh 
RUN cd /usr/src/firehol.git/ && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --disable-man --disable-doc 
RUN cd /usr/src/firehol.git/ && make clean && make && make install
RUN rm -rf /usr/src/firehol.git

RUN touch /etc/firehol/fireqos.conf

RUN rpm -i https://repo.opensciencegrid.org/osg/3.6/el8/release/x86_64/osg-ca-certs-1.94-1.osg36.el8.noarch.rpm
RUN yum clean all && rm -rf /var/cache/yum
