# frozen_string_literal: true

module Geo
  module RepositoryReplicatorStrategy
    extend ActiveSupport::Concern

    include Delay
    include Gitlab::Geo::LogHelpers

    included do
      event :updated
      event :deleted
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_updated(**params)
      return unless in_replicables_for_geo_node?

      sync_repository
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_deleted(**params)
      return unless in_replicables_for_geo_node?

      replicate_destroy(params)
    end

    def replicate_destroy(event_data)
      result = Repositories::DestroyService.new(repository).execute

      if result[:status] == :error
        log_error("#{replicable_name} couldn't be destroyed", nil, {
          replicable_name: replicable_name,
          model_record_id: model_record.id
        })
      end
    end

    def sync_repository
      Geo::RepositoryBaseSsfSyncService.new(replicator: self).execute
    end

    def reschedule_sync
      Geo::EventWorker.perform_async(replicable_name, 'updated', {})
    end

    def remote_url
      Gitlab::Utils.append_path(Gitlab::Geo.primary_node.internal_url, "#{repository.full_path}.git")
    end

    def jwt_authentication_header
      authorization = ::Gitlab::Geo::RepoSyncRequest.new(
        scope: repository.full_path
      ).authorization

      { "http.#{remote_url}.extraHeader" => "Authorization: #{authorization}" }
    end
  end
end
