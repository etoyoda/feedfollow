#!/bin/bash

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

$ruby $syndl ${datedir}/obsan-etag.db ${datedir}/obsan-log.db \
  --tar=obsan-${reftime}.tar $ca --tag=obsan \
  --match='TEMP|PILOT|AIREP|AMDAR|PIREP' \
  "${app}&Type=Alphanumeric&Category=Upper+air" \
  --match='SYNOP|SHIP|BUOY|RADOB|WAVEOB' \
  "${app}&Type=Alphanumeric&Category=Surface" \
  --match='' "${app}&Type=Alphanumeric&Subcategory=CLIMAT"

sleep 1

$ruby $syndl ${datedir}/obsbf-etag.db ${datedir}/obsbf-log.db \
  --tar=obsbf-${reftime}.tar $ca --tag=obsbf \
  --match='TEMP|PILOT' \
  "${app}&Type=BUFR&Category=Upper+air" \
  --match='SYNOP|SHIP|BUOY|RADOB|WAVEOB' \
  "${app}&Type=BUFR&Category=Surface" \
  --match='A_IU(PC[45]|[KS]C[67])[0-9]RJTD' \
  "${app}&Type=BUFR&Category=Empty+or+Invalid" 

exit 0
