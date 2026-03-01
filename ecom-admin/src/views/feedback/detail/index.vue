<template>
  <div class="feedback-detail-page">
    <a-spin :loading="loading" class="page-loading">
      <div v-if="feedback" class="detail-container">
        <!-- 左侧主区域 -->
        <div class="main-content">
          <!-- 反馈标题区 -->
          <div class="feedback-header">
            <div class="header-top">
              <div class="feedback-id">#{{ feedback.id }}</div>
              <div class="feedback-meta">
                <a-tag :color="getStatusColor(feedback.status)" size="small">
                  {{ getStatusName(feedback.status) }}
                </a-tag>
                <a-tag :color="getPriorityColor(feedback.priority)" size="small">
                  {{ getPriorityName(feedback.priority) }}
                </a-tag>
              </div>
            </div>
            <h1 class="feedback-title">{{ feedback.title }}</h1>
            <div class="header-bottom">
              <div class="creator-info">
                <a-avatar :size="24" :src="feedback.creator_avatar">
                  <template #default>{{ feedback.creator_name?.charAt(0) }}</template>
                </a-avatar>
                <span class="creator-name">{{ feedback.creator_name }}</span>
                <span class="create-time">创建于 {{ formatDate(feedback.created_at) }}</span>
              </div>
              <div class="header-actions">
                <!-- 【权限控制】编辑按钮 - 有编辑权限才显示 -->
                <a-button
                  v-if="canEditFeedback(feedback)"
                  type="primary"
                  size="small"
                  @click="handleEdit"
                >
                  <template #icon><icon-edit /></template>
                  编辑
                </a-button>
                <!-- 【权限控制】关闭按钮 - 未关闭且有权限才显示 -->
                <a-button
                  v-if="feedback.status !== FeedbackStatus.CLOSED && canChangeStatus(feedback)"
                  size="small"
                  status="warning"
                  @click="handleClose"
                >
                  <template #icon><icon-close-circle /></template>
                  关闭
                </a-button>
                <!-- 【权限控制】删除按钮 - 有删除权限才显示 -->
                <a-button
                  v-if="canDeleteFeedback(feedback)"
                  size="small"
                  status="danger"
                  @click="handleDelete"
                >
                  <template #icon><icon-delete /></template>
                  删除
                </a-button>
                <!-- 质量中心联动 -->
                <a-divider direction="vertical" />
                <a-dropdown @select="handleQualityAction">
                  <a-button size="small" type="outline" status="success">
                    <template #icon><icon-shield-check /></template>
                    质量中心
                    <icon-down />
                  </a-button>
                  <template #content>
                    <a-doption value="toTask">
                      <icon-swap /> 转为测试任务
                    </a-doption>
                    <a-doption value="linkBug">
                      <icon-bug /> 关联到Bug
                    </a-doption>
                    <a-doption value="viewDashboard">
                      <icon-dashboard /> 查看质量面板
                    </a-doption>
                    <a-doption value="viewMindmap">
                      <icon-mind-mapping /> 反馈分类脑图
                    </a-doption>
                  </template>
                </a-dropdown>
              </div>
            </div>
          </div>

          <!-- 反馈描述区 -->
          <div class="feedback-description">
            <div class="section-title">
              <icon-file-text />
              反馈描述
            </div>
            <div class="description-content" v-html="renderMarkdown(feedback.content)"></div>

            <!-- 附件列表 -->
            <div v-if="feedback.attachments?.length" class="attachments-section">
              <div class="attachments-title">
                <icon-attachment />
                附件 ({{ feedback.attachments.length }})
              </div>
              <div class="attachments-list">
                <a-link
                  v-for="(attachment, index) in feedback.attachments"
                  :key="index"
                  :href="attachment"
                  target="_blank"
                  class="attachment-item"
                >
                  <icon-file />
                  {{ getFileName(attachment) }}
                </a-link>
              </div>
            </div>
          </div>

          <!-- 评论讨论区 -->
          <div class="feedback-comments">
            <div class="comments-header">
              <div class="section-title">
                <icon-message />
                评论讨论
                <a-badge :count="feedback.comment_count" class="comment-count" />
              </div>
              <a-radio-group v-model="commentSort" type="button" size="small">
                <a-radio value="newest">最新</a-radio>
                <a-radio value="oldest">最早</a-radio>
              </a-radio-group>
            </div>

            <!-- 评论输入框 -->
            <div class="comment-input-section">
              <a-textarea
                v-model="newComment"
                placeholder="输入评论内容，支持 @提及用户..."
                :auto-size="{ minRows: 3, maxRows: 6 }"
                allow-clear
              />
              <div class="comment-actions">
                <a-button type="primary" :loading="submitting" @click="handleSubmitComment">
                  <template #icon><icon-send /></template>
                  发表评论
                </a-button>
              </div>
            </div>

            <!-- 评论列表 -->
            <CommentList
              :comments="sortedComments"
              :loading="commentsLoading"
              :current-user-id="currentUserId"
              :is-admin="isAdmin"
              @reply="handleReply"
              @delete="handleDeleteComment"
            />
          </div>
        </div>

        <!-- 右侧侧边栏 -->
        <div class="sidebar">
          <!-- 状态管理卡片 -->
          <StatusCard
            :status="feedback.status"
            :status-name="getStatusName(feedback.status)"
            :status-color="getStatusColor(feedback.status)"
            :can-change="canChangeStatus(feedback)"
            @change="handleStatusChange"
          />

          <!-- 指派信息卡片 -->
          <AssigneeCard
            :assignee-id="feedback.handler_id"
            :assignee-name="feedback.handler_name"
            :assignee-avatar="feedback.handler_avatar"
            :can-assign="canAssign"
            @change="handleAssigneeChange"
          />

          <!-- 优先级卡片 -->
          <PriorityCard
            :priority="feedback.priority"
            :priority-name="getPriorityName(feedback.priority)"
            :priority-color="getPriorityColor(feedback.priority)"
            :can-change="canEditFeedback(feedback)"
            @change="handlePriorityChange"
          />

          <!-- 标签卡片 -->
          <TagsCard
            :tags="feedback.tags || []"
            :tag-ids="feedback.tag_ids || []"
            :can-manage="canManageTags"
            @add="handleAddTag"
            @remove="handleRemoveTag"
          />

          <!-- 订阅卡片 -->
          <SubscribeCard
            :is-subscribed="feedback.is_subscribed"
            :subscriber-count="feedback.subscriber_count"
            @toggle="handleToggleSubscribe"
          />

          <!-- 参与者卡片 -->
          <ParticipantsCard
            :creator="{
              id: feedback.creator_id,
              name: feedback.creator_name,
              avatar: feedback.creator_avatar,
            }"
            :assignee="
              feedback.handler_id
                ? {
                    id: feedback.handler_id,
                    name: feedback.handler_name,
                    avatar: feedback.handler_avatar,
                  }
                : undefined
            "
            :participants="participants"
          />
        </div>
      </div>

      <!-- 空状态 -->
      <div v-else-if="!loading" class="empty-state">
        <a-empty description="反馈不存在或已被删除">
          <a-button type="primary" @click="goBack">返回列表</a-button>
        </a-empty>
      </div>
    </a-spin>

    <!-- 编辑对话框 -->
    <a-modal
      v-model:visible="editModalVisible"
      title="编辑反馈"
      :width="700"
      :mask-closable="false"
      @ok="handleEditConfirm"
      @cancel="handleEditCancel"
    >
      <a-form :model="editForm" layout="vertical">
        <a-form-item label="标题" required>
          <a-input v-model="editForm.title" placeholder="请输入反馈标题" />
        </a-form-item>
        <a-form-item label="内容" required>
          <a-textarea
            v-model="editForm.content"
            placeholder="请输入反馈内容"
            :auto-size="{ minRows: 6, maxRows: 12 }"
          />
        </a-form-item>
        <a-form-item label="类型">
          <a-select v-model="editForm.type" placeholder="请选择反馈类型">
            <a-option
              v-for="type in feedbackTypes"
              :key="type.value"
              :value="type.value"
              :label="type.label"
            />
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, onMounted, watch } from 'vue';
  import { useRoute, useRouter } from 'vue-router';
  import { Message, Modal } from '@arco-design/web-vue';
  import {
    IconEdit,
    IconCloseCircle,
    IconDelete,
    IconFileText,
    IconAttachment,
    IconFile,
    IconMessage,
    IconSend,
  } from '@arco-design/web-vue/es/icon';
  import dayjs from 'dayjs';
  import MarkdownIt from 'markdown-it';
  import {
    getFeedbackDetail,
    updateFeedback,
    deleteFeedback,
    updateFeedbackStatus,
    assignFeedback,
    subscribeFeedback,
    unsubscribeFeedback,
    getCommentList,
    createComment,
    deleteComment,
    FeedbackStatus,
    FeedbackPriority,
    FeedbackType,
    type Feedback,
    type Comment,
  } from '@/api/feedback';
  import CommentList from './components/CommentList.vue';
  import StatusCard from './components/StatusCard.vue';
  import AssigneeCard from './components/AssigneeCard.vue';
  import PriorityCard from './components/PriorityCard.vue';
  import TagsCard from './components/TagsCard.vue';
  import SubscribeCard from './components/SubscribeCard.vue';
  import ParticipantsCard from './components/ParticipantsCard.vue';
  // 【权限控制】导入权限检查工具
  import {
    useFeedbackPermission,
    canEditFeedback,
    canDeleteFeedback,
    canChangeStatus,
    canDeleteComment,
    canManageTags,
    isAdmin,
    getCurrentUserId,
  } from '../utils/permission';
  import { FeedbackPermissions } from '../constants/permissions';
  import { useQualityCenterStore } from '@/store/modules/quality-center';

  const route = useRoute();
  const router = useRouter();
  const feedbackId = computed(() => Number(route.params.id));
  const qcStore = useQualityCenterStore();

  // Markdown 渲染器
  const md = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
  });

  // 【权限控制】使用权限检查组合式函数
  const {
    hasPermission: checkPermission,
    isAdmin: isAdminRef,
  } = useFeedbackPermission();

  // ========== 权限控制计算属性 ==========

  /** 当前用户ID */
  const currentUserId = computed(() => getCurrentUserId());

  /** 是否管理员 */
  const isAdminUser = computed(() => isAdmin());

  /** 是否有指派权限 */
  const canAssign = computed(() => checkPermission(FeedbackPermissions.ASSIGN).value);

  /** 是否有管理标签权限 */
  const canManageTagsFlag = computed(() => canManageTags());

  // 状态
  const loading = ref(false);
  const feedback = ref<Feedback | null>(null);
  const comments = ref<Comment[]>([]);
  const commentsLoading = ref(false);
  const newComment = ref('');
  const submitting = ref(false);
  const commentSort = ref<'newest' | 'oldest'>('newest');

  // 编辑相关
  const editModalVisible = ref(false);
  const editForm = ref({
    title: '',
    content: '',
    type: FeedbackType.FEATURE,
  });

  // 反馈类型选项
  const feedbackTypes = [
    { value: FeedbackType.FEATURE, label: '功能建议' },
    { value: FeedbackType.BUG, label: 'Bug 反馈' },
    { value: FeedbackType.PERFORMANCE, label: '性能问题' },
    { value: FeedbackType.UX, label: '用户体验' },
    { value: FeedbackType.OTHER, label: '其他' },
  ];

  // 状态映射
  const statusMap: Record<number, { name: string; color: string }> = {
    [FeedbackStatus.PENDING]: { name: '待处理', color: 'gray' },
    [FeedbackStatus.PROCESSING]: { name: '处理中', color: 'orange' },
    [FeedbackStatus.RESOLVED]: { name: '已解决', color: 'green' },
    [FeedbackStatus.CLOSED]: { name: '已关闭', color: 'gray' },
    [FeedbackStatus.REJECTED]: { name: '已拒绝', color: 'red' },
  };

  // 优先级映射
  const priorityMap: Record<number, { name: string; color: string }> = {
    [FeedbackPriority.URGENT]: { name: '紧急', color: 'red' },
    [FeedbackPriority.HIGH]: { name: '高', color: 'orange' },
    [FeedbackPriority.MEDIUM]: { name: '中', color: 'blue' },
    [FeedbackPriority.LOW]: { name: '低', color: 'green' },
  };

  // 计算属性：排序后的评论
  const sortedComments = computed(() => {
    const sorted = [...comments.value];
    if (commentSort.value === 'newest') {
      sorted.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    } else {
      sorted.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
    }
    return sorted;
  });

  // 计算属性：参与者列表
  const participants = computed(() => {
    const participantMap = new Map();

    // 添加评论者
    comments.value.forEach((comment) => {
      if (!participantMap.has(comment.user_id)) {
        participantMap.set(comment.user_id, {
          id: comment.user_id,
          name: comment.user_name,
          avatar: comment.user_avatar,
        });
      }
    });

    return Array.from(participantMap.values());
  });

  // 获取状态名称
  const getStatusName = (status: number) => {
    return statusMap[status]?.name || '未知';
  };

  // 获取状态颜色
  const getStatusColor = (status: number) => {
    return statusMap[status]?.color || 'gray';
  };

  // 获取优先级名称
  const getPriorityName = (priority: number) => {
    return priorityMap[priority]?.name || '未知';
  };

  // 获取优先级颜色
  const getPriorityColor = (priority: number) => {
    return priorityMap[priority]?.color || 'gray';
  };

  // 格式化日期
  const formatDate = (date: string) => {
    return dayjs(date).format('YYYY-MM-DD HH:mm');
  };

  // 渲染 Markdown
  const renderMarkdown = (content: string) => {
    if (!content) return '';
    return md.render(content);
  };

  // 获取文件名
  const getFileName = (url: string) => {
    return url.split('/').pop() || url;
  };

  // 加载反馈详情
  const loadFeedbackDetail = async () => {
    loading.value = true;
    try {
      const res = await getFeedbackDetail(feedbackId.value);
      feedback.value = res.data.data;
    } catch (error) {
      Message.error('加载反馈详情失败');
    } finally {
      loading.value = false;
    }
  };

  // 加载评论列表
  const loadComments = async () => {
    commentsLoading.value = true;
    try {
      const res = await getCommentList({ feedback_id: feedbackId.value });
      comments.value = res.data.data?.list || [];
    } catch (error) {
      Message.error('加载评论失败');
    } finally {
      commentsLoading.value = false;
    }
  };

  // 返回列表
  const goBack = () => {
    router.push('/feedback/list');
  };

  // 编辑反馈
  const handleEdit = () => {
    // 【权限控制】检查编辑权限
    if (!feedback.value || !canEditFeedback(feedback.value)) {
      Message.error('您没有编辑该反馈的权限');
      return;
    }

    if (!feedback.value) return;
    editForm.value = {
      title: feedback.value.title,
      content: feedback.value.content,
      type: feedback.value.type,
    };
    editModalVisible.value = true;
  };

  // 确认编辑
  const handleEditConfirm = async () => {
    if (!editForm.value.title.trim()) {
      Message.warning('请输入标题');
      return;
    }
    if (!editForm.value.content.trim()) {
      Message.warning('请输入内容');
      return;
    }

    // 【权限控制】再次检查权限
    if (!feedback.value || !canEditFeedback(feedback.value)) {
      Message.error('您没有编辑该反馈的权限');
      return;
    }

    try {
      await updateFeedback({
        id: feedbackId.value,
        title: editForm.value.title,
        content: editForm.value.content,
        type: editForm.value.type,
      });
      Message.success('更新成功');
      editModalVisible.value = false;
      loadFeedbackDetail();
    } catch (error) {
      Message.error('更新失败');
    }
  };

  // 取消编辑
  const handleEditCancel = () => {
    editModalVisible.value = false;
  };

  // 关闭反馈
  const handleClose = () => {
    // 【权限控制】检查状态变更权限
    if (!feedback.value || !canChangeStatus(feedback.value)) {
      Message.error('您没有关闭该反馈的权限');
      return;
    }

    Modal.confirm({
      title: '确认关闭',
      content: '关闭后该反馈将不再接受新的评论，是否继续？',
      onOk: async () => {
        try {
          await updateFeedbackStatus({
            id: feedbackId.value,
            status: FeedbackStatus.CLOSED,
          });
          Message.success('关闭成功');
          loadFeedbackDetail();
        } catch (error) {
          Message.error('关闭失败');
        }
      },
    });
  };

  // 删除反馈
  const handleDelete = () => {
    // 【权限控制】检查删除权限
    if (!feedback.value || !canDeleteFeedback(feedback.value)) {
      Message.error('您没有删除该反馈的权限');
      return;
    }

    Modal.confirm({
      title: '确认删除',
      content: '删除后无法恢复，是否继续？',
      okButtonProps: { status: 'danger' },
      onOk: async () => {
        try {
          await deleteFeedback(feedbackId.value);
          Message.success('删除成功');
          goBack();
        } catch (error) {
          Message.error('删除失败');
        }
      },
    });
  };

  // 质量中心联动操作
  const handleQualityAction = async (value: string | number | Record<string, unknown> | undefined) => {
    const key = String(value);
    if (!feedback.value) return;
    console.log(`[反馈详情][质量中心联动][${key}][反馈#${feedback.value.id}]`);

    switch (key) {
      case 'toTask': {
        Modal.confirm({
          title: '转为测试任务',
          content: `确定将反馈 #${feedback.value.id}「${feedback.value.title}」转为测试任务？`,
          okText: '确认转换',
          async onOk() {
            try {
              await qcStore.convertFeedbackToTask({
                feedback_id: feedback.value!.id,
                title: `[反馈] ${feedback.value!.title}`,
                priority: 'medium',
                assigned_to: 'auto',
              });
              Message.success('已成功转为测试任务');
            } catch {
              Message.error('转换失败，请重试');
            }
          },
        });
        break;
      }
      case 'linkBug': {
        Modal.confirm({
          title: '关联到Bug',
          content: `确定将反馈 #${feedback.value.id}「${feedback.value.title}」关联到Bug追踪？`,
          okText: '确认关联',
          async onOk() {
            try {
              await qcStore.convertBugToFeedback({
                bug_id: feedback.value!.id,
                feedback_id: feedback.value!.id,
                link_type: 'feedback_to_bug',
                description: `反馈关联: ${feedback.value!.title}`,
              });
              Message.success('已关联到Bug追踪');
            } catch {
              Message.error('关联失败，请重试');
            }
          },
        });
        break;
      }
      case 'viewDashboard':
        router.push('/quality-center/dashboard');
        break;
      case 'viewMindmap':
        router.push('/quality-center/mindmap');
        break;
      default:
        break;
    }
  };

  // 提交评论
  const handleSubmitComment = async () => {
    if (!newComment.value.trim()) {
      Message.warning('请输入评论内容');
      return;
    }

    submitting.value = true;
    try {
      await createComment({
        feedback_id: feedbackId.value,
        content: newComment.value,
      });
      Message.success('评论成功');
      newComment.value = '';
      loadComments();
      loadFeedbackDetail();
    } catch (error) {
      Message.error('评论失败');
    } finally {
      submitting.value = false;
    }
  };

  // 回复评论
  const handleReply = async (commentId: number, content: string) => {
    try {
      await createComment({
        feedback_id: feedbackId.value,
        parent_id: commentId,
        content,
      });
      Message.success('回复成功');
      loadComments();
      loadFeedbackDetail();
    } catch (error) {
      Message.error('回复失败');
    }
  };

  // 删除评论
  const handleDeleteComment = async (commentId: number, commentUserId: number) => {
    // 【权限控制】检查评论删除权限
    if (!canDeleteComment(commentUserId)) {
      Message.error('您没有删除该评论的权限');
      return;
    }

    Modal.confirm({
      title: '确认删除',
      content: '删除后无法恢复，是否继续？',
      onOk: async () => {
        try {
          await deleteComment(commentId);
          Message.success('删除成功');
          loadComments();
          loadFeedbackDetail();
        } catch (error) {
          Message.error('删除失败');
        }
      },
    });
  };

  // 状态变更
  const handleStatusChange = async (status: number) => {
    // 【权限控制】检查状态变更权限
    if (!feedback.value || !canChangeStatus(feedback.value)) {
      Message.error('您没有更改该反馈状态的权限');
      return;
    }

    try {
      await updateFeedbackStatus({
        id: feedbackId.value,
        status,
      });
      Message.success('状态更新成功');
      loadFeedbackDetail();
    } catch (error) {
      Message.error('状态更新失败');
    }
  };

  // 指派变更
  const handleAssigneeChange = async (handlerId: number) => {
    // 【权限控制】检查指派权限
    if (!canAssign.value) {
      Message.error('您没有指派反馈的权限');
      return;
    }

    try {
      await assignFeedback({
        id: feedbackId.value,
        handler_id: handlerId,
      });
      Message.success('指派成功');
      loadFeedbackDetail();
    } catch (error) {
      Message.error('指派失败');
    }
  };

  // 优先级变更
  const handlePriorityChange = async (priority: number) => {
    // 【权限控制】检查编辑权限
    if (!feedback.value || !canEditFeedback(feedback.value)) {
      Message.error('您没有更改优先级的权限');
      return;
    }

    try {
      await updateFeedback({
        id: feedbackId.value,
        priority,
      });
      Message.success('优先级更新成功');
      loadFeedbackDetail();
    } catch (error) {
      Message.error('优先级更新失败');
    }
  };

  // 添加标签
  const handleAddTag = async (tagId: number) => {
    // 【权限控制】检查标签管理权限
    if (!canManageTags()) {
      Message.error('您没有管理标签的权限');
      return;
    }

    if (!feedback.value) return;
    const newTagIds = [...(feedback.value.tag_ids || []), tagId];
    try {
      await updateFeedback({
        id: feedbackId.value,
        tag_ids: newTagIds,
      });
      Message.success('添加标签成功');
      loadFeedbackDetail();
    } catch (error) {
      Message.error('添加标签失败');
    }
  };

  // 移除标签
  const handleRemoveTag = async (tagId: number) => {
    // 【权限控制】检查标签管理权限
    if (!canManageTags()) {
      Message.error('您没有管理标签的权限');
      return;
    }

    if (!feedback.value) return;
    const newTagIds = (feedback.value.tag_ids || []).filter((id) => id !== tagId);
    try {
      await updateFeedback({
        id: feedbackId.value,
        tag_ids: newTagIds,
      });
      Message.success('移除标签成功');
      loadFeedbackDetail();
    } catch (error) {
      Message.error('移除标签失败');
    }
  };

  // 切换订阅
  const handleToggleSubscribe = async (isSubscribed: boolean) => {
    try {
      if (isSubscribed) {
        await subscribeFeedback({ id: feedbackId.value });
        Message.success('订阅成功');
      } else {
        await unsubscribeFeedback({ id: feedbackId.value });
        Message.success('取消订阅成功');
      }
      loadFeedbackDetail();
    } catch (error) {
      Message.error('操作失败');
    }
  };

  // 监听路由参数变化
  watch(
    () => route.params.id,
    () => {
      if (feedbackId.value) {
        loadFeedbackDetail();
        loadComments();
      }
    },
    { immediate: true }
  );

  onMounted(() => {
    loadFeedbackDetail();
    loadComments();
  });
