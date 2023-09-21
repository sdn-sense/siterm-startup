ARG RELEASE=latest
ARG ARCH="x86_64"
FROM sdnsense/sitefe-base:$RELEASE
MAINTAINER Justas Balcas <jbalcas@caltech.edu>

ADD build_files/ssh-keygen.py /root/ssh-keygen.py
ADD build_files/ansible-prepare.py /root/ansible-prepare.py
ADD build_files/dircreate.py /root/dircreate.py

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN cd /opt/siterm/sitermcode && git clone -b $GITBR https://github.com/$GITORG/$GITREPO
# Rust is needed only of ppc64le
RUN if [[ $ARCH == "ppc64le" ]]; then source $HOME/.cargo/env && cd /opt/siterm/sitermcode/siterm/ && pip3 install --no-cache-dir -r requirements-sitefe.txt || exit $?; fi
RUN if [[ $ARCH != "ppc64le" ]]; then cd /opt/siterm/sitermcode/siterm/ && pip3 install --no-cache-dir -r requirements-sitefe.txt || exit $?; fi
RUN cd /opt/siterm/sitermcode/siterm/ && python3 setup-sitefe.py install || exit $?

# Install all ansible collections
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-aristaeos-collection,main
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos10-collection,master
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos9-collection,main
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-freertr-collection,master
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-sonic-collection,master
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-cisconx9-collection,main

# Add all supervisord configs
# Copy Supervisor.d Config, Script files
ADD build_files/usr/local/sbin/mariadb.sh /usr/local/sbin/mariadb.sh
COPY build_files/usr/local/sbin/start-cleanup.sh /usr/local/sbin/start-cleanup.sh
COPY build_files/etc/supervisord.d/00-cleanup.conf /etc/supervisord.d/00-cleanup.conf
COPY build_files/etc/supervisord.d/09-mariadb.conf /etc/supervisord.d/09-mariadb.conf
COPY build_files/etc/supervisord.d/11-config-fetcher.conf /etc/supervisord.d/11-config-fetcher.conf
COPY build_files/etc/supervisord.d/12-httpd.conf /etc/supervisord.d/12-httpd.conf
COPY build_files/etc/supervisord.d/13-lookup-service.conf /etc/supervisord.d/13-lookup-service.conf
COPY build_files/etc/supervisord.d/14-provisioning-service.conf /etc/supervisord.d/14-provisioning-service.conf
COPY build_files/etc/supervisord.d/15-snmpmon-service.conf /etc/supervisord.d/15-snmpmon-service.conf

EXPOSE 80 443

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

# NOTE:
# ppc64le keeps very old openssl. There is only one machine of this
# So not rebuilding whole ssl just for this. This is not needed
# for x86_64
# export CRYPTOGRAPHY_ALLOW_OPENSSL_102=1
