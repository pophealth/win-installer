# This script will take a directory of CCR's and run them through the preprocessor. It will output
# them into a different directory. It uses the first argument to the script as the directory of CCR's.
# It does not perform any checks to ensure that the document is a CCR, it will only look to make sure
# that the file ends in .xml. It then preprocesses the file and outputs it into the clean directory.
# The clean directory is specified by the second argument passed to the script.

ccr_dir = nil
clean_dir = nil

def chop(path)
  if path[-1] == '/'
    path.chop
  else
    path
  end
end

if ARGV[0] && ARGV[0]
  if File.exists?(ARGV[0])
    ccr_dir = chop(ARGV[0])
  else
    raise "Could not find the directory #{ARGV[0]}"
  end
  clean_dir = chop(ARGV[1])
  Dir.mkdir(clean_dir) unless File.exists?(clean_dir)
else
  raise "Please specify directories for CCR's and where the pre-processed output should be placed"
end

require 'rubygems'
require 'pathname'
require 'java'
require 'json'

Dir.glob('jars/*.jar').each do |jar_file|
  require jar_file
end

import javax.xml.bind.JAXBContext
import org.ohd.pophealth.preprocess.Scanner
import java.io.FileOutputStream
import java.io.PrintStream
import javax.xml.bind.JAXBContext
import java.io.InputStream
import java.io.FileInputStream
import java.io.FileWriter

jc = JAXBContext.new_instance("org.astm.ccr")
unmarshaller = jc.create_unmarshaller()
marshaller = jc.create_marshaller()
summaryfn = clean_dir + '/' + "summary.out"
summaryfn_uniq = clean_dir + '/' + "summary.out.uniq"
summaryfn_uniq_json = clean_dir + '/' + "summary.out.uniq.json"
STDERR.puts "summary in #{summaryfn} and #{summaryfn_uniq}"

summaryps = PrintStream.new(FileOutputStream.new(summaryfn))

#pp = PreProcessor.new('umls_db.cfg', 'lvg_db.cfg')
 scan = Scanner.new(summaryps)

Dir.glob(ccr_dir + '/*.xml').each do |ccr_file|
#  STDOUT.puts "Processing #{ccr_file}"
  ccr = unmarshaller.unmarshal(FileInputStream.new(ccr_file))
  new_ccr = scan.pre_process(ccr)
  fw = FileWriter.new(clean_dir + '/' + File.basename(ccr_file))
  marshaller.marshal(new_ccr, fw)
  fw.close

end
summaryps.close
%x[sort #{summaryfn} | uniq > #{summaryfn_uniq}]

terms = {}
File.open(summaryfn_uniq, "r") do |infile|
     while (line = infile.gets)
          l = line.dup.split(";;")
          if(!terms[l[2]]) then
             terms[l[2].dup] = { :type => l[0].dup, :subtype => l[1].dup, :vocab => {} }
          end
          terms[l[2]][:vocab] [ l[3].dup.strip] = "none"
    end
end



jsf = File.new(summaryfn_uniq_json,"w");
jsf.puts JSON.pretty_generate(terms)
jsf.close

jsif = File.new(summaryfn_uniq_json,"r");
lines = jsif.read

new_terms = JSON.parse(lines)

STDERR.puts "avocado = #{new_terms["avocado"]}"






