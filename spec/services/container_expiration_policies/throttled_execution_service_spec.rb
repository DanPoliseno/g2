# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerExpirationPolicies::ThrottledExecutionService, :clean_gitlab_redis_shared_state do
  let_it_be(:policies) { create_list(:container_expiration_policy, 10, :runnable) }
  let_it_be(:policy_ids) { policies.map(&:id) }
  let_it_be(:container_repositories) { policies.flat_map { |policy| create_list(:container_repository, 3, :with_expiration_policy_started, project: policy.project) } }
  let_it_be(:other_container_repositories) { create_list(:container_repository, 5) }

  let(:service) { described_class.new }

  describe '#execute' do
    let(:capacity) { 50 }
    let(:batch_size) { 10 }
    let(:batch_backoff_delay) { 25 }

    subject { service.execute }

    before do
      stub_application_setting(container_registry_expiration_policies_capacity: capacity)
      stub_application_setting(container_registry_expiration_policies_batch_size: batch_size)
      stub_application_setting(container_registry_expiration_policies_batch_backoff_delay: batch_backoff_delay)
    end

    RSpec.shared_examples 'handling slots properly with' do |push_bulk_call_count:, available_slots: 0, job_ids_count: nil|
      it 'runs successfuly' do
        expect(Sidekiq::Client)
          .to receive(:push_bulk).exactly(push_bulk_call_count).times
                                  .and_call_original

        response = subject

        expect(response[:status]).to eq(:success)

        job_ids_count = service.send(:job_ids_count)
        expect(job_ids_count).to eq(job_ids_count || push_bulk_call_count * batch_size)
        expect(capacity - job_ids_count).to eq(available_slots)
      end
    end

    it 'runs successfuly' do
      expect(Sidekiq::Client).to receive(:push_bulk).exactly(3).times
      expect(subject).to include(status: :success)
    end

    context 'capacity management' do
      let(:capacity) { 50 }

      context 'with all slots free' do
        it_behaves_like 'handling slots properly with',
                        push_bulk_call_count: 3,
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
                        push_bulk_call_count: 3,
                        available_slots: 0,
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
                        push_bulk_call_count: 0,
                        available_slots: 0,
                        job_ids_count: 50
      end
    end

    context 'capacity' do
      context 'lower than container repositories count' do
        let(:capacity) { 5 }

        it_behaves_like 'handling slots properly with',
                        push_bulk_call_count: 1
      end

      context 'exactly equals to container repositories count' do
        let(:capacity) { 30 }

        it_behaves_like 'handling slots properly with',
                        push_bulk_call_count: 3
      end

      context 'bigger than container repositories count' do
        let(:capacity) { 50 }

        it_behaves_like 'handling slots properly with',
                        push_bulk_call_count: 3,
                        available_slots: 20
      end
    end

    context 'batch size and backoff delay' do
      let(:batch_size) { 10 }
      let(:batch_backoff_delay) { 25 }
      let(:expected_delays) { [0, 25, 50] }
      let(:all_expected_arguments) do
        expected_delays.map do |delay|
          {
            'class' => CleanupContainerRepositoryWorker,
            'args' => array_including(
              array_including(
                nil,
                an_instance_of(Integer),
                container_expiration_policy: true,
                jids_redis_key: described_class::REDIS_KEY
              )
            ),
            'at' => (delay + described_class::DELAY).seconds.from_now.to_i
          }
        end
      end

      RSpec.shared_examples 'handling batch size and batch backoff delay' do
        it 'runs successfully' do
          Timecop.freeze do
            all_expected_arguments.each do |expected_arguments|
              expect(Sidekiq::Client).to receive(:push_bulk).with(expected_arguments)
            end
            expect(subject).to include(status: :success)
          end
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
        let(:expected_delays) { [0] }

        it_behaves_like 'handling batch size and batch backoff delay'
      end
    end
  end
end
