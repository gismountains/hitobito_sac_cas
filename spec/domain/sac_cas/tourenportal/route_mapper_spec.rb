# frozen_string_literal: true

require "spec_helper"
require_relative "../../../../app/domain/sac_cas/tourenportal/route_mapper"

RSpec.describe SacCas::Tourenportal::RouteMapper do
  let(:fixture_path) { File.expand_path("../../../fixtures/sac_tourenportal/route_detail.json", __dir__) }
  let(:raw)          { JSON.parse(File.read(fixture_path)) }
  let(:canonical)    { "https://example.com/routes/1" }

  subject(:result)   { described_class.call(raw, canonical_url: canonical) }

  # 1. Happy path – full fixture
  describe "happy path with fixture" do
    it "maps name" do
      expect(result[:name]).to eq("Von der Albert-Heim-Hütte SAC")
    end

    it "maps summit from destination_poi" do
      expect(result[:summit]).to eq("Lochberg")
    end

    it "maps location from departure_point" do
      expect(result[:location]).to eq("Albert-Heim-Hütte SAC")
    end

    it "maps description from teaser" do
      expect(result[:description]).to start_with("Interessante und abwechslungsreiche Tour")
    end

    it "maps ascent to 700 meters" do
      expect(result[:ascent]).to eq(700)
    end

    it "maps descent to 700 meters" do
      expect(result[:descent]).to eq(700)
    end

    it "maps duration_h to 2 (upper bound of 2–2:30 h)" do
      expect(result[:duration_h]).to eq(2)
    end

    it "maps duration_m to 30 (upper bound of 2–2:30 h)" do
      expect(result[:duration_m]).to eq(30)
    end

    it "echoes tourenportal_link" do
      expect(result[:tourenportal_link]).to eq(canonical)
    end
  end

  # 2. Duration range "2–2:30 h, 700 m" → 2h30m
  describe "duration upper-bound parsing" do
    it "uses the upper bound of a range (2–2:30 h → 2h30m)" do
      overridden = raw.dup
      overridden["route_info"] = {
        "list" => [{"label" => "Ascent", "value" => "2–2:30 h, 700 m"}]
      }
      res = described_class.call(overridden, canonical_url: canonical)
      expect(res[:duration_h]).to eq(2)
      expect(res[:duration_m]).to eq(30)
    end
  end

  # 3. Duration without minutes "4 h, 1200 m" → 4h0m
  describe "duration without minutes" do
    it "returns 0 minutes when no :mm part" do
      overridden = raw.dup
      overridden["route_info"] = {
        "list" => [
          {"label" => "Ascent", "value" => "4 h, 1200 m"},
          {"label" => "Descent", "value" => "1200 m"}
        ]
      }
      res = described_class.call(overridden, canonical_url: canonical)
      expect(res[:duration_h]).to eq(4)
      expect(res[:duration_m]).to eq(0)
      expect(res[:ascent]).to eq(1200)
    end
  end

  # 4. Missing optional fields → omitted from result; critical fields still present
  describe "missing optional fields" do
    let(:stripped) do
      raw.except("teaser", "destination_poi", "departure_point")
    end

    subject(:res) { described_class.call(stripped, canonical_url: canonical) }

    it "omits description" do
      expect(res).not_to have_key(:description)
    end

    it "omits summit" do
      expect(res).not_to have_key(:summit)
    end

    it "omits location" do
      expect(res).not_to have_key(:location)
    end

    it "still includes name (critical)" do
      expect(res[:name]).to eq("Von der Albert-Heim-Hütte SAC")
    end

    it "still includes ascent (critical)" do
      expect(res[:ascent]).to eq(700)
    end
  end

  # 5. Empty hash → raises ImportError with code :upstream
  describe "empty hash" do
    it "raises ImportError with code :upstream" do
      expect {
        described_class.call({}, canonical_url: canonical)
      }.to raise_error(SacCas::Tourenportal::ImportError) { |e|
        expect(e.code).to eq(:upstream)
      }
    end
  end
end
