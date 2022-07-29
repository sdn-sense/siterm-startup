FROM sitefe-base:latest
MAINTAINER Justas Balcas <jbalcas@caltech.edu>

ADD build_files/mariadb.sh /root/mariadb.sh
RUN chmod +x /root/mariadb.sh

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN chmod g+s /var/log/dtnrm-site-fe/
RUN mkdir -p /opt/siterm/dtnrmcode
RUN cd /opt/siterm/dtnrmcode && git clone -b $GITBR https://github.com/$GITORG/$GITREPO
RUN cd /opt/siterm/dtnrmcode/siterm/ && pip3 install -r requirements-sitefe.txt || exit $?
RUN cd /opt/siterm/dtnrmcode/siterm/ && python3 setup-sitefe.py install || exit $?

RUN ansible-galaxy collection install dellemc.os9
RUN ansible-galaxy collection install arista.eos

EXPOSE 80 443
COPY run-wrapper.sh /usr/local/bin/run-wrapper.sh
ENTRYPOINT ["/usr/local/bin/run-wrapper.sh"]