</script>

<style scoped lang="less">
  .feedback-detail-page {
    padding: 20px;
    min-height: 100%;
    background-color: var(--color-fill-2);

    .page-loading {
      width: 100%;
    }

    .detail-container {
      display: flex;
      gap: 20px;
      max-width: 1400px;
      margin: 0 auto;
    }

    .main-content {
      flex: 2;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .sidebar {
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 16px;
      max-width: 360px;
    }

    // 反馈标题区
    .feedback-header {
      background: var(--color-bg-2);
      border-radius: 8px;
      padding: 20px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

      .header-top {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;

        .feedback-id {
          font-size: 14px;
          color: var(--color-text-3);
          font-weight: 500;
        }

        .feedback-meta {
          display: flex;
          gap: 8px;
        }
      }

      .feedback-title {
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-1);
        margin: 0 0 16px 0;
        line-height: 1.4;
      }

      .header-bottom {
        display: flex;
        justify-content: space-between;
        align-items: center;

        .creator-info {
          display: flex;
          align-items: center;
          gap: 8px;

          .creator-name {
            font-size: 14px;
            color: var(--color-text-1);
            font-weight: 500;
          }

          .create-time {
            font-size: 13px;
            color: var(--color-text-3);
          }
        }

        .header-actions {
          display: flex;
          gap: 8px;
        }
      }
    }

    // 反馈描述区
    .feedback-description {
      background: var(--color-bg-2);
      border-radius: 8px;
      padding: 20px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

      .section-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 16px;
        font-weight: 600;
        color: var(--color-text-1);
        margin-bottom: 16px;
        padding-bottom: 12px;
        border-bottom: 1px solid var(--color-border-2);
      }

      .description-content {
        font-size: 14px;
        line-height: 1.8;
        color: var(--color-text-1);

        :deep(p) {
          margin: 0 0 12px 0;

          &:last-child {
            margin-bottom: 0;
          }
        }

        :deep(code) {
          background: var(--color-fill-2);
          padding: 2px 6px;
          border-radius: 4px;
          font-family: monospace;
        }

        :deep(pre) {
          background: var(--color-fill-2);
          padding: 12px;
          border-radius: 6px;
          overflow-x: auto;

          code {
            background: none;
            padding: 0;
          }
        }

        :deep(ul),
        :deep(ol) {
          padding-left: 24px;
          margin: 12px 0;
        }

        :deep(blockquote) {
          border-left: 4px solid var(--color-primary-light-3);
          padding-left: 12px;
          margin: 12px 0;
          color: var(--color-text-2);
        }
      }

      .attachments-section {
        margin-top: 20px;
        padding-top: 16px;
        border-top: 1px solid var(--color-border-2);

        .attachments-title {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-1);
          margin-bottom: 12px;
        }

        .attachments-list {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;

          .attachment-item {
            display: flex;
            align-items: center;
            gap: 4px;
            padding: 6px 12px;
            background: var(--color-fill-2);
            border-radius: 4px;
            font-size: 13px;
            transition: background 0.2s;

            &:hover {
              background: var(--color-fill-3);
            }
          }
        }
      }
    }

    // 评论讨论区
    .feedback-comments {
      background: var(--color-bg-2);
      border-radius: 8px;
      padding: 20px;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

      .comments-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 16px;
        padding-bottom: 12px;
        border-bottom: 1px solid var(--color-border-2);

        .section-title {
          display: flex;
          align-items: center;
          gap: 8px;
          font-size: 16px;
          font-weight: 600;
          color: var(--color-text-1);

          .comment-count {
            margin-left: 4px;
          }
        }
      }

      .comment-input-section {
        margin-bottom: 20px;

        .comment-actions {
          display: flex;
          justify-content: flex-end;
          margin-top: 12px;
        }
      }
    }

    // 空状态
    .empty-state {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 400px;
    }
  }

  // 响应式适配
  @media (max-width: 1024px) {
    .feedback-detail-page {
      .detail-container {
        flex-direction: column;
      }

      .sidebar {
        max-width: none;
      }
    }
  }
</style>
