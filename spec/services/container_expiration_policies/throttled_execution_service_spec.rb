# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerExpirationPolicies::ThrottledExecutionService do
  let_it_be(:policies) { create_list(:container_expiration_policy, 10, :runnable) }
  let_it_be(:policy_ids) { policies.map(&:id) }

  describe '#execute' do
    subject { described_class.new(container: policy_ids).execute }

    context 'with feature flag enabled' do
      before do
        stub_feature_flags(container_registry_expiration_policies_throttling: true)
      end

      it 'schedules the next runs' do
        expect { subject }.to change { policies.map(&:reload).map(&:next_run_at) }
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
