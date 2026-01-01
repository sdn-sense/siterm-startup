ARG RELEASE=latest
ARG ARCH="x86_64"
FROM sdnsense/sitermfebase:$RELEASE

COPY build_files/root/ssh-keygen.py /root/ssh-keygen.py
COPY build_files/root/ansible-prepare.py /root/ansible-prepare.py
COPY build_files/root/dircreate.py /root/dircreate.py
COPY build_files/root/generate_jwt.py /root/generate_jwt.py

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master
ARG GITBRANS=master

WORKDIR /opt/siterm/sitermcode
RUN git clone -b $GITBR https://github.com/$GITORG/$GITREPO
WORKDIR /opt/siterm/sitermcode/siterm/
RUN pip3 install --no-cache-dir -r requirements-sitefe.txt --upgrade || exit $?
RUN ./pre-install.sh "$RELEASE" && mv setup-sitefe.py setup.py && pip3 install --no-cache-dir . -v || exit $?
# Install all data files needed for FE - httpd, cron, web files
RUN cp packaging/siterm-site-fe/sitefe.py /var/www/wsgi-scripts/ && \
    cp packaging/general/siterm-crons /etc/cron.d/ && \
    cp packaging/general/siterm-ca-cron.sh /etc/cron-scripts/ && \
    cp -R src/html/* /var/www/html/

# Install all ansible collections
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/sense-aristaeos-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos10-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-dellos9-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-freertr-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-sonic-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-cisconx9-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-frr-collection,"$GITBRANS" && \
    ansible-galaxy collection install git+https://github.com/sdn-sense/sense-junos-collection,"$GITBRANS"

# Add all supervisord configs
# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/ /usr/local/sbin/
COPY build_files/etc/supervisord.d/ /etc/supervisord.d/
COPY build_files/root/.ansible.cfg /root/.ansible.cfg
COPY build_files/var/www/wsgi-scripts/ /var/www/wsgi-scripts/

# Copy all HTTP Templates
COPY build_files/etc/httpd/httpd.conf /etc/httpd/conf/httpd.conf
COPY build_files/etc/httpd/sitefe-httpd.conf-template /etc/httpd/sitefe-httpd.conf-template
COPY build_files/etc/httpd/welcome.conf /etc/httpd/conf.d/welcome.conf

EXPOSE 443

HEALTHCHECK --retries=3 --start-period=60s --interval=60s --timeout=30s CMD bash /usr/local/sbin/docker-healthcheck.sh || exit 1

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
