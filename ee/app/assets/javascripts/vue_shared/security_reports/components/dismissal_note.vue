<script>
import { escape } from 'lodash';
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import { GlDeprecatedButton } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import LoadingButton from '~/vue_shared/components/loading_button.vue';

export default {
  components: {
    EventItem,
    GlDeprecatedButton,
    LoadingButton,
  },
  props: {
    feedback: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isCommentingOnDismissal: {
      type: Boolean,
      required: false,
      default: false,
    },
    isShowingDeleteButtons: {
      type: Boolean,
      required: false,
      default: false,
    },
    showDismissalCommentActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    isDismissingVulnerability: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    eventText() {
      const { project, feedback } = this;
      const { pipeline } = feedback;

      const pipelineLink =
        pipeline && pipeline.path && pipeline.id
          ? `<a href="${pipeline.path}">#${pipeline.id}</a>`
          : null;

      const projectLink =
        project && project.url && project.value
          ? `<a href="${escape(project.url)}">${escape(project.value)}</a>`
          : null;

      if (pipelineLink && projectLink) {
        return sprintf(
          __('Dismissed on pipeline %{pipelineLink} at %{projectLink}'),
          { pipelineLink, projectLink },
          false,
        );
      }
      if (pipelineLink && !projectLink) {
        return sprintf(__('Dismissed on pipeline %{pipelineLink}'), { pipelineLink }, false);
      }
      if (!pipelineLink && projectLink) {
        return sprintf(__('Dismissed at %{projectLink}'), { projectLink }, false);
      }
      return __('Dismissed');
    },
    commentDetails() {
      return this.feedback.comment_details;
    },
    vulnDismissalActionButtons() {
      return [
        {
          iconName: 'pencil',
          onClick: () => this.$emit('editVulnerabilityDismissalComment'),
          title: __('Edit Comment'),
        },
        {
          iconName: 'remove',
          onClick: () => this.$emit('showDismissalDeleteButtons'),
          title: __('Delete Comment'),
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <event-item
      :author="feedback.author"
      :created-at="feedback.created_at"
      icon-name="cancel"
      icon-class="ci-status-icon-pending"
    >
      <div v-if="feedback.created_at" v-html="eventText"></div>
    </event-item>
    <template v-if="commentDetails && !isCommentingOnDismissal">
      <hr class="my-3" />
      <event-item
        :action-buttons="vulnDismissalActionButtons"
        :author="commentDetails.comment_author"
        :created-at="commentDetails.comment_timestamp"
        :show-right-slot="isShowingDeleteButtons"
        :show-action-buttons="showDismissalCommentActions"
        icon-name="comment"
        icon-class="ci-status-icon-pending"
      >
        {{ commentDetails.comment }}

        <template #right-content>
          <div class="d-flex flex-grow-1 align-self-start flex-row-reverse">
            <loading-button
              :label="__('Delete comment')"
              container-class="btn btn-remove"
              @click="$emit('deleteDismissalComment')"
            />

            <gl-deprecated-button class="mr-2" @click="$emit('hideDismissalDeleteButtons')">
              {{ __('Cancel') }}
            </gl-deprecated-button>
          </div>
        </template>
      </event-item>
    </template>
  </div>
</template>
