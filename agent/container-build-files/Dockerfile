ARG RELEASE=latest
FROM sdnsense/siteagent-base:$RELEASE
MAINTAINER Justas Balcas <jbalcas@caltech.edu>

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN cd /opt/siterm/dtnrmcode && git clone -b $GITBR https://github.com/$GITORG/$GITREPO
RUN cd /opt/siterm/dtnrmcode/siterm/ && pip3 install -r requirements-agent.txt || exit $?
RUN cd /opt/siterm/dtnrmcode/siterm/ && python3 setup-agent.py install || exit $?

# Copy Supervisor.d Config, Script files
COPY build_files/usr/local/sbin/start-cleanup.sh /usr/local/sbin/start-cleanup.sh
COPY build_files/etc/supervisord.d/00-cleanup.conf /etc/supervisord.d/00-cleanup.conf
COPY build_files/etc/supervisord.d/11-config-fetcher.conf /etc/supervisord.d/11-config-fetcher.conf
COPY build_files/etc/supervisord.d/12-dtnrm-debugger.conf /etc/supervisord.d/12-dtnrm-debugger.conf
COPY build_files/etc/supervisord.d/13-dtnrm-ruler.conf /etc/supervisord.d/13-dtnrm-ruler.conf
COPY build_files/etc/supervisord.d/14-dtnrm-agent.conf etc/supervisord.d/14-dtnrm-agent.conf

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisord.conf"]
