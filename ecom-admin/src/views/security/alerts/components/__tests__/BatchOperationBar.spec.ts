import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import BatchOperationBar from '../BatchOperationBar.vue';

describe('BatchOperationBar', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('renders correctly with selected IDs', () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    expect(wrapper.text()).toContain('已选择 3 项');
  });

  it('does not render when no items selected', () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [],
      },
    });

    expect(wrapper.find('.batch-operation-bar').exists()).toBe(false);
  });

  it('emits batch-handle event', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="batch-handle-btn"]').trigger('click');
    expect(wrapper.emitted('batch-handle')).toBeTruthy();
  });

  it('emits batch-ignore event', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="batch-ignore-btn"]').trigger('click');
    expect(wrapper.emitted('batch-ignore')).toBeTruthy();
  });

  it('emits batch-export event', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="batch-export-btn"]').trigger('click');
    expect(wrapper.emitted('batch-export')).toBeTruthy();
  });

  it('shows confirmation before batch delete', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="batch-delete-btn"]').trigger('click');

    // 应该显示确认对话框
    expect(wrapper.find('.arco-popconfirm').exists()).toBe(true);
  });

  it('emits batch-delete event after confirmation', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="batch-delete-btn"]').trigger('click');
    await wrapper.find('[data-test="confirm-delete-btn"]').trigger('click');

    expect(wrapper.emitted('batch-delete')).toBeTruthy();
  });

  it('emits clear event', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    await wrapper.find('[data-test="clear-btn"]').trigger('click');
    expect(wrapper.emitted('clear')).toBeTruthy();
  });

  it('disables buttons when loading', () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
        loading: true,
      },
    });

    expect(wrapper.find('[data-test="batch-handle-btn"]').attributes('disabled')).toBeDefined();
    expect(wrapper.find('[data-test="batch-ignore-btn"]').attributes('disabled')).toBeDefined();
    expect(wrapper.find('[data-test="batch-export-btn"]').attributes('disabled')).toBeDefined();
    expect(wrapper.find('[data-test="batch-delete-btn"]').attributes('disabled')).toBeDefined();
  });

  it('updates selected count when prop changes', async () => {
    const wrapper = mount(BatchOperationBar, {
      props: {
        selectedIds: [1, 2, 3],
      },
    });

    expect(wrapper.text()).toContain('已选择 3 项');

    await wrapper.setProps({ selectedIds: [1, 2, 3, 4, 5] });

    expect(wrapper.text()).toContain('已选择 5 项');
  });
});
