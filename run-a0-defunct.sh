#!/bin/bash
set -Ceuo pipefail

: ${ACLOG:='/var/log/apache2/access.log.1'}
: ${RUBY:='/usr/bin/ruby'}

if [ -f ${HOME}/.archhost ]; then
  . ${HOME}/.archhost
fi
: ${ARCHHOST:='localhost'}
export ARCHHOST

${RUBY} -- - ${ACLOG} <<-'END_OF_RUBY'
  archhost = ENV['ARCHHOST']
  ARGF.each_line {|line|
    next unless /^\S+ (\S+) .*\] "GET (\S+[^\/]) HTTP\/1\.\d+" 200 (\d+) / === line
    clie, path, size = $1, $2, $3
    size = size.to_i
    next unless /^\/nwp\/a0\// === path
    if clie != archhost
      $stderr.puts "BADHOST #{clie} #{archhost}"
      next
    end
    begin
      fst = File.stat(path)
    rescue Errno::ENOENT
      $stderr.puts "ENOENT #{path}"
      next
    end
    unless size > fst.size
      $stderr.puts "MIDWAY #{path} #{fst.size} #{size} #{size * 1000 / fst.size}"
      next
    end
    begin
      # $stderr.puts "unlink #{path}"
      File.unlink(path)
    rescue Errno::EACCES
      $stderr.puts "Permission denied: unlink #{path}"
      next
    end
  }
END_OF_RUBY
