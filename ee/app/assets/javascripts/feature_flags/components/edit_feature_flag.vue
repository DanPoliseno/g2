<script>
import { GlAlert, GlLoadingIcon, GlToggle } from '@gitlab/ui';
import { createNamespacedHelpers } from 'vuex';
import { sprintf, s__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { LEGACY_FLAG, NEW_FLAG_ALERT } from '../constants';
import store from '../store/index';
import FeatureFlagForm from './form.vue';

const { mapState, mapActions } = createNamespacedHelpers('edit');

export default {
  store,
  components: {
    GlAlert,
    GlLoadingIcon,
    GlToggle,
    FeatureFlagForm,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    endpoint: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    environmentsEndpoint: {
      type: String,
      required: true,
    },
  },
  translations: {
    legacyFlagAlert: s__(
      'FeatureFlags|GitLab is moving to a new way of managing feature flags, and in 13.4, this feature flag will become read-only. Please create a new feature flag.',
    ),
    newFlagAlert: NEW_FLAG_ALERT,
  },
  computed: {
    ...mapState([
      'error',
      'name',
      'description',
      'scopes',
      'strategies',
      'isLoading',
      'hasError',
      'iid',
      'active',
      'version',
    ]),
    title() {
      return this.iid
        ? `^${this.iid} ${this.name}`
        : sprintf(s__('Edit %{name}'), { name: this.name });
    },
    deprecated() {
      return this.hasNewVersionFlags && this.version === LEGACY_FLAG;
    },
    hasNewVersionFlags() {
      return this.glFeatures.featureFlagsNewVersion;
    },
  },
  created() {
    this.setPath(this.path);
    return this.setEndpoint(this.endpoint).then(() => this.fetchFeatureFlag());
  },
  methods: {
    ...mapActions([
      'updateFeatureFlag',
      'setEndpoint',
      'setPath',
      'fetchFeatureFlag',
      'toggleActive',
    ]),
  },
};
</script>
<template>
  <div>
    <gl-alert v-if="!hasNewVersionFlags" variant="warning" :dismissible="false" class="gl-my-5">
      {{ $options.translations.newFlagAlert }}
    </gl-alert>
    <gl-loading-icon v-if="isLoading" />

    <template v-else-if="!isLoading && !hasError">
      <gl-alert v-if="deprecated" variant="warning" :dismissible="false" class="gl-my-5">
        {{ $options.translations.legacyFlagAlert }}
      </gl-alert>
      <div class="d-flex align-items-center mb-3 mt-3">
        <gl-toggle :value="active" class="m-0 mr-3 js-feature-flag-status" @change="toggleActive" />
        <h3 class="page-title m-0">{{ title }}</h3>
      </div>

      <div v-if="error.length" class="alert alert-danger">
        <p v-for="(message, index) in error" :key="index" class="mb-0">{{ message }}</p>
      </div>

      <feature-flag-form
        :name="name"
        :description="description"
        :scopes="scopes"
        :strategies="strategies"
        :cancel-path="path"
        :submit-text="__('Save changes')"
        :environments-endpoint="environmentsEndpoint"
        :active="active"
        :version="version"
        @handleSubmit="data => updateFeatureFlag(data)"
      />
    </template>
  </div>
</template>
