# frozen_string_literal: true

#  Copyright (c) 2025, Schweizer Alpen-Club. This file is part of
#  hitobito_sac_cas and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sac_cas

require "spec_helper"

describe Event::TourenportalImportsController do
  let(:admin) { people(:admin) }
  let(:mitglied) { people(:mitglied) }
  let(:group) { groups(:root) }
  let(:importer) { instance_double(SacCas::Tourenportal::Importer) }

  before do
    allow(SacCas::Tourenportal::Importer).to receive(:new).and_return(importer)
  end

  describe "POST#create" do
    let(:params) { {group_id: group.id, url: "https://sac-cas.ch/tourenportal/tours/42"} }

    context "as admin" do
      before { sign_in(admin) }

      context "happy path" do
        let(:mapped_fields) { {name: "Matterhorn Nordwand", ascent: 1100} }

        before do
          allow(importer).to receive(:call).with(params[:url]).and_return(mapped_fields)
        end

        it "returns 200 with status ok and fields" do
          post :create, params: params

          expect(response).to have_http_status(:ok)
          json = response.parsed_body
          expect(json["status"]).to eq("ok")
          expect(json["fields"]["name"]).to eq("Matterhorn Nordwand")
          expect(json["fields"]["ascent"]).to eq(1100)
        end
      end

      context "when importer raises ImportError" do
        %i[invalid_url not_found timeout upstream network].each do |code|
          context "with code :#{code}" do
            before do
              allow(importer).to receive(:call)
                .and_raise(SacCas::Tourenportal::ImportError.new(code))
            end

            it "returns 422 with status error and code #{code}" do
              post :create, params: params

              expect(response).to have_http_status(:unprocessable_entity)
              json = response.parsed_body
              expect(json["status"]).to eq("error")
              expect(json["code"]).to eq(code.to_s)
              expect(json["message"]).to be_present
            end
          end
        end
      end
    end

    context "authorization" do
      before { sign_in(mitglied) }

      it "raises CanCan::AccessDenied when user cannot create Event::Tour" do
        expect do
          post :create, params: params
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
