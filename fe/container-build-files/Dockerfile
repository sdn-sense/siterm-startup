ARG RELEASE=latest
ARG ARCH="x86_64"
FROM sdnsense/sitefe-base:$RELEASE

COPY build_files/ssh-keygen.py /root/ssh-keygen.py
COPY build_files/ansible-prepare.py /root/ansible-prepare.py
COPY build_files/dircreate.py /root/dircreate.py

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

WORKDIR /opt/siterm/sitermcode
RUN git clone -b $GITBR https://github.com/$GITORG/$GITREPO
WORKDIR /opt/siterm/sitermcode/siterm/
# Rust is needed only of ppc64le
RUN if [ "$ARCH" == "ppc64le" ]; then source "$HOME"/.cargo/env && pip3 install --no-cache-dir -r requirements-sitefe.txt || exit $?; fi
RUN if [ "$ARCH" != "ppc64le" ]; then pip3 install --no-cache-dir -r requirements-sitefe.txt || exit $?; fi
RUN python3 setup-sitefe.py install || exit $?

# Install all ansible collections
# TODO Move all main to MASTER and use $GITBR
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-aristaeos-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos10-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos9-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-freertr-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-sonic-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-cisconx9-collection,"$GITBR"

# Add all supervisord configs
# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/mariadb.sh /usr/local/sbin/mariadb.sh
COPY build_files/usr/local/sbin/start-cleanup.sh /usr/local/sbin/start-cleanup.sh
COPY build_files/etc/supervisord.d/00-cleanup.conf /etc/supervisord.d/00-cleanup.conf
COPY build_files/etc/supervisord.d/09-mariadb.conf /etc/supervisord.d/09-mariadb.conf
COPY build_files/etc/supervisord.d/11-config-fetcher.conf /etc/supervisord.d/11-config-fetcher.conf
COPY build_files/etc/supervisord.d/12-siterm-debugger.conf /etc/supervisord.d/12-siterm-debugger.conf
COPY build_files/etc/supervisord.d/12-httpd.conf /etc/supervisord.d/12-httpd.conf
COPY build_files/etc/supervisord.d/13-lookup-service.conf /etc/supervisord.d/13-lookup-service.conf
COPY build_files/etc/supervisord.d/15-snmpmon-service.conf /etc/supervisord.d/15-snmpmon-service.conf

EXPOSE 80 443

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

# NOTE:
# ppc64le keeps very old openssl. There is only one machine of this
# So not rebuilding whole ssl just for this. This is not needed
# for x86_64
# export CRYPTOGRAPHY_ALLOW_OPENSSL_102=1
