# frozen_string_literal: true

class PropagateIntegrationProjectWorker
  include ApplicationWorker

  feature_category :integrations
  idempotent!
  loggable_arguments 1

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(integration_id, min_id, max_id)
    batch_ids = Project.where(id: min_id..max_id).without_integration(Service.find(integration_id)).pluck(:id)
    BulkCreateIntegrationService.new(integration_id, batch_ids, 'project').execute
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
