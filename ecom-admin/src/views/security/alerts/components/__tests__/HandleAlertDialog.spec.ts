import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import HandleAlertDialog from '../HandleAlertDialog.vue';
import type { SecurityAlert } from '@/types/security';

describe('HandleAlertDialog', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  const mockAlert: SecurityAlert = {
    id: 1,
    level: 'high',
    type: 'brute_force',
    status: 'pending',
    message: '检测到暴力破解尝试',
    details: {},
    created_at: '2026-03-07T10:00:00Z',
    updated_at: '2026-03-07T10:00:00Z',
  };

  it('renders correctly when visible', () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    expect(wrapper.find('.arco-modal').exists()).toBe(true);
    expect(wrapper.text()).toContain('处理告警');
  });

  it('does not render when not visible', () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: false,
        alert: mockAlert,
      },
    });

    expect(wrapper.find('.arco-modal').exists()).toBe(false);
  });

  it('validates required fields', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 尝试提交空表单
    await wrapper.find('[data-test="submit-btn"]').trigger('click');

    // 应该显示验证错误
    expect(wrapper.text()).toContain('请选择处理结果');
  });

  it('shows escalate target when action is escalate', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 选择升级
    await wrapper.find('[data-test="action-select"]').setValue('escalate');

    // 应该显示升级对象选择
    expect(wrapper.find('[data-test="escalate-target"]').exists()).toBe(true);
  });

  it('hides escalate target when action is not escalate', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 选择标记已处理
    await wrapper.find('[data-test="action-select"]').setValue('resolve');

    // 不应该显示升级对象选择
    expect(wrapper.find('[data-test="escalate-target"]').exists()).toBe(false);
  });

  it('validates comment length', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 输入超长文本
    const longText = 'a'.repeat(501);
    await wrapper.find('[data-test="comment-input"]').setValue(longText);

    // 应该显示长度限制错误
    expect(wrapper.text()).toContain('处理说明不能超过500字');
  });

  it('submits form with correct data', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 填写表单
    await wrapper.find('[data-test="action-select"]').setValue('resolve');
    await wrapper.find('[data-test="comment-input"]').setValue('已处理该告警');

    // 提交表单
    await wrapper.find('[data-test="submit-btn"]').trigger('click');

    // 应该触发提交事件
    expect(wrapper.emitted('submit')).toBeTruthy();
    expect(wrapper.emitted('submit')?.[0]).toEqual([
      {
        action: 'resolve',
        comment: '已处理该告警',
        escalate_target: undefined,
        attachments: [],
      },
    ]);
  });

  it('handles file upload', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    const file = new File(['test'], 'test.png', { type: 'image/png' });
    const input = wrapper.find('[data-test="file-input"]');

    Object.defineProperty(input.element, 'files', {
      value: [file],
      writable: false,
    });

    await input.trigger('change');

    // 应该显示上传的文件
    expect(wrapper.text()).toContain('test.png');
  });

  it('removes uploaded file', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 上传文件
    const file = new File(['test'], 'test.png', { type: 'image/png' });
    const input = wrapper.find('[data-test="file-input"]');
    Object.defineProperty(input.element, 'files', {
      value: [file],
      writable: false,
    });
    await input.trigger('change');

    // 删除文件
    await wrapper.find('[data-test="remove-file-btn"]').trigger('click');

    // 文件应该被移除
    expect(wrapper.text()).not.toContain('test.png');
  });

  it('resets form when closed', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 填写表单
    await wrapper.find('[data-test="action-select"]').setValue('resolve');
    await wrapper.find('[data-test="comment-input"]').setValue('已处理');

    // 关闭对话框
    await wrapper.find('[data-test="cancel-btn"]').trigger('click');

    // 重新打开
    await wrapper.setProps({ visible: true });

    // 表单应该被重置
    expect(wrapper.find('[data-test="action-select"]').element.value).toBe('');
    expect(wrapper.find('[data-test="comment-input"]').element.value).toBe('');
  });

  it('disables submit button when submitting', async () => {
    const wrapper = mount(HandleAlertDialog, {
      props: {
        visible: true,
        alert: mockAlert,
      },
    });

    // 填写表单
    await wrapper.find('[data-test="action-select"]').setValue('resolve');
    await wrapper.find('[data-test="comment-input"]').setValue('已处理');

    // 提交表单
    await wrapper.find('[data-test="submit-btn"]').trigger('click');

    // 提交按钮应该被禁用
    expect(wrapper.find('[data-test="submit-btn"]').attributes('disabled')).toBeDefined();
  });
});
