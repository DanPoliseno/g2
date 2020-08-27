# frozen_string_literal: true

class ContainerExpirationPolicyWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include CronjobQueue

  feature_category :container_registry

  def perform(started_at = nil, container_repository_ids = [])
    @started_at = started_at || Time.zone.now
    @container_repository_ids = container_repository_ids

    throttling_enabled? ? perform_throttled : perform_unthrottled
  end

  private

  def perform_unthrottled
    ContainerExpirationPolicy.runnable_schedules.preloaded.find_each do |container_expiration_policy|
      with_context(project: container_expiration_policy.project,
                   user: container_expiration_policy.project.owner) do |project:, user:|
        ContainerExpirationPolicyService.new(project, user)
          .execute(container_expiration_policy)
      rescue ContainerExpirationPolicyService::InvalidPolicyError => e
        Gitlab::ErrorTracking.log_exception(e, container_expiration_policy_id: container_expiration_policy.id)
      end
    end
  end

  def perform_throttled
    unless allowed_to_run?
      # log timeout
      return
    end

    response = ContainerExpirationPolicies::ThrottledExecutionService.new(container: valid_runnable_policies)
                                                                     .execute

    self.class.perform_in(backoff_delay, @started_at, response[:remaining_container_repository_ids]) if allowed_to_reenqueue?
  end

  def valid_runnable_policies
    policies, invalid_policies = ContainerExpirationPolicy.runnable_schedules
                                                          .partition { |policy| policy.valid? }

    invalid_policies.each do |policy|
      policy.disable!
      Gitlab::ErrorTracking.log_exception(
        ContainerExpirationPolicyService::InvalidPolicyError.new,
        container_expiration_policy_id: policy.id
      )
    end

    policies
  end

  def allowed_to_run?
    return true unless @started_at.present?

    (Time.zone.now - @started_at) < max_execution_time
  end

  def allowed_to_reenqueue?
    Time.zone.now + backoff_delay - @started_at < max_execution_time
  end

  def throttling_enabled?
    Feature.enabled?(:container_registry_expiration_policies_throttling)
  end

  def max_execution_time
    ::Gitlab::CurrentSettings.current_application_settings.container_registry_container_expiration_timeout
  end

  def backoff_delay
    ::Gitlab::CurrentSettings.current_application_settings.container_registry_container_expiration_backoff_delay
  end
end
