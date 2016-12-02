require 'uri'

module Mei
  class Mesh

    include Mei::WebServiceBase

    def self.pop_graph(value)
      RDF::Graph.load("#{Mei::Mesh.ldf_config[:ldf_server]}#{value}.ttl", format: :ttl)
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

    def self.rdfs_namepace value
        return ::RDF::URI.new("http://www.w3.org/2000/01/rdf-schema##{value}")
    end

    def self.nlm_namepace value
      return ::RDF::URI.new("http://id.nlm.nih.gov/mesh/vocab##{value}")
    end

    def sparql
      #@sparql ||= SPARQL::Client.new("http://localhost:8988/blazegraph/sparql")
      SPARQL::Client.new("http://localhost:8988/blazegraph/sparql")
    end

    def initialize(type, solr_field)
      @solr_field = solr_field
      #RestClient.enable Rack::Cache
    end

    def search q
      q = q.downcase

      conditions = %{prefix nlm: <http://id.nlm.nih.gov/mesh/vocab#>
SELECT  DISTINCT ?term_ident ?plabel
WHERE   {  { ?term_ident nlm:prefLabel ?plabel
            FILTER regex( str(?plabel), "^#{q}", "i" ) }
           UNION
           { ?term_ident nlm:prefLabel ?plabel
            FILTER regex( str(?plabel), " #{q}", "i" ) }
        }
}
      term_result = sparql.query(conditions)

      term_result.sort_by! { |term|
        term[:plabel].to_s.split(' ').select { |inner_term| inner_term.downcase.match(/^#{q.split(' ').first}/) }.first
      }

      term_result = term_result[0..64] #limit to trying the first 65 results at maximum

      parse_authority_response(term_result)
    end

    # Reformats the data received from the LOC service
    def parse_authority_response(term_result)
      threaded_responses = []
      #end_response = Array.new(20)
      end_response = []
      position_counter = 0
      term_result.each do |term_row|
        threaded_responses << Thread.new(position_counter) { |local_pos|
          end_response[local_pos] = term_row_to_mei(term_row, position_counter)
        }
        position_counter+=1
        #sleep(0.05)

        #loc_response_to_qa(response_to_struct(response))
      end
      threaded_responses.each { |thr|  thr.join }
      end_response = end_response.reject { |c| c.empty? }

      end_response.uniq! { |c| c["uri_link"]} #Remove duplicates
      end_response[0..24] #Return up to 25 valid options
      end_response
    end

    def term_row_to_mei(term_statement, counter)
      conditions = %{prefix nlm: <http://id.nlm.nih.gov/mesh/vocab#>
SELECT  ?middle_ident
WHERE   {  ?middle_ident nlm:term <#{term_statement[:term_ident].to_s}>
        }
}

      middle_result = sparql.query(conditions)

      if middle_result.present?
        conditions = %{prefix nlm: <http://id.nlm.nih.gov/mesh/vocab#>
        prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT  DISTINCT ?concept_ident ?concept_label
WHERE   {  ?concept_ident nlm:preferredConcept <#{middle_result.first[:middle_ident].to_s}> .
           ?concept_ident rdfs:label ?concept_label .
            ?concept_ident nlm:treeNumber ?treeNumber
            FILTER regex( str(?treeNumber), "^http://id.nlm.nih.gov/mesh/2017/C.........." )
        }
}
      else
        conditions = %{prefix nlm: <http://id.nlm.nih.gov/mesh/vocab#>
        prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT  DISTINCT ?concept_ident ?concept_label
WHERE   {  ?concept_ident nlm:preferredTerm <#{term_statement[:term_ident].to_s}> .
           ?concept_ident rdfs:label ?concept_label .
            ?concept_ident nlm:treeNumber ?treeNumber
            FILTER regex( str(?treeNumber), "^http://id.nlm.nih.gov/mesh/2017/C.........." )
        }
}
      end


        concept_result = sparql.query(conditions)



        if concept_result.present?


         return {
              "uri_link" => concept_result.first[:concept_ident].to_s,
              "label" => concept_result.first[:concept_label].to_s,
              "broader" => get_broader(concept_result.first[:concept_ident].to_s),
              "narrower" => get_narrower(concept_result.first[:concept_ident].to_s),
              "variants" => get_variants(concept_result.first[:concept_ident].to_s),
              "related" => get_related(concept_result.first[:concept_ident].to_s),
              "count" => get_count(concept_result.first[:concept_label].to_s)
          }

        end
        return {}
    end

    def get_count(label)
      solr = RSolr.connect :url => CatalogController.blacklight_config.connection_config[:url]
      response = solr.get 'select', :params => {
          :q=>"#{@solr_field}:#{label}",
          :start=>0,
          :rows=>100
      }
      count = response["response"]["numFound"]
      if count >= 99
        count = "99+"
      else
        count = count.to_s
      end

      return count
    end

    def get_variants(ident)
      variant_labels = []
      repo = ::Mei::Mesh.pop_graph(ident)
      repo.query(:subject=>::RDF::URI.new(ident), :predicate=>Mei::Mesh.nlm_namepace('preferredConcept')).each_statement do |result_statement|
        if !result_statement.object.literal? and result_statement.object.uri?
          concept_uri = result_statement.object.to_s

          concept_repo = ::Mei::Mesh.pop_graph(concept_uri)
          concept_repo.query(:subject=>::RDF::URI.new(concept_uri), :predicate=>Mei::Mesh.nlm_namepace('term')).each_statement do |concept_statement|
            term_uri = concept_statement.object.to_s
            term_repo = ::Mei::Mesh.pop_graph(term_uri)
            term_repo.query(:subject=>::RDF::URI.new(term_uri), :predicate=>Mei::Mesh.nlm_namepace('prefLabel')).each_statement do |term_statement|
              variant_labels << term_statement.object.to_s
            end
          end
        end

      end

      return variant_labels
    end

    def get_broader(ident)
      broader_list = []

      repo = ::Mei::Mesh.pop_graph(ident)
      repo.query(:subject=>::RDF::URI.new(ident), :predicate=>Mei::Mesh.nlm_namepace('broaderDescriptor')).each_statement do |result_statement|
        if !result_statement.object.literal? and result_statement.object.uri?
          broader_label = nil
          broader_uri = result_statement.object.to_s

          valid = false
          broader_repo = ::Mei::Mesh.pop_graph(broader_uri)
          broader_repo.query(:subject=>::RDF::URI.new(broader_uri)).each_statement do |broader_statement|
            if broader_statement.predicate.to_s == Mei::Mesh.rdfs_namepace('label')
              broader_label ||= broader_statement.object.value if broader_statement.object.literal?
            end

            if broader_statement.predicate.to_s == 'http://id.nlm.nih.gov/mesh/vocab#treeNumber'
              valid = true if broader_statement.object.value.match(/2017\/C........../)
            end
          end
          broader_label ||= broader_uri
          broader_list << {:uri_link=>broader_uri, :label=>broader_label} if valid
          #end
        end
      end
      return broader_list
    end

    def get_narrower(ident)
      narrower_list = []

      conditions = %{prefix nlm: <http://id.nlm.nih.gov/mesh/vocab#>
        prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT  DISTINCT ?narrower_ident ?narrower_label
WHERE   {  ?narrower_ident nlm:broaderDescriptor <#{ident}> .
           ?narrower_ident rdfs:label ?narrower_label .
            ?narrower_ident nlm:treeNumber ?treeNumber
            FILTER regex( str(?treeNumber), "^http://id.nlm.nih.gov/mesh/2017/C.........." )
        }
}
      narrower_result = sparql.query(conditions)

      narrower_result.each do |narrower_statement|
        narrower_label = narrower_statement[:narrower_label].to_s
        narrower_uri = narrower_statement[:narrower_ident].to_s
        narrower_list << {:uri_link=>narrower_uri, :label=>narrower_label}
      end

      return narrower_list
    end

    def get_related(ident)
      related_list = []

      repo = ::Mei::Mesh.pop_graph(ident)
      repo.query(:subject=>::RDF::URI.new(ident), :predicate=>Mei::Mesh.nlm_namepace('seeAlso')).each_statement do |result_statement|
        if !result_statement.object.literal? and result_statement.object.uri?
          related_label = nil
          related_uri = result_statement.object.to_s

          valid = false
          related_repo = ::Mei::Mesh.pop_graph(related_uri)
          related_repo.query(:subject=>::RDF::URI.new(related_uri)).each_statement do |related_statement|
            if related_statement.predicate.to_s == Mei::Mesh.rdfs_namepace('label')
              related_label ||= related_statement.object.value if related_statement.object.literal?
            end

            if related_statement.predicate.to_s == 'http://id.nlm.nih.gov/mesh/vocab#treeNumber'
              valid = true if related_statement.object.value.match(/2017\/C........../)
            end
          end
          related_label ||= related_uri
          related_list << {:uri_link=>related_uri, :label=>related_label} if valid
          #end
        end
      end
      return related_list
    end

    def solr_clean(term)
      return term.gsub('\\', '\\\\').gsub(':', '\\:').gsub(' ', '\ ')
    end


  end
end