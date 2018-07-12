set -x
set -e
test ! -f ztest.tar || rm -f ztest.tar
ruby tarwriter.rb ztest.tar tarwriter.rb
tar tvf ztest.tar
