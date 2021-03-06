# frozen_string_literal: true

require 'spec_helper'

describe Banzai::Filter::LabelReferenceFilter do
  include FilterSpecHelper

  let(:project)      { create(:project, :public, name: 'sample-project') }
  let(:label)        { create(:label, name: 'label', project: project) }
  let(:scoped_label) { create(:label, name: 'key::value', project: project) }

  context 'with scoped labels enabled' do
    before do
      stub_licensed_features(scoped_labels: true)
    end

    it 'renders scoped label with link to documentation' do
      doc = reference_filter("See #{scoped_label.to_reference}")

      expect(doc.css('.gl-label-scoped .gl-label-text').map(&:text)).to eq([scoped_label.scoped_label_key, scoped_label.scoped_label_value])
    end

    it 'renders common label' do
      doc = reference_filter("See #{label.to_reference}")

      expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([label.name])
    end
  end

  context 'with scoped labels disabled' do
    before do
      stub_licensed_features(scoped_labels: false)
    end

    it 'renders scoped label as a common label' do
      doc = reference_filter("See #{scoped_label.to_reference}")

      expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([scoped_label.name])
    end
  end
end
