# frozen_string_literal: true

module ContainerExpirationPolicies
  class StartOnContainerRepositoriesService < BaseContainerService
    alias_method :expiration_policies, :container

    def execute
      container_repositories.update_all(expiration_policy_started_at: Time.zone.now)
      success
    end

    private

    def container_repositories
      return ContainerRepository.none if expiration_policies.empty?

      ContainerRepository.for_project(expiration_policies.select(:project_id))
    end
  end
end
