# This script will read a JSON hash, and add codes to it


require 'net/https'
require 'rubygems'
require 'json'
require 'pathname'
require 'savon'
require 'nokogiri'


sin = "LDL-CHOLESTEROL"


 $proxy_grant_ticket = ""






def get_proxy_grant_ticket(client)
 response = client.request :get_proxy_grant_ticket do  
  soap.body = {  :in0 => "skravitz" ,
                  :in1 => "Ayelet#0504"
              }
  end
  proxy = response[:get_proxy_grant_ticket_response][:get_proxy_grant_ticket_return]
 STDERR.puts "$proxy_grant_ticket = #{proxy}"
 return proxy
end


def get_proxy_ticket(client, proxy)
response = client.request :get_proxy_ticket do
  soap.body = { :in0 => proxy ,
                :in1 => "http://umlsks.nlm.nih.gov"}
 end
 ticket = response[:get_proxy_ticket_response][:get_proxy_ticket_return]
#  STDERR.puts "ticket = #{ticket}"
 return ticket
end


def findCUI(type, term)  #type = ByNormString, ByWord, ByExact
  
  proxy_ticket = get_proxy_ticket($authorizationClient, $proxy_grant_ticket)
  STDERR.puts "===findCUI#{type}====term = #{term}"

  response = $umlsClient.request "findCUI#{type}" do
    soap.body = { "ConceptId#{type[2-type.length]}Request" =>
                 { :casTicket => proxy_ticket,
                 :searchString => term,
                 :release => "2010AB",
                 :includeSuppressibles => false,
#                 "SABs" => ["LNC"],
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
 return(concepts)
end

 def getConceptProperties(concept, codeset)
    proxy_ticket = get_proxy_ticket($authorizationClient, $proxy_grant_ticket)
    response = $umlsClient.request "getConceptProperties" do
   soap.body = { "getConceptPropertiesRequest" =>
                 { :casTicket => proxy_ticket,
                 "CUI" => concept,
                 :release => "2010AB",
                 :includeTerminology => 1,
                  "SABs" => [codeset],
                 "CVF" => 1023
                 }
               }
    end
    doc = Nokogiri::XML(response.to_xml) 
    codenodes = doc.xpath('//code')
    codes = [].to_set
    codenodes.each do |node|
         codes.add(node.content)
    end
    return codes.to_a 
 end



def initialize_umls
STDERR.puts "HOORAY 1"
 Savon.configure do |config|
  config.log = false            # disable logging
  config.log_level = :error
 end
  HTTPI::log = false

$authorizationClient = Savon::Client.new do |wsdl, http|
  wsdl.document = "https://uts-ws.nlm.nih.gov/authorization/services/AuthorizationPort?WSDL"
#  http.proxy = "http://gateway-w.mitre.org:80"
 end

 $proxy_grant_ticket = get_proxy_grant_ticket($authorizationClient)
 proxy_ticket = get_proxy_ticket($authorizationClient, $proxy_grant_ticket)


$umlsClient = Savon::Client.new do
   wsdl.document = "/home/saul/Downloads/UMLSKSService.xml"
end

#STDERR.puts $umlsClient.wsdl.soap_actions

 proxy_ticket = get_proxy_ticket($authorizationClient, $proxy_grant_ticket)
 STDERR.puts "HOORAY 2"
end

def getCodes(term, codeset)

 concepts = findCUI("ByExact", term )
 STDOUT.puts "> Input concept: #{term}"
 STDOUT.puts "  #{concepts.keys.size} concepts - #{concepts.keys.join(',')} #{concepts.values.join(',')}"
 codes = []
 concepts.each_pair do |c,n|
   codes = codes | getConceptProperties(c,codeset)   # returns an array of codes
 end
 STDERR.puts "#{codeset} Codes are: #{codes.join(",")}" 

 return(codes)
end

initialize_umls
getCodes("Hba1c","SNOMEDCT")
getCodes("Total Cholesterol","SNOMEDCT")


