# frozen_string_literal: true

# Conan Project-Level Package Manager Client API
module API
  class ConanProjectPackages < Grape::API::Instance
    params do
      requires :id, type: String, desc: 'The ID of a project', regexp: %r{\A[1-9]\d*\z}
    end

    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/packages/conan/v1' do
        include ConanPackageEndpoints
      end
    end
  end
end
