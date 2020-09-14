<script>
import { GlButton, GlTooltip } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  components: {
    GlButton,
    GlTooltip,
  },
  props: {
    exportHref: {
      required: true,
      type: String,
    },
  },
  strings: {
    buttonText: __('Current view'),
    tooltipText: __('Export as CSV'),
    tooltipSizeLimit: __('(max size 15 MB)'),
  },
  data() {
    return {
      button: null,
    };
  },
  mounted() {
    this.button = this.$refs.button;
  },
};
</script>

<template>
  <div>
    <gl-button ref="button" :href="exportHref" icon="export">
      {{ $options.strings.buttonText }}
    </gl-button>
    <gl-tooltip v-if="button" :target="button" boundary="viewport" placement="top">
      <p class="gl-my-0">{{ $options.strings.tooltipText }}</p>
      <p class="gl-my-0">{{ $options.strings.tooltipSizeLimit }}</p>
    </gl-tooltip>
  </div>
</template>
