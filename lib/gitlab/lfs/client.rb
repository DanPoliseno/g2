# frozen_string_literal: true
module Gitlab
  module Lfs
    class Client
      attr_reader :base_url

      def initialize(base_url)
        @base_url = base_url
      end

      def batch(operation, objects)
        body = {
          operation: operation,
          transfers: ['basic'],
          # We don't know `ref`, so can't send it
          objects: objects.map { |object| { oid: object.oid, size: object.size } }
        }

        rsp = Gitlab::HTTP.post(
          batch_url,
          format: 'application/vnd.git-lfs+json',
          body: body
        )

        transfer = rsp.fetch('transfer', 'basic')
        raise "Unsupported transfer: #{transfer.inspect}" unless transfer == 'basic'

        rsp
      end

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

      private

      def batch_url
        base_url + '/info/lfs/objects/batch'
      end
    end
  end
end
