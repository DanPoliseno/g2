# frozen_string_literal: true

class RemoteMirrorLfsObjectUploaderWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  feature_category :source_code_management
  weight 2

  def perform(remote_mirror_id, spec, object)
    @remote_mirror = RemoteMirror.find_by_id(remote_mirror_id)
    return unless @remote_mirror&.enabled?

    upload = spec.dig('actions', 'upload')
    verify = spec.dig('actions', 'verify')

    lfs_client.upload(object, upload)

    if verify
      lfs_client.verify(object, verify)
    end
  end

  private

  def lfs_client
    @_lfs_client ||= Gitlab::Lfs::Client.new(@remote_mirror.url)
  end
end
