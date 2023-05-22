FROM almalinux:8
# Architecture argument: amd64 ppc64le
ARG ARCH="x86_64"

MAINTAINER Justas Balcas <jbalcas@caltech.edu>

RUN yum -y install wget epel-release

# Maria DB Configuration
ADD build_files/mariadb.repo-$ARCH /etc/yum.repos.d/mariadb.repo
ADD build_files/mariadb.sql /root/mariadb.sql
ADD build_files/server.cnf /etc/my.cnf.d/server.cnf
# Import GPG Keys for MariaDB and EPEL
RUN cd /etc/pki/rpm-gpg/ && wget https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-MariaDB

RUN adduser apache -U -u 48
RUN adduser mysql -U -u 4000

# Precreate all directories
RUN mkdir -p /var/log/dtnrm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api,SNMPMonitoring}/
RUN touch /var/log/dtnrm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api,SNMPMonitoring}/api.log
RUN mkdir -p /var/log/mariadb/
RUN mkdir -p /opt/siterm/config/mysql/
RUN chown mysql:mysql /var/log/mariadb/
RUN chown mysql:mysql /opt/siterm/config/mysql/
RUN chown -R apache:apache /var/log/dtnrm-site-fe
RUN chmod g+ws /var/log/dtnrm-site-fe/
RUN chmod -R g+ws /var/log/dtnrm-site-fe/*
RUN mkdir -p /opt/siterm/config && mkdir -p /opt/siterm/dtnrmcode
RUN mkdir -p /etc/httpd/{certs,conf.d}/ && mkdir -p /etc/grid-security/certificates
RUN mkdir -p /root/.ssh/

# Install all required packages
RUN yum -y install git autoconf sudo libcurl-devel libffi-devel openssl-devel automake curl gcc libuuid-devel lm_sensors make nc pkgconfig wget zlib-devel python39-devel httpd httpd-devel python39-mod_wsgi mod_ssl cronie python39-pip python39 python3-pyOpenSSL mariadb-server python3-mysql mariadb-devel fetch-crl procps-ng redhat-rpm-config net-snmp-devel && yum clean all
RUN pip3 install --no-cache-dir --upgrade setuptools
RUN pip3 install --no-cache-dir --upgrade pip

# Install supervisord and superlance to run service, monitor mem usage
RUN pip3 install --no-cache-dir supervisor superlance
RUN mkdir -p /var/log/supervisor

# Configure Supervisord
RUN mkdir -p /etc/supervisord.d/
COPY build_files/etc/supervisord.conf /etc/

RUN mkdir -p /usr/local/sbin/

RUN rpm -i https://repo.opensciencegrid.org/osg/3.6/el8/release/x86_64/osg-ca-certs-1.110-1.2.osg36.el8.noarch.rpm

RUN rm -f /etc/httpd/conf.d/ssl.conf
RUN mkdir -p /run/httpd

RUN yum clean all && rm -rf /var/cache/yum

# Install crons to fetch CA Certs
RUN mkdir -p /etc/cron.d/
COPY build_files/etc/cron.d/fetch-crl /etc/cron.d/fetch-crl
COPY build_files/etc/cron.d/fetch-crl-reboot /etc/cron.d/fetch-crl-reboot

# Install rust if ppc64le. Need for TLS, due to old OpenSSL
RUN if [[ $ARCH == "ppc64le" ]]; then cd /tmp/ && curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf &> rust-install.sh && sh rust-install.sh -y && source $HOME/.cargo/env && rm -f rust-install.sh; fi
RUN if [[ $ARCH != "ppc64le" ]]; then mkdir -p $HOME/.cargo && touch $HOME/.cargo/env; fi
