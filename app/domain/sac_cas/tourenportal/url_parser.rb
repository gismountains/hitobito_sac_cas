require "uri"
require "cgi"

module SacCas
  module Tourenportal
    # Extracts a numeric route ID from anything a user is likely to paste:
    #   - the TYPO3-style query param: `?...routeId=1756` (URL-encoded brackets too)
    #   - path segments: `/routen/1756`, `/routes/1756`, `/itinerari/1756`, `/route/1756`
    #   - a raw numeric id: "1756"
    # Returns the id as a String, or nil.
    class UrlParser
      # Old-style path: /routen/1756 or /route/1756 etc.
      PATH_REGEX     = %r{/(?:routen|routes|itinerari|route)/(\d+)\b}
      # TYPO3 query param: ?tx_usersaccas2020_sac2020[routeId]=1756
      ROUTE_ID_PARAM = /routeId[^0-9]{0,4}(\d+)/i
      # Current public URL shape, last slug segment ends in -<id>:
      # /de/huetten-und-touren/sac-tourenportal/rossstock-sz-1567/skitouren/von-der-lidernenhuette-sac-1345/
      SLUG_ID_REGEX     = %r{-(\d+)/?\z}
      # The discipline lives in the second-to-last path segment (the one
      # just before the route slug). Keep the raw slug; mapping to a
      # hitobito Event::Discipline happens in RouteMapper.
      DISCIPLINE_REGEX  = %r{/sac-tourenportal/[^/]+/([^/]+)/[^/]+-\d+/?\z}

      def self.route_id(input)
        return nil if input.nil?
        str = input.to_s.strip
        return nil if str.empty?

        return str if str.match?(/\A\d+\z/)

        uri = safe_parse(str)
        return nil unless uri && uri.host&.include?("sac-cas.ch")

        query_hit = ROUTE_ID_PARAM.match(CGI.unescape(uri.query.to_s))
        return query_hit[1] if query_hit

        haystack = "#{uri.path}/#{uri.fragment}"
        path_hit = haystack.match(PATH_REGEX)
        return path_hit[1] if path_hit

        # Public tourenportal URL: last `-<digits>` in the path is the route id
        # (only when the URL lives under the tourenportal section).
        if uri.path.to_s.include?("/sac-tourenportal/") || uri.path.to_s.include?("/tourenportal/")
          slug_hit = uri.path.to_s.match(SLUG_ID_REGEX)
          return slug_hit[1] if slug_hit
        end

        nil
      end

      def self.discipline_slug(input)
        uri = safe_parse(input.to_s)
        return nil unless uri
        match = uri.path.to_s.match(DISCIPLINE_REGEX)
        match && match[1]
      end

      def self.safe_parse(str)
        URI.parse(str)
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
