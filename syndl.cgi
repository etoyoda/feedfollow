#!/usr/bin/ruby

class Time
  def rfc1123
    utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
  end
  def xmlstr
    utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  end
  MONTAB = {
    :jan => 1,        :feb => 2,        :mar => 3,        :apr => 4,
    :may => 5,        :jun => 6,        :jul => 7,        :aug => 8,
    :sep => 9,        :oct => 10,        :nov => 11,        :dec => 12
  }
  def Time.parse str
    begin
      case str
      when /(\d+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+GMT/ then
        d, m, y, h, n, s = $1, $2, $3, $4, $5, $6
        d, y, h, n, s = [d, y, h, n, s].map{|cell| cell.to_i}
        m = MONTAB[m.downcase.to_sym].to_i
        Time.gm(y, m, d, h, n, s)
      when /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)Z/ then
        y, m, d, h, n = [$1, $2, $3, $4, $5].map{|cell| cell.to_i}
        s = $6.to_f
        Time.gm(y, m, d, h, n, s)
      when /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)([-+]\d\d):?(\d\d)/ then
        y, m, d, h, n, zh, zn = [$1, $2, $3, $4, $5, $7, $8].map{|cell| cell.to_i}
        s = $6.to_f
        Time.gm(y, m, d, h, n, s) - (zh * 60 + zn)
      else raise "unknown datetime format #{str}"
      end
    rescue
      Time.now
    end
  end
end

