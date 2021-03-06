# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      module LicenseScanning
        class License
          LICENSE_TO_SPDX_ID = {
            'AGPL-1.0' => 'AGPL-1.0',
            'AGPL-3.0' => 'AGPL-3.0',
            'Apache 2.0' => 'Apache-2.0',
            'Artistic-2.0' => 'Artistic-2.0',
            'BSD' => 'BSD-4-Clause',
            'CC0 1.0 Universal' => 'CC0-1.0',
            'CDDL-1.0' => 'CDDL-1.0',
            'CDDL-1.1' => 'CDDL-1.1',
            'EPL-1.0' => 'EPL-1.0',
            'EPL-2.0' => 'EPL-2.0',
            'GPLv2' => 'GPL-2.0',
            'GPLv3' => 'GPL-3.0',
            'ISC' => 'ISC',
            'LGPL' => 'LGPL-3.0-only',
            'LGPL-2.1' => 'LGPL-2.1',
            'MIT' => 'MIT',
            'Mozilla Public License 2.0' => 'MPL-2.0',
            'MS-PL' => 'MS-PL',
            'MS-RL' => 'MS-RL',
            'New BSD' => 'BSD-3-Clause',
            'Python Software Foundation License' => 'Python-2.0',
            'ruby' => 'Ruby',
            'Simplified BSD' => 'BSD-2-Clause',
            'WTFPL' => 'WTFPL',
            'Zlib' => 'Zlib'
          }.freeze

          attr_reader :id, :name, :url

          delegate :count, to: :dependencies

          def initialize(id:, name:, url:)
            @id = LICENSE_TO_SPDX_ID.fetch(name) do
              id == 'unknown' ? nil : id
            end
            @name = name
            @url = url
            @dependencies = Set.new
          end

          def canonical_id
            id || name&.downcase
          end

          def hash
            canonical_id.hash
          end

          def add_dependency(name)
            @dependencies.add(::Gitlab::Ci::Reports::LicenseScanning::Dependency.new(name))
          end

          def dependencies
            @dependencies.to_a
          end

          def eql?(other)
            super(other) ||
              (id && other.id && id.eql?(other.id)) ||
              (name && other.name && name.casecmp?(other.name))
          end
        end
      end
    end
  end
end
