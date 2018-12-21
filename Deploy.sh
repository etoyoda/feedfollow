#!/bin/bash

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

target="act-*.sh run-*.sh syndl.rb feedstore.rb syslogscan.rb"

sudo -u $priv install -m 0755 $target $bindir

sudo install -m 0755 syndl.cgi $cgidir/
