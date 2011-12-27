

    require 'nokogiri'
    require 'json'


       doc = Nokogiri::XML(File.open(ARGV[0]) ) 
       STDERR.puts doc.root
       doc.remove_namespaces!()
       adescription = doc.xpath("//Encounter/Description")[0]
       Nokogiri::XML::Builder.with(adescription) do |xml|
        xml.Code {
           xml.CodingSystem "snomedct"
           xml.value "32333"
           xml.version "someversion"
        }
        end
       STDERR.puts doc.root





