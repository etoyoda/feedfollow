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
        File.open(file, WRONLY|CREAT|EXCL|TRUNC|BINARY).set_encoding('BINARY')
      when 'a'
        File.open(file, RDWR|CREAT|BINARY).set_encoding('BINARY')
      when 'w'
	File.open(file, WRONLY|CREAT|TRUNC|BINARY).set_encoding('BINARY')
      else
        raise "unsupported mode=#{mode}"
      end
    end
    find_eof if mode == 'a'
    @blocking_factor = 20
    @pool = []
  end

  def header bfnam, size, time, cksum = nil
    raise "too long filename #{bfnam}" if bfnam.size >= 100
    mode = sprintf("%07o", 0664)
    uid = gid = sprintf("%07o", 99)
    csize = sprintf("%011o", size)
    cks = cksum ? sprintf("%06o\0", cksum) : ""
    mtime = sprintf("%011o", time)
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

  def add fnam, content, time = Time.now
    bfnam = String.new(fnam, encoding: "BINARY")
    bcontent = String.new(content, encoding: "BINARY")
    testhdr = header(bfnam, bcontent.size, time)
    cksum = 0
    testhdr.each_byte {|b| cksum += b }
    hdr = header(bfnam, bcontent.size, time, cksum)
    block_write(hdr)
    ofs = 0
    while blk = bcontent.byteslice(ofs, 512)
      block_write([blk].pack('a512'))
      ofs += 512
    end
  end

  def find_eof
    @io.seek(0, IO::SEEK_END)
    base = @io.pos
    base -= base % 10240
    loop do
      base -= 10240
      raise "tar header not found" if base < 0
      @io.pos = base
      STDERR.puts "read #{base}+20b" if $DEBUG
      buf = @io.read(10240)
      19.downto(0) {|i|
        magic = buf[512 * i + 257, 5]
	next unless magic == 'ustar'
	recpos = base + 512 * i
	STDERR.puts "ustar found at #{recpos}" if $DEBUG
	hdr = buf[512 * i, 500]
	cksum = hdr[148, 8].unpack('A*').first.to_i(8)
	hdr[148, 8] = ' ' * 8
	s = 0
	hdr.each_byte{|c| s += c}
	next unless cksum == s
	STDERR.puts "checksum #{s} matches at #{recpos}" if $DEBUG
	size = hdr[124, 12].unpack('A*').first.to_i(8)
	size -= 1
	size -= size % 512
	size += 512
	@io.pos = (recpos + 512 + size)
	return @io
      }
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
  mode = 'x'
  mode = ARGV.shift.sub(/^-/, '') if /^-[xwa]/ === ARGV.first
  ofn = ARGV.shift
  TarWriter.open(ofn, mode) {|tar|
    ARGV.each {|fn|
      File.open(fn) {|ifp|
        tar.add(File.basename(fn), ifp.read)
      }
    }
  }
end
