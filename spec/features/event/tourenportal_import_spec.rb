# frozen_string_literal: true

#  Copyright (c) 2026, Schweizer Alpen-Club. This file is part of
#  hitobito_sac_cas and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sac_cas.

require "spec_helper"
require "webmock/rspec"

describe "Event::Tour Tourenportal Import", js: true do
  let(:group) { groups(:root) }
  let(:api_base) { Settings.sac_tourenportal.api_base_url }
  let(:fixture_body) do
    File.read(Rails.root.join("spec/fixtures/sac_tourenportal/route_detail.json"))
  end
  let(:import_url) { "https://www.sac-cas.ch/de/tourenportal/routen/6209" }

  before { sign_in(people(:admin)) }

  def visit_new_tour_form
    visit new_group_event_path(group_id: group.id, event: {type: "Event::Tour"})
    expect(page).to have_css(".tour-form--redesign__import")
  end

  def open_import_modal
    click_on I18n.t("event.tourenportal_imports.title")
    expect(page).to have_css(".modal.show")
  end

  def fill_and_submit_import(url)
    find("[data-tourenportal-import-target='urlInput']").set(url)
    click_on I18n.t("event.tourenportal_imports.submit")
  end

  context "happy path" do
    before do
      stub_request(:get, /#{Regexp.escape(api_base)}\/route\/6209/)
        .to_return(status: 200, body: fixture_body, headers: {"Content-Type" => "application/json"})
    end

    it "prefills form fields after import" do
      visit_new_tour_form
      open_import_modal
      fill_and_submit_import(import_url)

      # Modal should close after successful import
      expect(page).to have_no_css(".modal.show")

      # Name is mapped from fixture "title"
      expect(find("[name='event[name]']").value).to eq("Von der Albert-Heim-Hütte SAC")

      # Ascent: fixture route_info Ascent value is "2–2:30 h, 700 m" → 700
      expect(find("[name='event[ascent]']").value).to eq("700")

      # Descent: fixture route_info Descent value is "700 m" → 700
      expect(find("[name='event[descent]']").value).to eq("700")

      # Duration: upper bound of "2–2:30 h" → h=2, m=30
      expect(find("[name='event[duration_h]']").value).to eq("2")
      expect(find("[name='event[duration_m]']").value).to eq("30")
    end
  end

  context "overwrite confirmation" do
    before do
      stub_request(:get, /#{Regexp.escape(api_base)}\/route\/6209/)
        .to_return(status: 200, body: fixture_body, headers: {"Content-Type" => "application/json"})
    end

    it "overwrites fields when user accepts the confirm dialog" do
      visit_new_tour_form

      # Pre-fill the name so confirm dialog is triggered
      find("[name='event[name]']").set("Existing Tour Name")

      open_import_modal

      accept_confirm do
        fill_and_submit_import(import_url)
      end

      expect(page).to have_no_css(".modal.show")
      expect(find("[name='event[name]']").value).to eq("Von der Albert-Heim-Hütte SAC")
    end

    it "leaves fields unchanged when user dismisses the confirm dialog" do
      visit_new_tour_form

      find("[name='event[name]']").set("Existing Tour Name")

      open_import_modal

      dismiss_confirm do
        fill_and_submit_import(import_url)
      end

      # Modal should stay open (or close without writing) — name must be unchanged
      expect(find("[name='event[name]']").value).to eq("Existing Tour Name")
    end
  end

  context "error surface: 404 from upstream" do
    before do
      stub_request(:get, /#{Regexp.escape(api_base)}\/route\/6209/)
        .to_return(status: 404, body: '{"detail":"not found"}',
          headers: {"Content-Type" => "application/json"})
    end

    it "shows localised not_found error message and leaves form untouched" do
      visit_new_tour_form
      find("[name='event[name]']").set("Should Stay")

      open_import_modal
      fill_and_submit_import(import_url)

      # Error banner is visible inside the modal
      expect(page).to have_css("[data-tourenportal-import-target='error']",
        text: I18n.t("event.tourenportal_imports.errors.not_found"))

      # Modal stays open
      expect(page).to have_css(".modal.show")

      # Form field is untouched
      expect(find("[name='event[name]']").value).to eq("Should Stay")
    end
  end
end
