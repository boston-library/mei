module Mei
  module WebServiceBase
    attr_accessor :raw_response

    def self.fetch(uri_str, limit = 10)
      # You should choose better exception.
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      url = URI.parse(uri_str)
      req = Net::HTTP::Get.new(url.request_uri, { 'User-Agent' => 'Mozilla/5.0 (etc...)', 'Accept' => 'application/json' })
      response = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') { |http| http.request(req) }
      case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch(response['location'], limit - 1)
        else
          response.error!
      end
    end

    def self.get_redirect(uri_str)
      # You should choose better exception.
      url = URI.parse(uri_str)
      req = Net::HTTP::Get.new(url.request_uri, { 'User-Agent' => 'Mozilla/5.0 (etc...)',  'Accept' => 'application/json' })
      response = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') { |http| http.request(req) }
      case response
        when Net::HTTPRedirection then return response['location']
        else
          response.error!
      end
    end

    # mix-in to retreive and parse JSON content from the web
    def get_json(url)
      r = Mei::WebServiceBase.fetch(url)
      JSON.parse(r)
    end

    def request_options
      { accept: :json }
    end

    def get_xml(url)
      RestClient.enable Rack::Cache
      r = RestClient.get url
      RestClient.disable Rack::Cache
      r
    end



  end
end