# frozen_string_literal: true

#  Copyright (c) 2012-2025, Schweizer Alpen-Club. This file is part of
#  hitobito_sac_cas and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sac_cas.

require "spec_helper"
require "webmock/rspec"
require_relative "../../../../app/domain/sac_cas/tourenportal/import_error"
require_relative "../../../../app/domain/sac_cas/tourenportal/api_client"

RSpec.describe SacCas::Tourenportal::ApiClient do
  let(:base_url) { "http://tourenportal.test" }
  let(:client)   { described_class.new(base_url: base_url, timeout: 1) }

  before { WebMock.enable! }
  after  { WebMock.reset! }

  describe "#fetch_route" do
    # 1. 2xx returns parsed hash
    it "returns parsed JSON body on 200" do
      stub_request(:get, "#{base_url}/route/12345")
        .with(query: hash_including("lang" => "de"))
        .to_return(status: 200, body: '{"title":"X"}', headers: {"Content-Type" => "application/json"})

      expect(client.fetch_route("12345")).to eq("title" => "X")
    end

    # 2. 404 → :not_found
    it "raises ImportError with code :not_found on 404" do
      stub_request(:get, "#{base_url}/route/12345")
        .with(query: hash_including("lang" => "de"))
        .to_return(status: 404, body: "not found")

      expect { client.fetch_route("12345") }
        .to raise_error(SacCas::Tourenportal::ImportError) { |e|
          expect(e.code).to eq(:not_found)
        }
    end

    # 3. 500 → :upstream
    it "raises ImportError with code :upstream on 500" do
      stub_request(:get, "#{base_url}/route/12345")
        .with(query: hash_including("lang" => "de"))
        .to_return(status: 500, body: "error")

      expect { client.fetch_route("12345") }
        .to raise_error(SacCas::Tourenportal::ImportError) { |e|
          expect(e.code).to eq(:upstream)
        }
    end

    # 4. 3 timeouts → :timeout, stub hit 3 times
    it "raises ImportError with code :timeout after 3 timeout attempts" do
      stub = stub_request(:get, "#{base_url}/route/12345")
        .with(query: hash_including("lang" => "de"))
        .to_raise(Faraday::TimeoutError)

      expect { client.fetch_route("12345") }
        .to raise_error(SacCas::Tourenportal::ImportError) { |e|
          expect(e.code).to eq(:timeout)
        }

      expect(stub).to have_been_requested.times(3)
    end

    # 5. ConnectionFailed → :network
    it "raises ImportError with code :network on ConnectionFailed" do
      stub_request(:get, "#{base_url}/route/12345")
        .with(query: hash_including("lang" => "de"))
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.fetch_route("12345") }
        .to raise_error(SacCas::Tourenportal::ImportError) { |e|
          expect(e.code).to eq(:network)
        }
    end

    # 6. lang query param matches I18n.locale
    it "sends the current I18n.locale as the lang param" do
      I18n.locale = :fr
      stub = stub_request(:get, "#{base_url}/route/99")
        .with(query: hash_including("lang" => "fr"))
        .to_return(status: 200, body: "{}", headers: {"Content-Type" => "application/json"})

      client.fetch_route("99")
      expect(stub).to have_been_requested
    ensure
      I18n.locale = :de
    end
  end
end
