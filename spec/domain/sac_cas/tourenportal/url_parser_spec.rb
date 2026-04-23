require "spec_helper"

describe SacCas::Tourenportal::UrlParser do
  describe ".route_id" do
    cases = {
      "https://www.sac-cas.ch/de/tourenportal/routen/12345/piz-palue-bumillergrat" => "12345",
      "https://www.sac-cas.ch/fr/tourenportal/routes/67890"                        => "67890",
      "https://www.sac-cas.ch/it/tourenportal/itinerari/42/trail-name/"            => "42",
      "https://www.sac-cas.ch/en/tour-portal/routes/99?foo=bar"                    => "99",
      "https://www.suissealpine.sac-cas.ch/api/1/route/555"                        => "555",
      "12345"                                                                       => "12345",
      "https://example.com/foo"                                                     => nil,
      ""                                                                             => nil,
      nil                                                                            => nil
    }

    cases.each do |input, expected|
      it "returns #{expected.inspect} for #{input.inspect}" do
        expect(described_class.route_id(input)).to eq(expected)
      end
    end
  end
end
