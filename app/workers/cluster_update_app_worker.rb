# frozen_string_literal: true

class ClusterUpdateAppWorker # rubocop:disable Scalability/IdempotentWorker
  UpdateAlreadyInProgressError = Class.new(StandardError)

  include ApplicationWorker
  include ClusterQueue
  include ClusterApplications
  include ExclusiveLeaseGuard

  sidekiq_options retry: 3, dead: false

  LEASE_TIMEOUT = 10.minutes.to_i

  def perform(app_name, app_id, project_id, scheduled_time)
    @app_id = app_id

    try_obtain_lease do
      execute(app_name, app_id, project_id, scheduled_time)
    end
  end

  private

  # rubocop: disable CodeReuse/ActiveRecord
  def execute(app_name, app_id, project_id, scheduled_time)
    project = Project.find_by(id: project_id)
    return unless project

    find_application(app_name, app_id) do |app|
      update_prometheus(app, scheduled_time, project)
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def update_prometheus(app, scheduled_time, project)
    return if app.updated_since?(scheduled_time)
    return if app.update_in_progress?

    Clusters::Applications::PrometheusUpdateService.new(app, project).execute
  end

  def lease_key
    @lease_key ||= "#{self.class.name.underscore}-#{@app_id}"
  end

  def lease_timeout
    LEASE_TIMEOUT
  end
end
