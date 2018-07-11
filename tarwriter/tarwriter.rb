#!/bin/env ruby

class TarWriter

  include File::Constants

  def TarWriter::open fnam, mode
    tar = TarWriter.new(fnam, mode)
    yield(tar) if block_given?
    tar.close
    fnam
  end

  def initialize file, mode = 'w'
    @io = nil
    if IO === file
    then
      file
    else
      case mode
      when 'x'
        File.open(file, WRONLY|CREAT|EXCL|TRUNC).set_encoding('BINARY')
      else
	File.open(file, fmode)
      end
    end
  end

  def header bfnam, size, cksum = "       "
    mode = '0644'
    uid = gid = 'nobody'
    fmt = ''
    [bfnam, mode, uid, gid, csize, mtime, cksum, typeflag, linkname, magic,
    version, uname, gname, devmajor, devminor, prefix].pack(fmt)
  end

  def add fnam, content
    bfnam = String(fnam, encoding: "BINARY")
    raise "too long filename #{fnam}" if bfnam.size >= 100
    bcontent = String(content, encoding: "BINARY")
    testhdr = header(bfnam, bcontent.size)

  end

  def flush
    @io.flush
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
