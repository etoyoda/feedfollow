if ! ruby tarwriter.rb ztest.tar tarwriter.rb
then
  echo fail 1
  exit
fi
if ! tar tvf ztest.tar
then
  echo fail 2
  exit
fi
