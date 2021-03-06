import { GlLoadingIcon } from '@gitlab/ui';
import { mount, shallowMount, createLocalVue } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import EpicsListEmpty from 'ee/roadmap/components/epics_list_empty.vue';
import RoadmapApp from 'ee/roadmap/components/roadmap_app.vue';
import RoadmapShell from 'ee/roadmap/components/roadmap_shell.vue';
import { PRESET_TYPES, EXTEND_AS } from 'ee/roadmap/constants';
import eventHub from 'ee/roadmap/event_hub';
import createStore from 'ee/roadmap/store';
import * as types from 'ee/roadmap/store/mutation_types';
import { getTimeframeForMonthsView } from 'ee/roadmap/utils/roadmap_utils';
import {
  basePath,
  epicsPath,
  mockFormattedEpic,
  mockGroupId,
  mockNewEpicEndpoint,
  mockSortedBy,
  mockSvgPath,
  mockTimeframeInitialDate,
  rawEpics,
} from 'ee_jest/roadmap/mock_data';

describe('RoadmapApp', () => {
  const localVue = createLocalVue();
  let store;
  let wrapper;

  localVue.use(Vuex);

  const currentGroupId = mockGroupId;
  const emptyStateIllustrationPath = mockSvgPath;
  const epics = [mockFormattedEpic];
  const hasFiltersApplied = true;
  const newEpicEndpoint = mockNewEpicEndpoint;
  const presetType = PRESET_TYPES.MONTHS;
  const timeframe = getTimeframeForMonthsView(mockTimeframeInitialDate);

  const createComponent = (mountFunction = shallowMount) => {
    return mountFunction(RoadmapApp, {
      localVue,
      propsData: {
        emptyStateIllustrationPath,
        hasFiltersApplied,
        newEpicEndpoint,
        presetType,
      },
      store,
    });
  };

  beforeEach(() => {
    store = createStore();
    store.dispatch('setInitialData', {
      currentGroupId,
      sortedBy: mockSortedBy,
      presetType,
      timeframe,
      filterQueryString: '',
      initialEpicsPath: epicsPath,
      basePath,
    });
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe.each`
    testLabel         | epicList | showLoading | showRoadmapShell | showEpicsListEmpty
    ${'is loading'}   | ${null}  | ${true}     | ${false}         | ${false}
    ${'has epics'}    | ${epics} | ${false}    | ${true}          | ${false}
    ${'has no epics'} | ${[]}    | ${false}    | ${false}         | ${true}
  `(
    `when epic list $testLabel`,
    ({ epicList, showLoading, showRoadmapShell, showEpicsListEmpty }) => {
      beforeEach(() => {
        wrapper = createComponent();
        if (epicList) {
          store.commit(types.RECEIVE_EPICS_SUCCESS, epicList);
        }
      });

      it(`loading icon is${showLoading ? '' : ' not'} shown`, () => {
        expect(wrapper.contains(GlLoadingIcon)).toBe(showLoading);
      });

      it(`roadmap is${showRoadmapShell ? '' : ' not'} shown`, () => {
        expect(wrapper.contains(RoadmapShell)).toBe(showRoadmapShell);
      });

      it(`empty state view is${showEpicsListEmpty ? '' : ' not'} shown`, () => {
        expect(wrapper.contains(EpicsListEmpty)).toBe(showEpicsListEmpty);
      });
    },
  );

  describe('empty state view', () => {
    beforeEach(() => {
      wrapper = createComponent();
      store.commit(types.RECEIVE_EPICS_SUCCESS, []);
    });

    it('contains path for the empty state illustration', () => {
      expect(wrapper.find(EpicsListEmpty).props('emptyStateIllustrationPath')).toBe(
        emptyStateIllustrationPath,
      );
    });

    it('contains whether to apply filters', () => {
      expect(wrapper.find(EpicsListEmpty).props('hasFiltersApplied')).toBe(hasFiltersApplied);
    });

    it('contains whether it is child epics', () => {
      expect(wrapper.find(EpicsListEmpty).props('isChildEpics')).toBe(false);
    });

    it('contains endpoint to create a new epic', () => {
      expect(wrapper.find(EpicsListEmpty).props('newEpicEndpoint')).toBe(mockNewEpicEndpoint);
    });

    it('contains the preset type', () => {
      expect(wrapper.find(EpicsListEmpty).props('presetType')).toBe(presetType);
    });

    it('contains the start of the timeframe', () => {
      expect(wrapper.find(EpicsListEmpty).props('timeframeStart')).toStrictEqual(timeframe[0]);
    });

    it('contains the end of the timeframe', () => {
      expect(wrapper.find(EpicsListEmpty).props('timeframeEnd')).toStrictEqual(
        timeframe[timeframe.length - 1],
      );
    });
  });

  describe('roadmap view', () => {
    beforeEach(() => {
      wrapper = createComponent();
      store.commit(types.RECEIVE_EPICS_SUCCESS, epics);
    });

    it('contains the current group id', () => {
      expect(wrapper.find(RoadmapShell).props('currentGroupId')).toBe(currentGroupId);
    });

    it('contains epics', () => {
      expect(wrapper.find(RoadmapShell).props('epics')).toEqual(epics);
    });

    it('contains whether filters are applied', () => {
      expect(wrapper.find(RoadmapShell).props('hasFiltersApplied')).toBe(hasFiltersApplied);
    });

    it('contains milestones', () => {
      expect(wrapper.find(RoadmapShell).props('milestones')).toEqual([]);
    });

    it('contains the preset type', () => {
      expect(wrapper.find(RoadmapShell).props('presetType')).toBe(presetType);
    });

    it('contains timeframe', () => {
      expect(wrapper.find(RoadmapShell).props('timeframe')).toEqual(timeframe);
    });
  });

  describe('extending the roadmap timeline', () => {
    let roadmapTimelineEl;

    beforeEach(() => {
      store.dispatch('receiveEpicsSuccess', { rawEpics: rawEpics.slice(0, 2) });
      wrapper = createComponent(mount);
      roadmapTimelineEl = wrapper.find('.roadmap-timeline-section').element;
    });

    it('updates timeline by extending timeframe from the start when called with extendType as `prepend`', () => {
      jest.spyOn(eventHub, '$emit').mockImplementation();

      wrapper.vm.processExtendedTimeline({
        extendType: EXTEND_AS.PREPEND,
        roadmapTimelineEl,
        itemsCount: 0,
      });

      expect(eventHub.$emit).toHaveBeenCalledWith('refreshTimeline', expect.any(Object));
      expect(roadmapTimelineEl.parentElement.scrollBy).toHaveBeenCalled();
    });

    it('updates timeline by extending timeframe from the end when called with extendType as `append`', () => {
      jest.spyOn(eventHub, '$emit').mockImplementation();

      wrapper.vm.processExtendedTimeline({
        extendType: EXTEND_AS.APPEND,
        roadmapTimelineEl,
        itemsCount: 0,
      });

      expect(eventHub.$emit).toHaveBeenCalledWith('refreshTimeline', expect.any(Object));
    });

    it('updates the store and refreshes roadmap with extended timeline based on provided extendType', () => {
      jest.spyOn(wrapper.vm, 'extendTimeframe').mockImplementation();
      jest.spyOn(wrapper.vm, 'refreshEpicDates').mockImplementation();
      jest.spyOn(wrapper.vm, 'refreshMilestoneDates').mockImplementation();
      jest.spyOn(wrapper.vm, 'fetchEpicsForTimeframe').mockResolvedValue();

      const extendType = EXTEND_AS.PREPEND;

      wrapper.vm.handleScrollToExtend(roadmapTimelineEl, extendType);

      expect(wrapper.vm.extendTimeframe).toHaveBeenCalledWith({ extendAs: extendType });
      expect(wrapper.vm.refreshEpicDates).toHaveBeenCalled();
      expect(wrapper.vm.refreshMilestoneDates).toHaveBeenCalled();
    });

    it('calls `fetchEpicsForTimeframe` with extended timeframe array', () => {
      jest.spyOn(wrapper.vm, 'fetchEpicsForTimeframe').mockResolvedValue();

      const extendType = EXTEND_AS.PREPEND;

      wrapper.vm.handleScrollToExtend(roadmapTimelineEl, extendType);

      return Vue.nextTick(() => {
        expect(wrapper.vm.fetchEpicsForTimeframe).toHaveBeenCalledWith(
          expect.objectContaining({
            timeframe: wrapper.vm.extendedTimeframe,
          }),
        );
      });
    });
  });
});
