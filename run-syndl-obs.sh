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

TZ=UTC

set -e

datedir=${base}/`date +%Y-%m-%d`

mkdir -p ${datedir}
cd ${base}
if [ X`readlink today || :` != X"$datedir" ]; then
  rm -f today
  ln -s ${datedir} today
fi
cd ${datedir}

$ruby $syndl ${datedir}/obsan-etag.db ${datedir}/obsan-log.db \
  --tar=obsan.tar $ca --tag=obsan \
  --match='TEMP|PILOT|AIREP|AMDAR|PIREP' \
  "${app}&Type=Alphanumeric&Category=Upper+air" \
  --match='SYNOP|SHIP|BUOY|RADOB|WAVEOB' \
  "${app}&Type=Alphanumeric&Category=Surface" 

sleep 1

$ruby $syndl ${datedir}/obsbf-etag.db ${datedir}/obsbf-log.db \
  --tar=obsbf.tar $ca --tag=obsbf \
  --match='TEMP|PILOT' \
  "${app}&Type=BUFR&Category=Upper+air" \
  --match='SYNOP|SHIP|BUOY|RADOB|WAVEOB' \
  "${app}&Type=BUFR&Category=Surface" \
  --match='A_IU(PC[45]|[KS]C[67])[0-9]RJTD' \
  "${app}&Type=BUFR&Category=Empty+or+Invalid" 

exit 0
