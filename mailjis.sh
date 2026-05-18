#!/bin/sh

LANG=en_US.UTF-8
export LANG

: usage: $0 input.txt from@example.org [-s subject] dest@example.com ...

input=$1
shift
mailfrom="$1"
shift

sbj=$(ruby -ne 'puts $1.split(" ").map{|f| "=?UTF-8?B?" + [f].pack("m").chomp + "?="}.join(" ") if /^~s *(.*)/' $input)

case "$1" in
-s)
  shift
  sbj="$1"
  shift
  ;;
esac

test ! -f z.mail || rm -f z.mail
printf '%s\r\n' "From: $mailfrom" > z.mail
printf '%s\r\n' "To: $mailfrom" >> z.mail
printf '%s\r\n' "Subject: ${sbj}" >> z.mail
printf '%s\r\n' "Mime-Version: 1.0" >> z.mail
printf '%s\r\n' "Content-Type: text/plain; charset=ISO-2022-JP" >> z.mail
#printf '%s\r\n' "Content-Transfer-Encoding: 8bit" >> z.mail
printf '\r\n' >> z.mail
iconv -f UTF-8 -t ISO-2022-JP < $input >> z.mail
/usr/lib/sendmail "$@" < z.mail
