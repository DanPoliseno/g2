# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::ImportExport::Project::TreeSaver do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:shared) { project.import_export_shared }
  let_it_be(:note2) { create(:note, noteable: issue, project: project, author: user) }

  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:epic_issue) { create(:epic_issue, issue: issue, epic: epic) }

  let_it_be(:export_path) { "#{Dir.tmpdir}/project_tree_saver_spec_ee" }

  after :all do
    FileUtils.rm_rf(export_path)
  end

  shared_examples 'EE saves project tree successfully' do |ndjson_enabled|
    include ::ImportExport::CommonUtil

    let_it_be(:project_tree_saver) { described_class.new(project: project, current_user: user, shared: shared) }

    let_it_be(:full_path) do
      if ndjson_enabled
        File.join(shared.export_path, 'tree')
      else
        File.join(shared.export_path, Gitlab::ImportExport.project_filename)
      end
    end

    let_it_be(:exportable_path) { 'project' }

    before_all do
      RSpec::Mocks.with_temporary_scope do
        allow(Feature).to receive(:enabled?) { true }
        stub_feature_flags(project_export_as_ndjson: ndjson_enabled)
        project.add_maintainer(user)

        expect(project_tree_saver.save).to be true
      end
    end

    let_it_be(:issue_json) { get_json(full_path, exportable_path, :issues, ndjson_enabled).first }

    context 'epics' do
      it 'has epic_issue' do
        expect(issue_json['epic_issue']).not_to be_empty
        expect(issue_json['epic_issue']['id']).to eql(epic_issue.id)
      end

      it 'has epic' do
        expect(issue_json['epic_issue']['epic']['title']).to eql(epic.title)
      end

      it 'does not have epic_id' do
        expect(issue_json['epic_issue']['epic_id']).to be_nil
      end

      it 'does not have issue_id' do
        expect(issue_json['epic_issue']['issue_id']).to be_nil
      end
    end
  end

  context 'with JSON' do
    it_behaves_like "EE saves project tree successfully", false
  end

  context 'with NDJSON' do
    it_behaves_like "EE saves project tree successfully", true
  end
end
