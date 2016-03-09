require 'uri'

module Mei
  class Loc

    include Mei::WebServiceBase

    def initialize(subauthority, solr_field)
      @subauthority = subauthority
      @solr_field = solr_field
      #RestClient.enable Rack::Cache
    end

    def search q
      @raw_response = skip_cache_request(build_query_url(q))
      parse_authority_response
    end


    def build_query_url q
      escaped_query = URI.escape(q)
      authority_fragment = Qa::Authorities::Loc.get_url_for_authority(@subauthority) + URI.escape(@subauthority)
      return "http://id.loc.gov/search/?q=#{escaped_query}&q=#{authority_fragment}&format=json"
    end

    # Reformats the data received from the LOC service
    def parse_authority_response
      threaded_responses = []
      #end_response = Array.new(20)
      end_response = []
      position_counter = 0
      @raw_response.select {|response| response[0] == "atom:entry"}.map do |response|
          threaded_responses << Thread.new(position_counter) { |local_pos|
            end_response[local_pos] = loc_response_to_qa(response_to_struct(response), position_counter)
          }
          position_counter+=1
      end
      threaded_responses.each { |thr|  thr.join }
      end_response
    end

    # Simple conversion from LoC-based struct to QA hash
    def loc_response_to_qa(data, counter)
      json_link = data.links.select { |link| link.first == 'application/json' }
      if json_link.present?
        json_link = json_link[0][1]
        #puts 'Json Link is: ' + json_link
        #item_response = get_json(json_link.gsub('.json','.rdf'))
        #item_response = Nokogiri::XML(get_xml(json_link.gsub('.json','.rdf'))).remove_namespaces!

        broader, narrower, variants = get_skos_concepts(json_link.gsub('.json',''))
      end

      #count = ActiveFedora::Base.find_with_conditions("subject_tesim:#{data.id.gsub('info:lc', 'http://id.loc.gov').gsub(':','\:')}", rows: '100', fl: 'id' ).length
      #FIXME
      count = ActiveFedora::Base.find_with_conditions("#{@solr_field}:#{solr_clean(data.id.gsub('info:lc', 'http://id.loc.gov'))}", rows: '100', fl: 'id' ).length

      if count >= 99
        count = "99+"
      else
        count = count.to_s
      end


      {
          "uri_link" => data.id.gsub('info:lc', 'http://id.loc.gov') || data.title,
          "label" => data.title,
          "broader" => broader,
          "narrower" => narrower,
          "variants" => variants,
          "count" => count
      }
    end


    def solr_clean(term)
      return term.gsub('\\', '\\\\').gsub(':', '\\:').gsub(' ', '\ ')
    end

    def response_to_struct response
      result = response.each_with_object({}) do |result_parts, result|
        next unless result_parts[0]
        key = result_parts[0].sub('atom:', '').sub('dcterms:', '')
        info = result_parts[1]
        val = result_parts[2]

        case key
          when 'title', 'id', 'name', 'updated', 'created'
            result[key] = val
          when 'link'
            result["links"] ||= []
            result["links"] << [info["type"], info["href"]]
        end
      end

      OpenStruct.new(result)
    end

    def get_skos_concepts subject
      broader_list = []
      narrower_list = []
      variant_list = []

      #xml_response = Nokogiri::XML(response).remove_namespaces!
      response = get_json(subject)

      if response["skos:broader"].present?
        ensure_array(response["skos:broader"]).each do |broader_uri|
          #Used due to "Medicine" vs "Medicine":  http://id.loc.gov/authorities/subjects/sh00006614.html vs http://id.loc.gov/authorities/subjects/sh85083064.html
          # See discussion at: https://etherpad.wikimedia.org/p/Hydra-LDP-20160303
          potential_label = nil
          #unless broader_uri["@id"].match(/^\_\:t/) #blank node
            relation_response = get_json(broader_uri["@id"])
            invalid = nil
            #invalid = ensure_array(relation_response["mads:isMemberOfMADSCollection"]).select { |obj| obj["@id"] == 'http://id.loc.gov/authorities/subjects/collection_Subdivisions' } if broader_uri["mads:isMemberOfMADSCollection"].present?
            if invalid.blank?
              ensure_array(relation_response["skos:prefLabel"]).each do |potential_label_ele|
                potential_label ||= potential_label_ele["@value"]
              end
              potential_label ||= broader_uri
              broader_list << {:uri_link=>broader_uri["@id"], :label=>potential_label}
            end
          #end
        end

      end

      if response["skos:narrower"].present?
        ensure_array(response["skos:narrower"]).each do |narrower_uri|
          potential_label = nil
          unless narrower_uri["@id"].match(/^\_\:t/) #blank node
            relation_response = get_json(narrower_uri["@id"])
            invalid = nil
            #invalid = ensure_array(relation_response["mads:isMemberOfMADSCollection"]).select { |obj| obj["@id"] == 'http://id.loc.gov/authorities/subjects/collection_Subdivisions' } if narrower_uri["mads:isMemberOfMADSCollection"].present?
            if invalid.blank?
              ensure_array(relation_response["skos:prefLabel"]).each do |potential_label_ele|
                potential_label ||= potential_label_ele["@value"]
              end
              potential_label ||= broader_uri
              narrower_list << {:uri_link=>narrower_uri["@id"], :label=>potential_label}
            end
          end
        end
      end

      if response["skos:altLabel"].present?
        ensure_array(response["skos:altLabel"]).each do |alt_labels|
          variant_list << alt_labels["@value"]
        end
      end


      return broader_list, narrower_list, variant_list
    end


  end
end