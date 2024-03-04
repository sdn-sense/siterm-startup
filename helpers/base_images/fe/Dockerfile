FROM almalinux:8
# Architecture argument: amd64 ppc64le
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
    mkdir -p mkdir -p /var/log/siterm-site-fe/contentdb && \
    mkdir -p /var/log/siterm-site-fe/http-api && \
    mkdir -p /var/log/siterm-site-fe/SNMPMonitoring && \
    mkdir -p /var/log/mariadb/ && mkdir -p /opt/siterm/config/mysql/ && \
    mkdir -p /var/log/supervisor && mkdir -p /etc/supervisord.d/ && \
    mkdir -p /usr/local/sbin/ && mkdir -p /run/httpd && mkdir -p /etc/cron.d/

RUN touch /var/log/siterm-site-fe/LookUpService/api.log && \
    touch /var/log/siterm-site-fe/ProvisioningService/api.log && \
    touch /var/log/siterm-site-fe/PolicyService/api.log && \
    touch /var/log/siterm-site-fe/SwitchBackends/api.log && \
    touch /var/log/siterm-site-fe/Debugger/api.log && \
    touch /var/log/siterm-site-fe/contentdb/api.log && \
    touch /var/log/siterm-site-fe/http-api/api.log && \
    touch /var/log/siterm-site-fe/SNMPMonitoring/api.log

RUN chown mysql:mysql /var/log/mariadb/ && \
    chown mysql:mysql /opt/siterm/config/mysql/ && \
    chown -R apache:apache /var/log/siterm-site-fe && \
    chmod g+ws /var/log/siterm-site-fe/ && \
    chmod -R g+ws /var/log/siterm-site-fe/*

RUN mkdir -p /opt/siterm/config && \
    mkdir -p /opt/siterm/sitermcode && \
    mkdir -p /etc/httpd/certs && mkdir -p /etc/httpd/conf.d/ && \
    mkdir -p /etc/grid-security/certificates && \
    mkdir -p /root/.ssh/

# Install all required packages
RUN yum -y install git autoconf sudo libcurl-devel libffi-devel openssl-devel automake curl gcc libuuid-devel lm_sensors make nc pkgconfig wget zlib-devel python39-devel httpd httpd-devel python39-mod_wsgi mod_ssl cronie python39-pip python39 python3-pyOpenSSL mariadb-server python3-mysql mariadb-devel fetch-crl procps-ng redhat-rpm-config net-snmp-devel sshpass && yum clean all

# Remove ssl.conf file (siterm write's own httpd conf file)
RUN rm -f /etc/httpd/conf.d/ssl.conf

# Install all pip packages
RUN pip3 install --no-cache-dir --upgrade setuptools pip && \
    pip3 install --no-cache-dir supervisor superlance


COPY build_files/etc/supervisord.conf /etc/

#RUN rpm -i https://repo.opensciencegrid.org/osg/23-main/el8/release/x86_64/osg-ca-certs-1.117-1.osg23.el8.noarch.rpm
RUN rpm -i https://mirror.grid.uchicago.edu/pub/osg/23-main/el8/release/x86_64/osg-ca-certs-1.118-1.osg23.el8.noarch.rpm

# Install crons to fetch CA Certs
COPY build_files/etc/cron.d/fetch-crl /etc/cron.d/fetch-crl
COPY build_files/etc/cron.d/fetch-crl-reboot /etc/cron.d/fetch-crl-reboot

# Install rust if ppc64le. Need for TLS, due to old OpenSSL
WORKDIR /tmp
RUN if [ "$ARCH" == "ppc64le" ]; then wget --output-document - --quiet https://sh.rustup.rs &> rust-install.sh && sh rust-install.sh -y && source "$HOME"/.cargo/env && rm -f rust-install.sh; fi
RUN if [ "$ARCH" != "ppc64le" ]; then mkdir -p "$HOME"/.cargo && touch "$HOME"/.cargo/env; fi
