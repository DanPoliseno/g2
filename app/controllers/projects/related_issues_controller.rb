module Projects
  class RelatedIssuesController < ApplicationController
    before_action :authorize_read_related_issue!
    before_action :authorize_admin_related_issue!, only: [:create]

    def index
      render json: RelatedIssues::ListService.new(issue, current_user).execute
    end

    def create
      opts = { issue_references: params[:issue_references] }
      result = RelatedIssues::CreateService.new(issue, current_user, opts).execute

      render json: result, status: result['http_status']
    end

    private

    def authorize_admin_related_issue!
      return render_404 unless can?(current_user, :admin_related_issue, @project)
    end

    def authorize_read_related_issue!
      return render_404 unless can?(current_user, :read_related_issue, @project)
    end

    def issue
      @issue ||=
        IssuesFinder.new(current_user, project_id: project.id)
                    .execute
                    .where(iid: params[:issue_id])
                    .first!
    end
  end
end
