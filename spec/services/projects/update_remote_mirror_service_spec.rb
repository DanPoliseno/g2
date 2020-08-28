# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdateRemoteMirrorService do
  let(:project) { create(:project, :repository) }
  let(:remote_project) { create(:forked_project_with_submodules) }
  let(:remote_mirror) { create(:remote_mirror, project: project, enabled: true) }
  let(:remote_name) { remote_mirror.remote_name }

  subject(:service) { described_class.new(project, project.creator) }

  describe '#execute' do
    subject(:execute!) { service.execute(remote_mirror, 0) }

    before do
      project.repository.add_branch(project.owner, 'existing-branch', 'master')

      allow(remote_mirror)
        .to receive(:update_repository)
        .and_return(double(divergent_refs: []))
    end

    it 'ensures the remote exists' do
      expect(remote_mirror).to receive(:ensure_remote!)

      execute!
    end

    it 'does not fetch the remote repository' do
      # See https://gitlab.com/gitlab-org/gitaly/-/issues/2670
      expect(project.repository).not_to receive(:fetch_remote)

      execute!
    end

    it 'marks the mirror as started when beginning' do
      expect(remote_mirror).to receive(:update_start!).and_call_original

      execute!
    end

    it 'marks the mirror as successfully finished' do
      result = execute!

      expect(result[:status]).to eq(:success)
      expect(remote_mirror).to be_finished
    end

    it 'marks the mirror as failed and raises the error when an unexpected error occurs' do
      allow(remote_mirror).to receive(:update_repository).and_raise('Badly broken')

      expect { execute! }.to raise_error(/Badly broken/)

      expect(remote_mirror).to be_failed
      expect(remote_mirror.last_error).to include('Badly broken')
    end

    context 'when the URL is blocked' do
      before do
        allow(Gitlab::UrlBlocker).to receive(:blocked_url?).and_return(true)
      end

      it 'fails and returns error status' do
        expect(execute!).to eq(status: :error, message: 'The remote mirror URL is invalid.')
      end
    end

    context "when given URLs containing escaped elements" do
      using RSpec::Parameterized::TableSyntax

      where(:url, :result_status) do
        "https://user:0a%23@test.example.com/project.git"                               | :success
        "https://git.example.com:1%2F%2F@source.developers.google.com/project.git"      | :success
        CGI.escape("git://localhost:1234/some-path?some-query=some-val\#@example.com/") | :error
        CGI.escape(CGI.escape("https://user:0a%23@test.example.com/project.git"))       | :error
      end

      with_them do
        before do
          allow(remote_mirror).to receive(:url).and_return(url)
        end

        it "returns expected status" do
          result = execute!

          expect(result[:status]).to eq(result_status)
        end
      end
    end

    context 'when the update fails because of a `Gitlab::Git::CommandError`' do
      before do
        allow(remote_mirror).to receive(:update_repository)
          .and_raise(Gitlab::Git::CommandError.new('update failed'))
      end

      it 'wraps `Gitlab::Git::CommandError`s in a service error' do
        expect(execute!).to eq(status: :error, message: 'update failed')
      end

      it 'marks the mirror as to be retried' do
        execute!

        expect(remote_mirror).to be_to_retry
        expect(remote_mirror.last_error).to include('update failed')
      end

      it "marks the mirror as failed after #{described_class::MAX_TRIES} tries" do
        service.execute(remote_mirror, described_class::MAX_TRIES)

        expect(remote_mirror).to be_failed
        expect(remote_mirror.last_error).to include('update failed')
      end
    end

    context 'when there are divergent refs' do
      it 'marks the mirror as failed and sets an error message' do
        response = double(divergent_refs: %w[refs/heads/master refs/heads/develop])
        expect(remote_mirror).to receive(:update_repository).and_return(response)

        execute!

        expect(remote_mirror).to be_failed
        expect(remote_mirror.last_error).to include("Some refs have diverged")
        expect(remote_mirror.last_error).to include("refs/heads/master\n")
        expect(remote_mirror.last_error).to include("refs/heads/develop")
      end
    end

    context "sending lfs objects" do
      let!(:lfs_object) { create(:lfs_objects_project, project: project).lfs_object }
      let(:sample_lfs_object) { project.lfs_objects.first }
      let(:spec) do
        {
          "objects" => [{
            "oid" => sample_lfs_object.oid,
            "size" => sample_lfs_object.size,
            "actions" => {
              "upload" => {
                "href" => "https://example.com/some/file",
                "header" => {
                  "Key" => "value"
                }
              },
              "verify" => {
                "href" => "https://example.com/some/file/verify",
                "header" => {
                  "Key" => "value"
                }
              }
            }
          }]
        }
      end

      shared_examples "returns early without attempting upload" do
        it "returns early without attempting upload" do
          expect(Gitlab::Lfs::Client).not_to receive(:upload)

          execute!
        end
      end

      context "object and and spec size do not match" do
        before do
          project.update_attribute(:lfs_enabled, true)
          allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)

          spec['objects'].first['size'] = sample_lfs_object.size + 1

          expect(Gitlab::HTTP).to receive(:post).and_return(spec)
        end

        it_behaves_like "returns early without attempting upload"

        it "logs a warning about the size mismatch" do
          expect(Rails.logger)
            .to receive(:warn)
            .with("Couldn't match #{spec['objects'].first['oid']} at size #{spec['objects'].first['size']} with an LFS object")

          execute!
        end
      end

      context "missing 'actions'" do
        before do
          spec['objects'].first.delete('actions')
        end

        it_behaves_like "returns early without attempting upload"
      end

      context "missing 'upload' action" do
        before do
          spec['objects'].first['actions'].delete('upload')
        end

        it_behaves_like "returns early without attempting upload"
      end
    end
  end
end
