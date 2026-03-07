import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import AlertDetailDrawer from '../AlertDetailDrawer.vue';
import type { SecurityAlert } from '@/types/security';

describe('AlertDetailDrawer', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  const mockAlert: SecurityAlert = {
    id: 1,
    level: 'high',
    type: 'brute_force',
    status: 'pending',
    message: '检测到暴力破解尝试',
    details: {
      ip: '192.168.1.100',
      username: 'admin',
      attempts: 5,
    },
    created_at: '2026-03-07T10:00:00Z',
    updated_at: '2026-03-07T10:00:00Z',
  };

  it('renders correctly when visible', () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    expect(wrapper.find('.arco-drawer').exists()).toBe(true);
    expect(wrapper.text()).toContain('告警详情');
  });

  it('does not render when not visible', () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: false,
        alert: mockAlert,
      },
    });

    expect(wrapper.find('.arco-drawer').exists()).toBe(false);
  });

  it('displays alert basic information', () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    expect(wrapper.text()).toContain('检测到暴力破解尝试');
    expect(wrapper.text()).toContain('高危');
    expect(wrapper.text()).toContain('暴力破解');
  });

  it('formats JSON details correctly', () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    const detailsText = wrapper.text();
    expect(detailsText).toContain('192.168.1.100');
    expect(detailsText).toContain('admin');
    expect(detailsText).toContain('5');
  });

  it('emits close event when close button clicked', async () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    await wrapper.find('.arco-drawer-close-btn').trigger('click');
    expect(wrapper.emitted('update:visible')).toBeTruthy();
    expect(wrapper.emitted('update:visible')?.[0]).toEqual([false]);
  });

  it('emits handle event when handle button clicked', async () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    await wrapper.find('[data-test="handle-btn"]').trigger('click');
    expect(wrapper.emitted('handle')).toBeTruthy();
    expect(wrapper.emitted('handle')?.[0]).toEqual([mockAlert]);
  });

  it('copies alert ID to clipboard', async () => {
    const mockClipboard = {
      writeText: vi.fn().mockResolvedValue(undefined),
    };
    Object.assign(navigator, { clipboard: mockClipboard });

    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    await wrapper.find('[data-test="copy-id-btn"]').trigger('click');
    expect(mockClipboard.writeText).toHaveBeenCalledWith('1');
  });

  it('exports alert details as JSON', async () => {
    const mockCreateElement = vi.fn(() => ({
      click: vi.fn(),
      href: '',
      download: '',
    }));
    document.createElement = mockCreateElement;

    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    await wrapper.find('[data-test="export-btn"]').trigger('click');
    expect(mockCreateElement).toHaveBeenCalledWith('a');
  });

  it('displays related events when available', () => {
    const alertWithEvents = {
      ...mockAlert,
      related_events: [
        {
          id: 1,
          type: 'login_failed',
          message: '登录失败',
          created_at: '2026-03-07T09:55:00Z',
        },
        {
          id: 2,
          type: 'login_failed',
          message: '登录失败',
          created_at: '2026-03-07T09:56:00Z',
        },
      ],
    };

    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: alertWithEvents,
      },
    });

    expect(wrapper.text()).toContain('关联事件');
    expect(wrapper.text()).toContain('登录失败');
  });

  it('displays handle records when available', () => {
    const alertWithRecords = {
      ...mockAlert,
      handle_records: [
        {
          id: 1,
          action: 'resolve',
          comment: '已处理',
          handler: 'admin',
          created_at: '2026-03-07T10:30:00Z',
        },
      ],
    };

    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: alertWithRecords,
      },
    });

    expect(wrapper.text()).toContain('处理记录');
    expect(wrapper.text()).toContain('已处理');
    expect(wrapper.text()).toContain('admin');
  });

  it('handles null alert gracefully', () => {
    const wrapper = mount(AlertDetailDrawer, {
      props: {
        visible: true,
        alert: null,
      },
    });

    expect(wrapper.find('.arco-drawer').exists()).toBe(true);
    expect(wrapper.text()).toContain('暂无数据');
  });
});
