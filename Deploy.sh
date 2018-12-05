#!/bin/bash

if [ -f .deploy ] ; then
  source ./.deploy
else
  cat > .deploy <<CONFIG
bindir=/nwp/bin
priv=nwp
CONFIG
  echo please check config file .deploy and rerun.
  exit 1
fi
: ${bindir:?} ${priv:?}

target="run-*.sh syndl.rb feedstore.rb"

sudo -u $priv install -m 0755 $target $bindir
