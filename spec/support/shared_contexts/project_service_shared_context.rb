# frozen_string_literal: true

RSpec.shared_context 'project service activation' do
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  def visit_project_integrations
    visit project_settings_integrations_path(project)
  end

  def visit_project_integration(name)
    visit_project_integrations
    click_link(name)
  end

  def click_active_checkbox
    find('input[name="service[active]"]').click
  end

  def click_save_integration
    click_button('Save changes')
  end

  def click_test_integration
    click_link('Test settings')
  end

  def click_test_then_save_integration
    click_test_integration

    expect(page).to have_content('Connection failed.')

    click_save_integration
  end
end