module DataSpool
class App

  def initialize
    @method = ENV['REQUEST_METHOD'].to_s
    @path = ENV['PATH_INFO'].to_s
    @reqbody = nil
    @myname = nil; myname
    #config
    @dbdir = '/nwp/p0'
    @pagesize = 25
  end

  def myname
    return @myname if @myname
    host = ENV['SERVER_NAME'] || 'localhost'
    port = ENV['SERVER_PORT'] || '80'
    script = ENV['SCRIPT_NAME']
    @myname = "//#{host}:#{port}#{script}"
  end

  def check_hims span = 60, tnow = Time.now
    if hims = ENV['HTTP_IF_MODIFIED_SINCE'] then
      STDERR.puts "HIMS #{hims.inspect}" if $VERBOSE
      t = Time.parse(hims) + span
      STDERR.puts "CMP t=#{t} tnow=#{tnow}" if $VERBOSE
      raise Errno::EAGAIN, File.join(myname, @path) if t > tnow
      STDERR.puts "CMP PASSTHRU" if $VERBOSE
    end
    tnow
  end

  def path_index
    tnow = check_hims
    latest_dir = File.join(@dbdir, 'incomplete')
    require 'rubygems'
    require 'html_builder'
    d = HTMLBuilder.new('syndl: dataset list')
    d.header('lang', 'en')
    d.tag('h1') { d.puts('dataset list') }
    cols = ['Dataset', 'Today\'s Size', 'Last Modified']
    insmax = Time.gm(1900, 1, 1)
    d.table(cols) {
      Dir.foreach(latest_dir) {|fnam|
        next unless /^(\w.*)-\d\d\d\d-\d\d-\d\d\.tar$/ === fnam
        dsname = $1
        stat = File.stat(File.join(latest_dir, fnam))
        insmax = stat.mtime if stat.mtime > insmax
        d.tag("tr") {
          d.tag('td') {
            href = File.join(myname, "hist", dsname)
            d.tag('a', 'href'=>href) { d.puts dsname }
          }
          d.tag('td') { d.puts sprintf('%.3f MB', stat.size / 1.0e6) }
          d.tag('td') { d.puts stat.mtime.xmlstr }
        }
      }
    }
    d.tag('hr')
    d.tag('p') { d << "Last-Modified: " + insmax.xmlstr }
    xpr = (tnow.utc + 60)
    body = d.to_s
    return [ "Expires: #{xpr.rfc1123}",
      "Last-Modified: #{insmax.rfc1123}",
      "Content-Type: text/html; charset=utf-8",
      "Content-Length: #{body.bytesize}",
      "", body
      ].join("\r\n")
  end

  def path_hist dsname
    tnow = check_hims
    require 'html_builder'
    d = HTMLBuilder.new("syndl: history - #{dsname}")
    d.header('lang', 'en')
    d.tag('h1') { d.puts("dataset history - #{dsname}") }
    cols = ['Dataset', 'Today\'s Size', 'Last Modified']
    insmax = Time.gm(1900, 1, 1)
    database = []
    Dir.foreach(@dbdir) {|datedir|
      next unless /^(\d\d\d\d-\d\d-\d\d)(?:\.new)?$/ === datedir
      ymd = $1
      path = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.tar")
      begin
        stat = File.stat(path)
      rescue Errno::ENOENT
        path += ".gz"
        begin
          stat = File.stat(path)
        rescue Errno::ENOENT
          next
        end
      end
      insmax = stat.mtime if stat.mtime > insmax
      href = File.join(myname, "list", datedir, dsname, '0')
      row = { :href => href, :ymd => ymd, :stat => stat }
      row[:ymdplus] = " (incomplete)" if /\.new/ === datedir
      database.push row
    }
    database.sort! {|a,b| a[:ymd] <=> b[:ymd] }
    d.table(cols) {
      database.each {|row|
        d.tag("tr") {
          d.tag('td') {
            d.tag('a', 'href'=>row[:href]) { d.puts row[:ymd] }
            d.puts row[:ymdplus] if row[:ymdplus]
          }
          d.tag('td') { d.puts sprintf('%.3f MB', row[:stat].size / 1.0e6) }
          d.tag('td') { d.puts row[:stat].mtime.xmlstr }
        }
      }
    }
    d.tag('hr')
    d.tag('p') { d << "Last-Modified: " + insmax.xmlstr }
    xpr = (tnow.utc + 60)
    body = d.to_s
    return [ "Expires: #{xpr.rfc1123}",
      "Last-Modified: #{insmax.rfc1123}",
      "Content-Type: text/html; charset=utf-8",
      "Content-Length: #{body.bytesize}",
      "", body ].join("\r\n")
  end

  def path_list datedir, dsname, offset = 0
    ttl = 86400
    ttl = 60 if /\.new$/ === datedir
    tnow = check_hims(ttl)
    offset = offset.to_i
    require 'archive/tar/minitar'
    require 'html_builder'
    ymd = datedir.sub(/\.new$/, '')
    d = HTMLBuilder.new("syndl: list - #{dsname} #{ymd} offset #{offset}")
    d.header('lang', 'en')
    d.tag('h1') { d.puts("data list - #{dsname} #{ymd} offset #{offset}") }
    cols = ['Message-ID', 'Size', 'Arrival Time']
    tarfile = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.tar")
    do_gunzip = false
    begin
      tarstat = File.stat(tarfile)
    rescue Errno::ENOENT
      require 'zlib'
      do_gunzip = true
      tarfile += '.gz'
      begin
        tarstat = File.stat(tarfile)
      rescue Errno::ENOENT
        do_gunzip = false
        tarfile.sub!(/\.gz$/, '')
        tarfile.sub!(/(\/20\d\d-[01]\d-[0-3]\d)/, '\1.new')
        tarstat = File.stat(tarfile)
      end
    end
    insmax = tarstat.mtime
    database = []
    nextlink = nil
    iskip = offset
    File.open(tarfile, 'rb') {|fp|
      fp.set_encoding('BINARY')
      io = do_gunzip ? Zlib::GzipReader.new(fp) : fp
      Archive::Tar::Minitar::Reader.open(io) { |tar|
        tar.each_entry {|ent|
          iskip -= 1
          next if iskip >= 0
          # drops the last row, same as "LIMIT pagesize + 1" in SQL
          if database.size > @pagesize then
            nextlink = File.join(myname, "list", datedir, dsname, String(offset + @pagesize))
            next
          end
          row = { :name => ent.name, :size => ent.size, :mtime => ent.mtime }
          database.push(row)
        }
      }
      io.close if do_gunzip
    }
    d.tag('p') {
      toplink = File.join(myname, "index.html")
      d.puts ' '
      d.tag('a', 'href'=>toplink) { d.puts "Datasets" }
      histlink = File.join(myname, "hist", dsname)
      d.puts ' '
      d.tag('a', 'href'=>histlink) { d.puts "History" }
      if offset > @pagesize then
        firstlink = File.join(myname, "list", datedir, dsname, "0")
        d.puts ' '
        d.tag('a', 'href'=>firstlink) { d.puts "First #@pagesize" }
      end
      if offset >= @pagesize then
        prevlink = File.join(myname, "list", datedir, dsname, String(offset - @pagesize))
        d.puts ' '
        d.tag('a', 'href'=>prevlink) { d.puts "Prev #@pagesize" }
      end
      if nextlink then
        d.puts ' '
        d.tag('a', 'href'=>nextlink) { d.puts "Next #@pagesize" }
      end
    }
    d.tag('hr')
    d.table(cols) {
      if iskip >= 0 then
        d.tag("tr") {
          d.tag("td", "colspan"=>"3") { d.puts "End of file reached" }
        }
      end
      database.each {|row|
        d.tag("tr") {
          d.tag('td') {
            href = File.join(myname, "entry", datedir, dsname, row[:name])
            d.tag('a', 'href'=>href) { d.puts row[:name] }
          }
          ssize = if row[:size] > 32_000
            then sprintf('%.3f MB', row[:size] / 1.0e6)
            else sprintf('%.3f kB', row[:size] / 1.0e3)
            end
          d.tag('td') { d.puts ssize }
          d.tag('td') { d.puts Time.at(row[:mtime]).utc.xmlstr }
        }
      }
    }
    d.tag('hr')
    d.tag('p') { d << "Last-Modified: " + insmax.xmlstr }
    xpr = (tnow.utc + 60)
    body = d.to_s
    return [ "Expires: #{xpr.rfc1123}",
      "Last-Modified: #{insmax.rfc1123}",
      "Content-Type: text/html; charset=utf-8",
      "Content-Length: #{body.bytesize}",
      "", body ].join("\r\n")
  end

  def path_entry datedir, dsname, msgid
    check_hims(86400 * 10)
    require 'rubygems'
    require 'tarreader'
    require 'html_builder'
    ymd = datedir.sub(/\.new$/, '')
    tarfile = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.tar")
    do_gunzip = false
    begin
      tarstat = File.stat(tarfile)
    rescue Errno::ENOENT
      require 'zlib'
      do_gunzip = true
      tarfile += '.gz'
      begin
        tarstat = File.stat(tarfile)
      rescue Errno::ENOENT
        do_gunzip = false
        tarfile.sub!(/\.gz$/, '')
        tarfile.sub!(/(\/20\d\d-[01]\d-[0-3]\d)/, '\1.new')
        tarstat = File.stat(tarfile)
      end
    end
    seek = nil
    idxfile = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.idx1")
    begin
      require 'gdbm'
      GDBM.open(idxfile) {|db|
        seek = db[msgid].to_i if db[msgid]
      }
      $stderr.puts "seek=#{seek}" if $VERBOSE
    rescue Errno::ENOENT
    end
    body = nil
    upd = nil
    File.open(tarfile, 'rb') {|fp|
      fp.set_encoding('BINARY')
      io = do_gunzip ? Zlib::GzipReader.new(fp) : fp
      TarReader.open(io) { |tar|
        tar.pos = seek if seek
        tar.each_entry {|ent|
          next unless ent.name == msgid
          $stderr.puts "ent.pos=#{ent.pos}" if $VERBOSE
          body = ent.read
          upd = Time.at(ent.mtime).utc
        }
      }
    }
    raise Errno::ENOENT, "file #{msgid} not found" unless body
    xpr = (Time.now.utc + 86400 * 2)
    ctype = case msgid
      when /\.(?:txt|log|ltsv|csv)$/ then 'text/plain; charset=utf-8'
      when /\.(?:html|xhtml)$/ then 'text/html; charset=utf-8'
      when /\.bufr$/ then 'application/x-bufr' # Source: http://wis.wmo.int/doc=2343
      when /\.grib$/ then 'application/x-grib' # Source: http://wis.wmo.int/doc=2343
      when /\.nc$/ then 'application/netcdf' # Source: http://wis.wmo.int/doc=2343
      when /\.xml$/ then 'text/xml; charset=utf-8'
      when /^urn:uuid:[-0-9a-f]+$/ then 'text/xml; charset=utf-8'
      else 'application/octet-stream'
      end
    return [ "Expires: #{xpr.rfc1123}",
      "Last-Modified: #{upd.rfc1123}",
      "Content-Type: #{ctype}",
      "Content-Length: #{body.bytesize}",
      "", body ].join("\r\n")
  end

  def getmethod
    case @path
    when %r{^/index\.html?$} then path_index
    when %r{^/hist/([-\w]+)$} then path_hist($1)
    when %r{^/list/(\d\d\d\d-\d\d-\d\d(?:\.new)?)/([-\w]+)(?:/(\d+))?$} then path_list($1, $2, $3)
    when %r{^/entry/(\d\d\d\d-\d\d-\d\d(?:\.new)?)/([-\w]+)/([-.:\w]+)$} then path_entry($1, $2, $3)
    else
      url = "#{myname}/index.html"
      "Status: 302 Found\r\nLocation: #{url}\r\n\r\n#{url}"
    end
  end

  def errmsg ex, msg
    status = nil
    case ex
    when Errno::EXDEV  then status = "402 Payment Required"
    when Errno::EPERM  then status = "403 Forbidden"
    when Errno::ENOENT then status = "404 File Not Found"; msg += ex.backtrace.first
    when Errno::EILSEQ then status = "405 Method Not Allowed"
    when Errno::EBADF  then status = "410 Gone"
    else
      status = "501 Internal Server Error"
      msg += " (#{ex.class})\r\n#{ex.backtrace.join("\r\n")}"
    end
    return <<ERRMSG
Status: #{status}\r
Date: #{Time.now.rfc1123}\r
Content-Type: text/plain; charset=utf8\r
\r
#{msg}\r
ERRMSG
  end

  def run
    resp = case @method
    when 'GET' then getmethod
    else raise Errno::EILSEQ, "http method #@method unsupported"
    end
    resp = ["Date: #{Time.now.rfc1123}\r\n", resp].join
    print resp
  rescue Errno::EAGAIN => e
    puts <<ERRMSG304
Status: 304 Not Modified\r
Date: #{Time.now.rfc1123}\r
Content-Location: #{e.message.sub(/.* - /, '')}\r
\r
ERRMSG304
  rescue Exception => e
    puts errmsg(e, e.message)
  end
  
end
end

DataSpool::App.new.run
