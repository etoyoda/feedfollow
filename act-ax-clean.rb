#!/usr/bin/ruby

archsv="cherrypie"

Dir.glob("/nwp/a?").each{|ax|
  Dir.glob(ax+"/20[0-9][0-9]-[01][0-9]").each{|axym|
    STDERR.puts "scanning #{axym}"
    IO.popen("ssh #{archsv} find #{axym} -type f -ls", "r"){|fp|
      for line in fp
        cell=line.chomp.split(/ +/,11)
        size=cell[6].to_i
        fnam=cell[10]
        next unless File.exist?(fnam)
        st=File.stat(fnam)
        if st.size != size
          STDERR.puts "sz here #{st.size} != archsv #{size} : #{fnam}"
          next
        end
        puts "rm #{fnam}\r"
        begin
          File.delete(fnam)
        rescue
          STDERR.puts "#{$!}\r"
        end
      end
    }
  }
}
