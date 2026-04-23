require "spec_helper"

describe SacCas::Tourenportal::Importer do
  let(:fake_parser) do
    Class.new do
      def self.route_id(url)
        url == "https://good.url" ? "42" : nil
      end
    end
  end

  let(:fake_client) do
    instance_double(SacCas::Tourenportal::ApiClient)
  end

  let(:fake_mapper) do
    Class.new do
      def self.call(raw, canonical_url:)
        { name: "Route X", url: canonical_url, raw: raw }
      end
    end
  end

  let(:importer) do
    described_class.new(parser: fake_parser, client: fake_client, mapper: fake_mapper)
  end

  describe "#call" do
    context "with valid URL" do
      it "parses URL, fetches route, and maps result" do
        raw_data = { "id" => 42, "title" => "Test Route" }
        expect(fake_client).to receive(:fetch_route).with("42").and_return(raw_data)

        result = importer.call("https://good.url")

        expect(result).to eq({
          name: "Route X",
          url: "https://good.url",
          raw: raw_data
        })
      end
    end

    context "with invalid URL" do
      it "raises ImportError with :invalid_url code without calling client" do
        expect(fake_client).not_to receive(:fetch_route)

        expect {
          importer.call("https://bad.url")
        }.to raise_error(SacCas::Tourenportal::ImportError) do |error|
          expect(error.code).to eq(:invalid_url)
        end
      end
    end

    context "when ApiClient raises ImportError" do
      it "propagates the error" do
        expect(fake_client)
          .to receive(:fetch_route)
          .with("42")
          .and_raise(SacCas::Tourenportal::ImportError.new(:not_found, "Route not found"))

        expect {
          importer.call("https://good.url")
        }.to raise_error(SacCas::Tourenportal::ImportError) do |error|
          expect(error.code).to eq(:not_found)
        end
      end
    end

    context "when RouteMapper raises ImportError" do
      let(:failing_mapper) do
        Class.new do
          def self.call(raw, canonical_url:)
            raise SacCas::Tourenportal::ImportError.new(:upstream, "Mapping failed")
          end
        end
      end

      it "propagates the error" do
        expect(fake_client).to receive(:fetch_route).with("42").and_return({})

        importer_with_failing_mapper = described_class.new(
          parser: fake_parser,
          client: fake_client,
          mapper: failing_mapper
        )

        expect {
          importer_with_failing_mapper.call("https://good.url")
        }.to raise_error(SacCas::Tourenportal::ImportError) do |error|
          expect(error.code).to eq(:upstream)
        end
      end
    end
  end
end
