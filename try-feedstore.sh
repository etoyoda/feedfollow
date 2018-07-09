#!/bin/sh
ruby='/usr/local/bin/ruby243 -w'
url='http://www.data.jma.go.jp/developer/xml/feed/extra.xml'
cd $(dirname $0)

$ruby feedstore.rb y.rtdb zout $url

