# frozen_string_literal: true

#  Copyright (c) 2025, Schweizer Alpen-Club. This file is part of
#  hitobito_sac_cas and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_sac_cas

module SacCas
  module Event
    module TourenportalImportsController
      extend ActiveSupport::Concern

      def create
        authorize_import!
        fields = importer.call(params.require(:url).to_s)
        render json: {status: "ok", fields: fields}
      rescue SacCas::Tourenportal::ImportError => e
        render json: {
          status: "error",
          code: e.code.to_s,
          message: I18n.t("event.tourenportal_imports.errors.#{e.code}")
        }, status: :unprocessable_entity
      end

      private

      def authorize_import!
        group = ::Group.find(params.require(:group_id))
        authorize!(:create, ::Event::Tour.new(groups: [group]))
      end

      def importer
        @importer ||= SacCas::Tourenportal::Importer.new
      end
    end
  end
end
