# frozen_string_literal: true

class RemoteMirrorLfsObjectUploaderWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :source_code_management
  weight 2

  def perform(spec, object)
    upload = spec.dig('actions', 'upload')
    verify = spec.dig('actions', 'verify')

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
