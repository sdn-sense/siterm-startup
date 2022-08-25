FROM almalinux:8
# Architecture argument: amd64 ppc64le
ARG ARCH

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
RUN mkdir -p /var/log/dtnrm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api}/

RUN mkdir -p /var/log/mariadb/
RUN mkdir -p /opt/siterm/config/mysql/
RUN chown mysql:mysql /var/log/mariadb/
RUN chown mysql:mysql /opt/siterm/config/mysql/
RUN chown -R apache:apache /var/log/dtnrm-site-fe
RUN chmod g+s /var/log/dtnrm-site-fe/
RUN mkdir -p /opt/siterm/config && mkdir -p /opt/siterm/dtnrmcode
RUN mkdir -p /etc/httpd/{certs,conf.d}/ && mkdir -p /etc/grid-security/certificates

RUN yum -y install git autoconf sudo libcurl-devel libffi-devel openssl-devel automake curl gcc libuuid-devel lm_sensors make nc pkgconfig wget zlib-devel python38-devel httpd httpd-devel python38-mod_wsgi mod_ssl cronie python38-pip python38 python3-pyOpenSSL mariadb-server  python3-mysql mariadb-devel fetch-crl procps-ng ansible redhat-rpm-config && yum clean all

RUN pip3 install --upgrade setuptools
RUN pip3 install --upgrade pip
RUN pip3 install ansible-pylibssh

RUN rpm -i https://repo.opensciencegrid.org/osg/3.6/el8/release/x86_64/osg-ca-certs-1.94-1.osg36.el8.noarch.rpm

RUN rm -f /etc/httpd/conf.d/ssl.conf

RUN yum clean all && rm -rf /var/cache/yum

RUN if [ $ARCH = "ppc64le" ]; then cd /tmp/ && curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf &> rust-install.sh && sh rust-install.sh -y && source $HOME/.cargo/env && rm -f rust-install.sh; fi
RUN if [ $ARCH != "ppc64le" ]; then mkdir -p $HOME/.cargo && touch $HOME/.cargo/env; fi
