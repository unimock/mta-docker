#
#                    ##        .            
#              ## ## ##       ==            
#           ## ## ## ##      ===            
#       /""""""""""""""""\___/ ===        
#  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~   
#       \______ o          __/            
#         \    \        __/             
#          \____\______/                
# 
#          |          |
#       __ |  __   __ | _  __   _
#      /  \| /  \ /   |/  / _\ | 
#      \__/| \__/ \__ |\_ \__  |
#
FROM ubuntu:14.04

MAINTAINER Uni Mock <unimock@gate-m.de>

# Let the container know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# --- set timezone
ARG BUILD_TZ="Europe/Berlin"
RUN echo "$BUILD_TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# --- prepare apt
RUN apt-get update -q --fix-missing && apt-get -y upgrade

# --- docker only stuff
RUN apt-get -y install --no-install-recommends \
      supervisor locales

# Ensure that we always use UTF-8 and with US English locale
RUN locale-gen en_US.UTF-8

# configure locales
RUN locale-gen en_US.UTF-8  
ENV LANG en_US.UTF-8  
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# --- Install the SSH server
RUN apt-get -y install --no-install-recommends \
      openssh-server rsync git sendemail vim multitail nano heirloom-mailx

# --- base packages
RUN apt-get -y install --no-install-recommends \
      postfix gamin amavisd-new spamassassin spamc razor pyzor libsasl2-modules \
      clamav clamav-daemon libnet-dns-perl libmail-spf-perl bzip2 file gzip p7zip unzip arj rsyslog \
      cabextract cpio nomarch pax zip clamav-milter \
      opendkim opendkim-tools opendmarc curl ed iptables \
      amavisd-milter logwatch pflogsumm wget rsync telnet sa-compile
      
RUN touch /var/log/cron.log /var/log/auth.log

# --- prepare building macromilter from stefan
RUN apt-get update && apt-get install -y python2.7 python2.7-dev libmilter-dev libmilter1.0.1 python-pip

# --- Geo-Plugin (spamassassin)
RUN apt-get -y install libgeo-ip-perl && \
    cd /usr/share/GeoIP && rm GeoIP.dat GeoIPv6.dat && \
    wget -q -O - http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz | gunzip > GeoIP.dat   && \
    wget -q -O - http://geolite.maxmind.com/download/geoip/database/GeoIPv6.dat.gz              | gunzip > GeoIPv6.dat && \
    echo "loadplugin Mail::SpamAssassin::Plugin::RelayCountry"  >> /etc/spamassassin/init.pre

# --- cleanup
RUN apt-get autoclean && rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/share/locale/* && rm -rf /usr/share/man/* && rm -rf /usr/share/doc/*


# --- build and install macromilter from stefan
# install oletools
RUN pip install oletools
# install pymilter --> maybe you need some addtional dependencies - see doc
RUN pip install pymilter
RUN mkdir -p /etc/macromilter /var/log/macromilter/ /var/log/macromilter/log
RUN wget -O /tmp/macromilter.zip  https://github.com/sbidy/MacroMilter/archive/master.zip && \
    cd /tmp && \
    unzip macromilter.zip && \
    cp -v ./MacroMilter-master/macromilter/macromilter.py /etc/macromilter/
RUN touch /etc/macromilter/whitelist.list
RUN chown postfix:postfix -Rf /etc/macromilter
RUN chown postfix:postfix -Rf /var/log/macromilter


# --- Enable Spamassassin and CRON updates
#RUN sed -i -r 's/^(CRON|ENABLED)=0/\1=1/g' /etc/default/spamassassin

# --- Enables Amavis
#RUN sed -i -r 's/#(@|   \\%)bypass/\1bypass/g' /etc/amavis/conf.d/15-content_filter_mode
RUN adduser clamav amavis && adduser amavis clamav
RUN useradd -u 5000 -d /home/docker -s /bin/bash -p $(echo docker | openssl passwd -1 -stdin) docker

# --- Enable Clamav
#RUN (crontab; echo "0 0,6,12,18 * * * /usr/bin/freshclam --quiet") | sort - | uniq - | crontab -
RUN chmod 644 /etc/clamav/freshclam.conf && freshclam

# --- Enables Pyzor and Razor
USER amavis
RUN razor-admin -create && razor-admin -register && pyzor discover
USER root

# --- Configure DKIM (opendkim), DKIM config files
ADD opendkim/opendkim.conf      /etc/opendkim.conf
ADD opendkim/default-opendkim   /etc/default/opendkim
ADD bin/generate-dkim-config    /usr/local/bin

# --- Configure DMARC (opendmarc)
ADD opendmarc/opendmarc.conf    /etc/opendmarc.conf
ADD opendmarc/default-opendmarc /etc/default/opendmarc

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
RUN mkdir -p /usr/local/bin
COPY ./bin/*             /usr/local/bin/
RUN chmod a+x /usr/local/bin/*

RUN rm -f /etc/cron.daily/upstart
#
# webproc
#
ARG WEBPROC_VER=0.1.8
RUN mkdir -p /usr/local/sbin && \
    wget -q -O - https://github.com/jpillora/webproc/releases/download/${WEBPROC_VER}/webproc_linux_amd64.gz | gunzip > /usr/local/sbin/webproc && \
    chmod a+x /usr/local/sbin/webproc
COPY ./webproc.toml /etc/webproc.toml

#
# establisch supervisord
#
ADD /supervisor /etc/supervisor
# link old /etc/init.d/ startup scripts to supervisor
RUN ls -m1    /etc/supervisor/services.d | while read i; do mv /etc/init.d/$i /etc/init.d/$i-orig ;  ln -sf /etc/supervisor/super-init.sh /etc/init.d/$i ; done
RUN ln -sf    /etc/supervisor/systemctl /bin/systemctl
RUN chmod a+x /etc/supervisor/* /etc/supervisor/*.d/*
COPY /supervisor/invoke-rc.d /usr/sbin/invoke-rc.d
COPY /supervisor/reload      /sbin/reload
RUN  chmod a+x /sbin/reload /usr/sbin/invoke-rc.d 
#
# create directory for service volume
#
RUN mkdir -p /service ; chmod a+rwx /service
ADD track.gitignore /.gitignore

ENV TERM xterm
#
# startup script
#
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh
CMD ["/start.sh"]
