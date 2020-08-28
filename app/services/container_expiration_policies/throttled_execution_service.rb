# frozen_string_literal: true

module ContainerExpirationPolicies
  class ThrottledExecutionService < BaseContainerService
    include Gitlab::Utils::StrongMemoize

    alias_method :runnable_policy_ids, :container

    REDIS_KEY = 'container_expiration_policy_execution_service_jids'

    def execute
      return error('Feature flag disabled') unless throttling_enabled?

      schedule_next_runs

      remaining_ids = container_repository_ids

      enqueue_ids(remaining_ids.shift(available_slots))

      success(remaining_container_repository_ids: remaining_ids)
    end

    private

    def enqueue_ids(container_repository_ids)
      return if container_repository_ids.empty?

      jids = ContainerRepository.id_in(container_repository_ids)
                                .find_in_batches(batch_size: batch_size) # rubocop: disable CodeReuse/ActiveRecord
                                .with_index
                                .map do |repositories, index|
                                  delay = index * batch_backoff
                                  enqueue_cleanup_workers_for(repositories, delay)
                                end
      persist_job_ids(jids)
    end

    def enqueue_cleanup_workers_for(container_repositories, delay)
      return [] if container_repositories.empty?

      container_repositories.map do |repository|
        with_context( # useful?
          project: repository.project,
          user: repository.project.owner
        ) do |project:, user:|
          CleanupContainerRepositoryWorker.perform_in(
            delay,
            nil,
            repository.id,
            cleanup_worker_params_for(repository)
          )
        end
      end
    end

    def cleanup_worker_params_for(repository)
      repository.container_expiration_policy
                .attributes
                .except('created_at', 'updated_at')
                .merge(
                  'container_expiration_policy' => true,
                  'jids_redis_key' => REDIS_KEY
                )
    end

    def container_repository_ids
      ContainerRepository.for_project(runnable_policies.select(:project_id))
                         .pluck_primary_key
                         .shuffle # Useful? This is to not have all container repository ids of the single same project.
    end

    def runnable_policies
      strong_memoize(:runnable_policies) do
        ContainerExpirationPolicy.for_project_id(runnable_policy_ids)
      end
    end

    def available_slots
      update_cache

      max_slots - job_ids_count
    end

    def update_cache
      Sidekiq.redis do |redis|
        completed_jids = Gitlab::SidekiqStatus.completed_jids(job_ids)
        redis.srem(REDIS_KEY, completed_jids) if completed_jids.any?
      end
    end

    def job_ids
      Sidekiq.redis { |r| r.smembers(REDIS_KEY) }
    end

    def job_ids_count
      job_ids.size
    end

    def persist_job_ids(job_ids)
      return if job_ids.empty?

      Sidekiq.redis { |r| r.sadd(REDIS_KEY, job_ids) }
    end

    def schedule_next_runs
      runnable_policies.each(&:schedule_next_run!)
    end

    def max_slots
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_max_slots
    end

    def batch_size
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_batch_size
    end

    def batch_backoff_delay
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_batch_backoff_delay
    end

    def throttling_enabled?
      Feature.enabled?(:container_registry_expiration_policies_throttling)
    end
  end
end
