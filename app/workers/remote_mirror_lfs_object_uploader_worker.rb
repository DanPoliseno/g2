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

    # TODO: we need to discover credentials in some cases. These would come from
    #   the remote mirror's credentials
    #
    Gitlab::HTTP.post(
      upload['href'],
      body_stream: object.file,
      headers: upload['header'],
      format: 'application/octet-stream'
    )

    # TODO: Now we've uploaded, verify the upload if requested
    #
    if verify
      logger.warn("Was asked to verify #{spec['oid']} but didn't: #{verify}")
    end
  end
end
