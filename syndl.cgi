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
        d, y, h, n, s = [d, y, h, n, s].map{|s| s.to_i}
        m = MONTAB[m.downcase.to_sym].to_i
        Time.gm(y, m, d, h, n, s)
      when /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)Z/ then
        y, m, d, h, n = [$1, $2, $3, $4, $5].map{|s| s.to_i}
        s = $6.to_f
        Time.gm(y, m, d, h, n, s)
      when /(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+(?:\.\d+)?)([-+]\d\d):?(\d\d)/ then
        y, m, d, h, n, zh, zn = [$1, $2, $3, $4, $5, $7, $8].map{|s| s.to_i}
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
    @myname = myname
    @dbdir = '/nwp/p0'
  end

  def myname
    return @myname if @myname
    host = ENV['SERVER_NAME'] || 'localhost'
    port = ENV['SERVER_PORT'] || '80'
    script = ENV['SCRIPT_NAME']
    "//#{host}:#{port}#{script}"
  end

  def check_hims span = 60, tnow = Time.now
    if hims = ENV['HTTP_IF_MODIFIED_SINCE'] then
      STDERR.puts "HIMS #{hims.inspect}" if $DEBUG
      t = Time.parse(hims) + span
      STDERR.puts "CMP t=#{t} tnow=#{tnow}" if $DEBUG
      raise Errno::EAGAIN, File.join(myname, @path) if t > tnow
      STDERR.puts "CMP PASSTHRU" if $DEBUG
    end
    tnow
  end

  def path_index
    tnow = check_hims
    latest_dir = File.join(@dbdir, 'incomplete')
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
      href = File.join(myname, "list", datedir, dsname)
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

  def path_list datedir, dsname, offset = "0"
    tnow = check_hims
    offset = offset.to_i
    require 'zlib'
    require 'minitar'
    require 'html_builder'
    ymd = datedir.sub(/\.new$/, '')
    d = HTMLBuilder.new("syndl: list - #{dsname} #{ymd}")
    d.header('lang', 'en')
    d.tag('h1') { d.puts("data list - #{dsname} #{ymd}") }
    cols = ['Message-ID', 'Size', 'Arrival Time']
    insmax = Time.gm(1900, 1, 1)
    tarfile = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.tar")
    d.table(cols) {
      Dir.foreach(@dbdir) {|datedir|
        next unless /^(\d\d\d\d-\d\d-\d\d)(?:\.new)?$/ === datedir
        ymd = $1
        path = File.join(@dbdir, datedir, "#{dsname}-#{ymd}.tar")
        begin
          stat = File.stat(path)
        rescue Errno::ENOENT
          next
        end
        insmax = stat.mtime if stat.mtime > insmax
        d.tag("tr") {
          d.tag('td') {
            href = File.join(myname, "list", datedir, dsname)
            d.tag('a', 'href'=>href) { d.puts ymd }
            d.puts " (incomplete)" if /\.new/ === datedir
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
      "", body ].join("\r\n")
  end

  def path_entry date, uri
    tnow = check_hims(86400 * 365)
    upd, body = nil
    database {|db|
      sql = "SELECT upd, body FROM msgs WHERE uri = ?"
      st = db.prepare(sql)
      begin
        st.execute(uri)
        upd, body = st.fetch
      ensure
        st.close
      end
    }
    raise Errno::ENOENT, "uri #{uri} not found" unless body
    upd = Time.parse(upd).rfc1123
    xpr = (Time.now.utc + 86400 * 2).rfc1123
    "Expires:#{xpr}\r\nLast-Modified: #{upd}\r\nContent-Type: application/xml\r\n\r\n" + body.to_s
  end

  def getmethod
    case @path
    when %r{^/index\.html?$} then path_index
    when %r{^/hist/(\w+)$} then path_hist($1)
    when %r{^/list/(\d\d\d\d-\d\d-\d\d(?:\.new)?)/(\w+)(?:/(\d+))?$} then path_list($1, $2, $3)
    when %r{^/entry/(\d\d\d\d-\d\d-\d\d(?:\.new)?)/([-.\w]+)$} then path_entry($1, $2)
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
    when Errno::ENOENT then status = "404 File Not Found"
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