# frozen_string_literal: true
module Gitlab
  module Lfs
    class Client
      def upload(object, upload_action)
        # TODO: we need to discover credentials in some cases. These would come
        #   from the remote mirror's credentials
        #
        Gitlab::HTTP.post(
          upload_action['href'],
          body_stream: object.file,
          headers: upload_action['header'],
          format: 'application/octet-stream'
        )
      end

      # TODO: verify the file
      #
      def verify(object, verify_action)
        # noop
      end
    end
  end
end
