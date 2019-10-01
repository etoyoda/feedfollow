#!/usr/bin/ruby

require 'uri'
require 'net/http'
require 'gdbm'
require 'time'
require 'syslog'

fnam = ARGV.shift
limit = (ARGV.shift || '100').to_i
dest = ARGV.shift || 'http://alert-hub.appspot.com/publish'
now = Time.now
queue = []
$logger = Syslog.open('notifygah', Syslog::LOG_PID, Syslog::LOG_NEWS)

GDBM::open(fnam, GDBM::READER){|db|
  for k, v in db
    next unless /^lmt\// === k
    feed = $'
    lmt = Time.parse(v)
    if now - lmt > limit
      $logger.info('skip %g %s', now - lmt, File.basename(feed))
      next
    end
    queue.push feed
  end
}
udest = URI.parse(dest)
rc = 0
for feed in queue
  form = {'hub.mode'=>'publish', 'hub.url'=>feed}
  r = Net::HTTP.post_form(udest, form)
  case r.code
  when /^2/ then 
    $logger.info('ok %s feed=%s', r.code, File.basename(feed))
    rc = 0
  else
    $logger.err('ng %s feed=%s', r.code, File.basename(feed))
    rc = 4
  end
end
$logger.info('rc=%u', rc)
exit rc
