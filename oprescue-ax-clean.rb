#!/usr/bin/ruby

require 'time'

origsv="ika.toyoda-eizi.net"
DAY = 86400

Dir.glob("/nwp/a?").each{|ax|
    puts ": scanning #{ax}"
    IO.popen("ssh #{origsv} 'LC_ALL=C find #{ax}/ -type f -ls'", "r"){|fp|
      for line in fp
        cell=line.chomp.split(/ +/,12)
        size=cell[7].to_i
        fnam=cell[11]
        mtime=Time.parse(cell[8..10].join(' '))
        next unless File.exist?(fnam)
        st=File.stat(fnam)
        if st.size != size
          puts ": sz origsv #{size} != archsv #{st.size} : #{fnam}"
          next
        end
        if st.mtime < mtime
          puts ": mtime origsv #{mtime} > archsv #{st.mtime} #{fnam}"
          next
        end
        # never remove files on archsv, so hostname is tested
        puts "[ #{origsv} = `hostname` ] && rm #{fnam}"
      end
    }
}
puts ": run above script on #{origsv}"
