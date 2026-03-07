<template>
  <div class="comment-section">
    <!-- 评论输入框 -->
    <div class="comment-input">
      <a-textarea
        v-model="commentContent"
        placeholder="添加评论... 使用 @ 提及用户"
        :auto-size="{ minRows: 3, maxRows: 6 }"
        :max-length="1000"
        show-word-limit
        @keydown="handleKeydown"
      />
      
      <div class="input-actions">
        <a-space>
          <a-button size="small" @click="handleInsertMention">
            <template #icon><icon-at /></template>
            提及
          </a-button>
          <a-button size="small" @click="handleInsertCode">
            <template #icon><icon-code /></template>
            代码
          </a-button>
        </a-space>
        
        <a-space>
          <a-button @click="handleCancelComment">取消</a-button>
          <a-button
            type="primary"
            :loading="submitting"
            :disabled="!commentContent.trim()"
            @click="handleSubmitComment"
          >
            发表评论
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- 评论列表 -->
    <div class="comment-list">
      <div class="comment-header">
        <span class="comment-count">{{ comments.length }} 条评论</span>
        <a-select
          v-model="sortOrder"
          size="small"
          style="width: 120px"
          @change="handleSortChange"
        >
          <a-option value="desc">最新优先</a-option>
          <a-option value="asc">最早优先</a-option>
        </a-select>
      </div>

      <a-spin :loading="loading" style="width: 100%">
        <div v-if="sortedComments.length === 0" class="empty-comments">
          <a-empty description="暂无评论" />
        </div>

        <div
          v-for="comment in sortedComments"
          :key="comment.id"
          class="comment-item"
        >
          <div class="comment-avatar">
            <a-avatar :size="36">
              {{ comment.author.charAt(0).toUpperCase() }}
            </a-avatar>
          </div>

          <div class="comment-content">
            <div class="comment-meta">
              <span class="comment-author">{{ comment.author }}</span>
              <span class="comment-time">{{ formatTime(comment.created_at) }}</span>
            </div>

            <div class="comment-text" v-html="renderComment(comment.content)"></div>

            <div class="comment-actions">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="handleLikeComment(comment)"
                >
                  <template #icon>
                    <icon-heart-fill v-if="comment.liked" style="color: #f53f3f" />
                    <icon-heart v-else />
                  </template>
                  {{ comment.likes || 0 }}
                </a-button>

                <a-button
                  type="text"
                  size="small"
                  @click="handleReplyComment(comment)"
                >
                  <template #icon><icon-message /></template>
                  回复
                </a-button>

                <a-button
                  v-if="canEditComment(comment)"
                  type="text"
                  size="small"
                  @click="handleEditComment(comment)"
                >
                  <template #icon><icon-edit /></template>
                  编辑
                </a-button>

                <a-button
                  v-if="canDeleteComment(comment)"
                  type="text"
                  size="small"
                  status="danger"
                  @click="handleDeleteComment(comment)"
                >
                  <template #icon><icon-delete /></template>
                  删除
                </a-button>
              </a-space>
            </div>

            <!-- 回复列表 -->
            <div v-if="comment.replies && comment.replies.length > 0" class="reply-list">
              <div
                v-for="reply in comment.replies"
                :key="reply.id"
                class="reply-item"
              >
                <div class="reply-avatar">
                  <a-avatar :size="28">
                    {{ reply.author.charAt(0).toUpperCase() }}
                  </a-avatar>
                </div>

                <div class="reply-content">
                  <div class="reply-meta">
                    <span class="reply-author">{{ reply.author }}</span>
                    <span class="reply-time">{{ formatTime(reply.created_at) }}</span>
                  </div>

                  <div class="reply-text" v-html="renderComment(reply.content)"></div>
                </div>
              </div>
            </div>

            <!-- 回复输入框 -->
            <div v-if="replyingTo === comment.id" class="reply-input">
              <a-textarea
                v-model="replyContent"
                :placeholder="`回复 @${comment.author}`"
                :auto-size="{ minRows: 2, maxRows: 4 }"
                :max-length="500"
                show-word-limit
              />
              <div class="reply-actions">
                <a-button size="small" @click="handleCancelReply">取消</a-button>
                <a-button
                  type="primary"
                  size="small"
                  :loading="submitting"
                  :disabled="!replyContent.trim()"
                  @click="handleSubmitReply(comment)"
                >
                  回复
                </a-button>
              </div>
            </div>
          </div>
        </div>
      </a-spin>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconAt,
  IconCode,
  IconHeart,
  IconHeartFill,
  IconMessage,
  IconEdit,
  IconDelete,
} from '@arco-design/web-vue/es/icon';
import { useRequirementPermission } from '@/composables/usePermission';

