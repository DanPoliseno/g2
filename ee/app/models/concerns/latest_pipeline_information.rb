# frozen_string_literal: true

module LatestPipelineInformation
  private

  def scanner_enabled?(scan_type)
    latest_builds_reports.include?(scan_type)
  end

  def latest_builds_reports(only_successful_builds: false)
    strong_memoize("latest_builds_reports_#{only_successful_builds}" ) do
      builds = latest_security_builds
      builds = builds.select { |build| build.status == 'success' } if only_successful_builds
      builds.map do |build|
        if Feature.enabled?(:ci_build_metadata_config)
          build.metadata.config_options[:artifacts][:reports].keys.map(&:to_sym)
        else
          build.options[:artifacts][:reports].keys
        end
      end.flatten
    end
  end

  def latest_security_builds
    return [] unless latest_default_branch_pipeline

    ::Security::SecurityJobsFinder.new(pipeline: latest_default_branch_pipeline).execute +
      ::Security::LicenseComplianceJobsFinder.new(pipeline: latest_default_branch_pipeline).execute
  end

  def latest_default_branch_pipeline
    strong_memoize(:pipeline) { latest_pipeline_for_ref }
  end

  def auto_devops_source?
    latest_default_branch_pipeline&.auto_devops_source?
  end
end