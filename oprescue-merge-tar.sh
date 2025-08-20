#!/bin/sh
set -Cxv
: ${dd:=16}
ofn=jmx-2025-08-${dd}.tar
rm -f $ofn ${ofn}.gz
ruby /home/eiei/c/feedfollow/tarmerge.rb ${ofn} /nwp/a0/2025-08/${ofn}.gz jmx-eqvol-202508${dd}.tar jmx-extra-202508${dd}.tar jmx-other-202508${dd}.tar jmx-regular-202508${dd}.tar
gzip ${ofn}
ls -l ${ofn}.gz /nwp/a0/2025-08/${ofn}.gz
