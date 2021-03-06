# frozen_string_literal: true

require 'spec_helper'

describe 'getting merge request listings nested in a project' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:label) { create(:label) }
  let_it_be(:merge_request_a) { create(:labeled_merge_request, :unique_branches, source_project: project, labels: [label]) }
  let_it_be(:merge_request_b) { create(:merge_request, :closed, :unique_branches, source_project: project) }
  let_it_be(:merge_request_c) { create(:labeled_merge_request, :closed, :unique_branches, source_project: project, labels: [label]) }
  let_it_be(:merge_request_d) { create(:merge_request, :locked, :unique_branches, source_project: project) }

  let(:results) { graphql_data.dig('project', 'mergeRequests', 'nodes') }

  let(:search_params) { nil }

  def query_merge_requests(fields)
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(:merge_requests, search_params, [
        query_graphql_field(:nodes, nil, fields)
      ])
    )
  end

  let(:query) do
    query_merge_requests(all_graphql_fields_for('MergeRequest', max_depth: 1))
  end

  it_behaves_like 'a working graphql query' do
    before do
      post_graphql(query, current_user: current_user)
    end
  end

  # The following tests are needed to guarantee that we have correctly annotated
  # all the gitaly calls.  Selecting combinations of fields may mask this due to
  # memoization.
  context 'requesting a single field' do
    let(:fresh_mr) { create(:merge_request, :unique_branches, source_project: project) }
    let(:search_params) { { iids: [fresh_mr.iid.to_s] } }

    before do
      project.repository.expire_branches_cache
    end

    context 'selecting any single scalar field' do
      where(:field) do
        scalar_fields_of('MergeRequest').map { |name| [name] }
      end

      with_them do
        it_behaves_like 'a working graphql query' do
          let(:query) do
            query_merge_requests([:iid, field].uniq)
          end

          before do
            post_graphql(query, current_user: current_user)
          end

          it 'selects the correct MR' do
            expect(results).to contain_exactly(a_hash_including('iid' => fresh_mr.iid.to_s))
          end
        end
      end
    end

    context 'selecting any single nested field' do
      where(:field, :subfield, :is_connection) do
        nested_fields_of('MergeRequest').flat_map do |name, field|
          type = field_type(field)
          is_connection = type.name.ends_with?('Connection')
          type = field_type(type.fields['nodes']) if is_connection

          type.fields
            .select { |_, field| !nested_fields?(field) && !required_arguments?(field) }
            .map(&:first)
            .map { |subfield| [name, subfield, is_connection] }
        end
      end

      with_them do
        it_behaves_like 'a working graphql query' do
          let(:query) do
            fld = is_connection ? query_graphql_field(:nodes, nil, [subfield]) : subfield
            query_merge_requests([:iid, query_graphql_field(field, nil, [fld])])
          end

          before do
            post_graphql(query, current_user: current_user)
          end

          it 'selects the correct MR' do
            expect(results).to contain_exactly(a_hash_including('iid' => fresh_mr.iid.to_s))
          end
        end
      end
    end
  end

  shared_examples 'searching with parameters' do
    let(:expected) do
      mrs.map { |mr| a_hash_including('iid' => mr.iid.to_s, 'title' => mr.title) }
    end

    it 'finds the right mrs' do
      post_graphql(query, current_user: current_user)

      expect(results).to match_array(expected)
    end
  end

  context 'there are no search params' do
    let(:search_params) { nil }
    let(:mrs) { [merge_request_a, merge_request_b, merge_request_c, merge_request_d] }

    it_behaves_like 'searching with parameters'
  end

  context 'the search params do not match anything' do
    let(:search_params) { { iids: %w(foo bar baz) } }
    let(:mrs) { [] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by iids' do
    let(:search_params) { { iids: mrs.map(&:iid).map(&:to_s) } }
    let(:mrs) { [merge_request_a, merge_request_c] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by state' do
    let(:search_params) { { state: :closed } }
    let(:mrs) { [merge_request_b, merge_request_c] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by source_branch' do
    let(:search_params) { { source_branches: mrs.map(&:source_branch) } }
    let(:mrs) { [merge_request_b, merge_request_c] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by target_branch' do
    let(:search_params) { { target_branches: mrs.map(&:target_branch) } }
    let(:mrs) { [merge_request_a, merge_request_d] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by label' do
    let(:search_params) { { labels: [label.title] } }
    let(:mrs) { [merge_request_a, merge_request_c] }

    it_behaves_like 'searching with parameters'
  end

  context 'searching by combination' do
    let(:search_params) { { state: :closed, labels: [label.title] } }
    let(:mrs) { [merge_request_c] }

    it_behaves_like 'searching with parameters'
  end
end
