#!/bin/sh
ruby='ruby -w'
url='https://www.data.jma.go.jp/developer/xml/feed/extra.xml'
: ${ca:='/etc/ssl/certs/'}
cd $(dirname $0)

$ruby feedstore.rb y.rtdb zout $ca $url

