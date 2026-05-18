#!/bin/bash

if [ ! -x /usr/local/bin/gdbm ]; then
  echo install https://github.com/etoyoda/gdbm-frontend
  exit 1
fi

if [ -f .deploy ] ; then
  source ./.deploy
else
  cat > .deploy <<CONFIG
bindir=/nwp/bin
priv=nwp
cgidir=/usr/lib/cgi-bin
CONFIG
  echo please check config file .deploy and rerun.
  exit 1
fi
: ${bindir:?} ${priv:?} ${cgidir:?}

for p in /nwp/p0 /nwp/p1 /nwp/p2
do
  test -d "$p" || sudo -u $priv mkdir -p "$p"
done

target="batch.sh act-p0-housekeep.sh run-*.sh syndl.rb feedstore.rb syslogscan.rb idxshadow.rb notifygah.rb defunct-delete.rb mailjis.sh"

sudo -u $priv install -m 0755 $target $bindir

sudo install -m 0755 syndl.cgi pshbspool.cgi $cgidir/

if [[ -f /usr/local/etc/pshbspool-cfg.rb ]]; then
  echo Existing pshbspool-cfg.rb in /usr/local/etc/ - keep it as it is
else
  sudo install pshbspool-cfg.rb /usr/local/etc/
fi

sudo install -m 0644 crond.txt /etc/cron.d/feedfollow


