FROM almalinux:9
ARG ARCH="x86_64"

RUN yum -y install wget epel-release && yum clean all

# Maria DB Configuration
COPY build_files/mariadb.repo-$ARCH /etc/yum.repos.d/mariadb.repo
COPY build_files/mariadb.sql /root/mariadb.sql
COPY build_files/server.cnf /etc/my.cnf.d/server.cnf
# Import GPG Keys for MariaDB and EPEL
WORKDIR /etc/pki/rpm-gpg/
RUN wget --progress=dot:giga https://yum.mariadb.org/RPM-GPG-KEY-MariaDB && rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-MariaDB

RUN adduser apache -U -u 48 && adduser mysql -U -u 4000

# Precreate all directories
RUN mkdir -p /var/log/siterm-site-fe/LookUpService/ && \
    mkdir -p /var/log/siterm-site-fe/ProvisioningService && \
    mkdir -p /var/log/siterm-site-fe/PolicyService && \
    mkdir -p /var/log/siterm-site-fe/SwitchBackends && \
    mkdir -p /var/log/siterm-site-fe/Debugger && \
    mkdir -p /var/log/siterm-site-fe/DBWorker && \
    mkdir -p /var/log/siterm-site-fe/Config-Fetcher && \
    mkdir -p /var/log/siterm-site-fe/Validator && \
    mkdir -p /var/log/siterm-site-fe/contentdb && \
    mkdir -p /var/log/siterm-site-fe/http-api && \
    mkdir -p /var/log/siterm-site-fe/SNMPMonitoring && \
    mkdir -p /var/log/siterm-site-fe/DBCleaner && \
    mkdir -p /var/log/mariadb/ && mkdir -p /opt/siterm/config/mysql/ && \
    mkdir -p /var/log/supervisor && mkdir -p /etc/supervisord.d/ && \
    mkdir -p /usr/local/sbin/ && mkdir -p /run/httpd && mkdir -p /etc/cron.d/ && \
    mkdir -p /var/www/wsgi-scripts/ && mkdir -p /etc/cron-scripts/ && mkdir -p /var/www/html/ && \
    mkdir -p "$HOME"/.cargo && touch "$HOME"/.cargo/env

RUN touch /var/log/siterm-site-fe/LookUpService/api.log && \
    touch /var/log/siterm-site-fe/ProvisioningService/api.log && \
    touch /var/log/siterm-site-fe/PolicyService/api.log && \
    touch /var/log/siterm-site-fe/SwitchBackends/api.log && \
    touch /var/log/siterm-site-fe/Debugger/api.log && \
    touch /var/log/siterm-site-fe/DBWorker/api.log && \
    touch /var/log/siterm-site-fe/Config-Fetcher/api.log && \
    touch /var/log/siterm-site-fe/Validator/api.log && \
    touch /var/log/siterm-site-fe/DBCleaner/api.log && \
    touch /var/log/siterm-site-fe/contentdb/api.log && \
    touch /var/log/siterm-site-fe/http-api/api.log && \
    touch /var/log/siterm-site-fe/SNMPMonitoring/api.log

RUN mkdir -p /opt/siterm/config && \
    mkdir -p /opt/siterm/sitermcode && \
    mkdir -p /etc/httpd/certs && mkdir -p /etc/httpd/conf.d/ && \
    mkdir -p /etc/grid-security/certificates && \
    mkdir -p /root/.ssh/

RUN chown mysql:mysql /var/log/mariadb/ && \
    chown mysql:mysql /opt/siterm/config/mysql/ && \
    chown -R apache:apache /var/log/siterm-site-fe && \
    chmod g+ws /var/log/siterm-site-fe/ && \
    chmod -R g+ws /var/log/siterm-site-fe/*

# Install all required packages
RUN yum -y install git autoconf sudo mod_auth_openidc gettext libcurl-devel libffi-devel openssl-devel automake curl gcc libuuid-devel lm_sensors make nc pkgconfig zlib-devel python39-devel httpd httpd-devel python39-mod_wsgi mod_ssl cronie python39-pip python39 python3-pyOpenSSL mariadb-server python3-mysql mariadb-devel procps-ng redhat-rpm-config net-snmp-devel sshpass fetch-crl && yum clean all

# Remove ssl.conf file (siterm write's own httpd conf file)
RUN rm -f /etc/httpd/conf.d/ssl.conf

# Install all pip packages
RUN pip3 install --no-cache-dir --upgrade setuptools pip && \
    pip3 install --no-cache-dir supervisor superlance

COPY build_files/etc/supervisord.conf /etc/

# Install CA Certs
RUN rpm -i https://repo.opensciencegrid.org/osg/24-main/el9/release/x86_64/Packages/o/osg-ca-certs-1.135-1.osg24.el9.noarch.rpm
# Install InCommon Server CA 2
RUN wget -q -O /etc/grid-security/certificates/InCommon_RSA_Server_CA_2.pem "https://spaces.at.internet2.edu/download/attachments/24576265/InCommon%20RSA%20Server%20CA%202.pem?api=v2" && \
    ln -s /etc/grid-security/certificates/InCommon_RSA_Server_CA_2.pem /etc/grid-security/certificates/$(openssl x509 -in /etc/grid-security/certificates/InCommon_RSA_Server_CA_2.pem -noout -hash).0
# Install crons to fetch CA Certs
COPY build_files/etc/cron.d/fetch-crl /etc/cron.d/fetch-crl
COPY build_files/etc/cron.d/fetch-crl-reboot /etc/cron.d/fetch-crl-reboot

WORKDIR /tmp
