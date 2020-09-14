# frozen_string_literal: true

module DesignManagement
  class DesignCollection
    attr_reader :issue

    delegate :designs, :project, to: :issue

    state_machine :copy_state, initial: :ready, namespace: :copy do
      after_transition any => any, do: :store_copy_state!

      event :queue do
        transition ready: :pending
      end

      event :start do
        transition pending: :copying
      end

      event :end do
        transition copying: :ready
      end

      event :error do
        transition copying: :error
      end

      event :reset do
        transition any => :ready
      end
    end

    def initialize(issue)
      super() # Necessary to initialize state_machine

      @issue = issue

      if stored_copy_state = get_stored_copy_state
        @copy_state = stored_copy_state
      end
    end

    def ==(other)
      other.is_a?(self.class) && issue == other.issue
    end

    def find_or_create_design!(filename:)
      designs.find { |design| design.filename == filename } ||
        designs.safe_find_or_create_by!(project: project, filename: filename)
    end

    def versions
      @versions ||= DesignManagement::Version.for_designs(designs)
    end

    def repository
      project.design_repository
    end

    def designs_by_filename(filenames)
      designs.current.where(filename: filenames)
    end

    private

    def copy_state_cache_key
      "DesignCollection/copy_state/#{@issue.id}"
    end

    def get_stored_copy_state
      Gitlab::Redis::SharedState.with do |redis|
        redis.get(copy_state_cache_key)
      end
    end

    def store_copy_state!
      Gitlab::Redis::SharedState.with do |redis|
        redis.set(copy_state_cache_key, copy_state)
      end
    end
  end
end
