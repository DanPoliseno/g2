# frozen_string_literal: true

module Lfs
  # Lfs::PushService pushes the LFS objects associated with a project to a
  # remote URL
  class PushService < BaseService
    include Gitlab::Utils::StrongMemoize

    def execute
      project
        .lfs_objects_for_repository_type([nil, :project])
        .each_batch { |objects| push_objects(objects) }

      success
    rescue => err
      error(err.message)
    end

    private

    def push_objects(objects)
      rsp = lfs_client.batch('upload', objects)
      objects = objects.index_by(&:oid)

      rsp.fetch('objects', []).each do |spec|
        authenticated = spec.dig('authenticated')
        actions = spec.dig('actions')
        upload = spec.dig('actions', 'upload')
        verify = spec.dig('actions', 'verify')

        # The server already has this object, or we don't need to upload it
        next unless actions && upload

        object = objects[spec['oid']]
        # The server wants us to upload the object but something is wrong
        unless object && object.size == spec['size'].to_i
          log_error("Couldn't match object #{spec['oid']}/#{spec['size']}")
          next
        end

        lfs_client.upload(object, upload, authenticated: authenticated)

        if verify
          log_error("LFS upload verification requested, but not supported for #{object.oid}")
        end
      end
    end

    def url
      params.fetch(:url)
    end

    def credentials
      params.fetch(:credentials)
    end

    def lfs_client
      strong_memoize(:lfs_client) do
        Gitlab::Lfs::Client.new(url, credentials: credentials)
      end
    end
  end
end
