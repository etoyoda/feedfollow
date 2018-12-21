#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin
TZ=UTC; export TZ

# taken from run-prep0.sh
: ${base:?} ${reftime:?} ${yesterday:?}

cd $base
if test -f stop ; then
  logger --tag p0-housekeep --id=$$ -p news.err "suspended - remove ${base}/stop"
  false
fi

rm -f ${yesterday}/syslogscan.ltsv
ruby /nwp/bin/syslogscan.rb /var/log/syslog > ${yesterday}/syslogscan.ltsv
cat ${yesterday}/syslogscan.ltsv

for tar in ${yesterday}/*.tar
do
  if test -f $tar -a ! -f $tar.gz
  then
    gzip -9k $tar
  fi
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
