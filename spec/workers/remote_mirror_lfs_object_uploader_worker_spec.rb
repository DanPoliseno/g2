# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteMirrorLfsObjectUploaderWorker do
  let(:logger) { subject.send(:logger) }

  let(:object) { create(:lfs_object) }

  let(:spec) do
    {
      "oid" => object.oid,
      "size" => object.size,
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
    }
  end

  let_it_be(:project) { create(:forked_project_with_submodules) }
  let_it_be(:remote_mirror) { create(:remote_mirror, project: project, enabled: true) }

  describe "#perform" do
    context "upload to remote server is requested" do
      before do
        expect_next_instance_of(Gitlab::Lfs::Client) do |instance|
          expect(instance).to receive(:upload)
        end
      end

      it "attempts to upload the LFS object" do
        subject.perform(remote_mirror.id, spec, object)
      end

      context "when 'verify' action is present" do
        before do
          expect_any_instance_of(Gitlab::Lfs::Client).to receive(:verify).and_call_original
        end

        it "logs a warning about the lack of a verify routine" do
          subject.perform(remote_mirror.id, spec, object)
        end
      end

      context "when 'verify' action is missing" do
        before do
          spec['actions'].delete('verify')

          expect_any_instance_of(Gitlab::Lfs::Client).not_to receive(:verify).and_call_original
        end

        it "does not attempt to verify the object" do
          subject.perform(remote_mirror.id, spec, object)
        end
      end
    end
  end
end
