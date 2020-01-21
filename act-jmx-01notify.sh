#!/bin/sh
set -Ceuo pipefail

export LANG=en_US.UTF-8
PATH=/bin:/usr/bin

: ${datedir:?}
: ${nwp:?}

: ${ruby:=/usr/bin/ruby}
: ${script:=${nwp}/bin/notifygah.rb}

cd ${datedir}
ymd=$(basename ${datedir} .new)

rc=0 && $ruby ${script} jmx-lmt.db || rc=$?
if (( $rc != 0 )) ; then
  logger --tag notifygah --id=$$ -p news.err -s -- "rc=$rc"
  exit $rc
fi

exit 0

