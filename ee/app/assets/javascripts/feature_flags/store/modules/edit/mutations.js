import * as types from './mutation_types';

export default {
  [types.SET_ENDPOINT](state, endpoint) {
    state.endpoint = endpoint;
  },
  [types.SET_PATH](state, path) {
    state.path = path;
  },
  [types.REQUEST_FEATURE_FLAG](state) {
    state.isLoading = true;
  },
  [types.RECEIVE_FEATURE_FLAG_SUCCESS](state, response) {
    state.isLoading = false;
    state.hasError = false;

    state.name = response.name;
    state.description = response.description;
    state.scopes = state.scopes;
  },
  [types.RECEIVE_FEATURE_FLAG_ERROR](state) {
    state.isLoading = false;
    state.hasError = true;
  },
  [types.REQUEST_UPDATE_FEATURE_FLAG](state) {
    state.isSendingRequest = true;
    state.error = [];
  },
  [types.RECEIVE_UPDATE_FEATURE_FLAG_SUCCESS](state) {
    state.isSendingRequest = false;
  },
  [types.RECEIVE_UPDATE_FEATURE_FLAG_ERROR](state, error) {
    state.isSendingRequest = false;
    state.error = error.message;
  },
};
