#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin
TZ=UTC; export TZ

# taken from run-prep0.sh
: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${prefix:?} ${yesterday:?}

cd $base
if test -f stop ; then
  logger --tag p0-housekeep --id=$$ -p news.err "suspended - remove ${base}/stop"
  false
fi

for tar in ${yesterday}/*.tar
do
  if test -f $tar
  then
    gzip -9k $tar
  fi
  sleep 10
done

weekago=$(ruby -rdate -e 'puts(Date.parse(ARGV.first) - 7)' ${reftime})

for dir in 2*[0-9]
do
  if [[ $dir < $yesterday ]] ; then
    logger --tag p0-housekeep --id=$$ -p news.notice "rm -f $dir/{*.tar,*.db}"
    rm -f $dir/*.tar $dir/*.db
  fi
  if [[ $dir < $weekago ]] ; then
    logger --tag p0-housekeep --id=$$ -p news.notice "rm -rf $dir"
    rm -rf $dir
  fi
done

exit 0
