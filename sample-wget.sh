#!/bin/sh
PATH=/bin:/usr/bin

: ${ca:='/etc/ssl/certs/'}
: ${outdir:=/tmp}
: ${magic:=20}
: ${feeds:='regular extra eqvol other'}

cd $outdir
if test -d $ca; then
  scheme=https
  caflag="--ca-directory=${ca}"
else
  scheme=http
  caflag=''
fi
server="${scheme}://www.data.jma.go.jp/developer/xml/feed"

sleep ${magic}

for feed in ${feeds}
do
  feedurl="${server}/${feed}.xml"
  wget -qN ${caflag} ${feedurl}
  : > url.txt
  sed -n '/<link type="app/{s/.*href="//; s/".*//; p}' ${feed}.xml | while read url
  do
    base=`basename ${url}`
    if test ! -f $base; then
      echo $url >> url.txt
    fi
  done
  wget -qi url.txt
done