// ==================== Props ====================

interface Comment {
  id: number;
  author: string;
  content: string;
  created_at: number;
  likes?: number;
  liked?: boolean;
  replies?: Comment[];
}

interface Props {
  requirementId: number;
  comments: Comment[];
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

// ==================== Emits ====================

const emit = defineEmits<{
  addComment: [content: string];
  editComment: [id: number, content: string];
  deleteComment: [id: number];
  likeComment: [id: number];
  replyComment: [parentId: number, content: string];
  refresh: [];
}>();

// ==================== 权限 ====================

const permission = useRequirementPermission();

// ==================== 数据定义 ====================

const commentContent = ref('');
const replyContent = ref('');
const submitting = ref(false);
const sortOrder = ref<'asc' | 'desc'>('desc');
const replyingTo = ref<number | null>(null);

// ==================== 计算属性 ====================

const sortedComments = computed(() => {
  const sorted = [...props.comments];
  sorted.sort((a, b) => {
    return sortOrder.value === 'desc'
      ? b.created_at - a.created_at
      : a.created_at - b.created_at;
  });
  return sorted;
});

// ==================== 方法 ====================

/**
 * 格式化时间
 */
const formatTime = (timestamp: number): string => {
  const now = Date.now() / 1000;
  const diff = now - timestamp;

  if (diff < 60) {
    return '刚刚';
  } else if (diff < 3600) {
    return `${Math.floor(diff / 60)} 分钟前`;
  } else if (diff < 86400) {
    return `${Math.floor(diff / 3600)} 小时前`;
  } else if (diff < 604800) {
    return `${Math.floor(diff / 86400)} 天前`;
  } else {
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString('zh-CN');
  }
};

/**
 * 渲染评论内容
 */
const renderComment = (content: string): string => {
  // 处理 @提及
  let rendered = content.replace(/@(\w+)/g, '<span class="mention">@$1</span>');

  // 处理代码块
  rendered = rendered.replace(/`([^`]+)`/g, '<code>$1</code>');

  // 处理换行
  rendered = rendered.replace(/\n/g, '<br>');

  return rendered;
};

/**
 * 检查是否可以编辑评论
 */
const canEditComment = (comment: Comment): boolean => {
  return permission.isOwner(comment.author);
};

/**
 * 检查是否可以删除评论
 */
const canDeleteComment = (comment: Comment): boolean => {
  return permission.canDelete(comment.author);
};

/**
 * 插入提及
 */
const handleInsertMention = () => {
  commentContent.value += '@';
};

/**
 * 插入代码
 */
const handleInsertCode = () => {
  commentContent.value += '``';
};

/**
 * 键盘事件
 */
const handleKeydown = (e: KeyboardEvent) => {
  // Ctrl/Cmd + Enter 提交评论
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    handleSubmitComment();
  }
};

/**
 * 提交评论
 */
const handleSubmitComment = async () => {
  if (!commentContent.value.trim()) {
    Message.warning('请输入评论内容');
    return;
  }

  submitting.value = true;
  try {
    emit('addComment', commentContent.value);
    commentContent.value = '';
    Message.success('评论发表成功');
  } catch (error) {
    Message.error('评论发表失败');
    console.error(error);
  } finally {
    submitting.value = false;
  }
};

/**
 * 取消评论
 */
const handleCancelComment = () => {
  commentContent.value = '';
};

/**
 * 点赞评论
 */
const handleLikeComment = (comment: Comment) => {
  emit('likeComment', comment.id);
};

/**
 * 回复评论
 */
const handleReplyComment = (comment: Comment) => {
  replyingTo.value = comment.id;
  replyContent.value = '';
};

/**
 * 取消回复
 */
const handleCancelReply = () => {
  replyingTo.value = null;
  replyContent.value = '';
};

/**
 * 提交回复
 */
const handleSubmitReply = async (comment: Comment) => {
  if (!replyContent.value.trim()) {
    Message.warning('请输入回复内容');
    return;
  }

  submitting.value = true;
  try {
    emit('replyComment', comment.id, replyContent.value);
    replyingTo.value = null;
    replyContent.value = '';
    Message.success('回复成功');
  } catch (error) {
    Message.error('回复失败');
    console.error(error);
  } finally {
    submitting.value = false;
  }
};

/**
 * 编辑评论
 */
const handleEditComment = (comment: Comment) => {
  // TODO: 实现编辑功能
  Message.info('编辑功能开发中');
};

/**
 * 删除评论
 */
const handleDeleteComment = (comment: Comment) => {
  Modal.confirm({
    title: '确认删除',
    content: '确定要删除这条评论吗？此操作不可恢复。',
    onOk: () => {
      emit('deleteComment', comment.id);
    },
  });
};

/**
 * 排序变化
 */
const handleSortChange = () => {
  // 排序已通过计算属性自动更新
};
</script>

<style scoped lang="less">
.comment-section {
  .comment-input {
    margin-bottom: 24px;

    .input-actions {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 12px;
    }
  }

  .comment-list {
    .comment-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;

      .comment-count {
        font-weight: 500;
        color: var(--color-text-1);
      }
    }

    .empty-comments {
      padding: 40px 0;
    }

    .comment-item {
      display: flex;
      gap: 12px;
      padding: 16px 0;
      border-bottom: 1px solid var(--color-border-2);

      &:last-child {
        border-bottom: none;
      }

      .comment-avatar {
        flex-shrink: 0;
      }

      .comment-content {
        flex: 1;
        min-width: 0;

        .comment-meta {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-bottom: 8px;

          .comment-author {
            font-weight: 500;
            color: var(--color-text-1);
          }

          .comment-time {
            font-size: 12px;
            color: var(--color-text-3);
          }
        }

        .comment-text {
          line-height: 1.6;
          color: var(--color-text-2);
          word-break: break-word;

          :deep(.mention) {
            color: rgb(var(--primary-6));
            font-weight: 500;
          }

          :deep(code) {
            padding: 2px 6px;
            background: var(--color-fill-2);
            border-radius: 2px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
          }
        }

        .comment-actions {
          margin-top: 8px;
        }

        .reply-list {
          margin-top: 12px;
          padding-left: 12px;
          border-left: 2px solid var(--color-border-2);

          .reply-item {
            display: flex;
            gap: 8px;
            padding: 8px 0;

            .reply-avatar {
              flex-shrink: 0;
            }

            .reply-content {
              flex: 1;
              min-width: 0;

              .reply-meta {
                display: flex;
                align-items: center;
                gap: 8px;
                margin-bottom: 4px;

                .reply-author {
                  font-weight: 500;
                  font-size: 13px;
                  color: var(--color-text-1);
                }

                .reply-time {
                  font-size: 11px;
                  color: var(--color-text-3);
                }
              }

              .reply-text {
                font-size: 13px;
                line-height: 1.5;
                color: var(--color-text-2);
              }
            }
          }
        }

        .reply-input {
          margin-top: 12px;

          .reply-actions {
            display: flex;
            justify-content: flex-end;
            gap: 8px;
            margin-top: 8px;
          }
        }
      }
    }
  }
}
</style>
