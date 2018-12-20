#!/bin/bash

PATH=/bin:/usr/bin
TZ=UTC; export TZ

set -e

: ${phase:=p0}
: ${prefix:=${HOME}/nwp-test}
: ${base:=${prefix}/${phase}}
# simply using wall-clock time in UTC
: ${reftime:=`date +%Y-%m-%d`}

cd ${base}
# aborts by -e if prefix or base is ill-configured

if test -f stop ; then
  logger --tag run-rmdir --id=$$ -p news.err "suspended - remove ${base}/stop"
  false
fi

weekago=$(ruby -rdate -e 'puts(Date.parse(ARGV.first) - 7)' ${reftime})

for dir in 2*
do
  if [[ $dir < $weekago ]] ; then
    logger --tag run-rmdir --id=$$ -p news.notice "rm -rf $dir"
    rm -rf $dir
  fi
done

exit 0
