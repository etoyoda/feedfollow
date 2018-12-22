#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin
TZ=UTC; export TZ

: ${phase:=p0}
: ${prefix:=${HOME}/nwp-test}
: ${base:=${prefix}/${phase}}
# simply using wall-clock time in UTC
: ${reftime:=`date +%Y-%m-%d`}

datedir="${base}/${reftime}.new"
export phase base reftime datedir prefix

test -f "$1"

cd ${base}
# aborts by -e if prefix or base is ill-configured

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
    msg="$(echo "cd $base; prefix=$prefix bash $prefix/bin/act-p0-housekeep.sh" | TZ=UTC at -q Z 0:30 2>&1)"
    logger --tag run-prep --id=$$ -p news.info "$msg"
  fi
  ln -Tfs ${reftime}.new incomplete
fi

cd ${datedir}

bash -$- "$@"

exit 0
