#!/usr/local/bin/ruby

require 'net/http'
require 'openssl'
require 'uri'
require 'gdbm'
require 'syslog'
require 'rubygems'
require 'tarwriter'

class WGet

  def initialize
    @conn = nil
    @resp = nil
    @ca = nil
    $logger = Syslog.open('syndl', Syslog::LOG_PID, Syslog::LOG_NEWS)
    $onset = Time.now
    @n = Hash.new(0)
    @n['-w'] = !!($VERBOSE)
  end

  def ca= val
    @ca = val
  end

  def connect(uri)
    if @conn then
      return 0 if  @conn.address == uri.host and @conn.port == uri.port
      @conn.finish
    end
    STDERR.puts "#CONNECT #{uri.host}:#{uri.port}" if $VERBOSE
    @conn = Net::HTTP.new(uri.host, uri.port, :ENV)
    @conn.use_ssl = true
    if @ca
      if /\/$/ === @ca then
        @conn.ca_path = @ca
      else
        @conn.ca_file = @ca
      end
    else
      STDERR.puts "Warning: server certificate not verified"
      @conn.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    @conn.start
  end

  def get(uri, lmt = nil, etag = nil)
    begin
      connect(uri)
      hdr = {}
      path = uri.request_uri
      STDERR.puts "#GET #{path}" if $VERBOSE
      if lmt then
    hdr['if-modified-since'] = lmt
      end
      if etag then
    hdr['If-None-Match'] = etag
      end
      STDERR.puts "# #{hdr.inspect}" if $VERBOSE
      @resp = @conn.get2(path, hdr)
      STDERR.puts "#--> #{@resp.code}" if $VERBOSE
      rc = @resp.code
    rescue Exception => e
      rc = '500'
      $logger.err("#{rc} rescue=#{e.class.to_s}")
    end
    @n[rc] += 1
    rc
  end

  def body
    @resp.body
  end

  def lmt
    @resp['last-modified']
  end

  def etag
    @resp['etag']
  end

  def tag s
    @n['tag'] = s
  end

  def eagain
    @n['EAGAIN'] = 1
  end

  def close
    @conn.finish if @conn and @conn.started?
    $logger.info('elapsed %g wget %s', Time.now - $onset, @n.inspect)
    $logger.close
  end

end

class SynDL

  def help
    puts "#$0 rtdb logdb feedurl ..."
    exit 1
  end

  def initialize argv
    @rtdb = argv.shift
    @logdb = argv.shift
    @feeds = argv.dup
    help if @feeds.empty?
    # @folder and @wget must be close()-ed properly
    @folder = TarWriter::Folder.new(nil, 'a')
    @wget = WGet.new
    @pfilter = {}
  end

  def getlmt(feed)
    lmt = etag = nil
    mode = GDBM::NOLOCK | GDBM::READER
    GDBM.open(@rtdb, 0644, mode) {|rtdb|
      key = "lmt/#{feed}"
      lmt = rtdb[key]
      key = "etag/#{feed}"
      etag = rtdb[key]
    }
    return [lmt, etag]
  rescue Errno::ENOENT
    nil
  end

  def setlmt(feed, lmt, etag)
    return unless lmt or etag
    mode = GDBM::WRCREAT
    GDBM.open(@rtdb, 0644, mode) {|rtdb|
      if lmt then
    key = "lmt/#{feed}"
    rtdb[key] = lmt
      end
      if etag then
    key = "etag/#{feed}"
    rtdb[key] = etag
      end
    }
  end

  def getfeed(ldb, feed)
    lmt, etag = getlmt(feed)
    ufeed = URI.parse(feed)
    STDERR.puts "##{ufeed.inspect}" if $VERBOSE
    code = @wget.get(ufeed, lmt, etag)
    case code
    when '304' then
      STDERR.puts "#unchanged" if $VERBOSE
      errid = 'dup:' + Time.now.utc.strftime('%Y-%m-%dT%H%M%SZ')
      ldb[errid] = feed
      return 0
    when '200' then
      :do_nothing
    else
      errid = "err:#{code}:" + Time.now.utc.strftime('%Y-%m-%dT%H%M%SZ')
      ldb[errid] = feed
      exit 16
    end
    fbdy = @wget.body
    lmt2 = @wget.lmt
    etag2 = @wget.etag
    STDERR.puts "#ETag: #{etag2}" if $VERBOSE
    # @wget can be reused now
    fbdy.each_line { |line|
      id = line.chomp
      if @pfilter[:match] then
        next unless @pfilter[:match] =~ id
      end
      if @pfilter[:reject] then
        next if @pfilter[:reject] =~ id
      end
      if ldb[id] then
        STDERR.puts "#dup skip #{id}" if $VERBOSE
        next
      end
      begin
        umsg = URI.parse(id)
        @wget.get(umsg)
        body = @wget.body
        STDERR.puts "#size #{body.size}" if $VERBOSE
        fnam = File.basename(id).gsub(/[^A-Za-z_0-9.]/, '_')
        t = Time.now.utc
        @folder.add(fnam, body, t)
        ldb[id] = t.strftime('%Y-%m-%dT%H%M%SZ')
      end
    }
    setlmt(feed, lmt2, etag2)
  end

  def run
    GDBM.open(@logdb, 0644, GDBM::WRCREAT) {|ldb|
    @feeds.each {|feed|
      case feed
      when /^--match=/
        if $'.empty? then @pfilter.delete(:match)
        else @pfilter[:match] = Regexp.new($')
        end
      when /^--reject=/
        if $'.empty? then @pfilter.delete(:reject)
        else @pfilter[:reject] = Regexp.new($')
        end
      when /^--ca=/
        @wget.ca= $'
      when /^--tar=/
        tar = $'
        @folder.close
        @folder = TarWriter::Folder.new(tar, 'a')
      when /^--chdir=/
        dir = $'
        @folder.close
        Dir.chdir(dir)
        @folder = TarWriter::Folder.new(nil, 'a')
      when /^--tag=/
        @wget.tag($')
      else
        STDERR.puts "getfeed #{feed}" if $VERBOSE
        getfeed(ldb, feed)
        GC.start
      end
    }
    }
  rescue Errno::EAGAIN
    $logger.err("db #{@logdb} busy - possibly multiple runs")
    @wget.eagain
  ensure
    @wget.close
    @folder.close
  end

end

SynDL.new(ARGV).run
