// The order of the steps in this array determines the flow of the application
export const STEPS = ['subscriptionDetails', 'billingAddress', 'paymentMethod'];

export const COUNTRIES_URL = '/-/countries';

export const STATES_URL = '/-/country_states';

export const ZUORA_SCRIPT_URL = 'https://static.zuora.com/Resources/libs/hosted/1.3.1/zuora-min.js';

export const PAYMENT_FORM_URL = '/-/subscriptions/payment_form';

export const PAYMENT_FORM_ID = 'paid_signup_flow';

export const PAYMENT_METHOD_URL = '/-/subscriptions/payment_method';

export const ZUORA_IFRAME_OVERRIDE_PARAMS = {
  style: 'inline',
  submitEnabled: 'true',
  retainValues: 'true',
};

export const TAX_RATE = 0;
