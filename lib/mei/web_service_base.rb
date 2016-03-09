require 'rest_client'

module Mei
  module WebServiceBase
    attr_accessor :raw_response

    def skip_cache_request(uri)
      r = RestClient.get uri
      JSON.parse(r)
    end

    # mix-in to retreive and parse JSON content from the web
    def get_json(subject)
      r = RestClient.get Mei::WebServiceBase.ldf_server + subject + '.jsonld'
      JSON.parse(r)
    end

    def get_ttl(subject)
      r = RestClient.get Mei::WebServiceBase.ldf_server + subject + '.ttl'#, { accept: :ttl }
      r
    end

    def get_nt(subject)
      r = RestClient.get Mei::WebServiceBase.ldf_server + subject + '.nt'
      r
    end

    def self.ldf_server
      @ldf_server ||= Mei::TermsController.mei_config["ldf_server"]
    end

    def ensure_array(obj)
      if obj.class == Hash
        return [obj]
      end
      return obj
    end


  end
end