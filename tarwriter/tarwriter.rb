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
    @blocking_factor = 20
    @pool = []
  end

  def header bfnam, size, cksum = nil
    raise "too long filename #{bfnam}" if bfnam.size >= 100
    mode = sprintf("%07o", 0664)
    uid = gid = sprintf("%07o", 99)
    csize = sprintf("%011o", size)
    cks = cksum ? sprintf("%06o\0", cksum) : ""
    mtime = sprintf("%011o", Time.now.to_i)
    typeflag = '0'
    linkname = ''
    magic = 'ustar'
    version = '00'
    uname = gname = 'nobody'
    devmajor = devminor = sprintf('%07o', 0)
    prefix = filler = ''
    fmt = "a100 a8 a8 a8 a12 a12 A8 a1 a100 a6 a2 a32 a32 a8 a8 a155"
    [bfnam, mode, uid, gid, csize, mtime, cks, typeflag, linkname, magic,
      version, uname, gname, devmajor, devminor, prefix].pack(fmt)
  end

  def add fnam, content
    bfnam = String.new(fnam, encoding: "BINARY")
    bcontent = String.new(content, encoding: "BINARY")
    testhdr = header(bfnam, bcontent.size)
    cksum = 0
    testhdr.each_byte {|b| cksum += b }
    hdr = header(bfnam, bcontent.size, cksum)
    block_write(hdr)
    ofs = 0
    while blk = bcontent.byteslice(ofs, 512)
      block_write([blk].pack('a512'))
      ofs += 512
    end
  end

  def block_write str
    @pool.push [str].pack('a512')
    if @pool.size >= @blocking_factor
      @io.write @pool.join
      @pool = []
    end
  end

  def flush
    while not @pool.empty?
      block_write ''
    end
    @io.flush
  end

  def close
    block_write ''
    block_write ''
    flush
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
