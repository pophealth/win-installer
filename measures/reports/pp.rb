

    require 'nokogiri'
    STDERR.puts "indir = #{ARGV[0]}   outdir = #{ARGV[1]}"
    Dir.foreach(ARGV[0]) do |item|
       next if item == '.' or item == '..'
       fname = "#{ARGV[0]}/#{item}"
       # do work on real items
       STDERR.puts "Processing #{fname}"
       doc = Nokogiri::XML(File.open("#{fname}") ) 
       doc.remove_namespaces!()
       outfp = File.open("#{ARGV[1]}/#{item}","w")
       outfp.puts doc.root
       outfp.close
     end 

