#!/bin/env ruby

class TarWriter

  include File::Constants

  def TarWriter::open fnam, mode
    tar = TarWriter.new(fnam, mode)
    return tar unless block_given?
    begin
      yield tar
    ensure
      tar.close
    end
    fnam
  end

  def initialize file, mode = 'w'
    @io = nil
    @io = if IO === file
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

  def header bfnam, size, cksum = nil
    raise "too long filename #{bfnam}" if bfnam.size >= 100
    mode = '0000644'
    uid = gid = '32000'
    csize = sprintf("%011o", size)
    cks = cksum ? sprintf("%o\0", cksum) : ""
    mtime = sprintf("%011o", Time.now.to_i)
    typeflag = '0'
    linkname = ''
    magic = 'ustar'
    version = '00'
    uname = gname = 'nobody'
    devmajor = devminor = ''
    prefix = filler = ''
    fmt = "a100 a8 a8 a8 a12 a12 A8 a1 a100 a6 a2 a32 a32 a8 a8 a155"
    [bfnam, mode, uid, gid, csize, mtime, cks, typeflag, linkname, magic,
      version, uname, gname, devmajor, devminor, prefix].pack(fmt)
  end

  def blockwrite str
    @io.write [str].pack('a512')
  end

  def add fnam, content
    bfnam = String.new(fnam, encoding: "BINARY")
    bcontent = String.new(content, encoding: "BINARY")
    testhdr = header(bfnam, bcontent.size)
    cksum = 0
    testhdr.each_byte {|b| cksum += b }
    hdr = header(bfnam, bcontent.size, cksum)
    blockwrite(hdr)
    ofs = 0
    while blk = bcontent.byteslice(ofs, 512)
      blockwrite([blk].pack('a512'))
      ofs += 512
    end
  end

  def flush
    @io.flush
  end

  def close
    flush
    terminator = "\0" * 1024
    @io.write terminator
    @io.close
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
