# mta-docker

mail-trasfer-agent as a docker container.


contains:
* ubuntu 14.04
* supervisord
* postfix, spamd, ..
* ovw service volume
* webproc for remote configuration
* echo-mailer


## echo-mailer

### config
```
./do login
TOKEN=<token>
echo "echo:           \"|/usr/local/bin/mailecho.sh $TOKEN\"" >> /etc/aliases
newaliases
ovw /etc/aliases
```

