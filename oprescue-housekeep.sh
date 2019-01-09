#!/bin/bash
set -Ceuo pipefail
set -x

LANG=C
TZ=UTC
PATH=/bin:/usr/bin

reftime=$(date '+%Y-%m-%d')
yesterday=$(ruby -rtime -e 'puts((Time.parse(ARGV.first) - 86400).strftime("%Y-%m-%d"))' \
  $reftime)
base=/nwp/p0

echo base=$base reftime=$reftime yesterday=$yesterday bash act-p0-housekeep.sh | sudo -u nwp batch
