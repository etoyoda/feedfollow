#!/bin/sh
set -xv
feed=extra
for dd in 17 18
do
rm -rf f* z*
ruby -w /home/eiei/c/feedfollow/feedstore.rb zrtdb zout /etc/ssl/certs/ -d2025-08-${dd} https://www.data.jma.go.jp/developer/xml/feed/${feed}_l.xml
mv zout.tar jmx-${feed}-202508${dd}.tar
done
exit 0
