# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Database::CustomStructure do
  let_it_be(:structure) { described_class.new }
  let(:io) { StringIO.new }

  context 'when there are no partitioned_foreign_keys' do
    it 'dumps a valid structure file' do
      structure.dump(io)

      expect(io.string).to eq("SET search_path=public;\n\n")
    end
  end

  context 'when there are partitioned_foreign_keys' do
    let!(:first_fk) do
      Gitlab::Database::PartitioningMigrationHelpers::PartitionedForeignKey.create(
        cascade_delete: true, from_table: 'issues', from_column: 'project_id', to_table: 'projects', to_column: 'id')
    end
    let!(:second_fk) do
      Gitlab::Database::PartitioningMigrationHelpers::PartitionedForeignKey.create(
        cascade_delete: false, from_table: 'issues', from_column: 'moved_to_id', to_table: 'issues', to_column: 'id')
    end

    it 'dumps a file with the command to restore the keys' do
      structure.dump(io)

      expect(io.string).to eq(<<~DATA)
        SET search_path=public;

        COPY partitioned_foreign_keys (id, cascade_delete, from_table, from_column, to_table, to_column) FROM STDIN;
        #{first_fk.id}\ttrue\tissues\tproject_id\tprojects\tid
        #{second_fk.id}\tfalse\tissues\tmoved_to_id\tissues\tid
        \\.
      DATA
    end
  end
end
