# frozen_string_literal: true

require 'spec_helper'

describe Geo::ProjectUnsyncedFinder, :geo, :geo_fdw do
  describe '#execute' do
    let(:node) { create(:geo_node) }
    let(:group_1) { create(:group) }
    let(:group_2) { create(:group) }
    let(:nested_group_1) { create(:group, parent: group_1) }
    let!(:project_1) { create(:project, group: group_1) }
    let!(:project_2) { create(:project, group: nested_group_1) }
    let!(:project_3) { create(:project, group: group_2) }
    let!(:project_4) { create(:project, group: group_1) }

    before do
      project_4.update_column(:repository_storage, 'foo')
    end

    subject { described_class.new(current_node: node, shard_name: 'default', batch_size: 100) }

    context 'without selective sync' do
      it 'returns projects without an entry on the tracking database' do
        create(:geo_project_registry, :synced, project: project_2)

        expect(subject.execute).to match_ids(project_1, project_3)
      end
    end

    context 'with selective sync by namespace' do
      it 'returns projects that belong to the namespaces without an entry on the tracking database' do
        create(:geo_project_registry, :synced, project: project_4)

        node.update!(selective_sync_type: 'namespaces', namespaces: [group_1, nested_group_1])

        expect(subject.execute).to match_ids(project_1, project_2)
      end
    end

    context 'with selective sync by shard' do
      before do
        node.update!(selective_sync_type: 'shards', selective_sync_shards: ['foo'])
      end

      it 'does not return registries when selected shards to sync does not include the shard_name' do
        subject = described_class.new(current_node: node, shard_name: 'default', batch_size: 100)

        expect(subject.execute).to be_empty
      end

      it 'returns projects that belong to the shards without an entry on the tracking database' do
        project_5 = create(:project, group: group_1)
        project_5.update_column(:repository_storage, 'foo')
        create(:geo_project_registry, :synced, project: project_4)

        subject = described_class.new(current_node: node, shard_name: 'foo', batch_size: 100)

        expect(subject.execute).to match_ids(project_5)
      end
    end
  end
end
