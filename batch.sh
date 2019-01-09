#!/bin/bash
set -Ceuo pipefail
: ${nwp:=${HOME}/nwp-test}
: ${vlimit:=128000}

cmd=$(basename $1 .sh)
case "$cmd" in
run-prep0)
  cmd=$(basename $2 .sh)
  ;;
esac

batch 2>/dev/null <<EOF
: --- THIS PART CANNOT CONTAIN BASH SYNTAX ---
nwp=$nwp
JOBID=$cmd-`date +%Y%m%dT%H%M`_$$
LANG=C
TZ=UTC
export nwp JOBID LANG TZ
PATH=/bin:/usr/bin
cd $nwp/logs
logfile=zb-\${JOBID}.log
ulimit -v $vlimit
exec 3>&2
exec > \$logfile 2>&1
bash -x $*
rc=$?
logger --tag batch.sh --id=$$ -p news.notice -s -- "jobid=\$JOBID rc=\$rc job=<$*>"
exec >&3 2>&3
if [ \$rc = 0 ]; then
  mv -f \$logfile /nwp/p0/incomplete/logs/ || :
else
  echo "=== jobid=\$JOBID rc=\$rc job=<$*> ==="
  tail -40 \$logfile
fi
EOF
