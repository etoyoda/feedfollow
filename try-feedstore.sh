#!/bin/sh
ruby='ruby -w'
: ${part:='regular'}
url="https://www.data.jma.go.jp/developer/xml/feed/${part}.xml"
: ${ca:='/etc/ssl/certs/'}
cd $(dirname $0)

$ruby feedstore.rb zout.rtdb zout $ca -a60 -xVPRN50 $url

