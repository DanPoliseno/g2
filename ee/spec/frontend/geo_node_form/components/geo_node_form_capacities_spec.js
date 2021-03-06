import Vuex from 'vuex';
import { createLocalVue, mount } from '@vue/test-utils';
import GeoNodeFormCapacities from 'ee/geo_node_form/components/geo_node_form_capacities.vue';
import { VALIDATION_FIELD_KEYS } from 'ee/geo_node_form/constants';
import { MOCK_NODE } from '../mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('GeoNodeFormCapacities', () => {
  let wrapper;
  let store;

  const defaultProps = {
    nodeData: MOCK_NODE,
  };

  const createComponent = (props = {}) => {
    store = new Vuex.Store({
      state: {
        formErrors: Object.values(VALIDATION_FIELD_KEYS).reduce(
          (acc, cur) => ({ ...acc, [cur]: '' }),
          {},
        ),
      },
      actions: {
        setError({ state }, { key, error }) {
          state.formErrors[key] = error;
        },
      },
    });

    wrapper = mount(GeoNodeFormCapacities, {
      localVue,
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findGeoNodeFormRepositoryCapacityField = () =>
    wrapper.find('#node-repository-capacity-field');
  const findGeoNodeFormFileCapacityField = () => wrapper.find('#node-file-capacity-field');
  const findGeoNodeFormContainerRepositoryCapacityField = () =>
    wrapper.find('#node-container-repository-capacity-field');
  const findGeoNodeFormVerificationCapacityField = () =>
    wrapper.find('#node-verification-capacity-field');
  const findGeoNodeFormReverificationIntervalField = () =>
    wrapper.find('#node-reverification-interval-field');
  const findErrorMessage = () => wrapper.find('.invalid-feedback');

  describe('template', () => {
    describe.each`
      primaryNode | showRepoCapacity | showFileCapacity | showVerificationCapacity | showContainerCapacity | showReverificationInterval
      ${true}     | ${false}         | ${false}         | ${true}                  | ${false}              | ${true}
      ${false}    | ${true}          | ${true}          | ${true}                  | ${true}               | ${false}
    `(
      `conditional fields`,
      ({
        primaryNode,
        showRepoCapacity,
        showFileCapacity,
        showContainerCapacity,
        showVerificationCapacity,
        showReverificationInterval,
      }) => {
        beforeEach(() => {
          createComponent({
            nodeData: { ...defaultProps.nodeData, primary: primaryNode },
          });
        });

        it(`it ${showRepoCapacity ? 'shows' : 'hides'} the Repository Capacity Field`, () => {
          expect(findGeoNodeFormRepositoryCapacityField().exists()).toBe(showRepoCapacity);
        });

        it(`it ${showFileCapacity ? 'shows' : 'hides'} the File Capacity Field`, () => {
          expect(findGeoNodeFormFileCapacityField().exists()).toBe(showFileCapacity);
        });

        it(`it ${
          showContainerCapacity ? 'shows' : 'hides'
        } the Container Repository Capacity Field`, () => {
          expect(findGeoNodeFormContainerRepositoryCapacityField().exists()).toBe(
            showContainerCapacity,
          );
        });

        it(`it ${
          showVerificationCapacity ? 'shows' : 'hides'
        } the Verification Capacity Field`, () => {
          expect(findGeoNodeFormVerificationCapacityField().exists()).toBe(
            showVerificationCapacity,
          );
        });

        it(`it ${
          showReverificationInterval ? 'shows' : 'hides'
        } the Reverification Interval Field`, () => {
          expect(findGeoNodeFormReverificationIntervalField().exists()).toBe(
            showReverificationInterval,
          );
        });
      },
    );

    describe.each`
      data    | showError | errorMessage
      ${null} | ${true}   | ${"can't be blank"}
      ${''}   | ${true}   | ${"can't be blank"}
      ${-1}   | ${true}   | ${'should be between 1-999'}
      ${0}    | ${true}   | ${'should be between 1-999'}
      ${1}    | ${false}  | ${null}
      ${999}  | ${false}  | ${null}
      ${1000} | ${true}   | ${'should be between 1-999'}
    `(`errors`, ({ data, showError, errorMessage }) => {
      describe('on primary node', () => {
        beforeEach(() => {
          createComponent({
            nodeData: { ...defaultProps.nodeData, primary: true },
          });
        });

        describe('Verification Capacity Field', () => {
          beforeEach(() => {
            findGeoNodeFormVerificationCapacityField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormVerificationCapacityField().classes('is-invalid')).toBe(
              showError,
            );
            if (showError) {
              expect(findErrorMessage().text()).toBe(`Verification capacity ${errorMessage}`);
            }
          });
        });

        describe('Reverification Interval Field', () => {
          beforeEach(() => {
            findGeoNodeFormReverificationIntervalField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormReverificationIntervalField().classes('is-invalid')).toBe(
              showError,
            );
            if (showError) {
              expect(findErrorMessage().text()).toBe(`Re-verification interval ${errorMessage}`);
            }
          });
        });
      });

      describe('on secondary node', () => {
        beforeEach(() => {
          createComponent();
        });

        describe('Repository Capacity Field', () => {
          beforeEach(() => {
            findGeoNodeFormRepositoryCapacityField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormRepositoryCapacityField().classes('is-invalid')).toBe(showError);
            if (showError) {
              expect(findErrorMessage().text()).toBe(`Repository sync capacity ${errorMessage}`);
            }
          });
        });

        describe('File Capacity Field', () => {
          beforeEach(() => {
            findGeoNodeFormFileCapacityField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormFileCapacityField().classes('is-invalid')).toBe(showError);
            if (showError) {
              expect(findErrorMessage().text()).toBe(`File sync capacity ${errorMessage}`);
            }
          });
        });

        describe('Container Repository Capacity Field', () => {
          beforeEach(() => {
            findGeoNodeFormContainerRepositoryCapacityField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormContainerRepositoryCapacityField().classes('is-invalid')).toBe(
              showError,
            );
            if (showError) {
              expect(findErrorMessage().text()).toBe(
                `Container repositories sync capacity ${errorMessage}`,
              );
            }
          });
        });

        describe('Verification Capacity Field', () => {
          beforeEach(() => {
            findGeoNodeFormVerificationCapacityField().setValue(data);
          });

          it(`${showError ? 'shows' : 'hides'} error when data is ${data}`, () => {
            expect(findGeoNodeFormVerificationCapacityField().classes('is-invalid')).toBe(
              showError,
            );
            if (showError) {
              expect(findErrorMessage().text()).toBe(`Verification capacity ${errorMessage}`);
            }
          });
        });
      });
    });
  });

  describe('computed', () => {
    describe('visibleFormGroups', () => {
      describe('when nodeData.primary is true', () => {
        beforeEach(() => {
          createComponent({
            nodeData: { ...defaultProps.nodeData, primary: true },
          });
        });

        it('contains conditional form groups for primary', () => {
          expect(wrapper.vm.visibleFormGroups.some(g => g.conditional === 'primary')).toBeTruthy();
        });

        it('does not contain conditional form groups for secondary', () => {
          expect(wrapper.vm.visibleFormGroups.some(g => g.conditional === 'secondary')).toBeFalsy();
        });
      });

      describe('when nodeData.primary is false', () => {
        beforeEach(() => {
          createComponent();
        });

        it('contains conditional form groups for secondary', () => {
          expect(
            wrapper.vm.visibleFormGroups.some(g => g.conditional === 'secondary'),
          ).toBeTruthy();
        });

        it('does not contain conditional form groups for primary', () => {
          expect(wrapper.vm.visibleFormGroups.some(g => g.conditional === 'primary')).toBeFalsy();
        });
      });
    });
  });
});
