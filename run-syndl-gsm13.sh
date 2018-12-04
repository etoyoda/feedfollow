#!/bin/sh

PATH=/bin:/usr/bin

: ${ruby:='/usr/bin/ruby'}
: ${syndl:=${HOME}/bin/syndl.rb}
: ${app:='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Access=Open'}
: ${ca:='--ca=/etc/ssl/certs/'}
: ${base:='/nwp/p0'}

if tty -s; then
  ruby="${ruby} -w"
fi

TZ=UTC; export TZ

set -e

today=`date +%Y-%m-%d`
datedir=${base}/${today}.new

mkdir -p ${datedir}
cd ${base}
current="`readlink current || :`"
if [ X"${current}" != X"${datedir}" ]; then
  if [ -d "${current}" ]; then
    yesterday="`basename $current .new`"
    mv -f "${current}" "${yesterday}"
    ln -fs "${yesterday}" latest
  fi
  ln -fs ${datedir} current
fi
cd ${datedir}

$ruby $syndl ${base}/gsm13-etag.db ${base}/gsm13-log.db \
  --tar=gsm13-${today}.tar $ca --tag=gsm13 \
  --reject='2.5.2.5' \
  --match='Surface|Mean.sea.level|925hPa|850hPa|700hPa|500hPa|300hPa|250hPa|30hPa' \
  "${app}&Type=GRIB&Indicator=RJTD"

exit 0
