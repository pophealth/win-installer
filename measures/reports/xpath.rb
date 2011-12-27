

    require 'nokogiri'
    require 'json'

$coded_values = {}
$uncoded = {}

def normalize_coding_system(code)
   lookup = {
             "lnc" => "LOINC",
             "loinc" => "LOINC",
             "cpt" => "CPT",
             "cpt-4" => "CPT",
             "snomedct" => "SNOMEDCT",
             "snomed-ct" => "SNOMEDCT",
             "rxnorm" => "Rxnorm",
             "icd9-cm" => "ICD9",
             "icd9" => "ICD9"
   }
   codingsystem = lookup[code.xpath('./CodingSystem')[0].content.downcase]
   if(codingsystem)
       code.xpath('./CodingSystem')[0].content = codingsystem
   end
end

def add_code(descnode, vocabs)
     added_code = false
     text = descnode.xpath("./Text")[0]
      coded_value = $coded_values[text.content]
     if !coded_value 
#          STDERR.puts "NOT Found string: #{text} "
        return false;
#     else
#          STDERR.puts "Found string: #{text} #{JSON.pretty_generate(coded_value)}"
     end
     
     if !vocabs.is_a?(Array)
        vocaba = [vocabs]
     else
        vocaba = vocabs 
     end
     vocaba.each do |vocab|
       code = coded_value["Codes"][vocab]
#       STDERR.puts "code = #{code}"
       if(!code || code == "none")
#          STDERR.puts "#{text} Vocabulary #{vocab} code NOT FOUND"
          next
       end
   added_code = true
   $vocab = vocab
   $value = code
     Nokogiri::XML::Builder.with(descnode) do |xml|
        xml.Code {
           xml.CodingSystem $vocab
           xml.value $value
        }
    
    end

#   STDERR.puts "Updated: #{descnode.document.root}"
   end
    return added_code;
end

def add_uncoded(text, type, subtype, vocabs)
   vocaba = []
   if !$uncoded[text]
     if !vocabs.is_a?(Array)
        vocaba = [vocabs]
#        STDERR.puts "vocabs_is_a?(Array) #{vocabs.is_a?(Array)}   vocabs = #{vocabs}"
     else
        vocaba = vocabs 

     end
      $uncoded[text] = { :count => 0, :Type=>type, :SubType => subtype, :Codes => {} }
   end
    vocaba.each do | vocab |
         $uncoded[text][:Codes][vocab] = "none"
    end
    $uncoded[text][:count] += 1
end



def find_uncoded_products(doc)
     uncoded_products = []
     products = doc.xpath("//Product")
#    STDERR.puts "Products: #{products.size}" 
    products.each do | product | 
        productName = product.xpath("./ProductName")[0]
        brandName = product.xpath("./BrandName")[0]
#        STDERR.puts productName.xpath("./Text")[0]
#        STDERR.puts "*Product Code: #{product.xpath("./ProductName/Code")}"
        codes = product.xpath("./ProductName/Code")
        found_code = false
        if codes 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" ||
                 code.xpath("./CodingSystem")[0].content == "Rxnorm"
                     found_code = true
              end
           end
        end
#     STDERR.puts "productName: #{productName}"
        if !found_code  && !add_code(productName, ["Rxnorm"])
           uncoded_products.push(productName)
           add_uncoded(productName.xpath("./Text")[0].content, "Product", "ProductName", "Rxnorm");
        end
 #      STDERR.puts product.xpath("./BrandName/Text")
        codes = product.xpath("./BrandName/Code")
 #      STDERR.puts "*Brand Code: #{codes}"
        found_code = false
        if codes 
            codes.each do | code | 
             normalize_coding_system(code)
             value = code.xpath("./Value")[0]
             codingsystem = code.xpath("./CodingSystem")[0]
             if value.content != "0" ||
                 codingsystem.content == "Rxnorm"
                     found_code = true
              end
           end
        end
        if !found_code  && !add_code(brandName, ["Rxnorm"])
           uncoded_products.push(brandName)
           add_uncoded(brandName.xpath("./Text")[0].content, "Product", "BrandName", "Rxnorm");
        end
     end
    return uncoded_products
end

def find_uncoded_encounters(doc)
     uncoded_encounters = []
     encounters = doc.xpath("//Encounters/Encounter")
#    STDERR.puts "Encounters: #{encounters.size}" 
    encounters.each do | encounter | 
        codes = encounter.xpath("./Description/Code")
        text = encounter.xpath("./Description/Text")[0].content
#        STDERR.puts "*Encounter Code: #{codes}"
        found_code = false
        if codes 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&
                 code.xpath("./CodingSystem")[0].content == "CPT" 
                     found_code = true
              end
           end
        end
        if !found_code  && !add_code(encounter.xpath("./Description")[0], ["CPT"])
           uncoded_encounters.push(encounter)
           add_uncoded(text, "Encounter", "Encounter", [:CPT])
        end
    end
    return uncoded_encounters
end

def find_uncoded_problems(doc)
     uncoded_problems = []
     problems = doc.xpath("//Problem")
#     STDERR.puts "Problems: #{problems.size}" 
    problems.each do | problem | 
        codes = problem.xpath("./Description/Code")
