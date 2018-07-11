#!/bin/env ruby

class TarWriter

  def TarWriter::open fnam, mode
    tar = TarWriter.new(fnam, mode)
    yield(tar) if block_given?
    tar.close
    fnam
  end

  def initialize fnam, mode
  end

end

if $0 == __FILE__
  ofn = ARGV.shift
  TarWriter.open(ofn, 'x') {|tar|
    ARGV.each {|fn|
      File.open(fn) {|ifp|
        tar.add(File.basename(fn), ifp.read)
      }
    }
  }
end
