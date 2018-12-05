#!/usr/local/bin/ruby

require 'net/http'
require 'uri'
require 'gdbm'
require 'time'
require 'rexml/parsers/baseparser'
require 'rexml/parsers/streamparser'
require 'rexml/streamlistener'
require 'rubygems'
require 'tarwriter'

class WGet

  def initialize
    @conn = nil
    @resp = nil
  end

  def connect(uri)
    if @conn then
      STDERR.puts "now #{@conn.address}:#{@conn.port}" if $VERBOSE
      return 0 if  @conn.address == uri.host and @conn.port == uri.port
      @conn.finish
    end
    STDERR.puts "CONNECT #{uri.host}:#{uri.port}" if $VERBOSE
    @conn = Net::HTTP.start(uri.host, uri.port, :ENV)
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
    @resp = @conn.get2(path, hdr)
    STDERR.puts "--> #{@resp.code}" if $VERBOSE
    @resp.code
  end

  def body
    @resp.body
  end

  def lmt
    @resp['last-modified']
  end

  def close
    @conn.finish if @conn
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
    puts "#$0 rtdb outfnam feedurl ..."
    exit 1
  end

  def initialize argv
    @rtdb = argv.shift
    @outfnam = argv.shift
    @feeds = argv
    help if @feeds.empty?
    @wget = WGet.new
    @dfilter = nil
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


  def getfeed(idb, tar, feed)
    lmt = getlmt(feed)
    ufeed = URI.parse(feed)
    code = @wget.get(ufeed, lmt)
    case code
    when '304' then return 0
    when '200' then :do_nothing
    else exit "0#{code}".to_i
    end
    fbdy = @wget.body
    lmt2 = @wget.lmt
    # @wget can be reused now
    li = AtomParse.new { |rec|
      STDERR.puts rec.inspect if $VERBOSE
      if @dfilter then
        t = Time.parse(rec['updated'])
        unless @dfilter === t then
          STDERR.puts "skip -d #{t} #{id}" if $VERBOSE
          next
        end
      end
      id = rec['id']
      if idb.has_key?(id) then
        STDERR.puts "skip dup #{id}" if $VERBOSE
        next
      end
      begin
        umsg = ufeed.merge(rec['link/@href'])
        @wget.get(umsg)
        body = @wget.body
        STDERR.puts "size #{body.size}" if $VERBOSE
        pos = tar.add(id, body)
        idb[id] = pos.to_s
      end
    }
    REXML::Parsers::StreamParser.new(fbdy, li).parse
    setlmt(feed, lmt2)
  end

  def run
    idx = "#{@outfnam}.idx1"
    GDBM.open(idx, 0644, GDBM::WRCREAT) {|idb|
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
    ensure
    @wget.close
  end

end

FeedStore.new(ARGV).run
