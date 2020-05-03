# frozen_string_literal: true

module Mutations
  module AlertManagement
    class UpdateAlertStatus < Base
      graphql_name 'UpdateAlertStatus'

      argument :status, Types::AlertManagement::StatusEnum,
               required: true,
               description: 'The status to set the alert'

      def resolve(args)
        alert = authorized_find!(project_path: args[:project_path], iid: args[:iid])

        result = update_status(alert, args[:status])
        prepare_response(result)
      end

      private

      def update_status(alert, status)
        service = ::AlertManagement::UpdateAlertStatusService.new(alert, status)
        service.execute
      end

      def prepare_response(result)
        {
          alert: result.payload[:alert],
          errors: result.error? ? [result.message].compact : []
        }
      end
    end
  end
end
