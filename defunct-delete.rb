#!/usr/bin/ruby


class App

  def diag msg
    return unless $VERBOSE
    $stderr.puts msg
    msg
  end

  def initialize argv
    $VERBOSE = true if $stderr.tty?
    @argv = argv
    if @argv.empty?
      @argv = ['/var/log/apache2/access.log.1',
        '/var/log/apache2/access.log.7.gz']
      diag "argv = #{@argv.inspect}"
    end
    @archhosts = {}
    dotfile
    @n = 0
  end

  def dotfile
    fnam = File.join(ENV['HOME'], '.archhost')
    File.open(fnam, 'r') {|fp|
      for line in fp
        next unless /ARCHHOST\s*=\s*(\S+)/ === line
        @archhosts[$1] = true
      end
    }
  rescue Errno::ENOENT
  end

  def checkfile clie, path, size
    return if /\/$/ === path
    return unless /^\/nwp\/a/ === path
    diag "> #{clie} #{path} #{size}"
    unless @archhosts[clie] then
      return diag("unregisterd client: #{clie}")
    end
    begin
      sz = File.stat(path).size
      size = size.to_i
    rescue Errno::ENOENT
      return diag("already removed: #{path}")
    end
    if sz > size then
      return diag("partial transfer: #{path} #{sz}/#{size}")
    end
    File.unlink(path)
    @n += 1
    diag("ok removed: #{path}")
  end

  def logfile ifp
    ifp.each_line{|line|
      next unless /^\S+ (\S+) .*\] "GET (\S+) HTTP\/1\.." 200 (\d+)/ === line
      checkfile($1, $2, $3)
    }
  end

  def endmsg
    return if @n > 0
    msg = "no file removed this time - check config"
    $stderr.puts msg
    puts msg
    exit 16
  end

  def run
    @argv.sort.each{|file|
      diag "reading #{file}"
      case file
      when /\.gz$/ then
        require 'zlib'
        Zlib::GzipReader.open(file){|ifp| logfile(ifp) }
      else
        File.open(file){|ifp| logfile(ifp) }
      end
    }
    endmsg
  end

end

App.new(ARGV).run
