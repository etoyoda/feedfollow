#!/bin/bash

PATH=/bin:/usr/bin
TZ=UTC; export TZ

set -e

: ${phase:=p0}
: ${prefix:=/nwp}
: ${base:=${prefix}/${phase}}
# simply using wall-clock time in UTC
: ${reftime:=`date +%Y-%m-%d`}
: ${datedir:="${base}/${reftime}.new"}

test -f "$1"

export phase base reftime datedir prefix

mkdir -p ${datedir}
cd ${base}
# aborts by -e if prefix or base is ill-configured

incomplete="`readlink incomplete || :`"
if [ X"${incomplete}" != X"${datedir}" ]; then
  if [ -d "${incomplete}" ]; then
    yesterday="`basename $incomplete .new`"
    mv -f "${incomplete}" "${yesterday}"
    rm -f latest && ln -s "${yesterday}" latest
    logger --id=$$ -p news.info "latest -> ${yesterday}, incomplete -> ${datedir}"
  fi
  rm -f incomplete && ln -s ${datedir} incomplete
fi
cd ${datedir}

bash -$- "$@"

exit 0
