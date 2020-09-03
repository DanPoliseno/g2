# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerExpirationPolicies::ThrottledExecutionService, :clean_gitlab_redis_shared_state do
  let_it_be(:policies) { create_list(:container_expiration_policy, 10, :runnable) }
  let_it_be(:policy_ids) { policies.map(&:id) }
  let_it_be(:container_repositories) { policies.flat_map { |policy| create_list(:container_repository, 3, project: policy.project) } }

  let(:service) { described_class.new(container: policy_ids) }

  describe '#execute' do
    let(:max_slots) { 50 }
    let(:batch_size) { 10 }
    let(:batch_backoff_delay) { 25 }

    subject { service.execute }

    before do
      stub_application_setting(container_registry_expiration_policies_max_slots: max_slots)
      stub_application_setting(container_registry_expiration_policies_batch_size: batch_size)
      stub_application_setting(container_registry_expiration_policies_batch_backoff_delay: batch_backoff_delay)
    end

    RSpec.shared_examples 'handling slots properly with' do |perform_in_call_count:, remaining_ids_count: 0, available_slots: 0, job_ids_count: nil|
      it 'runs successfuly' do
        expect(CleanupContainerRepositoryWorker)
          .to receive(:perform_in).exactly(perform_in_call_count).times
                                  .and_call_original

        response = subject

        expect(response[:status]).to eq(:success)
        expect(response[:remaining_container_repository_ids].size).to eq(remaining_ids_count)

        job_ids_count = service.send(:job_ids_count)
        expect(job_ids_count).to eq(job_ids_count || perform_in_call_count)
        expect(max_slots - job_ids_count).to eq(available_slots)
      end
    end

    context 'with feature flag enabled' do
      before do
        stub_feature_flags(container_registry_expiration_policies_throttling: true)
      end

      it 'schedules the next runs' do
        expect { subject }.to change { policies.map(&:reload).map(&:next_run_at) }
      end

      it 'runs successfuly' do
        expect(CleanupContainerRepositoryWorker).to receive(:perform_in).exactly(30).times
        expect(subject).to include(status: :success, remaining_container_repository_ids: [])
      end

      context 'slots management' do
        let(:max_slots) { 50 }

        context 'with all slots free' do
          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 30,
                          available_slots: 20
        end

        context 'with half of the slots free' do
          let(:dummy_running_jids) { Array.new(25) { |i| "dummy_job_#{i}"} }

          before do
            Sidekiq.redis do |redis|
              redis.sadd(described_class::REDIS_KEY, dummy_running_jids)
            end

            expect(Gitlab::SidekiqStatus).to receive(:completed_jids).and_return([])
          end

          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 25,
                          available_slots: 0,
                          remaining_ids_count: 5,
                          job_ids_count: 50
        end

        context 'with no free slots' do
          let(:dummy_running_jids) { Array.new(50) { |i| "dummy_job_#{i}"} }

          before do
            Sidekiq.redis do |redis|
              redis.sadd(described_class::REDIS_KEY, dummy_running_jids)
            end

            expect(Gitlab::SidekiqStatus).to receive(:completed_jids).and_return([])
          end

          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 0,
                          available_slots: 0,
                          remaining_ids_count: 30,
                          job_ids_count: 50
        end
      end

      context 'max slots' do
        context 'lower than container repositories count' do
          let(:max_slots) { 5 }

          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 5,
                          remaining_ids_count: 25
        end

        context 'exactly equals to container repositories count' do
          let(:max_slots) { 30 }

          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 30
        end

        context 'bigger than container repositories count' do
          let(:max_slots) { 50 }

          it_behaves_like 'handling slots properly with',
                          perform_in_call_count: 30,
                          available_slots: 20
        end
      end

      context 'batch size and backoff delay' do
        let(:batch_size) { 10 }
        let(:batch_backoff_delay) { 25 }
        let(:expected_delays) { Array.new(10, 0) + Array.new(10, 25) + Array.new(10, 50) }
        let(:all_expected_arguments) do
          expected_delays.map do |delay|
            [
              delay,
              nil,
              an_instance_of(Integer),
              an_instance_of(Hash)
            ]
          end
        end

        RSpec.shared_examples 'handling batch size and batch backoff delay' do
          it 'runs successfully' do
            all_expected_arguments.each do |expected_arguments|
              expect(CleanupContainerRepositoryWorker).to receive(:perform_in).with(*expected_arguments)
            end
            expect(subject).to include(status: :success, remaining_container_repository_ids: [])
          end
        end

        it_behaves_like 'handling batch size and batch backoff delay'

        context 'with small values' do
          let(:batch_size) { 1 }
          let(:batch_backoff_delay) { 5 }
          let(:expected_delays) { Array.new(30) { |i| i * 5 } }

          it_behaves_like 'handling batch size and batch backoff delay'
        end

        context 'with big values' do
          let(:batch_size) { 50 }
          let(:expected_delays) { Array.new(30, 0) }

          it_behaves_like 'handling batch size and batch backoff delay'
        end
      end
    end

    context 'with feature flag disabled' do
      before do
        stub_feature_flags(container_registry_expiration_policies_throttling: false)
      end

      it { is_expected.to include(message: 'Feature flag disabled', status: :error) }
    end
  end
end
