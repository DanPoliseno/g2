# frozen_string_literal: true

class ContainerExpirationPolicyWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include CronjobQueue
  include Gitlab::Utils::StrongMemoize

  feature_category :container_registry

  InvalidPolicyError = Class.new(StandardError)

  def perform(started_at = nil)
    if throttling_enabled?
      @started_at = started_at
      perform_throttled
    else
      perform_unthrottled
    end
  end

  private

  def perform_unthrottled
    runnable_policies.each do |container_expiration_policy|
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

    if @started_at.blank? && runnable_policies.any?
      runnable_policies.each(&:schedule_next_run!)
      ContainerExpirationPolicies::StartOnContainerRepositoriesService.new(container: runnable_policies)
                                                                      .execute
    end

    @started_at ||= Time.zone.now

    return unless ContainerRepository.with_expiration_policy_started.any?

    ContainerExpirationPolicies::ThrottledExecutionService.new.execute

    self.class.perform_in(backoff_delay, @started_at) if allowed_to_reenqueue?
  end

  def runnable_policies
    strong_memoize(:runnable_policies) do
      valid, invalid = ContainerExpirationPolicy.runnable_schedules
                                                .preloaded
                                                .partition { |policy| policy.valid? }

      invalid.each do |policy|
        policy.disable!
        Gitlab::ErrorTracking.log_exception(
          ::ContainerExpirationPolicyWorker::InvalidPolicyError.new,
          container_expiration_policy_id: policy.id
        )
      end

      ContainerExpirationPolicy.for_project_id(valid.map(&:project_id))
    end
  end

  def allowed_to_run?
    return true unless @started_at.present?

    (Time.zone.now.to_i - @started_at.to_i) < max_execution_time
  end

  def allowed_to_reenqueue?
    (Time.zone.now.to_i + backoff_delay - @started_at.to_i) < max_execution_time
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
