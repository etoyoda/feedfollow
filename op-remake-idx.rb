#!/usr/bin/ruby
# encode: utf8

# usage: zcat jmx-2019-01-01.tar.gz | ruby op-remake-idx.rb jmx-2019-01-01.idx1

require 'rubygems'
require 'tarreader'
require 'gdbm'

GDBM.open(ARGV.first, 0644, GDBM::WRCREAT) { |db|
  TarReader.open($stdin) { |tar|
    tar.each_entry { |ent|
      db[ent.name] = ent.pos.to_s
      puts "db[#{ent.name}] = #{ent.pos}"
    }
  }
}
