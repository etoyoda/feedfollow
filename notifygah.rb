#!/usr/bin/ruby

require 'uri'
require 'net/http'
require 'gdbm'
require 'time'
require 'syslog'

fnam = ARGV.shift
limit = (ARGV.shift || '180').to_i
dest = ARGV.shift || 'http://alert-hub.appspot.com/publish'
now = Time.now
queue = {}
$logger = Syslog.open('notifygah', Syslog::LOG_PID, Syslog::LOG_NEWS)

GDBM::open(fnam, GDBM::READER){|db|
  for k, v in db
    next unless /^lmt\// === k
    feed = $'
    lmt = Time.parse(v)
    tdif = now - lmt
    if tdif > limit
      $logger.info('skip %g %s', tdif, File.basename(feed)) if $VERBOSE
      next
    end
    queue[feed] = tdif
  end
}
udest = URI.parse(dest)
rc = 0
for feed, tdif in queue
  form = {'hub.mode'=>'publish', 'hub.url'=>feed}
  r = Net::HTTP.post_form(udest, form)
  case r.code
  when /^2/ then 
    $logger.info('ok %s %g feed=%s', r.code, tdif, File.basename(feed))
    rc = 0
  else
    msg = sprintf('err %s %g feed=%s', r.code, tdif, File.basename(feed))
    $stderr.puts(msg)
    $logger.err(msg)
    rc = 4
  end
end
$logger.info('rc=%u', rc)
exit rc
