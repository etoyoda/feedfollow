#!/bin/sh
ruby='ruby'
url='https://www.wis-jma.go.jp/data/syn?ContentType=Text&Type=Alphanumeric&Access=Open&Category=Upper+air'
pat='--match=TEMP|PILOT'
#ca='--ca=/etc/ssl/certs/'

cd $(dirname $0)

$ruby -w syndl.rb ysyn.db logsyn.db --tar=output.tar $pat $ca $url

