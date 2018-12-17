#!/bin/sh

PATH=/bin:/usr/bin

: ${phase:?} ${base:?} ${reftime:?} ${datedir:?} ${prefix:?}

: ${ruby:=/usr/bin/ruby}
: ${syndl:=${prefix}/bin/syndl.rb}
: ${feeddir:='https://www.data.jma.go.jp/developer/xml/feed'}
: ${ca:='/etc/ssl/certs/'}

if tty -s; then
  ruby="${ruby} -w"
fi

set -e

rc=0 && $ruby ${prefix}/bin/feedstore.rb jmx-lmt.db jmx-${reftime} ${ca} \
  "${feeddir}/regular.xml" "${feeddir}/extra.xml" \
  "${feeddir}/eqvol.xml" "${feeddir}/other.xml" \
  || rc=$?

if (( $rc >= 128 )) ; then
  logger --tag feedstore --id=$$ -p news.err -s -- "killed rc=$rc"
fi
exit $rc
