module SacCas
  module Tourenportal
    class ImportError < StandardError
      CODES = %i[invalid_url not_found timeout upstream network].freeze

      attr_reader :code

      def initialize(code, message = nil)
        raise ArgumentError, "unknown code #{code}" unless CODES.include?(code)
        @code = code
        super(message || code.to_s)
      end
    end
  end
end
