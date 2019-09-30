#!/usr/bin/ruby

$LOAD_PATH.push '/usr/local/etc'

class Time
  def rfc1123
    utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
  end
  def isofull
    utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  end
end

module PSHBSpool
class App

  def initialize
    @method = ENV['REQUEST_METHOD'].to_s
    @qstr = ENV['QUERY_STRING'].to_s
    @path = ENV['PATH_INFO'].to_s
    @addr = ENV['REMOTE_ADDR'].to_s
    @link = ENV['HTTP_LINK'].to_s
    @ctype = ENV['CONTENT_TYPE'].to_s
    @clen = ENV['CONTENT_LENGTH']
    @clen = @clen.to_i if @clen
    @reqbody = nil
  end

  def verify_auth topic, vtok
    for cfg in TOPICS
      next unless cfg[:urlpat] === topic
      next unless cfg[:vtoken] === vtok
      return true
    end
    raise Errno::EPERM, "unregistered topic(#{topic}) & verify_token(#{vtok})"
  end

  def post_check
    for cfg in TOPICS
      next unless cfg[:bdypat] === @reqbody
      return true
    end
    raise Errno::EPERM, "pattern check failed: edit TOPICS::cfg[:bdypat]"
  end

  def verify
    pa = {}
    for span in @qstr.split(/[&;]/)
      next unless /^([.\w]+)=/ === span
      k, v = $1, $'
      pa[k] = v.gsub(/%[\dA-Fa-f]{2}/){|s| [s[1,2]].pack('H2') }
    end
    verify_auth(pa['hub.topic'].to_s, pa['hub.verify_token'].to_s)
    verify_log(pa)
    chal = pa['hub.challenge'].to_s
    <<EOF + chal
Content-Type: text/plain\r
Content-Length: #{chal.size}\r
\r
EOF
  end

  # transaction
  def database
    GDBM.open(STORAGE[:path], 0666, GDBM::WRCREAT) {|db|
      yield db
    }
  end

  def verify_log pa
    database {|db|
      # verifyid is always a String
      verifyid = (db['verifyid'].to_i + 1).to_s
      db['hub.mode:' + verifyid] = pa['hub.mode'].to_s
      db['hub.topic:' + verifyid] = pa['hub.topic'].to_s
      db['hub.challenge:' + verifyid] = pa['hub.challenge'].to_s
      db['hub.lease_seconds:' + verifyid] = pa['hub.lease_seconds'].to_s
      db['hub.verify_token:' + verifyid] = pa['hub.verify_token'].to_s
      db['verifyid'] = verifyid
      return verifyid
    }
  end

  def post_store1(db)
    # postid is always a String
    postid = (db['postid'].to_i + 1).to_s
    db['src:' + postid] = @addr
    db['lnk:' + postid] = @link
    db['upd:' + postid] = Time.now.isofull
    db['bdy:' + postid] = @reqbody
    db['postid'] = postid
    return postid
  end

  def post
    @reqbody = STDIN.read(@clen)
    postid = 'nil'
    database {|db|
      post_check
      postid = post_store1(db)
    }
    return "Content-Type: text/plain\r\n\r\nok postid:#{postid}"
  end

  def myname
    host = ENV['SERVER_NAME'] || 'localhost'
    port = ENV['SERVER_PORT'] || '443'
    script = ENV['SCRIPT_NAME']
    url = "https://#{host}:#{port}#{script}"
    if PRMS[:urlhook]
      PRMS[:urlhook].call(url)
    end
    return url
  end

  def path
    postid = verifyid = nil
    database {|db|
      postid = db['postid']
      verifyid = db['verifyid']
    }
    return "Content-Type: text/plain\r\n\r\npostid:#{postid} verifyid:#{verifyid}"
  end

  def getmethod
    if not @qstr.empty? then
      verify
    else
      path
    end
  end

  def run
    require 'pshbspool-cfg'
    require 'gdbm'
    resp = case @method
    when 'GET' then getmethod
    when 'POST' then post
    else raise "unknown http method #@method"
    end
    resp = ["Date: #{Time.now.rfc1123}\r\n", resp].join
    print resp
  rescue Errno::EAGAIN => e
    puts <<EOF
Status: 304 Not Modified\r
Date: #{Time.now.rfc1123}\r
Content-Location: #{e.message.sub(/.* - /, '')}\r
\r
EOF
  rescue Errno::EPERM => e
    puts <<EOF
Status: 404 File Not Found\r
Date: #{Time.now.rfc1123}\r
Content-Type: text/plain; charset=utf8\r
\r
#{e.message}\r
EOF
  rescue Exception => e
    puts <<EOF
Status: 501 Internal Server Error\r
Content-Type: text/plain; charset=utf8\r
\r
#{e.message} (#{e.class})
#{e.backtrace.join("\n")}
EOF
  end
  
end
end

PSHBSpool::App.new.run
