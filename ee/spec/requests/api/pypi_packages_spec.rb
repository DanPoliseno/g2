# frozen_string_literal: true
require 'spec_helper'

describe API::PypiPackages do
  include WorkhorseHelpers
  include EE::PackagesManagerApiSpecHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, reload: true) { create(:project, :public) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  describe 'GET /api/v4/projects/:id/packages/pypi/simple/:package_name' do
    let(:url) { "/projects/#{project.id}/packages/pypi/simple/sample-project" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | true  | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | true  | false | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | true  | false | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | false | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | false | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | false | false | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | false | false | 'process PyPi api request' | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process PyPi api request' | :success
          'PRIVATE' | :developer  | true  | true  | 'process PyPi api request' | :success
          'PRIVATE' | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :guest      | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects PyPI access with unknown project id'
    end

    it_behaves_like 'rejects PyPI packages access with packages features disabled'
  end

  describe 'POST /api/v4/projects/:id/packages/pypi/authorize' do
    let_it_be(:workhorse_token) { JWT.encode({ 'iss' => 'gitlab-workhorse' }, Gitlab::Workhorse.secret, 'HS256') }
    let_it_be(:workhorse_header) { { 'GitLab-Workhorse' => '1.0', Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER => workhorse_token } }
    let(:url) { "/projects/#{project.id}/packages/pypi/authorize" }
    let(:headers) { {} }

    subject { post api(url), headers: headers }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :developer  | false | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :guest      | false | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | true  | true  | 'process PyPi api request' | :success
          'PRIVATE' | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :guest      | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:user_headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }
          let(:headers) { user_headers.merge(workhorse_header) }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects PyPI access with unknown project id'
    end

    it_behaves_like 'rejects PyPI packages access with packages features disabled'
  end

  describe 'POST /api/v4/projects/:id/packages/pypi' do
    let(:workhorse_token) { JWT.encode({ 'iss' => 'gitlab-workhorse' }, Gitlab::Workhorse.secret, 'HS256') }
    let(:workhorse_header) { { 'GitLab-Workhorse' => '1.0', Gitlab::Workhorse::INTERNAL_API_REQUEST_HEADER => workhorse_token } }
    let_it_be(:file_name) { 'package.whl' }
    let(:url) { "/projects/#{project.id}/packages/pypi" }
    let(:headers) { {} }
    let(:params) { { content: temp_file(file_name) } }

    subject do
      workhorse_finalize(
        api(url),
        method: :post,
        file_key: :content,
        params: params,
        headers: headers
      )
    end

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process PyPi api request' | :created
          'PUBLIC'  | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :developer  | false | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :guest      | false | true  | 'process PyPi api request' | :forbidden
          'PUBLIC'  | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PUBLIC'  | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | true  | true  | 'process PyPi api request' | :created
          'PRIVATE' | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :guest      | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:user_headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }
          let(:headers) { user_headers.merge(workhorse_header) }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects PyPI access with unknown project id'
    end

    it_behaves_like 'rejects PyPI packages access with packages features disabled'
  end

  describe 'GET /api/v4/projects/:id/packages/pypi/files/*file_identifier' do
    let_it_be(:package_name) { 'Dummy-Package' }
    let_it_be(:package) { create(:pypi_package, project: project, name: package_name) }

    let(:url) { "/projects/#{project.id}/packages/pypi/files/sample_project-1.0.0-py3-none-any.whl" }

    subject { get api(url) }

    context 'with packages features enabled' do
      before do
        stub_licensed_features(packages: true)
      end

      context 'with valid project' do
        using RSpec::Parameterized::TableSyntax

        where(:project_visibility_level, :user_role, :member, :user_token, :shared_examples_name, :expected_status) do
          'PUBLIC'  | :developer  | true  | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | true  | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | true  | false | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | true  | false | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | false | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | false | true  | 'process PyPi api request' | :success
          'PUBLIC'  | :developer  | false | false | 'process PyPi api request' | :success
          'PUBLIC'  | :guest      | false | false | 'process PyPi api request' | :success
          'PUBLIC'  | :anonymous  | false | true  | 'process PyPi api request' | :success
          'PRIVATE' | :developer  | true  | true  | 'process PyPi api request' | :success
          'PRIVATE' | :guest      | true  | true  | 'process PyPi api request' | :forbidden
          'PRIVATE' | :developer  | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | true  | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :developer  | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :guest      | false | true  | 'process PyPi api request' | :not_found
          'PRIVATE' | :developer  | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :guest      | false | false | 'process PyPi api request' | :unauthorized
          'PRIVATE' | :anonymous  | false | true  | 'process PyPi api request' | :unauthorized
        end

        with_them do
          let(:token) { user_token ? personal_access_token.token : 'wrong' }
          let(:headers) { user_role == :anonymous ? {} : build_basic_auth_header(user.username, token) }

          subject { get api(url), headers: headers }

          before do
            project.update!(visibility_level: Gitlab::VisibilityLevel.const_get(project_visibility_level, false))
          end

          it_behaves_like params[:shared_examples_name], params[:user_role], params[:expected_status], params[:member]
        end
      end

      it_behaves_like 'rejects PyPI access with unknown project id'
    end

    it_behaves_like 'rejects PyPI packages access with packages features disabled'
  end
end
