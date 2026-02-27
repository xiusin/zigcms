<template>
  <div class="comment-list">
    <a-spin :loading="loading" class="comments-loading">
      <div v-if="comments.length === 0" class="empty-comments">
        <a-empty description="暂无评论，快来发表第一条评论吧" />
      </div>

      <div v-else class="comments-tree">
        <div
          v-for="comment in comments"
          :key="comment.id"
          class="comment-item"
          :class="{ 'is-internal': comment.type === 1 }"
        >
          <!-- 评论头部 -->
          <div class="comment-header">
            <a-avatar :size="32" :src="comment.user_avatar">
              <template #default>{{ comment.user_name?.charAt(0) }}</template>
            </a-avatar>
            <div class="comment-meta">
              <div class="comment-author">
                <span class="author-name">{{ comment.user_name }}</span>
                <a-tag v-if="comment.type === 1" size="small" color="orange">内部</a-tag>
                <a-tag v-if="comment.type === 2" size="small" color="blue">系统</a-tag>
                <span v-if="comment.is_edited" class="edited-mark">(已编辑)</span>
              </div>
              <div class="comment-time">{{ formatDate(comment.created_at) }}</div>
            </div>
          </div>

          <!-- 评论内容 -->
          <div class="comment-content">
            <div v-if="comment.parent_id" class="reply-to">
              回复 <span class="reply-user">@{{ getParentAuthor(comment.parent_id) }}</span>：
            </div>
            {{ comment.content }}
          </div>

          <!-- 评论操作 -->
          <div class="comment-actions">
            <a-button type="text" size="mini" @click="handleReply(comment)">
              <template #icon><icon-message /></template>
              回复
            </a-button>
            <!-- 【权限控制】编辑按钮 - 仅评论作者可编辑 -->
            <a-button
              v-if="canEditComment(comment.user_id)"
              type="text"
              size="mini"
              @click="handleEdit(comment)"
            >
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <!-- 【权限控制】删除按钮 - 评论作者或管理员可删除 -->
            <a-button
              v-if="canDeleteComment(comment.user_id)"
              type="text"
              size="mini"
              status="danger"
              @click="handleDelete(comment)"
            >
              <template #icon><icon-delete /></template>
              删除
            </a-button>
          </div>

          <!-- 回复输入框 -->
          <div v-if="replyingTo === comment.id" class="reply-input-section">
            <a-textarea
              v-model="replyContent"
              :placeholder="`回复 @${comment.user_name}...`"
              :auto-size="{ minRows: 2, maxRows: 4 }"
              allow-clear
            />
            <div class="reply-actions">
              <a-button size="small" @click="cancelReply">取消</a-button>
              <a-button type="primary" size="small" :loading="submitting" @click="submitReply">
                回复
              </a-button>
            </div>
          </div>

          <!-- 子评论 -->
          <div v-if="comment.children?.length" class="children-comments">
            <div
              v-for="child in comment.children"
              :key="child.id"
              class="comment-item child-item"
            >
              <div class="comment-header">
                <a-avatar :size="28" :src="child.user_avatar">
                  <template #default>{{ child.user_name?.charAt(0) }}</template>
                </a-avatar>
                <div class="comment-meta">
                  <div class="comment-author">
                    <span class="author-name">{{ child.user_name }}</span>
                    <a-tag v-if="child.type === 1" size="small" color="orange">内部</a-tag>
                    <span v-if="child.is_edited" class="edited-mark">(已编辑)</span>
                  </div>
                  <div class="comment-time">{{ formatDate(child.created_at) }}</div>
                </div>
              </div>

              <div class="comment-content">
                <div class="reply-to">
                  回复 <span class="reply-user">@{{ comment.user_name }}</span>：
                </div>
                {{ child.content }}
              </div>

              <div class="comment-actions">
                <a-button type="text" size="mini" @click="handleReply(child, comment)">
                  <template #icon><icon-message /></template>
                  回复
                </a-button>
                <!-- 【权限控制】编辑按钮 - 仅评论作者可编辑 -->
                <a-button
                  v-if="canEditComment(child.user_id)"
                  type="text"
                  size="mini"
                  @click="handleEdit(child)"
                >
                  <template #icon><icon-edit /></template>
                  编辑
                </a-button>
                <!-- 【权限控制】删除按钮 - 评论作者或管理员可删除 -->
                <a-button
                  v-if="canDeleteComment(child.user_id)"
                  type="text"
                  size="mini"
                  status="danger"
                  @click="handleDelete(child)"
                >
                  <template #icon><icon-delete /></template>
                  删除
                </a-button>
              </div>

              <!-- 子评论回复输入框 -->
              <div v-if="replyingTo === child.id" class="reply-input-section">
                <a-textarea
                  v-model="replyContent"
                  :placeholder="`回复 @${child.user_name}...`"
                  :auto-size="{ minRows: 2, maxRows: 4 }"
                  allow-clear
                />
                <div class="reply-actions">
                  <a-button size="small" @click="cancelReply">取消</a-button>
                  <a-button type="primary" size="small" :loading="submitting" @click="submitReply">
                    回复
                  </a-button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </a-spin>

    <!-- 编辑对话框 -->
    <a-modal
      v-model:visible="editModalVisible"
      title="编辑评论"
      :width="500"
      @ok="submitEdit"
      @cancel="cancelEdit"
    >
      <a-textarea
        v-model="editContent"
        placeholder="请输入评论内容"
        :auto-size="{ minRows: 4, maxRows: 8 }"
      />
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import {
    IconMessage,
    IconEdit,
    IconDelete,
  } from '@arco-design/web-vue/es/icon';
  import dayjs from 'dayjs';
  import { type Comment, updateComment } from '@/api/feedback';
  // 【权限控制】导入权限检查工具
  import { canDeleteComment as checkCanDeleteComment, getCurrentUserId } from '../../utils/permission';

  interface Props {
    comments: Comment[];
    loading?: boolean;
    /** 【权限控制】当前用户ID */
    currentUserId?: number;
    /** 【权限控制】是否管理员 */
    isAdmin?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    loading: false,
    currentUserId: undefined,
    isAdmin: false,
  });

  const emit = defineEmits<{
    (e: 'reply', commentId: number, content: string): void;
    /** 【权限控制】删除事件增加评论用户ID参数 */
    (e: 'delete', commentId: number, commentUserId: number): void;
    (e: 'update', commentId: number, content: string): void;
  }>();

  // 回复相关状态
  const replyingTo = ref<number | null>(null);
  const replyContent = ref('');
  const replyParentId = ref<number | null>(null);
  const submitting = ref(false);

  // 编辑相关状态
  const editModalVisible = ref(false);
  const editContent = ref('');
  const editingCommentId = ref<number | null>(null);

  /**
   * 【权限控制】检查是否能编辑评论
   * 规则：仅评论作者可编辑
   * @param commentUserId 评论作者ID
   */
  const canEditComment = (commentUserId: number): boolean => {
    return commentUserId === props.currentUserId;
  };

  /**
   * 【权限控制】检查是否能删除评论
   * 规则：评论作者或管理员可删除
   * @param commentUserId 评论作者ID
   */
  const canDeleteComment = (commentUserId: number): boolean => {
    // 使用工具函数检查权限
    return checkCanDeleteComment(commentUserId);
  };

  // 格式化日期
  const formatDate = (date: string) => {
    const now = dayjs();
    const commentDate = dayjs(date);
    const diffMinutes = now.diff(commentDate, 'minute');
    const diffHours = now.diff(commentDate, 'hour');
    const diffDays = now.diff(commentDate, 'day');

    if (diffMinutes < 1) {
      return '刚刚';
    } else if (diffMinutes < 60) {
      return `${diffMinutes}分钟前`;
    } else if (diffHours < 24) {
      return `${diffHours}小时前`;
    } else if (diffDays < 7) {
      return `${diffDays}天前`;
    } else {
      return commentDate.format('YYYY-MM-DD HH:mm');
    }
  };

  // 获取父评论作者
  const getParentAuthor = (parentId: number): string => {
    for (const comment of props.comments) {
      if (comment.id === parentId) {
        return comment.user_name;
      }
      if (comment.children) {
        for (const child of comment.children) {
          if (child.id === parentId) {
            return child.user_name;
          }
        }
      }
    }
    return '未知用户';
  };

  // 处理回复
  const handleReply = (comment: Comment, parentComment?: Comment) => {
    replyingTo.value = comment.id;
    replyParentId.value = parentComment?.id || comment.id;
    replyContent.value = '';
  };

  // 取消回复
  const cancelReply = () => {
    replyingTo.value = null;
    replyContent.value = '';
    replyParentId.value = null;
  };

  // 提交回复
  const submitReply = async () => {
    if (!replyContent.value.trim()) {
      Message.warning('请输入回复内容');
      return;
    }

    submitting.value = true;
    try {
      emit('reply', replyParentId.value!, replyContent.value);
      cancelReply();
    } finally {
      submitting.value = false;
    }
  };

  // 处理编辑
  const handleEdit = (comment: Comment) => {
    // 【权限控制】检查编辑权限
    if (!canEditComment(comment.user_id)) {
      Message.error('您没有编辑该评论的权限');
      return;
    }
    editingCommentId.value = comment.id;
    editContent.value = comment.content;
    editModalVisible.value = true;
  };

  // 取消编辑
  const cancelEdit = () => {
    editModalVisible.value = false;
    editingCommentId.value = null;
    editContent.value = '';
  };

  // 提交编辑
  const submitEdit = async () => {
    if (!editContent.value.trim()) {
      Message.warning('请输入评论内容');
      return;
    }

    try {
      await updateComment({
        id: editingCommentId.value!,
        content: editContent.value,
      });
      Message.success('编辑成功');
      emit('update', editingCommentId.value!, editContent.value);
      cancelEdit();
    } catch (error) {
      Message.error('编辑失败');
    }
  };

  // 处理删除
  const handleDelete = (comment: Comment) => {
    // 【权限控制】检查删除权限
    if (!canDeleteComment(comment.user_id)) {
      Message.error('您没有删除该评论的权限');
      return;
    }
    emit('delete', comment.id, comment.user_id);
  };
