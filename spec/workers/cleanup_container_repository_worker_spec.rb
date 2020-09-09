# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CleanupContainerRepositoryWorker, :clean_gitlab_redis_shared_state do
  let_it_be(:repository) { create(:container_repository) }

  let(:project) { repository.project }
  let(:user) { project.owner }

  describe '#perform' do
    let(:service) { instance_double(Projects::ContainerRepository::CleanupTagsService) }
    let(:user_id) { user.id }
    let(:repository_id) { repository.id }

    subject { described_class.new.perform(user_id, repository_id, params) }

    context 'bulk delete api' do
      let(:params) { { key: 'value', 'container_expiration_policy' => false } }

      it 'executes the destroy service' do
        expect(Projects::ContainerRepository::CleanupTagsService).to receive(:new)
          .with(project, user, params)
          .and_return(service)
        expect(service).to receive(:execute)

        subject
      end

      context 'with invalid user id' do
        let(:user_id) { -1 }

        it { expect { subject }.not_to raise_error }
      end

      context 'with invalid repository id' do
        let(:repository_id) { -1 }

        it { expect { subject }.not_to raise_error }
      end
    end

    context 'container expiration policy' do
      let(:params) { { key: 'value', 'container_expiration_policy' => true } }
      let(:expiration_policy_params) { repository.project.container_expiration_policy.attributes.except('created_at', 'updated_at') }
      let(:user_id) { nil }

      it 'executes the destroy service' do
        expect(Projects::ContainerRepository::CleanupTagsService).to receive(:new)
          .with(project, nil, params.merge(expiration_policy_params))
          .and_return(service)

        expect(service).to receive(:execute).and_return(status: :success)

        subject
      end

      context 'with a repository with expiration policy started' do
        let_it_be(:repository) { create(:container_repository, :with_expiration_policy_started) }

        before do
          allow_next_instance_of(Projects::ContainerRepository::CleanupTagsService) do |service|
            allow(service).to receive(:execute).and_return(status: :success)
          end
        end

        it 'properly resets it' do
          expect { subject }.to change { ContainerRepository.with_expiration_policy_started.count }.from(1).to(0)
          expect(repository.reload.expiration_policy_started_at).to be_nil
        end
      end
    end
  end
end
