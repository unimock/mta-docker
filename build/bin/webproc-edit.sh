#!/bin/bash
#
_reload()
{
  # /etc/postfix/access-client
  # /etc/postfix/relay_domains
  bash /etc/webproc.dat
  echo "/usr/sbin/postmap /etc/postfix/access-client"
  /usr/local/bin/ovw /etc/webproc.dat
  /usr/local/bin/ovw /etc/postfix/access-client
  /usr/local/bin/ovw /etc/postfix/relay_domains
  /usr/sbin/postmap /etc/postfix/access-client
  /etc/init.d/postfix restart
  cat /etc/postfix/access-client /etc/postfix/relay_domains

}

trap '_reload; exit 0' 2

#trap 'kill -TERM $PID; wait $PID' 2
#/usr/bin/supervisord -c /etc/supervisor/supervisord.conf &
#PID=$!
#wait $PID

while true ; do
 sleep 1
done
exit 0
