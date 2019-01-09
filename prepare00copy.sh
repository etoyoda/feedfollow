#!/bin/bash
set -Ceuo pipefail

: prepare00copy.sh - prepare the ~/nwp-test directory to be copy of current state 

: ${testdir:=${HOME}/nwp-test}
: ${rtndir:=/nwp}
: ${part:=p0}

mkdir -p ${testdir}/${part}

: yesterday

day1=$(readlink ${rtndir}/${part}/latest)
rsync -auv ${rtndir}/${part}/${day1}/ ${testdir}/${part}/${day1}/
ln -Tfs ${day1} ${testdir}/${part}/latest

: today

day2=$(readlink ${rtndir}/${part}/incomplete)
rsync -auv ${rtndir}/${part}/${day2}/ ${testdir}/${part}/${day2}/
ln -Tfs ${day2} ${testdir}/${part}/incomplete

: report

ls -l ${testdir}/${part}
