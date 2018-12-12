#!/bin/bash
set -Ceuo pipefail

: ${testdir:=${HOME}/nwp-test}
: ${rtndir:=/nwp}
: ${part:=p0}

test -d ${testdir}/${part}

: yesterday

day1=2018-12-10
ln -Tfs ${day1} ${testdir}/${part}/latest

: today

day2=2018-12-11
if test -d ${testdir}/${part}/${day2} ; then
  mv -f ${testdir}/${part}/${day2} ${testdir}/${part}/${day2}.new
fi
ln -Tfs ${day2}.new ${testdir}/${part}/incomplete

day3=2018-12-12
rm -rf ${testdir}/${part}/${day3}.new

: report

ls -l ${testdir}/${part}
