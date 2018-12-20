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

# exit 3 is HTTP 304 Not Modified, to be ignored
stderr=-s
case $rc in
0|3)
  stderr=''
  ;;
esac
logger --tag feedstore --id=$$ -p news.err $stderr -- "rc=$rc"

if (( $rc == 0 )) ; then
  for prog in ${prefix}/bin/act-jmx-*.sh
  do
    if test -e $prog ; then
      logger --tag feedstore --id=$$ -p news.info -- $(echo bash $prog | batch 2>&1)
    fi
  done
fi

exit $rc
