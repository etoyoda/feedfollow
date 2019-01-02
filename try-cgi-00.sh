#!/bin/bash
set -Ceuo pipefail

PATH=/bin:/usr/bin:/usr/local/bin

nwp=/nwp
idx1=${nwp}/p0/incomplete/jmx-2*.idx1
datedir=$(readlink ${nwp}/p0/incomplete)
datedir=2019-01-02

set $(gdbm ${idx1} select ^u | head -1)
uuid=$1
offset=$2

: ${uuid:?} ${offset:?}

test ! -f z.out || rm z.out

#cgi=/usr/lib/cgi-bin/syndl.cgi
cgi=./syndl.cgi

PATH_INFO=/entry/${datedir}/jmx/${uuid} REQUEST_METHOD=GET ruby -d $cgi > z.out
ls -l z.out
