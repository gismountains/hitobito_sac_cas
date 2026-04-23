# frozen_string_literal: true

#  Copyright (c) 2012-2025, Schweizer Alpen-Club. This file is part of
#  hitobito_sac_cas and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sac_cas.

require "faraday"
require "i18n"
require "json"

module SacCas
  module Tourenportal
    # Two-hop client against the SAC Tourenportal data:
    # 1. TYPO3 endpoint on sac-cas.ch returns minimal route info including destination_poi_id.
    # 2. suissealpine POI detail returns the POI with its used_as_destination_in routes.
    class ApiClient
      RETRY_COUNT = 2
      RETRY_BACKOFF = [1.0, 2.0].freeze

      TYPO3_TYPE = "1567765346410"
      TYPO3_URL  = "https://www.sac-cas.ch"

      def initialize(poi_base_url: Settings.sac_tourenportal.api_base_url,
                     typo3_base_url: TYPO3_URL,
                     timeout: Settings.sac_tourenportal.timeout_seconds.to_i)
        @poi_base_url = poi_base_url
        @typo3_base_url = typo3_base_url
        @timeout = timeout
      end

      # Fetches a route across both endpoints and returns a merged hash:
      # { "route" => <route hash from POI.used_as_destination_in>,
      #   "poi"   => <POI detail>,
      #   "basic" => <TYPO3 payload> }
      def fetch_route(route_id)
        lang = I18n.locale.to_s
        basic = fetch_typo3_route(route_id, lang)
        poi_id = basic["destination_poi_id"]
        raise ImportError.new(:upstream, "route #{route_id} has no destination_poi_id") unless poi_id

        poi = fetch_poi(poi_id, lang)
        route = find_route_in_poi(poi, route_id.to_i)
        raise ImportError.new(:not_found, "route #{route_id} not found in POI #{poi_id}") unless route

        {"route" => route, "poi" => poi, "basic" => basic}
      end

      private

      def fetch_typo3_route(route_id, lang)
        response = typo3_with_error_handling do
          typo3_connection.get("/#{lang}/", {
            type: TYPO3_TYPE,
            "tx_usersaccas2020_sac2020[routeId]" => route_id
          })
        end
        JSON.parse(response.body)
      end

      def fetch_poi(poi_id, lang)
        response = poi_with_error_handling do
          poi_connection.get("sacplus/poi/#{poi_id}", lang: lang)
        end
        JSON.parse(response.body)
      end

      def find_route_in_poi(poi, route_id)
        routes = poi["used_as_destination_in"]
        return nil unless routes.is_a?(Hash)

        routes.each_value do |arr|
          next unless arr.is_a?(Array)
          match = arr.find { |r| r.is_a?(Hash) && r["id"].to_i == route_id }
          return match if match
        end
        nil
      end

      def poi_connection
        @poi_connection ||= build_connection(@poi_base_url)
      end

      def typo3_connection
        @typo3_connection ||= build_connection(@typo3_base_url)
      end

      def build_connection(url)
        Faraday.new(url: url) do |f|
          f.headers["Accept"] = "application/json"
          f.headers["User-Agent"] = "hitobito-sac-cas/tourenportal-import"
          f.options.timeout = @timeout
          f.options.open_timeout = @timeout
          f.adapter Faraday.default_adapter
        end
      end

      def poi_with_error_handling(&block)
        with_error_handling("[Tourenportal/poi]", &block)
      end

      def typo3_with_error_handling(&block)
        with_error_handling("[Tourenportal/typo3]", &block)
      end

      def with_error_handling(tag)
        attempts = 0
        begin
          attempts += 1
          response = yield
          handle_response(response, tag)
          response
        rescue Faraday::TimeoutError
          if attempts <= RETRY_COUNT
            sleep RETRY_BACKOFF[attempts - 1] if RETRY_BACKOFF[attempts - 1]
            retry
          end
          warn_and_raise(:timeout, "#{tag} request timed out after #{attempts} attempts")
        rescue Faraday::ConnectionFailed => e
          warn_and_raise(:network, "#{tag} connection failed: #{e.message}")
        end
      end

      def handle_response(response, tag)
        return if response.success?

        if response.status == 404
          raise ImportError.new(:not_found, "#{tag} not found (404)")
        else
          warn_and_raise(:upstream, "#{tag} upstream #{response.status}")
        end
      end

      def warn_and_raise(code, message)
        Rails.logger.warn(message)
        if defined?(Sentry)
          Sentry.add_breadcrumb(Sentry::Breadcrumb.new(message: message, level: "warning"))
        end
        raise ImportError.new(code, message)
      end
    end
  end
end
