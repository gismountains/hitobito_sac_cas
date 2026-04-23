# frozen_string_literal: true

require_relative "import_error"

module SacCas
  module Tourenportal
    # Transforms the merged payload from ApiClient#fetch_route (route + POI + basic)
    # into a flat hash suitable for the Event::Tour form.
    class RouteMapper
      # SAC public URL slug → hitobito Event::Discipline label.
      # Missing entries mean "no discipline mapped" (the form stays empty
      # rather than guessing).
      DISCIPLINE_SLUG_TO_LABEL = {
        "skitouren"              => "Skihochtouren",
        "snowboardtouren"        => "Snowboardhochtouren",
        "hochtouren"             => "Hochtouren",
        "alpine-touren"          => "Hochtouren",
        "bergtouren"             => "Bergtour",
        "bergwandern"            => "Bergtour",
        "wandern"                => "Wandern",
        "wanderungen"            => "Wandern",
        "wanderwege"             => "Wanderweg",
        "kletterrouten"          => "Klettern",
        "alpinklettern"          => "Klettern",
        "sportklettern"          => "Klettern",
        "mehrseillaengen"        => "Mehrseillängen",
        "fels"                   => "Fels",
        "eisklettern"            => "Eis",
        "eis"                    => "Eis",
        "schneeschuhtouren"      => "Schneeschuhwandern",
        "schneeschuhwandern"     => "Schneeschuhwandern",
        "hoehlentouren"          => "Höhle",
        "hoehle"                 => "Höhle"
      }.freeze

      def self.call(payload, canonical_url:, discipline_slug: nil)
        new(payload, canonical_url: canonical_url, discipline_slug: discipline_slug).call
      end

      def initialize(payload, canonical_url:, discipline_slug: nil)
        @route = payload["route"] || {}
        @poi   = payload["poi"]   || {}
        @basic = payload["basic"] || {}
        @canonical_url   = canonical_url
        @discipline_slug = discipline_slug
      end

      def call
        result = {}
        result[:name]              = composed_name
        result[:summit]            = localized(@poi["display_name"]) || localized(@basic.dig("destination_poi", "display_name"))
        result[:location]          = localized(@basic.dig("departure_point", "display_name")) ||
                                     localized(@poi.dig("departure_point", "display_name"))
        result[:ascent]            = int(@route["ascent_altitude"])
        result[:descent]           = int(@route["descent_altitude"])
        result[:duration_h], result[:duration_m] = split_minutes(total_duration_minutes)
        # Prefer the route-specific teaser from the TYPO3 payload; the POI
        # description is about the mountain, not the route.
        result[:description]       = localized(@basic["teaser"]) ||
                                     localized(@poi["description_summer"]) ||
                                     localized(@poi["description_winter"])
        ids_with_labels = disciplines
        result[:discipline_ids]    = ids_with_labels ? ids_with_labels.map { |d| d[:id] } : nil
        result[:disciplines]       = ids_with_labels
        result[:tourenportal_link] = @canonical_url

        result.reject! { |k, v| k != :tourenportal_link && v.nil? }
        validate_critical!(result)
        result
      end

      private

      # Returns an array of { id:, label: } for Event::Discipline records
      # matching the URL slug, or nil when the slug can't be mapped.
      def disciplines
        label = DISCIPLINE_SLUG_TO_LABEL[@discipline_slug]
        return nil unless label

        records = ::Event::Discipline.joins(:translations)
                                     .where(event_discipline_translations: {label: label})
                                     .distinct
        list = records.map { |d| {id: d.id, label: d.label || label} }
        list.presence
      end

      # Compose name as "<Summit> <altitude> m - <route title>" when both
      # the POI name and the route title are available. Falls back
      # gracefully if either is missing.
      def composed_name
        summit   = localized(@poi["display_name"]) || localized(@basic.dig("destination_poi", "display_name"))
        altitude = int(@poi["altitude"]) || int(@basic.dig("destination_poi", "altitude"))
        title    = localized(@route["title"]) || localized(@basic["title"])

        summit_part = altitude ? "#{summit} #{altitude} m" : summit
        return blank_to_nil(title) unless summit_part
        return summit_part unless title

        "#{summit_part} - #{title}"
      end

      def localized(field)
        return nil if field.nil?
        return blank_to_nil(field) if field.is_a?(String)
        return nil unless field.is_a?(Hash)

        locale = I18n.locale.to_s
        blank_to_nil(field[locale]) ||
          blank_to_nil(field["de"]) ||
          blank_to_nil(field.values.compact.first)
      end

      def int(value)
        return nil if value.nil?
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      # Total = ascent_time_max + descent_time_max (minutes). Falls back to
      # ascent_time_min / descent_time_min when max is missing.
      def total_duration_minutes
        ascent = int(@route["ascent_time_max"]) || int(@route["ascent_time_min"])
        descent = int(@route["descent_time_max"]) || int(@route["descent_time_min"])
        total = [ascent, descent].compact.sum
        total.positive? ? total : nil
      end

      def split_minutes(total)
        return [nil, nil] if total.nil?
        [total / 60, total % 60]
      end

      def blank_to_nil(value)
        return nil if value.nil?
        str = value.to_s.strip
        str.empty? ? nil : str
      end

      def validate_critical!(result)
        critical = %i[name ascent descent duration_h]
        return if critical.any? { |k| result.key?(k) }

        raise ImportError.new(:upstream, "no mappable fields in payload")
      end
    end
  end
end
