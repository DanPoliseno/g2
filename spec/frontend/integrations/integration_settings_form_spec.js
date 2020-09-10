import MockAdaptor from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import IntegrationSettingsForm from '~/integrations/integration_settings_form';

describe('IntegrationSettingsForm', () => {
  const FIXTURE = 'services/edit_service.html';
  preloadFixtures(FIXTURE);

  beforeEach(() => {
    loadFixtures(FIXTURE);
  });

  describe('constructor', () => {
    let integrationSettingsForm;

    beforeEach(() => {
      integrationSettingsForm = new IntegrationSettingsForm('.js-integration-settings-form');
      jest.spyOn(integrationSettingsForm, 'init').mockImplementation(() => {});
    });

    it('should initialize form element refs on class object', () => {
      // Form Reference
      expect(integrationSettingsForm.$form).toBeDefined();
      expect(integrationSettingsForm.$form.prop('nodeName')).toEqual('FORM');
      expect(integrationSettingsForm.formActive).toBeDefined();
    });

    it('should initialize form metadata on class object', () => {
      expect(integrationSettingsForm.testEndPoint).toBeDefined();
    });
  });

  describe('toggleServiceState', () => {
    let integrationSettingsForm;

    beforeEach(() => {
      integrationSettingsForm = new IntegrationSettingsForm('.js-integration-settings-form');
    });

    it('should remove `novalidate` attribute to form when called with `true`', () => {
      integrationSettingsForm.formActive = true;
      integrationSettingsForm.toggleServiceState();

      expect(integrationSettingsForm.$form.attr('novalidate')).not.toBeDefined();
    });

    it('should set `novalidate` attribute to form when called with `false`', () => {
      integrationSettingsForm.formActive = false;
      integrationSettingsForm.toggleServiceState();

      expect(integrationSettingsForm.$form.attr('novalidate')).toBeDefined();
    });
  });

  describe('testSettings', () => {
    let integrationSettingsForm;
    let formData;
    let mock;
    let testSpy;

    beforeEach(() => {
      mock = new MockAdaptor(axios);

      jest.spyOn(axios, 'put');
      testSpy = jest.fn();

      integrationSettingsForm = new IntegrationSettingsForm('.js-integration-settings-form');
      integrationSettingsForm.init();
      integrationSettingsForm.vue.$toast = { show: testSpy };

      // eslint-disable-next-line no-jquery/no-serialize
      formData = integrationSettingsForm.$form.serialize();
    });

    afterEach(() => {
      mock.restore();
    });

    it('should make an ajax request with provided `formData`', async () => {
      await integrationSettingsForm.testSettings(formData);

      expect(axios.put).toHaveBeenCalledWith(integrationSettingsForm.testEndPoint, formData);
    });

    it('should show success message if test is successful', async () => {
      jest.spyOn(integrationSettingsForm.$form, 'submit').mockImplementation(() => {});

      mock.onPut(integrationSettingsForm.testEndPoint).reply(200, {
        error: false,
      });

      await integrationSettingsForm.testSettings(formData);

      expect(testSpy).toHaveBeenCalledWith('Connection successful.');
    });

    it('should show error message if ajax request responds with test error', async () => {
      const errorMessage = 'Test failed.';
      const serviceResponse = 'some error';

      mock.onPut(integrationSettingsForm.testEndPoint).reply(200, {
        error: true,
        message: errorMessage,
        service_response: serviceResponse,
        test_failed: false,
      });

      await integrationSettingsForm.testSettings(formData);

      expect(testSpy).toHaveBeenCalledWith(`${errorMessage} ${serviceResponse}`);
    });

    it('should show error message if ajax request failed', async () => {
      const errorMessage = 'Something went wrong on our end.';

      mock.onPut(integrationSettingsForm.testEndPoint).networkError();

      await integrationSettingsForm.testSettings(formData);

      expect(testSpy).toHaveBeenCalledWith(errorMessage);
    });

    it('should always dispatch `setIsTesting` with `false` once request is completed', async () => {
      const dispatchSpy = jest.fn();

      mock.onPut(integrationSettingsForm.testEndPoint).networkError();

      integrationSettingsForm.vue.$store = { dispatch: dispatchSpy };

      await integrationSettingsForm.testSettings(formData);

      expect(dispatchSpy).toHaveBeenCalledWith('setIsTesting', false);
    });
  });
});
