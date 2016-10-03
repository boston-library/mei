require 'uri'

module Mei
  class Loc

    include Mei::WebServiceBase

    def self.pop_graph(value)
      RDF::Graph.load("#{Mei::Loc.ldf_config[:ldf_server]}#{value}.ttl", format: :ttl)
    end

    def self.ldf_config
      @ldf_config ||= YAML::load(File.open(ldf_config_path))[env]
                                 .with_indifferent_access
    end

    def self.app_root
      return @app_root if @app_root
      @app_root = Rails.root if defined?(Rails) and defined?(Rails.root)
      @app_root ||= APP_ROOT if defined?(APP_ROOT)
      @app_root ||= '.'
    end

    def self.env
      return @env if @env
      #The following commented line always returns "test" in a rails c production console. Unsure of how to fix this yet...
      #@env = ENV["RAILS_ENV"] = "test" if ENV
      @env ||= Rails.env if defined?(Rails) and defined?(Rails.root)
      @env ||= 'development'
    end

    def self.ldf_config_path
      File.join(app_root, 'config', 'mei.yml')
    end

    def self.qskos value
      if value.match(/^sh\d+/)
        return ::RDF::URI.new("http://id.loc.gov/authorities/subjects/#{value}")
      else
        return ::RDF::URI.new("http://www.w3.org/2004/02/skos/core##{value}")
      end
    end

    def initialize(subauthority, solr_field)
      @subauthority = subauthority
      @solr_field = solr_field
      #RestClient.enable Rack::Cache
    end

    def search q
      @raw_response = get_json(build_query_url(q))
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
        #sleep(0.05)

        #loc_response_to_qa(response_to_struct(response))
      end
      threaded_responses.each { |thr|  thr.join }
      end_response
    end

    # Simple conversion from LoC-based struct to QA hash
    def loc_response_to_qa(data, counter)
      json_link = data.links.select { |link| link.first == 'application/json' }
      if json_link.present?
        json_link = json_link[0][1]

        broader, narrower, variants = get_skos_concepts(json_link.gsub('.json',''))
      end

      #count = ActiveFedora::Base.find_with_conditions("subject_tesim:#{data.id.gsub('info:lc', 'http://id.loc.gov').gsub(':','\:')}", rows: '100', fl: 'id' ).length
      #FIXME
      count = ActiveFedora::Base.search_with_conditions("#{@solr_field}:#{solr_clean(data.id.gsub('info:lc', 'http://id.loc.gov'))}", rows: '100', fl: 'id' ).length
      #count = 0
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

      repo = ::Mei::Loc.pop_graph(subject)
      repo.query(:subject=>::RDF::URI.new(subject), :predicate=>Mei::Loc.qskos('broader')).each_statement do |result_statement|
        if !result_statement.object.literal? and result_statement.object.uri?
          broader_label = nil
          broader_uri = result_statement.object.to_s
          #if Mei::Loc.repo.query(:subject=>::RDF::URI.new(broader_uri), :predicate=>Mei::Loc.qskos('narrower'), :object=>::RDF::URI.new(subject)).count > 0
          valid = false

          broader_repo = ::Mei::Loc.pop_graph(broader_uri)
          broader_repo.query(:subject=>::RDF::URI.new(broader_uri)).each_statement do |broader_statement|
            if broader_statement.predicate.to_s == Mei::Loc.qskos('prefLabel')
              broader_label ||= broader_statement.object.value if broader_statement.object.literal?
            end

            if broader_statement.predicate.to_s == Mei::Loc.qskos('member')
              valid = true if broader_statement.object.to_s == 'http://id.loc.gov/authorities/subjects/collection_LCSHAuthorizedHeadings'
            end
          end
          broader_label ||= broader_uri
          broader_list << {:uri_link=>broader_uri, :label=>broader_label} if valid
          #end
        end
      end

      repo.query(:subject=>::RDF::URI.new(subject), :predicate=>Mei::Loc.qskos('narrower')).each_statement do |result_statement|
        if !result_statement.object.literal? and result_statement.object.uri?
          narrower_label = nil
          narrower_uri = result_statement.object.to_s
          valid = false

          narrower_repo = ::Mei::Loc.pop_graph(narrower_uri)

          narrower_repo.query(:subject=>::RDF::URI.new(narrower_uri)).each_statement do |narrower_statement|
            if narrower_statement.predicate.to_s == Mei::Loc.qskos('prefLabel')
              narrower_label ||= narrower_statement.object.value if narrower_statement.object.literal?
            end

            if narrower_statement.predicate.to_s == Mei::Loc.qskos('member')
              valid = true if narrower_statement.object.to_s == 'http://id.loc.gov/authorities/subjects/collection_LCSHAuthorizedHeadings'
            end
          end
          narrower_label ||= narrower_uri
          narrower_list << {:uri_link=>narrower_uri, :label=>narrower_label} if valid
        end
      end

      repo.query(:subject=>::RDF::URI.new(subject), :predicate=>Mei::Loc.qskos('altLabel')).each_statement do |result_statement|
        variant_list << result_statement.object.value if result_statement.object.literal?
      end

      return broader_list, narrower_list, variant_list
    end




  end
end