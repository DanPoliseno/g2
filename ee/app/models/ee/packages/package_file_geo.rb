# frozen_string_literal: true

module EE
  module Packages
    module PackageFileGeo
      extend ActiveSupport::Concern

      prepended do
        include ::Gitlab::Geo::ReplicableModel
        with_replicator Geo::PackageFileReplicator
      end

      class_methods do
        def replicables_for_geo_node
          return self.all unless ::Gitlab::Geo.current_node.selective_sync?

          query = ::Packages::Package.where(project_id: ::Gitlab::Geo.current_node.projects).select(:id)
          cte = ::Gitlab::SQL::CTE.new(:restricted_packages, query)
          replicable_table = self.arel_table

          inner_join_restricted_packages =
            cte.table
              .join(replicable_table, Arel::Nodes::InnerJoin)
              .on(cte.table[:id].eq(replicable_table[:package_id]))
              .join_sources

          self
            .with(cte.to_arel)
            .from(cte.table)
            .joins(inner_join_restricted_packages)
        end
      end

      def log_geo_deleted_event
        # Keep empty for now. Should be addressed in future
        # by https://gitlab.com/gitlab-org/gitlab/issues/7891
      end
    end
  end
end