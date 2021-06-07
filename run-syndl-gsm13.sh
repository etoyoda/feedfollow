#!/bin/sh

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${nwp:?}

: ${wget:=/usr/bin/wget}
: ${app:='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Indicator=RJTD&Type=GRIB&Level=Upper+air+layers'}

if tty -s; then
  :
else
  wget="${wget} -q"
fi

set -e

text -d ${datedir}
cd ${datedir}

$wget -O"z-gsm13-syn.txt" "$app"
if test -s z-gsm13-syn.txt ; then
  $wget -i"z-gsm13-syn.txt"
  tar cf gsm13-${reftime}.tar *grib.bin
fi
rm -f ${datedir}/z-gsm13-syn.txt

exit 3

prio='-p news.err -s'
case $rc in
0|16)
  prio='-p news.info'
  ;;
esac
logger --tag syndl.gsm13 --id=$$ $prio -- "rc=$rc"

exit $rc
