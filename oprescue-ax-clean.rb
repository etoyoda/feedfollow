#!/usr/bin/ruby

origsv="ika.toyoda-eizi.net"
DAY = 86400
thr = Time.now.utc - DAY * 4

Dir.glob("/nwp/a?").each{|ax|
  Dir.glob(ax+"/20[0-9][0-9]-[01][0-9]").each{|axym|
    puts ": scanning #{axym}"
    IO.popen("ssh #{origsv} find #{axym} -type f -ls", "r"){|fp|
      for line in fp
        cell=line.chomp.split(/ +/,11)
        size=cell[6].to_i
        fnam=cell[10]
        next unless File.exist?(fnam)
        st=File.stat(fnam)
        if st.size != size
          puts ": sz here #{st.size} != origsv #{size} : #{fnam}"
          next
        end
        if st.mtime > thr
          puts ": keep new #{st.mtime} #{fnam}"
          next
        end
        puts "[ #{orighost} = `hostname` ] && rm #{fnam}\r"
      end
    }
  }
}
