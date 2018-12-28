module PSHBSpool

TOPICS = [
  {
    :name => 'JMAXML',
    :bdypat => %r{http://xml\.kishou\.go\.jp\/},
    :vtoken => '123456789'
  },
]

STORAGE = {
  :path => '/nwp/p0/incomplete/pshb.db'
}

PRMS = {
  #:urlhook => proc{|s|
  #  s.sub!(%r{^http://localhost:80/cgi-bin/backend}, 'http://example.com/xx')
  #},
}

end
