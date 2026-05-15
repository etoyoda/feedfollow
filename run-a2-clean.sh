#!/bin/bash
set -Ceuo pipefail

cd /nwp/p2
a2dir=/nwp/a2

set $(date --date='1 day ago' +'%Y %m %d')
yy=$1
mm=$2
dd=$3
ymd="${yy}-${mm}-${dd}"

a2mondir=${a2dir}/${yy}-${mm}
test -d $a2mondir || mkdir $a2mondir

zip -q -r $a2mondir/text-${ymd}.zip ${ymd}*wxmon ${ymd}*plot


set $(date --date='7 day ago' +'%Y-%m-%d')
ymd=$1
rm -rf ${ymd}*wxmon

set $(date --date='8 day ago' +'%Y-%m-%d')
ymd=$1
rm -rf ${ymd}*plot
