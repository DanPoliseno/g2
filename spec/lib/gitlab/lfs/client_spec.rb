# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Lfs::Client do
  let(:object) { create(:lfs_object) }

  let(:upload_action) do
    {
      "upload" => {
        "href" => "https://example.com/some/file",
        "header" => {
          "Key" => "value"
        }
      }
    }
  end

  let(:verify_action) do
    {
      "verify" => {
        "href" => "https://example.com/some/file/verify",
        "header" => {
          "Key" => "value"
        }
      }
    }
  end

  describe "#upload" do
    it "makes an HTTP post with expected parameters" do
      expect(Gitlab::HTTP)
        .to receive(:post)
        .with(
          upload_action['href'],
          body_stream: object.file,
          headers:     upload_action['header'],
          format:      'application/octet-stream'
        )

      subject.upload(object, upload_action)
    end
  end

  describe "#verify" do
    it "does nothing" do
      expect(subject.verify(object, verify_action)).to be_nil
    end
  end
end
