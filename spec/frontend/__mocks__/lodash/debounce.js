// `lodash/debounce` has a non-trivial implementation which can lead to
// [flaky spec errors][1]. This mock simply makes `debounce` calls synchronous.
//
// In the future we could enhance this by injecting some test values in
// the function passed to it. See [this issue][2] for more information.
//
// [1]: https://gitlab.com/gitlab-org/gitlab/-/issues/212532
// [2]: https://gitlab.com/gitlab-org/gitlab/-/issues/213378
// Further reference: https://github.com/facebook/jest/issues/3465

export default fn => fn;
