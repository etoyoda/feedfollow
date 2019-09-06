#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin:/usr/local/bin
TZ=UTC; export TZ

: ${phase:=p0}
: ${nwp:=${HOME}/nwp-test}
: ${base:=${nwp}/${phase}}
# simply using wall-clock time in UTC
: ${reftime:=`date +%Y-%m-%d`}

datedir="${base}/${reftime}.new"
export phase base reftime datedir nwp

test -f "$1"

cd ${base}
# aborts by -e if nwp or base is ill-configured

if test -f stop ; then
  logger --tag run-prep --id=$$ -p news.err "suspended - remove ${base}/stop"
  false
fi

if mkdmsg=$(mkdir ${datedir} 2>&1)
then
  : --- rotation 1: minimal renaming ---
  incomplete=$(readlink incomplete || echo missing)
  yesterday=$(basename $incomplete .new)
  if [ -d "${incomplete}" ]; then
    mv -f "${incomplete}" "${yesterday}"
    ln -Tfs "${yesterday}" latest
    logger --tag run-prep --id=$$ -p news.info "latest -> ${yesterday}, incomplete -> ${datedir}"
    export yesterday
    msg="$(echo "cd $base; nwp=$nwp bash $nwp/bin/act-p0-housekeep.sh" | TZ=UTC at -q Z 0:30 2>&1)"
    logger --tag run-prep --id=$$ -p news.info "$msg"
  fi
  ln -Tfs ${reftime}.new incomplete
  mkdir incomplete/logs
  touch incomplete/logs-${reftime}.tar
  gdbm incomplete/pshb.db clear
  chmod o+rw incomplete/pshb.db
  ln -Tf incomplete/pshb.db incomplete/psbm-${reftime}.db
  if [ -f latest/jmx-${yesterday}.idx1 ]; then
    ruby ${nwp}/bin/idxshadow.rb latest/jmx-${yesterday}.idx1 incomplete/jmx-${reftime}.idx1
  fi
  if [ -f ${nwp}/bin/act-wxmon-housekeep.sh ]; then
    bash ${nwp}/bin/act-wxmon-housekeep.sh
  fi
fi

cd ${datedir}

bash -$- "$@"
