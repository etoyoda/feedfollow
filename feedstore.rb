#!/usr/bin/ruby

require 'net/http'
require 'openssl'
require 'uri'
require 'gdbm'
require 'time'
require 'syslog'
require 'rexml/parsers/baseparser'
require 'rexml/parsers/streamparser'
require 'rexml/streamlistener'
require 'rubygems'
require 'tarwriter'

class WGet

  def initialize
    @conn = nil
    @resp = nil
    @ca = nil
    $logger = Syslog.open('feedstore', Syslog::LOG_PID, Syslog::LOG_NEWS)
    $onset = Time.now
    @n = Hash.new(0)
  end

  def ca= val
    @ca = val
  end

  def connect(uri)
    if @conn then
      STDERR.puts "now #{@conn.address}:#{@conn.port}" if $VERBOSE
      return 0 if  @conn.address == uri.host and @conn.port == uri.port
      @conn.finish
    end
    STDERR.puts "#CONNECT #{uri.host}:#{uri.port}" if $VERBOSE
    @conn = Net::HTTP.new(uri.host, uri.port, :ENV)
    @conn.use_ssl = true unless uri.port == 80
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

  def get(uri, lmt = nil)
    connect(uri)
    hdr = {}
    path = uri.request_uri
    STDERR.puts "GET #{path}" if $VERBOSE
    if lmt then
      STDERR.puts "If-Modified-Since: #{lmt}" if $VERBOSE
      hdr['if-modified-since'] = lmt
    end
    @resp = @conn.request_get(path, hdr)
    rc = @resp.code
    STDERR.puts "--> #{rc}" if $VERBOSE
    @n[rc] += 1
    rc
  end

  def body
    @resp.body
  end

  def lmt
    @resp['last-modified']
  end

  def close
    @conn.finish if @conn and @conn.started?
    $logger.info('elapsed %g wget %s', Time.now - $onset, @n.inspect)
    $logger.close
  end

  def status
    return 11 if @n.empty?
    if @n.include?('200') then 0
    elsif @n.include?('304') then 3
    else 4
    end
  end

end

class AtomParse
  include REXML::StreamListener

  def initialize
    @tag = nil
    @rec = {}
    @cb = proc
  end

  TAGS = /^(name|author|id|title|updated)$/

  def text(text)
    return unless @tag
    # return if text.strip.empty?
    @rec[@tag] = text
    @tag = nil
  end

  def tag_start(name, attrs)
    case name
    when 'entry' then @rec = {}
    when TAGS then @tag = name
    when 'link' then
      @rec['link/@href'] = attrs['href']
    end
  end

  def tag_end(name)
    return unless 'entry' == name
    @cb.call(@rec)
  end

end


class FeedStore

  def help
    puts "#$0 rtdb outfnam ca feedurl ..."
    exit 1
  end

  def initialize argv
    @rtdb = argv.shift
    @outfnam = argv.shift
    ca = argv.shift
    @feeds = argv
    help if @feeds.empty?
    @wget = WGet.new
    @wget.ca = ca
    @dfilter = nil
    @feedtar = nil
  end

  def getlmt(feed)
    lmt = nil
    mode = GDBM::NOLOCK | GDBM::READER
    GDBM.open(@rtdb, 0644, mode) {|rtdb|
      key = "lmt/#{feed}"
      lmt = rtdb[key]
    }
    return lmt
  rescue Errno::ENOENT
    nil
  end

  def setlmt(feed, lmt)
    key = "lmt/#{feed}"
    mode = GDBM::WRCREAT
    GDBM.open(@rtdb, 0644, mode) {|rtdb|
      rtdb[key] = lmt
    }
  end

  def tmpnam(feed)
    File.basename(feed) + Time.now.utc.strftime('-%Y-%m-%dT%H%M%S') + "-#{$$}.xml"
  end

  def getfeed(idb, tar, feed)
    lmt = getlmt(feed)
    ufeed = URI.parse(feed)
    code = @wget.get(ufeed, lmt)
    case code
    when '304' then return 0
    when '200' then :do_nothing
    else raise Errno::EIO, "HTTP #{code}"
    end
    fbdy = @wget.body
    lmt2 = @wget.lmt
    @feedtar.add(tmpnam(feed), fbdy)
    # @wget can be reused now
    li = AtomParse.new { |rec|
      STDERR.puts rec.inspect if $VERBOSE
      ft = Time.parse(rec['updated']).utc
      id = rec['id']
      if @dfilter then
        unless @dfilter === ft then
          STDERR.puts "skip -d #{ft} #{id}" if $VERBOSE
          next
        end
      end
      if idb.has_key?(id) then
        STDERR.puts "skip dup #{id}" if $VERBOSE
        next
      end
      begin
        umsg = ufeed.merge(rec['link/@href'])
        code2 = @wget.get(umsg)
        case code2
        when '200' then :do_nothing
        when '404' then
          $logger.err('rescue=ENOENT %s', umsg)
          raise Errno::ENOENT, umsg
        else
          $logger.err('rescue=EIO %s', umsg)
          raise Errno::EIO, "HTTP #{code2}"
        end
        body = @wget.body
        STDERR.puts "size #{body.size}" if $VERBOSE
        idb["lmt/#{id}"] = lmt2
        t = Time.now.utc
        mid = File.basename(id)
        pos = tar.add(mid, body, t)
        idb[mid] = idb[id] = pos.to_s
        m = t.strftime('m/%Y-%m-%dT%H%M')
        idb[m] = [String(idb[m]), id, " "].join
      rescue Errno::ENOENT
        nil
      end
    }
    begin
      REXML::Parsers::StreamParser.new(fbdy, li).parse
      setlmt(feed, lmt2)
    rescue REXML::ParseException => e
      STDERR.puts("feed #{feed} - #{e.message}")
      $logger.err('feed %s - %s', feed, e.message)
    end
  end

  def run2
    idx = "#{@outfnam}.idx1"
    GDBM.open(idx, 0644, GDBM::WRCREAT) {|idb|
      @feedtar = TarWriter.open("feed-#{@outfnam}.tar", "a");
      TarWriter.open("#{@outfnam}.tar", 'a') {|tar|
        @feeds.each {|feed|
          case feed
          when /^-d(\d\d\d\d)-?(\d\d)-?(\d\d)/
            base = Time.gm($1.to_i, $2.to_i, $3.to_i)
            @dfilter = base...(base + 86400)
            STDERR.puts @dfilter.inspect if $VERBOSE
          else
            getfeed(idb, tar, feed)
          end
        }
      }
    }
  rescue Errno::EAGAIN
    $logger.err('rescue=EAGAIN idx=%s', @outfnam)
  ensure
    @feedtar.close if @feedtar
    @wget.close
  end

  def run
    run2
    exit @wget.status
  end

end

FeedStore.new(ARGV).run
