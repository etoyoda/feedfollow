#!/bin/sh

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${prefix:?}

: ${ruby:=/usr/bin/ruby}
: ${syndl:=${prefix}/bin/syndl.rb}
: ${app:='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Access=Open'}
: ${ca:='--ca=/etc/ssl/certs/'}

if tty -s; then
  ruby="${ruby} -w"
fi

set -e

rc=0
$ruby $syndl ${datedir}/gsm13-etag.db ${datedir}/gsm13-log.db \
  --tar=gsm13-${reftime}.tar $ca --tag=gsm13 \
  --reject='2.5.2.5' \
  --match='Surface|Mean.sea.level|925hPa|850hPa|700hPa|500hPa|300hPa|250hPa|30hPa' \
  "${app}&Type=GRIB&Indicator=RJTD" || rc=$?

prio='-p news.err -s'
case $rc in
0|16)
  prio='-p news.info'
  ;;
esac
logger --tag syndl.gsm13 --id=$$ $prio -- "rc=$rc"

exit $rc
