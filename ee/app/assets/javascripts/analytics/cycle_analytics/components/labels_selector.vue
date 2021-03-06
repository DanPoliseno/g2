<script>
import Api from 'ee/api';
import { debounce } from 'lodash';
import { GlDropdown, GlDropdownItem, GlIcon, GlLoadingIcon, GlSearchBoxByType } from '@gitlab/ui';
import { mapGetters } from 'vuex';
import createFlash from '~/flash';
import { __ } from '~/locale';
import { removeFlash } from '../utils';

const DATA_REFETCH_DELAY = 250;

export default {
  name: 'LabelsSelector',
  components: {
    GlDropdown,
    GlDropdownItem,
    GlIcon,
    GlLoadingIcon,
    GlSearchBoxByType,
  },
  props: {
    defaultSelectedLabelIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    maxLabels: {
      type: Number,
      required: false,
      default: 0,
    },
    multiselect: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedLabelId: {
      type: Array,
      required: false,
      default: () => [],
    },
    right: {
      type: Boolean,
      required: false,
      default: false,
    },
    dropdownItemClass: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      loading: false,
      searchTerm: '',
      labels: [],
      selectedLabelIds: this.defaultSelectedLabelIds || [],
    };
  },
  computed: {
    selectedLabel() {
      const { selectedLabelId, labels = [] } = this;
      if (!selectedLabelId.length || !labels.length) return null;
      return labels.find(({ id }) => selectedLabelId.includes(id));
    },
    maxLabelsSelected() {
      return this.selectedLabelIds.length >= this.maxLabels;
    },
    noMatchingLabels() {
      return Boolean(this.searchTerm.length && !this.labels.length);
    },
  },
  watch: {
    searchTerm() {
      debounce(this.fetchData(), DATA_REFETCH_DELAY);
    },
  },
  mounted() {
    this.fetchData();
  },
  methods: {
    ...mapGetters(['currentGroupPath']),
    fetchData() {
      removeFlash();
      this.loading = true;
      return Api.cycleAnalyticsGroupLabels(this.currentGroupPath, {
        search: this.searchTerm,
        only_group_labels: true,
      })
        .then(({ data }) => {
          this.labels = data;
        })
        .catch(() => {
          createFlash(__('There was an error fetching label data for the selected group'));
        })
        .finally(() => {
          this.loading = false;
        });
    },
    labelTitle(label) {
      // there are 2 possible endpoints for group labels
      // one returns label.name the other label.title
      return label?.name || label.title;
    },
    isSelectedLabel(id) {
      return Boolean(this.selectedLabelId?.includes(id));
    },
    isDisabledLabel(id) {
      return Boolean(this.maxLabelsSelected && !this.isSelectedLabel(id));
    },
  },
};
</script>
<template>
  <gl-dropdown class="w-100" toggle-class="overflow-hidden" :right="right">
    <template #button-content>
      <slot name="label-dropdown-button">
        <span v-if="selectedLabel">
          <span
            :style="{ backgroundColor: selectedLabel.color }"
            class="d-inline-block dropdown-label-box"
          >
          </span>
          {{ labelTitle(selectedLabel) }}
        </span>
        <span v-else>{{ __('Select a label') }}</span>
      </slot>
    </template>
    <template>
      <slot name="label-dropdown-list-header">
        <gl-dropdown-item :active="!selectedLabelId.length" @click.prevent="$emit('clearLabel')"
          >{{ __('Select a label') }}
        </gl-dropdown-item>
      </slot>
      <div class="mb-3 px-3">
        <gl-search-box-by-type v-model.trim="searchTerm" class="mb-2" />
      </div>
      <div class="mb-3 px-3">
        <gl-dropdown-item
          v-for="label in labels"
          :key="label.id"
          :class="{
            'pl-4': multiselect && !isSelectedLabel(label.id),
            'cursor-not-allowed': disabled,
          }"
          :active="isSelectedLabel(label.id)"
          @click.prevent="$emit('selectLabel', label.id, selectedLabelIds)"
        >
          <gl-icon
            v-if="multiselect && isSelectedLabel(label.id)"
            class="text-gray-700 mr-1 vertical-align-middle"
            name="mobile-issue-close"
          />
          <span :style="{ backgroundColor: label.color }" class="d-inline-block dropdown-label-box">
          </span>
          {{ labelTitle(label) }}
        </gl-dropdown-item>
        <div v-show="loading" class="text-center">
          <gl-loading-icon :inline="true" size="md" />
        </div>
        <div v-show="noMatchingLabels" class="text-secondary">
          {{ __('No matching labels') }}
        </div>
      </div>
    </template>
  </gl-dropdown>
</template>