#       STDERR.puts "*Problem Code: #{codes}"
        found_code = false
        if codes 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&
                 (code.xpath("./CodingSystem")[0].content == "SNOMEDCT" ||
                  code.xpath("./CodingSystem")[0].content == "ICD9")
                     found_code = true
              end
           end
        end
        if !found_code  && !add_code(problem.xpath("./Description")[0], ["SNOMEDCT", "ICD9"])
           uncoded_problems.push(problem)
           add_uncoded(problem.xpath("./Description/Text")[0].content, "Problem", "Problem", [ :SNOMEDCT, "ICD9" ]);
        end
    end
    return uncoded_problems
end


def find_uncoded_alerts(doc)
     uncoded_alerts = []
     found_code = false
    alerts = doc.xpath("//Alerts/Alert")
#    STDERR.puts "Alerts: #{alerts.size}" 
    alerts.each do | alert | 
#        STDERR.puts "*Alert : #{alert}"
        codes = alert.xpath("./Description/Code")
#        STDERR.puts "*Alert Code: #{codes}"
        found_code = false
        if codes 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&
                 (code.xpath("./CodingSystem")[0].content == "Rxnorm")
                     found_code = true
              end
           end
        end
        if !found_code &&  !add_code(alert.xpath("./Description")[0], ["Rxnorm"])
           uncoded_alerts.push(alert)
           add_uncoded(alert.xpath("./Description/Text")[0].content, "Alert", "Alert", [ "Rxnorm"]);
        end
    end
    return uncoded_alerts
end

def find_uncoded_results(doc,type)
     results = doc.xpath("//" + type + "/Result")
     uncoded_results = []
#    STDERR.puts "#{type} Results: #{results.size}" 
    results.each do | result | 
        codes = result.xpath("./Description/Code")
#        STDERR.puts "*Result Code: #{codes}"
        found_code = false
        if !codes.empty? 
            codes.each do | code | 
              normalize_coding_system(code)
              if code.xpath("./Value")[0].content != "0" &&
                 (code.xpath("./CodingSystem")[0].content == "SNOMEDCT" ||
                  code.xpath("./CodingSystem")[0].content == "LOINC")
                     found_code = true
              end
           end
        end
        # If we didn't find anything, try to add it.
#        STDERR.puts "*Result: #{result}"
        if !found_code  && !add_code(result.xpath("./Description")[0], ["SNOMEDCT", "LOINC"])
           uncoded_results.push(result)
           add_uncoded(result.xpath("./Description/Text")[0].content, type, "Result", [ :SNOMEDCT, "LOINC" ]);
        end
        test = result.xpath("./Test/Description")
        if !test.empty? 
        # STDERR.puts "*Test : #{test}"
         codes = test.xpath("./Code")
         found_code = false
         if !codes.empty?
             codes.each do | code | 
               normalize_coding_system(code)
               if code.xpath("./Value")[0].content != "0" &&
                  (code.xpath("./CodingSystem")[0].content == "SNOMEDCT" ||
                   code.xpath("./CodingSystem")[0].content == "LOINC")
                      found_code = true
               end
            end
         end
         if !found_code  && !add_code(test[0], ["SNOMEDCT", "LOINC"])
            uncoded_results.push(test)
            add_uncoded(test.xpath("./Text")[0].content, type, "Test", [ :SNOMEDCT, "LOINC" ]);
         end  
        end  
    end
    return uncoded_results
end

 
def process_doc(doc)
    doc.remove_namespaces!()

    encounters = doc.xpath("//Encounters/Encounter")
    uncoded_encounters = find_uncoded_encounters(doc)
    uncoded_products = find_uncoded_products(doc)
    uncoded_problems = find_uncoded_problems(doc)
    uncoded_vital_results = find_uncoded_results(doc, "VitalSigns")
    uncoded_test_results = find_uncoded_results(doc, "Results")
    uncoded_alerts = find_uncoded_alerts(doc)
    perfect = uncoded_encounters.size > 0 && uncoded_products.size > 0 && uncoded_problems.size > 0 && uncoded_vital_results.size > 0 && uncoded_test_results.size > 0 && uncoded_alerts.size > 0
    if perfect 
         STDERR.puts "***PERFECT***"
    end
    STDERR.puts "e: #{uncoded_encounters.size} prod: #{uncoded_products.size}  prob: #{uncoded_problems.size} v: #{uncoded_vital_results.size} t: #{uncoded_test_results.size} a: #{uncoded_alerts.size}"
end


   indir = ARGV[0]
   outdir = ARGV[1]
   outfile = ARGV[2]
   hashfile = ARGV[3]

  STDERR.puts "indir = #{indir}  outdir = #{outdir} outfile = #{outfile} hashfile = #{hashfile}"

  STDERR.puts "Opening #{outfile} for write"
  outputfp = File.open(outfile,"w")
 
  if(hashfile)
     STDERR.puts "Opening #{hashfile} for read"
     $coded_values = JSON.parse(File.open(hashfile).read)
  else
     $coded_values = {}
  end

  STDERR.puts $coded_values["N/A"]    # just testing that the read succeeded

  
   STDERR.puts "indir = #{indir}"  
    Dir.foreach(indir) do |item|
       next if item == '.' or item == '..'
       # do work on real items
       STDERR.puts "Processing #{indir}/#{item}"
       doc = Nokogiri::XML(File.open("#{indir}/#{item}") ) 
       process_doc(doc)
       outfp = File.open("#{outdir}/#{item}","w")
       outfp.puts doc.root
      outfp.close
     end 

  outputfp.puts JSON.pretty_generate($uncoded) 