</script>

<style scoped lang="less">
  .comment-list {
    .comments-loading {
      width: 100%;
    }

    .empty-comments {
      padding: 40px 0;
    }

    .comments-tree {
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .comment-item {
      padding: 16px;
      background: var(--color-fill-1);
      border-radius: 8px;
      transition: background 0.2s;

      &:hover {
        background: var(--color-fill-2);
      }

      &.is-internal {
        border-left: 3px solid var(--color-warning-light-3);
      }

      .comment-header {
        display: flex;
        align-items: center;
        gap: 12px;
        margin-bottom: 12px;

        .comment-meta {
          flex: 1;

          .comment-author {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 4px;

            .author-name {
              font-size: 14px;
              font-weight: 500;
              color: var(--color-text-1);
            }

            .edited-mark {
              font-size: 12px;
              color: var(--color-text-3);
            }
          }

          .comment-time {
            font-size: 12px;
            color: var(--color-text-3);
          }
        }
      }

      .comment-content {
        font-size: 14px;
        line-height: 1.6;
        color: var(--color-text-1);
        margin-bottom: 12px;
        padding-left: 44px;

        .reply-to {
          display: inline;
          color: var(--color-text-3);
          font-size: 13px;

          .reply-user {
            color: var(--color-primary);
            font-weight: 500;
          }
        }
      }

      .comment-actions {
        display: flex;
        gap: 8px;
        padding-left: 44px;

        :deep(.arco-btn) {
          padding: 0 8px;
          height: 24px;
          font-size: 12px;
        }
      }

      .reply-input-section {
        margin-top: 12px;
        margin-left: 44px;
        padding: 12px;
        background: var(--color-bg-2);
        border-radius: 6px;

        .reply-actions {
          display: flex;
          justify-content: flex-end;
          gap: 8px;
          margin-top: 12px;
        }
      }

      .children-comments {
        margin-top: 16px;
        margin-left: 44px;
        padding-left: 16px;
        border-left: 2px solid var(--color-border-2);
        display: flex;
        flex-direction: column;
        gap: 12px;

        .child-item {
          padding: 12px;
          background: var(--color-bg-2);

          &:hover {
            background: var(--color-fill-1);
          }

          .comment-content,
          .comment-actions {
            padding-left: 40px;
          }

          .reply-input-section {
            margin-left: 40px;
          }
        }
      }
    }
  }
</style>
