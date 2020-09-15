# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'IDE user commits changes', :js do
  include WebIdeSpecHelpers

  let(:project) { create(:project, :public, :repository) }
  let(:user) { project.owner }

  context "with default" do
    before do
      sign_in(user)

      ide_visit(project)
    end

    it 'user updates nested files' do
      content = <<~HEREDOC
        Lorem ipsum
        Dolar sit
        Amit
      HEREDOC

      ide_create_new_file('foo/bar/lorem_ipsum.md', content: content)
      ide_delete_file('foo/bar/.gitkeep')

      ide_commit

      expect(page).to have_content('All changes are committed')
      expect(project.repository.blob_at('master', 'foo/bar/.gitkeep')).to be_nil
      expect(project.repository.blob_at('master', 'foo/bar/lorem_ipsum.md').data).to eql(content)
    end
  end

  context "with CODEOWNERS and push to protected is blocked" do
    let(:ruby_owner) { create(:user, username: 'ruby-owner') }
    let(:project) do
      create(:project, :custom_repo,
             files: { 'docs/CODEOWNERS' => "[Backend]\n*.rb @ruby-owner" })
    end

    before do
      project.add_developer(ruby_owner)
      stub_licensed_features(code_owners: true, code_owner_approval_required: true)

      create(:protected_branch,
        name: 'master',
        code_owner_approval_required: true,
        project: project)

      sign_in(user)

      ide_visit(project)
    end

    it 'shows error message' do
      ide_create_new_file('test.rb', content: '# A ruby file')

      ide_commit

      expect(page).to have_content('CODEOWNERS rule violation')
      expect(page).to have_button('Cancel')
      expect(page).to have_button('Create new branch')
    end
  end
end
