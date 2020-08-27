# frozen_string_literal: true

module ContainerExpirationPolicies
  class ThrottledExecutionService < BaseContainerService
    alias_method :runnable_policies, :container

    CACHE_KEY = 'container_expiration_policy_execution_service_jids_cache'

    def execute
      return unless throttling_enabled?

      schedule_next_runs

      remaining_ids = container_repository_ids

      enqueue_ids(remaining_ids.shift(available_slots))

      success(remaining_container_repository_ids: remaining_ids)
    end

    private

    def enqueue_ids(container_repository_ids)
      ContainerRepository.id_in(container_repository_ids)
                         .find_in_batches(batch_size: batch_size) # rubocop: disable CodeReuse/ActiveRecord
                         .with_index do |repositories, index|
                           delay = index * batch_backoff
                           enqueue_cleanup_worker_for(repositories, delay)
                         end
    end

    def enqueue_cleanup_worker_for(container_repositories, delay)
      container_repositories.each do |repository|
        CleanupContainerRepositoryWorker.perform_in(
          delay,
          nil,
          repository.id,
          cleanup_worker_params_for(repository)
        )
      end
    end

    def cleanup_worker_params_for(repository)
      repository.container_expiration_policy
                .attributes
                .except('created_at', 'updated_at')
                .merge(container_expiration_policy: true)
    end

    def container_repository_ids
      ContainerRepository.for_project(runnable_policies.select(:project_id))
                         .pluck_primary_key
                         .shuffle # Useful? This is to not have all container repository ids of the single same project.
    end

    def available_slots
      update_cache

      max_slots - cached_job_ids_count
    end

    def update_cache
      Gitlab::SidekiqStatus.completed_jids(job_ids).each do |jid|
        Sidekiq.redis { |r| r.lrem(CACHE_KEY, jid) }
      end
    end

    def cached_job_ids
      Sidekiq.redis { |r| r.lrange(CACHE_KEY, 0, max_slots) }
    end

    def cached_job_ids_count
      Sidekiq.redis { |r| r.llen(CACHE_KEY) }
    end

    def schedule_next_runs
      runnable_policies.each(&:schedule_next_run!)
    end

    def max_slots
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_container_expiration_policy_slots
    end

    def batch_size
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_container_expiration_policy_batch_size
    end

    def batch_backoff_delay
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_container_expiration_policy_backoff_delay
    end

    def throttling_enabled?
      Feature.enabled?(:container_registry_expiration_policies_throttling)
    end
  end
end
