# frozen_string_literal: true

module Projects
  class UpdateRemoteMirrorService < BaseService
    MAX_TRIES = 3

    def execute(remote_mirror, tries)
      return success unless remote_mirror.enabled?

      if Gitlab::UrlBlocker.blocked_url?(CGI.unescape(Gitlab::UrlSanitizer.sanitize(remote_mirror.url)))
        return error("The remote mirror URL is invalid.")
      end

      update_mirror(remote_mirror)

      success
    rescue Gitlab::Git::CommandError => e
      # This happens if one of the gitaly calls above fail, for example when
      # branches have diverged, or the pre-receive hook fails.
      retry_or_fail(remote_mirror, e.message, tries)

      error(e.message)
    rescue => e
      remote_mirror.mark_as_failed!(e.message)
      raise e
    end

    private

    def update_mirror(remote_mirror)
      remote_mirror.update_start!
      remote_mirror.ensure_remote!

      response = remote_mirror.update_repository

      if response.divergent_refs.any?
        message = "Some refs have diverged and have not been updated on the remote:"
        message += "\n\n#{response.divergent_refs.join("\n")}"

        remote_mirror.mark_as_failed!(message)
        return
      end

      send_lfs_objects!(remote_mirror)

      remote_mirror.update_finish!
    end

    # Minimal implementation of a git-lfs client, based on the docs here:
    # https://github.com/git-lfs/git-lfs/blob/master/docs/api/batch.md
    #
    # The object is to send all the project's LFS objects to the remote
    def send_lfs_objects!(remote_mirror)
      return unless Feature.enabled?(:push_mirror_syncs_lfs, project)
      return unless project.lfs_enabled?
      return if project.lfs_objects.count == 0

      # TODO: LFS sync should be configurable per remote mirror

      # TODO: LFS sync over SSH
      return unless remote_mirror.url =~ /\Ahttps?:\/\//i

      # FIXME: do we need .git on the URL?
      url = remote_mirror.url + "/info/lfs/objects/batch"
      objects = project.lfs_objects.index_by(&:oid)

      # TODO: we can use body_stream if we want to reduce overhead here
      body = {
        operation: 'upload',
        transfers: ['basic'],
        # We don't know `ref`, so can't send it
        objects: objects.map { |oid, object| { oid: oid, size: object.size } }
      }

      rsp = Gitlab::HTTP.post(url, format: 'application/vnd.git-lfs+json', body: body)
      transfer = rsp.fetch('transfer', 'basic')

      raise "Unsupported transfer: #{transfer.inspect}" unless transfer == 'basic'

      # TODO: we could parallelize this
      rsp['objects'].each do |spec|
        actions = spec.dig('actions')
        upload = spec.dig('actions', 'upload')
        verify = spec.dig('actions', 'verify')
        object = objects[spec['oid']]

        # The server already has this object, or we don't need to upload it
        next unless actions && upload

        # The server wants us to upload the object but something is wrong
        unless object && object.size == spec['size']
          logger.warn("Couldn't match #{spec['oid']} at size #{spec['size']} with an LFS object")
          next
        end

        # TODO: we need to discover credentials in some cases. These would come
        # from the remote mirror's credentials
        Gitlab::HTTP.post(
          upload['href'],
          body_stream: object.file,
          headers: upload['header'],
          format: 'application/octet-stream'
        )

        # TODO: Now we've uploaded, verify the upload if requested
        if verify
          logger.warn("Was asked to verify #{spec['oid']} but didn't: #{verify}")
        end
      end
    end

    def retry_or_fail(mirror, message, tries)
      if tries < MAX_TRIES
        mirror.mark_for_retry!(message)
      else
        # It's not likely we'll be able to recover from this ourselves, so we'll
        # notify the users of the problem, and don't trigger any sidekiq retries
        # Instead, we'll wait for the next change to try the push again, or until
        # a user manually retries.
        mirror.mark_as_failed!(message)
      end
    end
  end
end
