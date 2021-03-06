#!/bin/sh

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${nwp:?}

: ${ruby:=/usr/bin/ruby}
: ${syndl:=${nwp}/bin/syndl.rb}
: ${app:='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Access=Open'}
: ${ca:='--ca=/etc/ssl/certs/'}

if tty -s; then
  ruby="${ruby} -w"
fi

set -e

rc=0
$ruby $syndl ${datedir}/gsm13-etag.db ${datedir}/gsm13-log.db \
  --tar=gsm13-${reftime}.tar $ca --tag=gsm13 \
  --match='Upper.air.layers' \
  "${app}&Type=GRIB&Indicator=RJTD" || rc=$?

prio='-p news.err -s'
case $rc in
0|16)
  prio='-p news.info'
  ;;
esac
logger --tag syndl.gsm13 --id=$$ $prio -- "rc=$rc"

exit $rc
