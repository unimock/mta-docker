FROM debian:buster

ENV PATH="/container/scripts:${PATH}"
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -q -y update \
 && apt-get -q -y install locales supervisor \
                          telnet rsync wget sendemail vim s.nail curl ed less \
                          net-tools \
                          postfix \
                          rsyslog \
                          clamav clamav-daemon amavisd-new spamassassin razor pyzor sa-compile \
                          clamav-milter amavisd-milter \
                          arj bzip2 cabextract cpio file gzip nomarch pax unzip zip  p7zip \
                          opendkim opendkim-tools \
                          gamin libsasl2-modules \
                          libnet-dns-perl libmail-spf-perl \
                          logwatch pflogsumm  \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/locale/* /usr/share/man/* /usr/share/doc/*
 
# --- set timezone and locals
ARG BUILD_TZ="Europe/Berlin"
RUN echo "$BUILD_TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

#RUN head -n $(grep -n RULES /etc/rsyslog.conf | cut -d':' -f1) /etc/rsyslog.conf > /etc/rsyslog.conf.new \
#&& mv /etc/rsyslog.conf.new /etc/rsyslog.conf \
#&& echo '*.*        /dev/stdout' >> /etc/rsyslog.conf \
#&& sed -i '/imklog.so/d' /etc/rsyslog.conf

RUN touch /var/log/cron.log /var/log/auth.log

RUN adduser clamav amavis

#
# Postfix
#

RUN openssl dhparam -out /etc/postfix/dh1024.pem 1024 \
 && postconf -e 'smtpd_tls_dh1024_param_file=/etc/postfix/dh1024.pem' \
 && openssl dhparam -out /etc/postfix/dh512.pem 512 \
 && postconf -e 'smtpd_tls_dh512_param_file=/etc/postfix/dh512.pem'

#
# ClamAV
#

RUN service clamav-daemon restart \
  ; timeout 3 freshclam \
  ; rm /var/lib/clamav/mirrors.dat \
  ; freshclam

#
# razor & pyzor
#

RUN su - amavis -s /bin/bash -c 'razor-admin -create; razor-admin -register; pyzor discover'

#
# Relay Configuration
#

RUN postconf -e 'mydestination=localhost, localhost.localdomain, localhost' \
 && postconf -e 'smtpd_relay_restrictions=' \
 && postconf -e 'smtpd_recipient_restrictions=permit_mynetworks reject_unauth_destination' \
 \
 && postconf -e 'mydestination=' \
 && postconf -e 'local_recipient_maps=' \
 && postconf -e 'local_transport = error:local mail delivery is disabled'

# --- Configure DKIM (opendkim), DKIM config files
ADD opendkim/opendkim.conf      /etc/opendkim.conf
ADD opendkim/default-opendkim   /etc/default/opendkim
ADD bin/generate-dkim-config    /usr/local/bin

# --- add tomav postfix configuration files
ADD main.cf-tomav     /etc/postfix/
ADD master.cf-tomav   /etc/postfix/

# --- Configuring Logs
#RUN sed -i -r "/^#?compress/c\compress\ncopytruncate" /etc/logrotate.conf

# --- Start-mailserver scripts
ADD bin/generate-dkim-config /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# --- expost the ports
EXPOSE 22 25 587
############################################################################################
#
# docker-extensions
#
RUN mkdir -p  /usr/local/bin
COPY ./bin/*  /usr/local/bin/
RUN chmod a+x /usr/local/bin/*

RUN rm -f /etc/cron.daily/upstart
#
# webproc
#
ARG WEBPROC_VER=0.4.0
RUN mkdir -p /usr/local/sbin && \
    wget -q -O - https://github.com/jpillora/webproc/releases/download/v${WEBPROC_VER}/webproc_${WEBPROC_VER}_linux_amd64.gz | gunzip > /usr/local/sbin/webproc && \
    chmod a+x /usr/local/sbin/webproc
COPY ./webproc.toml /etc/webproc.toml

#
# establisch supervisord
#
ADD /supervisor /etc/supervisor
# link old /etc/init.d/ startup scripts to supervisor
RUN ls -m1    /etc/supervisor/services.d | while read i; do if [ -f /etc/init.d/$i ] ; then mv /etc/init.d/$i /etc/init.d/$i-orig ; fi ;  ln -sf /etc/supervisor/super-init.sh /etc/init.d/$i ; done
RUN ln -sf    /etc/supervisor/systemctl /bin/systemctl
RUN chmod a+x /etc/supervisor/* /etc/supervisor/*.d/*
COPY /supervisor/invoke-rc.d /usr/sbin/invoke-rc.d
COPY /supervisor/reload      /sbin/reload
RUN  chmod a+x /sbin/reload /usr/sbin/invoke-rc.d 
#
# create directory for service volume
#
RUN mkdir -p /service ; chmod a+rwx /service
#ADD track.gitignore /.gitignore

ENV TERM xterm
#
# startup script
#
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh
CMD ["/start.sh"]
