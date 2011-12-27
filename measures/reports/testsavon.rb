


require 'savon'

%x[wget "http://www.webservicex.net/uszip.asmx?WSDL"]    # This works fine


client = Savon::Client.new do |wsdl, http|
  wsdl.document = "http://www.webservicex.net/uszip.asmx?WSDL"
  http.proxy = "http://gateway.mitre.org:80"
end
STDERR.puts "hooray"
#This fails with Errno::ECONNREFUSED: Connection refused - Connection refused
zipClient = Savon::Client.new "http://www.webservicex.net/uszip.asmx?WSDL"    


