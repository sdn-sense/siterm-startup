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

COPY run-wrapper.sh /usr/local/bin/run-wrapper.sh
CMD /usr/local/bin/run-wrapper.sh
