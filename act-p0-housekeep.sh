#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin
TZ=UTC; export TZ

# taken from run-prep0.sh
: ${base:?} ${reftime:?} ${yesterday:?}
logger --tag p0-housekeep --id=$$ -p news.info "base=${base} reftime=${reftime} yesterday=${yesterday}"

abase=$(dirname $base)/a0

cd $base
if test -f stop ; then
  logger --tag p0-housekeep --id=$$ -p news.err "suspended - remove ${base}/stop"
  false
fi

if [[ -d ${yesterday}/logs ]]; then
  rm -f ${yesterday}/syslogscan.ltsv
  ruby /nwp/bin/syslogscan.rb /var/log/syslog.1 > ${yesterday}/logs/syslogscan.ltsv
  bash /nwp/bin/mailjis.sh ${yesterday}/logs/syslogscan.ltsv news \
    -s syslogscan-${yesterday}.ltsv news
  if ( cd ${yesterday} &&
    tar rf logs-${yesterday}.tar *.ltsv &&
    cd logs &&
    tar rf logs-${yesterday}.tar * && 
    cd .. &&
    rm -rf logs) 
  then
    logger --tag p0-housekeep --id=$$ -p news.notice -- "tarred ${yesterday}/logs"
  else
    logger --tag p0-housekeep --id=$$ -p news.err -- "retains $yesterday/logs"
  fi
fi

weekago=$(ruby -rdate -e 'puts(Date.parse(ARGV.first) - 9)' ${reftime})

for dir in 2???-??-?[0-9]
do
  if [[ $dir < $weekago ]] ; then
    logger --tag p0-housekeep --id=$$ -p news.notice -- "rm -rf $dir"
    rm -rf $dir
  else
    month=$(ruby -rdate -e 'puts(Date.parse(ARGV.first).strftime("%Y-%m"))' ${dir})
    mkdir -p ${abase}/${month}
    for tar in $dir/*.tar ; do
      if [[ ! -f ${tar} ]]; then
        continue
      fi
      tgz=${abase}/${month}/$(basename ${tar}).gz
      if [[ ! -f ${tar}.gz ]]; then
        logger --tag p0-housekeep --id=$$ -p news.notice "gzip -9k ${tar}"
        gzip -9k ${tar} || continue
      fi
      if [[ ! -f ${tgz} ]]; then
        logger --tag p0-housekeep --id=$$ -p news.notice "ln ${tar}.gz ${tgz}"
        ln -Tf ${tar}.gz ${tgz} || continue
      fi
      if [[ $dir < $yesterday ]] ; then
        logger --tag p0-housekeep --id=$$ -p news.notice "rm -f ${tar}"
        rm -f ${tar} || continue
      fi
    done
    for idx in $dir/*.idx1 ; do
      if [[ ! -f $idx ]]; then
        continue
      fi
      aidx=${abase}/${month}/$(basename ${idx})
      if [[ ! -f $aidx ]]; then
        logger --tag p0-housekeep --id=$$ -p news.notice "ln ${idx} ${aidx}"
        ln -Tf $idx $aidx || continue
      fi
    done
  fi
done

exit 0
