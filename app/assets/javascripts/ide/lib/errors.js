import { __ } from '~/locale';

export const TYPE_UNEXPECTED = 'unexpected';
export const TYPE_CODEOWNERS = 'codeowners';
export const TYPE_BRANCH_CHANGED = 'branch_changed';

const CODEOWNERS_REGEX = /Push.*protected branches.*CODEOWNERS/;
const BRANCH_CHANGED_REGEX = /changed.*since.*start.*edit/;

const joinSentences = (...sentences) =>
  sentences.reduce((acc, sentence) => {
    if (!sentence?.trim()) {
      return acc;
    } else if (!acc) {
      return sentence;
    } else if (/\.\s+$/.test(acc)) {
      return `${acc}${sentence}`;
    } else if (/\.$/.test(acc)) {
      return `${acc} ${sentence}`;
    }

    return `${acc}. ${sentence}`;
  }, '');

export const createUnexpectedCommitError = () => ({
  type: TYPE_UNEXPECTED,
  title: __('Unexpected error'),
  message: __('Could not commit. An unexpected error occurred.'),
  canCreateBranch: false,
});

export const createCodeownersCommitError = message => ({
  type: TYPE_CODEOWNERS,
  title: __('CODEOWNERS rule violation'),
  message,
  canCreateBranch: true,
});

export const createBranchChangedCommitError = message => ({
  type: TYPE_BRANCH_CHANGED,
  title: __('Branch changed'),
  message: joinSentences(message, __('Would you like to create a new branch?')),
  canCreateBranch: true,
});

export const parseCommitError = e => {
  const { message } = e.response?.data || {};

  if (!message) {
    return createUnexpectedCommitError();
  }

  if (CODEOWNERS_REGEX.test(message)) {
    return createCodeownersCommitError(message);
  } else if (BRANCH_CHANGED_REGEX.test(message)) {
    return createBranchChangedCommitError(message);
  }

  return createUnexpectedCommitError();
};
