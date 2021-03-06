import Vue from 'vue';
import { createComponentWithStore } from 'helpers/vue_mount_component_helper';
import { createStore } from '~/ide/stores';
import modal from '~/ide/components/new_dropdown/modal.vue';
import createFlash from '~/flash';

jest.mock('~/flash');

describe('new file modal component', () => {
  const Component = Vue.extend(modal);
  let vm;

  afterEach(() => {
    vm.$destroy();
  });

  describe.each`
    entryType | modalTitle                | btnTitle              | showsFileTemplates
    ${'tree'} | ${'Create new directory'} | ${'Create directory'} | ${false}
    ${'blob'} | ${'Create new file'}      | ${'Create file'}      | ${true}
  `('$entryType', ({ entryType, modalTitle, btnTitle, showsFileTemplates }) => {
    beforeEach(done => {
      const store = createStore();

      vm = createComponentWithStore(Component, store).$mount();
      vm.open(entryType);
      vm.name = 'testing';

      vm.$nextTick(done);
    });

    afterEach(() => {
      vm.close();
    });

    it(`sets modal title as ${entryType}`, () => {
      expect(document.querySelector('.modal-title').textContent.trim()).toBe(modalTitle);
    });

    it(`sets button label as ${entryType}`, () => {
      expect(document.querySelector('.btn-success').textContent.trim()).toBe(btnTitle);
    });

    it(`sets form label as ${entryType}`, () => {
      expect(document.querySelector('.label-bold').textContent.trim()).toBe('Name');
    });

    it(`shows file templates: ${showsFileTemplates}`, () => {
      const templateFilesEl = document.querySelector('.file-templates');
      expect(Boolean(templateFilesEl)).toBe(showsFileTemplates);
    });
  });

  describe('rename entry', () => {
    beforeEach(() => {
      const store = createStore();
      store.state.entries = {
        'test-path': {
          name: 'test',
          type: 'blob',
          path: 'test-path',
        },
      };

      vm = createComponentWithStore(Component, store).$mount();
    });

    it.each`
      entryType | modalTitle         | btnTitle
      ${'tree'} | ${'Rename folder'} | ${'Rename folder'}
      ${'blob'} | ${'Rename file'}   | ${'Rename file'}
    `(
      'renders title and button for renaming $entryType',
      ({ entryType, modalTitle, btnTitle }, done) => {
        vm.$store.state.entries['test-path'].type = entryType;
        vm.open('rename', 'test-path');

        vm.$nextTick(() => {
          expect(document.querySelector('.modal-title').textContent.trim()).toBe(modalTitle);
          expect(document.querySelector('.btn-success').textContent.trim()).toBe(btnTitle);

          done();
        });
      },
    );

    describe('entryName', () => {
      it('returns entries name', () => {
        vm.open('rename', 'test-path');

        expect(vm.entryName).toBe('test-path');
      });

      it('does not reset entryName to its old value if empty', () => {
        vm.entryName = 'hello';
        vm.entryName = '';

        expect(vm.entryName).toBe('');
      });
    });

    describe('open', () => {
      it('sets entryName to path provided if modalType is rename', () => {
        vm.open('rename', 'test-path');

        expect(vm.entryName).toBe('test-path');
      });

      it("appends '/' to the path if modalType isn't rename", () => {
        vm.open('blob', 'test-path');

        expect(vm.entryName).toBe('test-path/');
      });

      it('leaves entryName blank if no path is provided', () => {
        vm.open('blob');

        expect(vm.entryName).toBe('');
      });
    });
  });

  describe('submitForm', () => {
    let store;

    beforeEach(() => {
      store = createStore();
      store.state.entries = {
        'test-path/test': {
          name: 'test',
          deleted: false,
        },
      };

      vm = createComponentWithStore(Component, store).$mount();
    });

    it('throws an error when target entry exists', () => {
      vm.open('rename', 'test-path/test');

      expect(createFlash).not.toHaveBeenCalled();

      vm.submitForm();

      expect(createFlash).toHaveBeenCalledWith(
        'The name "test-path/test" is already taken in this directory.',
        'alert',
        expect.anything(),
        null,
        false,
        true,
      );
    });

    it('does not throw error when target entry does not exist', () => {
      jest.spyOn(vm, 'renameEntry').mockImplementation();

      vm.open('rename', 'test-path/test');
      vm.entryName = 'test-path/test2';
      vm.submitForm();

      expect(createFlash).not.toHaveBeenCalled();
    });

    it('removes leading/trailing found in the new name', () => {
      vm.open('rename', 'test-path/test');

      vm.entryName = 'test-path /test';

      vm.submitForm();

      expect(vm.entryName).toBe('test-path/test');
    });
  });
});
