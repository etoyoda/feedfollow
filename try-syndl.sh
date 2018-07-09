#!/bin/sh
ruby='/usr/local/bin/ruby243'
url='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Type=Alphanumeric&Access=Open&Category=Upper+air'
pat='--match=TEMP|PILOT'
ca='--ca=/etc/pki/tls/cert.pem'

cd $(dirname $0)

$ruby -w syndl.rb ysyn.db logsyn.db $pat $ca $url

