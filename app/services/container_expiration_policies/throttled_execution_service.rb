# frozen_string_literal: true

module ContainerExpirationPolicies
  class ThrottledExecutionService
    include BaseServiceUtility
    include Gitlab::Utils::StrongMemoize

    DELAY = 30.seconds.freeze
    REDIS_KEY = 'container_expiration_policy_execution_service_jids'

    def execute
      update_redis_entry

      enqueue_ids(container_repository_ids(available_capacity))

      success
    end

    private

    def enqueue_ids(repository_ids)
      return if repository_ids.empty?

      job_args = repository_ids.map do |repository_id|
        [
          nil,
          repository_id,
          container_expiration_policy: true,
          jids_redis_key: REDIS_KEY
        ]
      end

      # bulk_perform_in_with_contexts doesn't support batch_size and batch_delay
      # also, the only context we have here is the container repository id
      # rubocop: disable Scalability/BulkPerformWithContext
      jids = CleanupContainerRepositoryWorker.bulk_perform_in(
        DELAY,
        job_args,
        batch_size: batch_size,
        batch_delay: batch_backoff_delay
      )
      # rubocop: enable Scalability/BulkPerformWithContext
      persist_job_ids(jids)
    end

    def container_repository_ids(size)
      ContainerRepository.with_expiration_policy_started
                         .pluck_primary_key
                         .sample(size)
    end

    def available_capacity
      capacity - job_ids_count
    end

    def update_redis_entry
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

    def capacity
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_capacity
    end

    def batch_size
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_batch_size
    end

    def batch_backoff_delay
      ::Gitlab::CurrentSettings.current_application_settings.container_registry_expiration_policies_batch_backoff_delay
    end
  end
end
