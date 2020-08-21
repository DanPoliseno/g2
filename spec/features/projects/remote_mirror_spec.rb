# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project remote mirror', :feature do
  let(:project) { create(:project, :repository, :remote_mirror) }
  let(:remote_mirror) { project.remote_mirrors.first }
  let(:user) { create(:user) }

  describe 'On a project', :js do
    before do
      project.add_maintainer(user)
      sign_in user
    end

    context 'when last_error is present but last_update_at is not' do
      it 'renders error message without timstamp' do
        remote_mirror.update(last_error: 'Some new error', last_update_at: nil)

        visit project_mirror_path(project)

        expect_mirror_to_have_error_and_timeago('Never')
      end
    end

    context 'when last_error and last_update_at are present' do
      it 'renders error message with timestamp' do
        remote_mirror.update(last_error: 'Some new error', last_update_at: Time.now - 5.minutes)

        visit project_mirror_path(project)

        expect_mirror_to_have_error_and_timeago('5 minutes ago')
      end
    end

    context 'pushing to a remote' do
      let(:remote_project) { create(:project, :empty_repo) }

      before do
        remote_project.add_maintainer(user)

        # FIXME: currently blocked
        remote_mirror.update!(url: remote_project.http_url_to_repo)
      end

      it 'transfers code and LFS objects' do
        lfs_object = create(:lfs_objects_project, project: project).lfs_object

        Projects::UpdateRemoveMirrorService.new(project, user).execute(remote_mirror)

        expect(remote_project.lfs_objects.reload.count).to eq(1)
        expect(remote_project.commit).to eq(project.commit)
      end
    end

    def expect_mirror_to_have_error_and_timeago(timeago)
      row = first('.js-mirrors-table-body tr')
      expect(row).to have_content('Error')
      expect(row).to have_content(timeago)
    end
  end
end
