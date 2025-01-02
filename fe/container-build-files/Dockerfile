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
RUN ./pre-install.sh $RELEASE && mv setup-sitefe.py setup.py && pip3 install . -v || exit $?
# Install all data files needed for FE - httpd, cron, web files
RUN cp packaging/siterm-site-fe/sitefe.wsgi /var/www/wsgi-scripts/ && \
    cp packaging/siterm-site-fe/httpd.conf /etc/httpd/conf/httpd.conf && \
    cp packaging/siterm-site-fe/sitefe-httpd.conf /etc/httpd/sitefe-httpd.template && \
    cp packaging/siterm-site-fe/welcome.conf /etc/httpd/conf.d/ && \
    cp packaging/general/siterm-crons /etc/cron.d/ && \
    cp packaging/general/siterm-ca-cron.sh /etc/cron-scripts/ && \
    cp -R src/html/* /var/www/html/

# Install all ansible collections
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-aristaeos-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos10-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos9-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-freertr-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-sonic-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-cisconx9-collection,"$GITBR" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-frr-collection,"$GITBR"

# Add all supervisord configs
# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/ /usr/local/sbin/
COPY build_files/etc/supervisord.d/ /etc/supervisord.d/
COPY build_files/root/.ansible.cfg /root/.ansible.cfg

EXPOSE 80 443

HEALTHCHECK --retries=3 --start-period=60s --interval=60s --timeout=30s CMD bash /usr/local/sbin/docker-healthcheck.sh || exit 1

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]

# NOTE:
# ppc64le keeps very old openssl. There is only one machine of this
# So not rebuilding whole ssl just for this. This is not needed
# for x86_64
# export CRYPTOGRAPHY_ALLOW_OPENSSL_102=1
