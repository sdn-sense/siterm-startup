ARG RELEASE=latest
FROM sdnsense/sitefe-base:$RELEASE
MAINTAINER Justas Balcas <jbalcas@caltech.edu>

ADD build_files/mariadb.sh /root/mariadb.sh
ADD build_files/ssh-keygen.py /root/ssh-keygen.py
RUN chmod +x /root/mariadb.sh

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN chmod g+s /var/log/dtnrm-site-fe/
RUN mkdir -p /opt/siterm/dtnrmcode
RUN mkdir -p /root/.ssh/

RUN cd /opt/siterm/dtnrmcode && git clone -b $GITBR https://github.com/$GITORG/$GITREPO
# Rust is needed only of ppc64le
RUN if [[ $ARCH == "ppc64le" ]]; then source $HOME/.cargo/env && cd /opt/siterm/dtnrmcode/siterm/ && pip3 install -r requirements-sitefe.txt || exit $?; fi
RUN if [[ $ARCH != "ppc64le" ]]; then cd /opt/siterm/dtnrmcode/siterm/ && pip3 install -r requirements-sitefe.txt || exit $?; fi
RUN cd /opt/siterm/dtnrmcode/siterm/ && python3 setup-sitefe.py install || exit $?

RUN ansible-galaxy collection install dellemc.os9
RUN ansible-galaxy collection install dellemc.os10
RUN ansible-galaxy collection install arista.eos
RUN ansible-galaxy collection install cisco.nxos
RUN ansible-galaxy collection install git+https://github.com/sdn-sense/rare-freertr-collection,master
# 4.1.0 Needed because of this issue: https://github.com/ansible-collections/ansible.netcommon/issues/512
RUN ansible-galaxy collection install ansible.netcommon:4.1.0

EXPOSE 80 443
COPY build_files/run-wrapper.sh /usr/local/bin/run-wrapper.sh
ENTRYPOINT ["/usr/local/bin/run-wrapper.sh"]

