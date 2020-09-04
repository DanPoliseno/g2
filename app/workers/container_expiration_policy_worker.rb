# frozen_string_literal: true

class ContainerExpirationPolicyWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include CronjobQueue
  include Gitlab::Utils::StrongMemoize

  feature_category :container_registry

  InvalidPolicyError = Class.new(StandardError)

  def perform(started_at = nil, container_repository_ids = [])
    @started_at = started_at || Time.zone.now
    @container_repository_ids = container_repository_ids

    throttling_enabled? ? perform_throttled : perform_unthrottled
  end

  private

  def perform_unthrottled
    valid_runnable_policies.each do |container_expiration_policy|
      with_context(project: container_expiration_policy.project,
                   user: container_expiration_policy.project.owner) do |project:, user:|
        ContainerExpirationPolicyService.new(project, user)
                                        .execute(container_expiration_policy)
      end
    end
  end

  def perform_throttled
    unless allowed_to_run?
      # log timeout
      return
    end

    return unless valid_runnable_policies.any?

    response = ContainerExpirationPolicies::ThrottledExecutionService.new(container: valid_runnable_policies)
                                                                     .execute

    if allowed_to_reenqueue? && response[:remaining_container_repository_ids]&.any?
      # TODO is this safe? to send remaining_container_repository_ids
      self.class.perform_in(backoff_delay, @started_at, response[:remaining_container_repository_ids])
    end
  end

  def valid_runnable_policies
    strong_memoize(:valid_runnable_policies) do
      policies, invalid_policies = ContainerExpirationPolicy.runnable_schedules
                                                            .preloaded
                                                            .partition { |policy| policy.valid? }

      invalid_policies.each do |policy|
        policy.disable!
        Gitlab::ErrorTracking.log_exception(
          ::ContainerExpirationPolicyWorker::InvalidPolicyError.new,
          container_expiration_policy_id: policy.id
        )
      end

      policies
    end
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
    ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_timeout
  end

  def backoff_delay
    ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_backoff_delay
  end
end
