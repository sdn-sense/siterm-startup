ARG RELEASE=latest
FROM sdnsense/siteagent-base:$RELEASE

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

WORKDIR /opt/siterm/sitermcode
RUN git clone -b $GITBR https://github.com/$GITORG/$GITREPO
WORKDIR /opt/siterm/sitermcode/siterm/
RUN pip3 install --no-cache-dir -r requirements-agent.txt || exit $?
RUN python3 setup-agent.py install || exit $?

# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/start-cleanup.sh /usr/local/sbin/start-cleanup.sh
COPY build_files/etc/supervisord.d/00-cleanup.conf /etc/supervisord.d/00-cleanup.conf
COPY build_files/etc/supervisord.d/11-config-fetcher.conf /etc/supervisord.d/11-config-fetcher.conf
COPY build_files/etc/supervisord.d/12-siterm-debugger.conf /etc/supervisord.d/12-siterm-debugger.conf
COPY build_files/etc/supervisord.d/13-siterm-ruler.conf /etc/supervisord.d/13-siterm-ruler.conf
COPY build_files/etc/supervisord.d/14-siterm-agent.conf /etc/supervisord.d/14-siterm-agent.conf

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
