# frozen_string_literal: true

module Geo::ReplicableRepositoryRegistry
  extend ActiveSupport::Concern

  included do
    # Override state machine synced!
    #
    # @param [Boolean] missing_on_primary parameter
    def synced!(missing_on_primary: false)
      self.missing_on_primary = missing_on_primary

      super()
    end
  end
end
