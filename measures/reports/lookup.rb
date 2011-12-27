# This script will take a directory of CCR's and run them through the preprocessor. It will output
# them into a different directory. It uses the first argument to the script as the directory of CCR's.
# It does not perform any checks to ensure that the document is a CCR, it will only look to make sure
# that the file ends in .xml. It then preprocesses the file and outputs it into the clean directory.
# The clean directory is specified by the second argument passed to the script.


require 'rubygems'
require 'json'
require 'pathname'
require 'savon'
require 'nokogiri'

vocab = ["LOINC"]

# sout = pp.addCode(sin, vocab)

#puts "Translate #{sin} ==> #{mutate}, #{details}"

class  Umls_ticket
   def initialize
      @proxy_grant_ticket = ""
      @authorizationClient = Savon::Client.new "/home/saul/Downloads/AuthorizationPort.xml"
#      @authorizationClient = Savon::Client.new do
 #        wsdl.document = "/home/saul/Downloads/AuthorizationPort.xml"
 #        proxy  = "http://gatekeeper.mitre.org:80"
#      end
       response = @authorizationClient.request :get_proxy_grant_ticket do
            soap.body = { :in0 => "skravitz" ,
                          :in1 => "Ayelet#0504"}
        end
       @proxy = response[:get_proxy_grant_ticket_response][:get_proxy_grant_ticket_return]
       STDERR.puts "proxy_grant_ticket = #{proxy}"
  end

 
    def get_proxy_ticket
      response = @authorizationClient.request :get_proxy_ticket do
           soap.body = { :in0 => @proxy ,
                :in1 => "http://umlsks.nlm.nih.gov"}
       end
      ticket = response[:get_proxy_ticket_response][:get_proxy_ticket_return]
#  STDERR.puts "ticket = #{ticket}"
      return ticket
    end
end




class Umls
  def initialize
     @umls_ticket = Umls_ticket.new
     @proxy_ticket = @umls_ticket.get_proxy_ticket
     Savon.configure do |config|
          config.log = false            # disable logging
          config.log_level = :info
      end
      HTTPI::log = false
      @umlsClient = Savon::Client.new do
           wsdl.document = "/home/saul/Downloads/UMLSKSService.xml"
      end
  end
  
  def findCUIbyWord(sin)
     @proxy_ticket = @umls_ticket.get_proxy_ticket
     STDERR.puts "===findCUIByWord== #{sin} =="
     response = umlsClient.request "findCUIByWord" do
     soap.body = { "findCUIByWordRequest" =>
                 { :casTicket => proxy_ticket,
                 "searchString" => sin,
                 :release => "2010AB",
#                 "SABs" => ["SNOMEDCT"],
                 "language" => "ENG"
                 }
                 }
      end
     rh = response.to_hash[:multi_ref]
     rh.each do |e|
#  STDERR.puts "#{e}"
        if e.is_a?( Hash) && e[:cui] then
            STDOUT.puts "cui: #{e[:cui]}   cn: #{e[:cn]}"
        end
     end
   end
end

umls = Umls.new

umls.findCUIbyWord("Systolic Blood Pressure")

=begin
 proxy_ticket = get_proxy_ticket(authorizationClient, proxy_grant_ticket)
STDERR.puts "===findCUIByNormString===="

response = umlsClient.request "findCUIByNormString" do
   soap.body = { "ConceptIdNormStringRequest" =>
                 { :casTicket => proxy_ticket,
                 :searchString => sin,
                 :release => "2010AB",
                 :includeSuppressibles => true,
#                 "SABs" => ["LNC","SNOMEDCT"],
                 "language" => "ENG"
                 }
                 }
end
 proxy_ticket = get_proxy_ticket(authorizationClient, proxy_grant_ticket)
STDERR.puts "===findCUIByExact===="

response = umlsClient.request "findCUIByExact" do
   soap.body = { "ConceptIdExactRequest" =>
                 { :casTicket => proxy_ticket,
                 :searchString => sin,
                 :release => "2010AB",
                 :includeSuppressibles => true,
#                 "SABs" => ["LNC","SNOMEDCT"],
                 "language" => "ENG"
                 }
                 }
end


concepts = {}
# STDERR.puts "response = #{response.to_hash}"
rh = response.to_hash[:multi_ref]
rh.each do |e|
#  STDERR.puts "#{e}"
  if e.is_a?( Hash) && e[:cui] then
     STDOUT.puts "cui: #{e[:cui]}   cn: #{e[:cn]}"
     concepts[e[:cui]] = e[:cn]
  end

end
 STDOUT.puts "> Input concept: #{sin}"
 concepts.each_pair do |c,n|
 STDOUT.puts "=======================querying for concept #{c} ============================"
 proxy_ticket = get_proxy_ticket(authorizationClient, proxy_grant_ticket)
  response = umlsClient.request "getConceptProperties" do
   soap.body = { "getConceptPropertiesRequest" =>
                 { :casTicket => proxy_ticket,
                 "CUI" => c,
                 :release => "2010AB",
                 :includeTerminology => 1,
                  "SABs" => ["LNC"],
                 "CVF" => 1023
                 }
                 }
   end

 #STDERR.puts "#{response.to_hash}"
 doc = Nokogiri::XML(response.to_xml) 
 codenodes = doc.xpath('//code')
 codes = {}
codenodes.each do |node|
# STDERR.puts "codes: #{node.content}"
# STDERR.puts "parent = #{node.parent}" 
 sab = node.parent.xpath('//SAB')
 key = "#{sab[0].content}.#{node.content}"
# STDERR.puts "codes: #{key}"
 codes[key] = key
end

STDOUT.puts "> sconcept #{c} #{n} has IDs #{codes.keys} ============================"

end
=end

