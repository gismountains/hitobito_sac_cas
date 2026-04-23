module SacCas
  module Tourenportal
    class Importer
      def initialize(parser: UrlParser, client: ApiClient.new, mapper: RouteMapper)
        @parser = parser
        @client = client
        @mapper = mapper
      end

      def call(url)
        route_id = @parser.route_id(url)
        raise ImportError.new(:invalid_url, "unrecognized URL") if route_id.nil?

        raw = @client.fetch_route(route_id)
        @mapper.call(raw, canonical_url: url, discipline_slug: @parser.discipline_slug(url))
      end
    end
  end
end
