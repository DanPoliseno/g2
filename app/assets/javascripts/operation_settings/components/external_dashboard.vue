<script>
import { mapState, mapActions } from 'vuex';
import { GlDeprecatedButton, GlFormGroup, GlFormInput, GlLink } from '@gitlab/ui';

export default {
  components: {
    GlDeprecatedButton,
    GlFormGroup,
    GlFormInput,
    GlLink,
  },
  computed: {
    ...mapState([
      'externalDashboardHelpPagePath',
      'externalDashboardUrl',
      'operationsSettingsEndpoint',
    ]),
    userDashboardUrl: {
      get() {
        return this.externalDashboardUrl;
      },
      set(url) {
        this.setExternalDashboardUrl(url);
      },
    },
  },
  methods: {
    ...mapActions(['setExternalDashboardUrl', 'updateExternalDashboardUrl']),
  },
};
</script>

<template>
  <section class="settings no-animate">
    <div class="settings-header">
      <h3 class="js-section-header h4">
        {{ s__('ExternalMetrics|External Dashboard') }}
      </h3>
      <gl-deprecated-button class="js-settings-toggle">{{ __('Expand') }}</gl-deprecated-button>
      <p class="js-section-sub-header">
        {{
          s__(
            'ExternalMetrics|Add a button to the metrics dashboard linking directly to your existing external dashboards.',
          )
        }}
        <gl-link :href="externalDashboardHelpPagePath">{{ __('Learn more') }}</gl-link>
      </p>
    </div>
    <div class="settings-content">
      <form>
        <gl-form-group
          :label="s__('ExternalMetrics|Full dashboard URL')"
          label-for="full-dashboard-url"
          :description="s__('ExternalMetrics|Enter the URL of the dashboard you want to link to')"
        >
          <!-- placeholder with a url is a false positive  -->
          <!-- eslint-disable @gitlab/vue-require-i18n-attribute-strings -->
          <gl-form-input
            id="full-dashboard-url"
            v-model="userDashboardUrl"
            placeholder="https://my-org.gitlab.io/my-dashboards"
            @keydown.enter.native.prevent="updateExternalDashboardUrl"
          />
          <!-- eslint-enable @gitlab/vue-require-i18n-attribute-strings -->
        </gl-form-group>
        <gl-deprecated-button variant="success" @click="updateExternalDashboardUrl">
          {{ __('Save Changes') }}
        </gl-deprecated-button>
      </form>
    </div>
  </section>
</template>
