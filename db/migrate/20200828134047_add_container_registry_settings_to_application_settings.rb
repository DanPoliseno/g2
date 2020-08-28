# frozen_string_literal: true

class AddContainerRegistrySettingsToApplicationSettings < ActiveRecord::Migration[6.0]
  DOWNTIME = false

  def up
    add_column(:application_settings, :container_registry_expiration_policies_timeout, :integer, default: 1800, null: false)
    add_column(:application_settings, :container_registry_expiration_policies_backoff_delay, :integer, default: 25, null: false)
    add_column(:application_settings, :container_registry_expiration_policies_max_slots, :integer, default: 100, null: false)
    add_column(:application_settings, :container_registry_expiration_policies_batch_size, :integer, default: 10, null: false)
    add_column(:application_settings, :container_registry_expiration_policies_batch_backoff_delay, :integer, default: 25, null: false)
  end

  def down
    remove_column(:application_settings, :container_registry_expiration_policies_timeout)
    remove_column(:application_settings, :container_registry_expiration_policies_backoff_delay)
    remove_column(:application_settings, :container_registry_expiration_policies_max_slots)
    remove_column(:application_settings, :container_registry_expiration_policies_batch_size)
    remove_column(:application_settings, :container_registry_expiration_policies_batch_backoff_delay)
  end
end
