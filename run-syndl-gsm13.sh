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

if (( $rc != 0 )) ; then
  logger --tag syndl.gsm13 --id=$$ -p news.err -s -- "rc=$rc"
fi

exit $rc
