ARG RELEASE=latest
FROM sdnsense/sitermagentbase:$RELEASE

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN yum -y install traceroute tcpdump wireshark iperf3 java wget && yum clean all
RUN wget -nv https://github.com/fast-data-transfer/fdt/releases/download/0.27.0/fdt.jar -O /opt/fdt.jar


WORKDIR /opt/siterm/sitermcode
RUN git clone -b $GITBR https://github.com/$GITORG/$GITREPO
WORKDIR /opt/siterm/sitermcode/siterm/
RUN pip3 install --no-cache-dir -r requirements-agent.txt || exit $?
RUN ./pre-install.sh "$RELEASE" && mv setup-agent.py setup.py && pip3 install --no-cache-dir . -v || exit $?
# Install all data files needed for Agent, e.g. crons
RUN cp packaging/general/siterm-crons /etc/cron.d/ && \
    cp packaging/general/siterm-ca-cron.sh /etc/cron-scripts/

# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/start-cleanup.sh /usr/local/sbin/start-cleanup.sh
COPY build_files/usr/local/sbin/docker-healthcheck.sh /usr/local/sbin/docker-healthcheck.sh
COPY build_files/etc/supervisord.d/00-cleanup.conf /etc/supervisord.d/00-cleanup.conf
COPY build_files/etc/supervisord.d/11-config-fetcher.conf /etc/supervisord.d/11-config-fetcher.conf
COPY build_files/etc/supervisord.d/12-siterm-debugger.conf /etc/supervisord.d/12-siterm-debugger.conf


HEALTHCHECK --retries=3 --start-period=60s --interval=60s --timeout=30s CMD bash /usr/local/sbin/docker-healthcheck.sh  || exit 1

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
