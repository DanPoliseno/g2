# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerExpirationPolicyWorker do
  let(:worker) { described_class.new }
  let(:started_at) { nil }

  describe '#perform' do
    subject { worker.perform(started_at) }

    context 'with throttling enabled' do
      let(:timeout) { 1800 }
      let(:backoff_delay) { 25 }

      before do
        stub_feature_flags(container_registry_expiration_policies_throttling: true)
        stub_application_setting(container_registry_expiration_policies_timeout: timeout)
        stub_application_setting(container_registry_expiration_policies_backoff_delay: backoff_delay)
      end

      context 'With no container expiration policies' do
        it 'Does not execute any policies' do
          expect(ContainerExpirationPolicies::ThrottledExecutionService).not_to receive(:new)

          subject
        end
      end

      context 'with container expiration policies' do
        let_it_be(:container_expiration_policy) { create(:container_expiration_policy, :runnable) }
        let_it_be(:container_repository) { create(:container_repository, project: container_expiration_policy.project) }
        let(:dummy_service) { double(execute: nil) }

        context 'without started at parameter' do
          it 'schedules the next run' do
            expect { subject }.to change { container_expiration_policy.reload.next_run_at }

            expect(container_expiration_policy.next_run_at).to be > Time.zone.now
          end

          it 'executes the proper services' do
            Timecop.freeze do
              expect(ContainerExpirationPolicies::StartOnContainerRepositoriesService)
                .to receive(:new).with(container: [container_expiration_policy]).and_call_original
              expect(ContainerExpirationPolicies::ThrottledExecutionService)
                .to receive(:new).and_return(dummy_service)
              expect(ContainerExpirationPolicyService).not_to receive(:new)

              expect { subject }.to change { container_repository.reload.expiration_policy_started_at }.from(nil).to(Time.zone.now)
            end
          end

          it 're enqueues itself' do
            Timecop.freeze do
              expect(ContainerExpirationPolicyWorker).to receive(:perform_in).with(backoff_delay, Time.zone.now)

              subject
            end
          end
        end

        context 'with started at parameter' do
          let_it_be(:container_repository_with_policy_started) do
            create(
              :container_repository,
              project: container_expiration_policy.project,
              expiration_policy_started_at: 10.minutes.ago
            )
          end

          let(:started_at) { 10.minutes.ago }

          it "doesn't schedules the next run" do
            expect { subject }.not_to change { container_expiration_policy.reload.next_run_at }

            expect(container_expiration_policy.next_run_at).to be < Time.zone.now
          end

          it 'executes the proper services' do
            expect(ContainerExpirationPolicies::StartOnContainerRepositoriesService)
                .not_to receive(:new)
            expect(ContainerExpirationPolicies::ThrottledExecutionService)
              .to receive(:new).and_return(dummy_service)
            expect(ContainerExpirationPolicyService).not_to receive(:new)

            expect { subject }.not_to change { container_repository.reload.expiration_policy_started_at }
          end

          it 're enqueues itself' do
            expect(ContainerExpirationPolicyWorker).to receive(:perform_in).with(backoff_delay, started_at)

            subject
          end

          context 'when the timeout is triggered' do
            let(:started_at) { (timeout + 30).seconds.ago }

            it 'is not allowed to run' do
              expect(ContainerExpirationPolicies::StartOnContainerRepositoriesService).not_to receive(:new)
              expect(ContainerExpirationPolicies::ThrottledExecutionService).not_to receive(:new)
              expect(ContainerExpirationPolicyService).not_to receive(:new)
              expect(ContainerExpirationPolicyWorker).not_to receive(:perform_in)

              expect { subject }.not_to change { container_repository.reload.expiration_policy_started_at }
            end
          end

          context 'when not allowed to re enqueue' do
            let(:started_at) { Time.zone.now - timeout.seconds + backoff_delay.seconds - 5.seconds }

            before do
              allow(ContainerExpirationPolicies::ThrottledExecutionService)
                .to receive(:new).and_return(dummy_service)
            end

            it "doesn't re enqueue itself" do
              expect(ContainerExpirationPolicyWorker).not_to receive(:perform_in)

              subject
            end
          end
        end

        context 'with a disabled container expiration policy' do
          before do
            container_expiration_policy.disable!
          end

          it 'does not run the policy' do
            expect(ContainerExpirationPolicies::StartOnContainerRepositoriesService).not_to receive(:new)
            expect(ContainerExpirationPolicies::ThrottledExecutionService).not_to receive(:new)
            expect(ContainerExpirationPolicyService).not_to receive(:new)

            subject
          end
        end

        context 'with an invalid container expiration policy' do
          let(:user) { container_expiration_policy.project.owner }

          before do
            container_expiration_policy.update_column(:name_regex, '*production')
          end

          it 'disables the policy and tracks an error' do
            expect(ContainerExpirationPolicies::ThrottledExecutionService).not_to receive(:new)
            expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(described_class::InvalidPolicyError), container_expiration_policy_id: container_expiration_policy.id)

            expect { subject }.to change { container_expiration_policy.reload.enabled }.from(true).to(false)
          end
        end
      end
    end

    context 'with throttling disabled' do
      before do
        stub_feature_flags(container_registry_expiration_policies_throttling: false)
      end

      context 'with no container expiration policies' do
        it 'Does not execute any policies' do
          expect(ContainerExpirationPolicyService).not_to receive(:new)

          subject
        end
      end

      context 'with container expiration policies' do
        let(:user) { container_expiration_policy.project.owner }

        context 'a valid policy' do
          let_it_be(:container_expiration_policy) { create(:container_expiration_policy, :runnable) }

          it 'runs the policy' do
            service = instance_double(ContainerExpirationPolicyService, execute: true)

            expect(ContainerExpirationPolicyService)
              .to receive(:new).with(container_expiration_policy.project, user).and_return(service)

            subject
          end
        end

        context 'a disabled policy' do
          let_it_be(:container_expiration_policy) { create(:container_expiration_policy, :runnable, :disabled) }

          it 'does not run the policy' do
            expect(ContainerExpirationPolicyService)
              .not_to receive(:new).with(container_expiration_policy, user)

            subject
          end
        end

        context 'a policy that is not due for a run' do
          let_it_be(:container_expiration_policy) { create(:container_expiration_policy) }
          let(:user) {container_expiration_policy.project.owner }

          it 'does not run the policy' do
            expect(ContainerExpirationPolicyService)
              .not_to receive(:new).with(container_expiration_policy, user)

            subject
          end
        end

        context 'an invalid policy' do
          let_it_be(:container_expiration_policy) { create(:container_expiration_policy, :runnable) }
          let_it_be(:user) {container_expiration_policy.project.owner }

          before do
            container_expiration_policy.update_column(:name_regex, '*production')
          end

          it 'disables the policy and tracks an error' do
            expect(ContainerExpirationPolicyService).not_to receive(:new).with(container_expiration_policy, user)
            expect(Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(described_class::InvalidPolicyError), container_expiration_policy_id: container_expiration_policy.id)

            expect { subject }.to change { container_expiration_policy.reload.enabled }.from(true).to(false)
          end
        end
      end
    end
  end
end
