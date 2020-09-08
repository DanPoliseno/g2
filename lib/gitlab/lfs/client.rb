# frozen_string_literal: true
module Gitlab
  module Lfs
    # Gitlab::Lfs::Client implements a simple LFS client, designed to talk to
    # LFS servers as described in these documents:
    #   * https://github.com/git-lfs/git-lfs/blob/master/docs/api/batch.md
    #   * https://github.com/git-lfs/git-lfs/blob/master/docs/api/basic-transfers.md
    class Client
      attr_reader :base_url

      def initialize(base_url, credentials:)
        @base_url = base_url
        @credentials = credentials
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
          basic_auth: basic_auth,
          body: body,
          format: 'application/vnd.git-lfs+json'
        )

        transfer = rsp.fetch('transfer', 'basic')
        raise "Unsupported transfer: #{transfer.inspect}" unless transfer == 'basic'

        rsp
      end

      def upload(object, upload_action)
        # TODO: we need to discover credentials in some cases. These would come
        #   from the remote mirror's credentials
        #
        Gitlab::HTTP.put(
          upload_action['href'],
          body_stream: object.file.file.to_file,
          headers: {
            'Content-Length' => object.size.to_s
          }.merge(upload_action['header'] || {}),
          format: 'application/octet-stream'
        )
      end

      # TODO: verify the file
      #
      def verify(object, verify_action)
        # noop
      end

      private

      attr_reader :credentials

      def batch_url
        base_url + '/info/lfs/objects/batch'
      end

      def basic_auth
        return unless credentials[:auth_method] == "password"

        { username: credentials[:user], password: credentials[:password] }
      end
    end
  end
end
