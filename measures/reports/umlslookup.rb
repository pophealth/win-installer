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
#  STDERR.puts "===findCUI#{type}====term = #{term}"

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
     STDERR.puts "cui: #{e[:cui]}   cn: #{e[:cn]}"
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
# STDERR.puts "> Input concept: #{term}"
# STDERR.puts "  #{concepts.keys.size} concepts - #{concepts.keys.join(',')} #{concepts.values.join(',')}"
 codes = []
 concepts.each_pair do |c,n|
   codes = codes | getConceptProperties(c,codeset)   # returns an array of codes
 end
 # STDERR.puts "#{codeset} Codes are: #{codes.join(",")}" 

 return(codes)
end

  uncoded_encounters = ["99201", "99202", "99203", "99204",
        "99205", "99211", "99212", "99213", "99214", "99215", "99217", "99218", "99219",
        "99220", "99241", "99242", "99243", "99244", "99245", "99341", "99342", "99343",
        "99344", "99345", "99347", "99348", "99349", "99350", "99384", "99385", "99386",
        "99387", "99394", "99395", "99396", "99397", "99401", "99402", "99403", "99404",
        "99411", "99412", "99420", "99429", "99455", "99456"]

   infile = ARGV[0]
   outfile = ARGV[1]

  STDERR.puts "Opening #{outfile} for write"
  outfp = File.open(outfile,"w")
 
  STDERR.puts "Opening #{infile} for read"
  uncoded_terms = JSON.parse(File.open(infile).read)
  STDERR.puts uncoded_terms["N/A"]    # just testing that the read succeeded
   initialize_umls

  uncoded_terms.each_pair do |key,value|
#   STDERR.puts "key = #{key}  and value = #{value}   #{value["Codes"]} #{value["Codes"].class.name}"
   value["Codes"].each_pair do |codeset,v|
     if(codeset == "ICD9" && v == "none")
#           STDERR.puts v
           key[/(.*) ([\dA-Z]\d*[\.]*\d*)/]
           data = Regexp.last_match
           if(data && data.size == 3)
              icd9_code = data[2]
#              STDERR.puts "ICD9 #{icd9_code} found in #{key}"
              uncoded_terms[key]["Codes"]["ICD9"] = [icd9_code]
           else
              codes = getCodes(key,"ICD9")
              if(codes.size > 0)
                uncoded_terms[key]["Codes"]["ICD9"] = codes
                
              end
           end
     end
     if(codeset == "Rxnorm" && v == "none")
              codes = getCodes(key,"RXNORM")
              if(codes.size > 0)
                uncoded_terms[key]["Codes"]["Rxnorm"] = codes
#               STDERR.puts "Rxnorm Matched #{key} to #{codes.join(",")}"
              end
     end
     if(codeset == "LOINC" && v == "none")
              codes = getCodes(key,"LNC")
              if(codes.size > 0)
                uncoded_terms[key]["Codes"]["LOINC"] = codes
#               STDERR.puts "LOINC Matched #{key} to #{codes.join(",")}"
              end
     end
     if(codeset == "CPT" && v == "none")
              codes = getCodes(key,"CPT")
              if(codes.size > 0)
                uncoded_terms[key]["Codes"]["CPT"] = codes
#               STDERR.puts "CPT Matched #{key} to #{codes.join(",")}"
              end
              if value["Type"] == "Encounter"
                   if uncoded_terms[key]["Codes"]["CPT"] == "none"
                       uncoded_terms[key]["Codes"]["CPT"] = uncoded_encounters
                   else
                       uncoded_terms[key]["Codes"]["CPT"] = uncoded_terms[key]["Codes"]["CPT"] | uncoded_encounters
                   end
              end
     end
     if(codeset == "SNOMEDCT" && v == "none")
              codes = getCodes(key,"SNOMEDCT")
              if(codes.size > 0)
                uncoded_terms[key]["Codes"]["SNOMEDCT"] = codes
 #              STDERR.puts "SNOMEDCT Matched #{key} to #{codes.join(",")}"
              end
     end
#     STDERR.puts JSON.pretty_generate(uncoded_terms[key]) 
   end
end

     STDERR.puts "Writing output to #{outfile}"
     outfp.puts JSON.pretty_generate(uncoded_terms) 

