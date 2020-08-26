# frozen_string_literal: true

class RemoteMirrorLfsObjectUploaderWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :source_code_management
  weight 2

  def perform(spec, object)
    actions = spec.dig('actions')
    upload = spec.dig('actions', 'upload')
    verify = spec.dig('actions', 'verify')

    # The server already has this object, or we don't need to upload it
    #
    return unless actions && upload

    # The server wants us to upload the object but something is wrong
    #
    unless object && object.size == spec['size']
      logger.warn("Couldn't match #{spec['oid']} at size #{spec['size']} with an LFS object")
      return
    end

    lfs_client.upload(object, upload)

    if verify
      lfs_client.verify(object, verify)
    end
  end

  private

  def lfs_client
    @_lfs_client ||= Gitlab::Lfs::Client.new
  end
end
