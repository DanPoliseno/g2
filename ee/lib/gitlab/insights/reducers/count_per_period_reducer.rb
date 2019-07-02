# frozen_string_literal: true

module Gitlab
  module Insights
    module Reducers
      class CountPerPeriodReducer < BaseReducer
        InvalidPeriodError = Class.new(BaseReducerError)
        InvalidPeriodFieldError = Class.new(BaseReducerError)
        InvalidPeriodLimitError = Class.new(BaseReducerError)

        VALID_PERIOD = %w[day week month].freeze
        VALID_PERIOD_FIELD = %i[created_at].freeze

        def initialize(issuables, period:, period_limit:, period_field: :created_at)
          super(issuables)
          @period = period.to_s.singularize
          @period_limit = period_limit.to_i
          @period_field = period_field

          validate!
        end

        # Returns a hash { period => value_for_period(issuables) }, e.g.
        #   {
        #     #<InsightLabel @title='January 2019', @color='#990000'> => 1,
        #     #<InsightLabel @title='February 2019', @color='#009900'> => 1,
        #     #<InsightLabel @title='March 2019', @color='#000099'> => 2
        #   }
        def reduce
          count_per_period
        end

        private

        attr_reader :period, :period_limit, :period_field

        def validate!
          unless VALID_PERIOD.include?(period)
            raise InvalidPeriodError, "Invalid value for `period`: `#{period}`. Allowed values are #{VALID_PERIOD}!"
          end

          unless VALID_PERIOD_FIELD.include?(period_field)
            raise InvalidPeriodFieldError, "Invalid value for `period_field`: `#{period_field}`. Allowed values are #{VALID_PERIOD_FIELD}!"
          end

          unless period_limit > 0
            raise InvalidPeriodLimitError, "Invalid value for `period_limit`: `#{period_limit}`. Value must be greater than 0!"
          end
        end

        def count_per_period
          (0...period_limit).reverse_each.each_with_object({}) do |period_ago, hash|
            period_time = normalized_time(period_ago.public_send(period).ago) # rubocop:disable GitlabSecurity/PublicSend
            insight_label = InsightLabel.new(period_time.strftime(period_format))

            hash[insight_label] = value_for_period(issuables_grouped_by_normalized_period.fetch(period_time, []))
          end
        end

        # Returns a hash { period => [array of issuables] }, e.g.
        #   {
        #     #<Tue, 01 Jan 2019 00:00:00 UTC +00:00> => [#<Issue id:1 namespace1/project1#1>],
        #     #<Fri, 01 Feb 2019 00:00:00 UTC +00:00> => [#<Issue id:2 namespace1/project1#2>],
        #     #<Fri, 01 Mar 2019 00:00:00 UTC +00:00> => [#<Issue id:3 namespace1/project1#3>]
        #   }
        def issuables_grouped_by_normalized_period
          @issuables_grouped_by_normalized_period ||= issuables.group_by do |issuable|
            normalized_time(issuable.public_send(period_field)) # rubocop:disable GitlabSecurity/PublicSend
          end
        end

        def normalized_time(time)
          time.public_send(period_normalizer) # rubocop:disable GitlabSecurity/PublicSend
        end

        def period_normalizer
          :"beginning_of_#{period}"
        end

        def period_format
          case period
          when 'day'
            '%d %b %y'
          when 'week'
            '%d %b %y'
          when 'month'
            '%B %Y'
          end
        end

        # Can be overridden by subclasses.
        #
        # Returns the count of issuables.
        def value_for_period(issuables)
          issuables.size
        end
      end
    end
  end
end
