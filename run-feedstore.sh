#!/bin/sh
set -Ceuo pipefail

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${nwp:?}
export phase base reftime datedir nwp

: ${ruby:=/usr/bin/ruby}
: ${feeddir:='https://www.data.jma.go.jp/developer/xml/feed'}
: ${ca:='/etc/ssl/certs/'}
: ${magic:=20}

cd ${datedir}

sleep ${magic}

rc=0 && \
$ruby ${nwp}/bin/feedstore.rb jmx-lmt.db jmx-${reftime} ${ca} \
  "${feeddir}/regular.xml" "${feeddir}/extra.xml" \
  "${feeddir}/eqvol.xml" "${feeddir}/other.xml" \
  || rc=$?

# exit 3 is HTTP 304 Not Modified, to be ignored
stderr=-s
case $rc in
0|3)
  stderr=''
  ;;
esac
logger --tag feedstore --id=$$ -p news.err $stderr -- "rc=$rc"

if (( $rc == 0 )) ; then
  for prog in ${nwp}/bin/act-jmx-*.sh
  do
    if test -e $prog ; then
      msg=$(echo nwp=$nwp bash $prog | batch 2>&1)
      logger --tag feedstore --id=$$ -p news.info -- "$msg"
    fi
  done
fi

case $rc in
3)
  rc=3
  ;;
esac
exit $rc
