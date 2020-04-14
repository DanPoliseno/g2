# frozen_string_literal: true

module Gitlab
  module Database
    class CustomStructure
      def dump(io)
        io << "SET search_path=public;\n\n"

        dump_partitioned_foreign_keys(io) if partitioned_foreign_keys_exist?
      end

      private

      def dump_partitioned_foreign_keys(io)
        io << "COPY partitioned_foreign_keys (#{partitioned_fk_columns.join(", ")}) FROM STDIN;\n"

        PartitioningMigrationHelpers::PartitionedForeignKey.find_each do |fk|
          io << fk.attributes.values_at(*partitioned_fk_columns).join("\t") << "\n"
        end
        io << "\\.\n"
      end

      def partitioned_foreign_keys_exist?
        return false unless PartitioningMigrationHelpers::PartitionedForeignKey.table_exists?

        PartitioningMigrationHelpers::PartitionedForeignKey.exists?
      end

      def partitioned_fk_columns
        @partitioned_fk_columns ||= PartitioningMigrationHelpers::PartitionedForeignKey.column_names
      end
    end
  end
end
