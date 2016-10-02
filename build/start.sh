#!/bin/bash
echo "#################################################"
echo "# starting container boot up script (start.sh)  #"
echo "#################################################"

list=$(ls -1 /etc/supervisor/boot.d/*)
for i in $list ; do
  echo "execute : <$i>"
  $i
done

echo "#################################################"
echo "# check for disabled services"
echo "#"

for task in $DISABLED_SERVICES ; do
  echo "disable : $task"
  sed  -i "/program:$task/a autostart=false"  /etc/supervisor/services.d/$task
done

echo "#################################################"
echo "# execute init scripts for enabled services"
echo "#"

list=$(ls -1 /etc/supervisor/init.d/*)
for i in $list ; do
  if [ -e $i ] ; then
    task=`basename $i`
     if [ "$(grep 'autostart=false' /etc/supervisor/services.d/${task})" = "" ] ; then
       echo "execute: <$task>"
       $i
     fi
  fi
done

##############################################################################################################################
# Consolidate all state that should be persisted across container restarts into one mounted
# directory
voldir=/volume/data
mkdir -p $voldir ; chmod a+rwx $voldir
if [ -d $voldir ]; then
  echo "Consolidating all state onto $voldir"
  for d in /var/spool/postfix /var/lib/postfix /var/lib/amavis /var/lib/clamav /var/lib/spamassassin; do
    dest=$voldir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
    #dest=$voldir/${d#/}
    if [ -d $dest ]; then
      echo "  Destination $dest exists, linking $d to it"
      rm -rf $d
      ln -s $dest $d
    elif [ -d $d ]; then
      echo "  Moving contents of $d to $dest" 
      mv $d $dest
      ln -s $dest $d
    else
      echo "  Linking $d to $dest"
      mkdir -p $dest
      ln -s $dest $d
    fi
  done
fi
#if ! [ "$DISABLE_OPENDKIM" = 1 ]; then
#  # DKIM
#  # Check if keys are already available
#  if [ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]; then
#    mkdir -p /etc/opendkim
#    cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
#    echo "DKIM keys added for: `ls -C /etc/opendkim/keys/`"
#    echo "Changing permissions on /etc/opendkim"
#    # chown entire directory
#    chown -R opendkim:opendkim /etc/opendkim/
#    # And make sure permissions are right
#    chmod -R 0700 /etc/opendkim/keys/
#  else
#    echo "No DKIM key provided. Check the documentation to find how to get your keys."
#  fi
#fi
#if ! [ "$DISABLE_OPENDMARC" = 1 ]; then
#  # DMARC
#  # if there is no AuthservID create it
#  if [ `cat /etc/opendmarc.conf | grep -w AuthservID | wc -l` -eq 0 ]; then
#    echo "AuthservID $(hostname)" >> /etc/opendmarc.conf
#  fi
#  if [ `cat /etc/opendmarc.conf | grep -w TrustedAuthservIDs | wc -l` -eq 0 ]; then
#    echo "TrustedAuthservIDs $(hostname)" >> /etc/opendmarc.conf
#  fi
#  if [ ! -f "/etc/opendmarc/ignore.hosts" ]; then
#    mkdir -p /etc/opendmarc/
#    echo "localhost" >> /etc/opendmarc/ignore.hosts
#  fi
#fi
# amavisd-milter
sed -i -e 's/#MILTERSOCKET=inet:60001@127.0.0.1/MILTERSOCKET=inet:10101@127.0.0.1/g' /etc/default/amavisd-milter
# macromilter
sed -i -e 's/inet:3690@127.0.0.1/inet:10103@127.0.0.1/g' /etc/macromilter/macromilter.py
echo "Postfix configurations"
# Fix permissions, but skip this if 3 levels deep the user id is already set
if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
  echo "Fixing /var/mail permissions"
  chown -R 5000:5000 /var/mail
else
  echo "Permissions in /var/mail look OK"
fi
echo "Creating /etc/mailname"
echo $(hostname -d) > /etc/mailname
echo "Configuring Spamassassin"
FI=/etc/amavis/conf.d/20-debian_defaults
SA_TAG=${SA_TAG:="2.0"}    && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g'    $FI
SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' $FI
SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' $FI
echo "Starting daemons"
#cron
#rm -f /var/run/rsyslogd.pid
#/etc/init.d/rsyslog start
# prepare service startup
chmod go-rwx /etc/certs/*
list=`cd /etc/postfix && ls *.db`
for i in $list ; do
   echo " running postmap for </etc/postfix/${i%.db}>"
   postmap /etc/postfix/${i%.db}
done
#if ! [ "$DISABLE_OPENDKIM" = 1 ]; then
#  /etc/init.d/opendkim start
#fi
#if ! [ "$DISABLE_OPENMARC" = 1 ]; then
#  /etc/init.d/opendmarc start
#fi
#/etc/init.d/amavisd-milter start
#/etc/init.d/macromilter start
#/etc/init.d/postfix start

##############################################################################################################################

echo "#################################################"
echo "# start supervisord"
echo "#"

trap 'kill -TERM $PID; wait $PID' TERM
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &
PID=$!
wait $PID

echo "#################################################"
echo "# shutdown container"
echo "#"
list=$(ls -1 /etc/supervisor/shutdown.d/*)
for i in $list ; do
  echo "execute: <$i>"
  $i
done

