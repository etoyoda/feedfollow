#!/usr/bin/ruby

require 'time'

class App

  def initialize argv
    @db = {}
  end

  def register tag, time, line
    @db[tag] = {} unless @db[tag]
    row = @db[tag]
    row['count'] = row['count'].to_i + 1
    if /elapsed ([.0-9]+)/ === line then
      row['elapsed'] = row['elapsed'].to_f + Float($1)
    end
    if /012job \d+ at / === line then
      row['batch'] = row['batch'].to_i + 1
    end
    if /rc=(\d+)/ === line then
      rc = $1
      rc = '0' if tag == 'feedstore' and rc == '3' or rc == '11'
      unless rc == '0' then
        row['err'] = '' unless row['err']
        row['err'] += " #{rc},#{time.strftime('%H:%M')}"
      end
    end
    if /"200"=>(\d+)/ === line then
      row['dlfiles'] = row['dlfiles'].to_i + Integer($1)
    end
    if /"([45]\d\d)"=>\d+/ === line then
      rc = $1
      row['err'] = '' unless row['err']
      row['err'] += " #{rc},#{time.strftime('%H:%M')}"
    end
    if /"(wait\w+)"=>\d+/ === line then
      rc = $1
      row['err'] = '' unless row['err']
      row['err'] += " #{rc},#{time.strftime('%H:%M')}"
    end
    if /rescue=([:\w]+)/ === line then
      rc = $1.sub(/[:\w]+::/, '')
      row['err'] = '' unless row['err']
      row['err'] += " #{rc},#{time.strftime('%H:%M')}"
    end
    if /(\S+) invoked oom-killer/ === line then
      cause = $1
      row['oom'] = '' unless row['oom']
      row['oom'] += " #{cause},#{time.strftime('%H:%M')}"
    end
  end

  def dump
    @db.keys.sort.each {|tag|
      row = ['tag:' + tag]
      @db[tag].keys.sort.each {|item|
        val = @db[tag][item]
        case val
        when String
          val = val.gsub(/\s+/, '|')
        when Float
          val = '%-9.3f' % val
        end
        row.push "#{item}:#{val}"
      }
      puts row.join("\t")
    }
  end

  def run argf
    argf.set_encoding('ASCII-8BIT')
    argf.each_line {|line|
      raise "bad time format <#{line}>" unless /^(\w\w\w [ 123]\d \d\d:\d\d:\d\d)/ === line
      time = Time.parse($1)
      next unless /(oom-killer|run-prep|syndl|feedstore|wxmon|jmxscan|pshbspool|tarwriter|notifygah)/ === line
      tag = $1
      tag = $1 if /syndl\.(\w+)/ === line
      tag = $1 if /"tag"=>"(\w+)"/ === line
      register(tag, time, line)
    }
    dump
  end

end

App.new(ARGV).run(ARGF)
