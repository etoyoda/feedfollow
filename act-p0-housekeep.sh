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
ruby /nwp/bin/syslogscan.rb /var/log/syslog.1 > ${yesterday}/syslogscan.ltsv

bash /nwp/bin/mailjis.sh ${yesterday}/syslogscan.ltsv news -s syslogscan-${yesterday}.ltsv news

(cd ${yesterday}; tar cf logs-${yesterday}.tar *.ltsv)

weekago=$(ruby -rdate -e 'puts(Date.parse(ARGV.first) - 7)' ${reftime})

for dir in 2*[0-9]
do
  if [[ $dir < $weekago ]] ; then
    logger --tag p0-housekeep --id=$$ -p news.notice "rm -rf $dir"
    rm -rf $dir
  else
    for tar in $dir/*.tar ; do
      if [[ ! -f ${tar}.gz ]] ; then
        logger --tag p0-housekeep --id=$$ -p news.notice "gzip -9k ${tar}"
        gzip -9k ${tar}
      fi
    done
    if [[ $dir < $yesterday ]] ; then
      for tar in $dir/*.tar ; do
        if [[ -f ${tar}.gz ]] ; then
          logger --tag p0-housekeep --id=$$ -p news.notice "rm -f ${tar}"
          rm -f ${tar}
        fi
      done
    fi
  fi
done

exit 0
