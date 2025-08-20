require 'rubygems/package'
require 'stringio'
require 'tarwriter'
require 'zlib'

ofn = ARGV.shift
unless ofn
  puts "usage: #$0 out input..."
  exit 16
end

h=Hash.new

STDERR.puts "== open #{ofn}"
TarWriter.open(ofn,'w') {|ofp|
  ARGV.each{|arg|
    STDERR.puts "== open #{arg}"
    begin
      File.open(arg,'rb', encoding: 'ASCII-8BIT:ASCII-8BIT') {|ifp|
        if /\.gz$/ === arg then
          ifp = Zlib::GzipReader.new(ifp)
        end
        Gem::Package::TarReader.new(ifp) { |tar|
          tar.each{|ent|
            fn=ent.full_name
            if h[fn] then
              STDERR.puts "dup #{fn}"
              next
            end
            h[fn]=true
            STDERR.puts "add #{fn}"
            ofp.add(fn, ent.read)
          }
          tar.close
        }
      }
    rescue EOFError
    end
  }
}
