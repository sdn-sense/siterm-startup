FROM almalinux:8
# Architecture argument: amd64 ppc64le
ARG ARCH

MAINTAINER Justas Balcas <jbalcas@caltech.edu>

RUN yum -y install wget epel-release

# Maria DB Configuration
ADD build_files/mariadb.repo-$ARCH /etc/yum.repos.d/mariadb.repo
ADD build_files/mariadb.sql /root/mariadb.sql
ADD build_files/server.cnf /etc/my.cnf.d/server.cnf
ADD build_files/mariadb.sh /root/mariadb.sh
# Import GPG Keys for MariaDB and EPEL
RUN cd /etc/pki/rpm-gpg/ && wget https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-MariaDB
RUN chmod +x /root/mariadb.sh

# Configuration which repo to use for build
ARG GITREPO=siterm
ARG GITORG=sdn-sense
ARG GITBR=master

RUN adduser apache -U -u 48
RUN adduser mysql -U -u 4000
RUN mkdir -p /var/log/dtnrm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api}/

RUN mkdir -p /var/log/mariadb/
RUN mkdir -p /opt/siterm/config/mysql/
RUN chown mysql:mysql /var/log/mariadb/
RUN chown mysql:mysql /opt/siterm/config/mysql/
RUN chown -R apache:apache /var/log/dtnrm-site-fe
RUN chmod g+s /var/log/dtnrm-site-fe/
RUN mkdir -p /opt/siterm/config && mkdir -p /opt/siterm/dtnrmcode
RUN mkdir -p /etc/httpd/{certs,conf.d}/ && mkdir -p /etc/grid-security/certificates
RUN yum -y install git sudo && yum clean all
RUN cd /opt/siterm/dtnrmcode && git clone -b $GITBR https://github.com/$GITORG/$GITREPO
RUN cd /opt/siterm/dtnrmcode/$GITREPO/installers/ && sudo sh ./fresh-siterm-fe-install.sh -R /opt/siterm/ -D yes -G $GITREPO -O $GITORG -B $GITBR

RUN rpm -i https://repo.opensciencegrid.org/osg/3.6/el8/release/x86_64/osg-ca-certs-1.94-1.osg36.el8.noarch.rpm
RUN rm -f /etc/httpd/conf.d/ssl.conf

RUN yum clean all && rm -rf /var/cache/yum

EXPOSE 80 443
COPY run-wrapper.sh /usr/local/bin/run-wrapper.sh
CMD /usr/local/bin/run-wrapper.sh

