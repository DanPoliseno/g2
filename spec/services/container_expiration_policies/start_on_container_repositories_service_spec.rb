# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerExpirationPolicies::StartOnContainerRepositoriesService, :clean_gitlab_redis_shared_state do
  let(:policies) { [] }
  let(:service) { described_class.new(container: ContainerExpirationPolicy.for_project_id(policies.map(&:project_id))) }

  describe '#execute' do
    subject { service.execute }

    context 'with no policies' do
      it { is_expected.to include(status: :success) }

      it 'runs without updating container repositories' do
        expect { subject }.not_to change { ContainerRepository.with_expiration_policy_started.count }
      end
    end

    context 'with policies' do
      let_it_be(:policies) { create_list(:container_expiration_policy, 5) }

      context 'without container repositories' do
        it { is_expected.to include(status: :success) }

        it 'runs without updating container repositories' do
          expect { subject }.not_to change { ContainerRepository.with_expiration_policy_started.count }
        end
      end

      context 'with container repositories' do
        before do
          policies.sample(2).each do |policy|
            create_list(:container_repository, 2, project: policy.project)
          end
        end

        it { is_expected.to include(status: :success) }

        it 'updates container repositories' do
          expect { subject }
            .to change { ContainerRepository.with_expiration_policy_started.count }.from(0).to(4)
        end
      end
    end
  end
end
