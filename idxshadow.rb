# usage: ruby idxshadow.rb yesterday.idx today.idx

require 'gdbm'

infnam = ARGV.shift
outfnam = ARGV.shift

raise Errno::EEXIST, outfnam if FileTest.exist?(outfnam)

GDBM.open(infnam, 0666, GDBM::READER) { |idb|
  GDBM.open(outfnam, 0666, GDBM::WRCREAT) { |odb|
    idb.each_pair { |k, v|
      next unless /^(urn:uuid|http:|2\w+\.xml)/ === k
      next unless /^[0-9]/ === v
      odb[k] = ""
    }
    odb['idxshadow/updated'] = Time.now.to_s
  }
}
