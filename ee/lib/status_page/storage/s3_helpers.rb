# frozen_string_literal: true

module StatusPage
  module Storage
    module S3Helpers
      def wrap_errors(**args)
        yield
      rescue Aws::Errors::ServiceError => e
        raise Error, bucket: bucket_name, error: e, **args
      end
    end
  end
end
