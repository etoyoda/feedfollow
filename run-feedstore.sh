#!/bin/sh

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${prefix:?}

: ${ruby:=/usr/bin/ruby}
: ${syndl:=${prefix}/bin/syndl.rb}
: ${feeddir:='http://www.data.jma.go.jp/developer/xml/feed'}
: ${ca:='--ca=/etc/ssl/certs/'}

if tty -s; then
  ruby="${ruby} -w"
fi

set -e

$ruby ${prefix}/bin/feedstore.rb jmx-lmt.db jmx-${reftime} \
  "${feeddir}/regular.xml" "${feeddir}/extra.xml" "${feeddir}/eqvol.xml" "${feeddir}/other.xml"

