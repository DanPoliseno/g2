# frozen_string_literal: true

require 'spec_helper'

describe GroupDeletionSchedule do
  describe 'Associations' do
    it { is_expected.to belong_to :group }
    it { is_expected.to belong_to(:deleting_user).class_name('User').with_foreign_key('user_id') }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:marked_for_deletion_on) }
  end
end
