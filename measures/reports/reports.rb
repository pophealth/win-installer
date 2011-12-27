#!/usr/bin/env ruby
## To change this template, choose Tools | Templates
# and open the template in the editor.
#
#

require "set"
require "rubygems"
require "json"
require "mktemp"
require "ap"
include MkTemp


    report = {}
    concepts = {}
    $code_to_concepts = {}


def add_code_to_concept(taxonomy, codes, conceptID)    
   codes.each do |code|
     tax_code = "#{taxonomy}:#{code}"
     $code_to_concepts[tax_code]  ||= [].to_set
     $code_to_concepts[tax_code].add(conceptID)
   end
end

    # Patch the supplied property_json hash with the contents of a patch file named
      # "#{property_file}.patch" and return the result
      def patch_properties(property_file)
        patch_file = "#{property_file}.patch"
        property_json = nil
        if File.exists?(property_file) 
          property_json = JSON.parse(File.read(property_file))

         if File.exists? patch_file
#           STDERR.puts "Patching #{patch_file}"
           patch_json = JSON.parse(File.read(patch_file))

          property_json = property_json.merge(patch_json) do |key, old, new|
            old.merge(new)
          end
         end
 
         property_json
         end
      end


 dir = Dir["/home/saul/src/measures/measure_props/*.json"]
 concept_file_path = "./report.tsv"
 codes_file_path = "./codes.tsv"
  # clobber the concept file.   Each invocation of process_measure will apppend to this file
  file_concepts = File.new(concept_file_path,"w")
  file_codes = File.new(codes_file_path,"w")
  STDERR.puts "Found #{dir.length} xls files in directory #{dir.sort.join("\n")}"
  first = true
# Now, process each xls file
    dir.sort.each  do |jsonfile|
     property_json = patch_properties(jsonfile) 
#    STDERR.puts JSON.pretty_generate(property_json)

     property_json.each_pair do |key,value|
      conceptID = value["standard_concept_id"]
      concept = value['standard_concept']
     report[concept] ||= {'measures'=>[].to_set, 'qds_data_types'=>[].to_set, 'codesets' =>[].to_set, 'concept_ids'=>[].to_set}   #if empty, create an empty hash, with an array of measures in it
     report[concept]['concept'] = value["standard_concept"]
     report[concept]['qds_data_types'].add(value["QDS_data_type"]) 
     report[concept]['measures'].add(value['NQF_id'] || "(none" )
     report[concept]['codesets'].add(value["standard_taxonomy"] || "(none)")
     report[concept]['concept_ids'].add(conceptID)
     report[concept]['standard_category'] = value["standard_category"]
#      STDERR.puts "report[#{concept}] = #{conceptID}  #{value["standard_taxonomy"]}"

     if value["standard_taxonomy"] && value["standard_taxonomy"] != "GROUPING"
         codes = value["standard_code_list"].sub(/ /,'')
         value_set = Set.new codes.split(',')
         add_code_to_concept(value["standard_taxonomy"], value_set, conceptID)         
         if(!concepts[conceptID])
           concepts[conceptID] = {}
           concepts[conceptID][:file] = File.basename(jsonfile)
           concepts[conceptID][:concept] = concept
           concepts[conceptID][:taxonomy] = value["standard_taxonomy"]
           concepts[conceptID][:codes] = value_set
         else
           if concepts[conceptID][:file] == File.basename(jsonfile)
                next
           end
           values = concepts[conceptID][value["standard_taxonomy"]]
           if(values && value_set.difference(values).size > 0)
                STDERR.puts "#{File.basename(jsonfile)}  #{concepts[conceptID][:file]} #{conceptID}   #{value["standard_taxonomy"]}   is INCONSISTENT #{values.size} vs #{value_set.size}"
                STDERR.puts "values #{values.to_a.sort.join(',')}"
                STDERR.puts "value_set #{value_set.to_a.sort.join(',')}"
                STDERR.puts "difference (a-b) #{value_set.difference(values).size}  #{value_set.difference(values).to_a.sort.join(',')}"
                STDERR.puts "difference (b-a) #{values.difference(value_set).size}  #{values.difference(value_set).to_a.sort.join(',')}"
                STDERR.puts "intersection #{values.intersection(value_set).size}   #{values.intersection(value_set).to_a.sort.join(',')}"
                concepts[concept][:codes] = values.intersection(value_set)
           end
           concepts[conceptID][:file] = File.basename(jsonfile)
         end
      end
      end
     end

   # Convert the sets back to arrays
   concepts.each_key do |conceptID|
       concepts[conceptID][:codes] = concepts[conceptID][:codes].to_a.sort
   end

   # Convert the sets back to arrays
   report.each_key do |key|
     report[key]['measures'] = report[key]['measures'].to_a.sort
     report[key]['qds_data_types'] = report[key]['qds_data_types'].to_a.sort
     report[key]['codesets'] = report[key]['codesets'].to_a
     report[key]['concept_ids'] = report[key]['concept_ids'].to_a.sort
   end
   # STDERR.puts JSON.pretty_generate(report)
    file_concepts.puts "standard_concept\tstandard_category\tqds_data_types\tstandard_concept_id\tcodesets\tmeasures"
   allkeys = report.keys
   allkeys.each do |key|
    value = report[key]
    file_concepts.puts "#{key}\t#{value['standard_category']}\t#{value['qds_data_types']}\t#{value['codesets']}\t#{value['concept_ids']}\t#{value['measures']}"
   end
   file_concepts.close
    file_codes.puts "concept_id\tstandard_concept\tcodeset\tcodes"
  concepts.each_key do |conceptID|
       file_codes.puts "#{conceptID}\t#{concepts[conceptID][:concept]}\t#{concepts[conceptID][:taxonomy]}\t#{concepts[conceptID][:codes].join(",")}"
   end

 file_codes.close
   $code_to_concepts.each_key do | tax_code |
     if($code_to_concepts[tax_code].size > 1)
          STDERR.puts "Code #{tax_code} belongs to multiple concepts"
          $code_to_concepts[tax_code].to_a.sort.each do |conceptID|
             STDERR.puts "\t#{conceptID}\t#{concepts[conceptID][:concept]}"
          end
     end
   end





  




