# frozen_string_literal: true

RSpec.shared_examples 'a Geo framework repository registry' do
  let(:registry_class_factory) { described_class.underscore.tr('/', '_').to_sym }

  describe '#synced!' do
    let!(:registry) { create(registry_class_factory, :started) }

    it 'sets missing_on_primary true' do
      registry.synced!(missing_on_primary: true)

      expect(registry.missing_on_primary).to be_truthy
    end

    it 'sets missing_on_primary to false by default' do
      registry.synced!

      expect(registry.missing_on_primary).to be_falsey
    end
  end
end
