<template>
  <div class="comment-section">
    <!-- 评论列表 -->
    <div class="comment-list">
      <a-empty v-if="comments.length === 0" description="暂无评论" />
      
      <div v-else class="comment-items">
        <div
          v-for="comment in comments"
          :key="comment.id"
          class="comment-item"
        >
          <!-- 评论头部 -->
          <div class="comment-header">
            <a-avatar :size="32">
              {{ comment.author.charAt(0) }}
            </a-avatar>
            <div class="comment-info">
              <div class="comment-author">{{ comment.author }}</div>
              <div class="comment-time">{{ formatTime(comment.created_at) }}</div>
            </div>
            <div class="comment-actions">
              <a-button
                type="text"
                size="small"
                @click="handleReply(comment)"
              >
                <template #icon><icon-message /></template>
                回复
              </a-button>
              <a-button
                v-if="canEdit(comment)"
                type="text"
                size="small"
                @click="handleEdit(comment)"
              >
                <template #icon><icon-edit /></template>
                编辑
              </a-button>
              <a-button
                v-if="canDelete(comment)"
                type="text"
                size="small"
                status="danger"
                @click="handleDelete(comment)"
              >
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </div>
          </div>
          
          <!-- 评论内容 -->
          <div class="comment-content" v-html="renderContent(comment.content)"></div>
          
          <!-- 附件 -->
          <div v-if="comment.attachments && comment.attachments.length > 0" class="comment-attachments">
            <a-space wrap>
              <a-tag
                v-for="attachment in comment.attachments"
                :key="attachment.url"
                color="blue"
                @click="handleDownloadAttachment(attachment)"
              >
                <template #icon><icon-file /></template>
                {{ attachment.name }}
              </a-tag>
            </a-space>
          </div>
          
          <!-- 回复列表 -->
          <div v-if="comment.replies && comment.replies.length > 0" class="comment-replies">
            <div
              v-for="reply in comment.replies"
              :key="reply.id"
              class="reply-item"
            >
              <div class="reply-header">
                <a-avatar :size="24">
                  {{ reply.author.charAt(0) }}
                </a-avatar>
                <div class="reply-info">
                  <span class="reply-author">{{ reply.author }}</span>
                  <span v-if="reply.reply_to" class="reply-to">
                    回复 <span class="reply-to-name">@{{ reply.reply_to }}</span>
                  </span>
                  <span class="reply-time">{{ formatTime(reply.created_at) }}</span>
                </div>
              </div>
              <div class="reply-content" v-html="renderContent(reply.content)"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 评论输入框 -->
    <div class="comment-input">
      <a-card :bordered="false">
        <template #title>
          <span v-if="replyTo">回复 @{{ replyTo.author }}</span>
          <span v-else-if="editingComment">编辑评论</span>
          <span v-else>添加评论</span>
        </template>
        
        <template #extra>
          <a-button
            v-if="replyTo || editingComment"
            type="text"
            size="small"
            @click="handleCancel"
          >
            取消
          </a-button>
        </template>
        
        <MentionInput
          v-model="commentContent"
          placeholder="输入评论内容，使用 @ 提及用户..."
          :auto-size="{ minRows: 3, maxRows: 8 }"
          :max-length="1000"
          :show-word-limit="true"
          @mention="handleMention"
        />
        
        <div class="comment-toolbar">
          <a-space>
            <AttachmentUpload
              v-model="attachments"
              :limit="5"
              :max-size="10"
              button-text="添加附件"
            />
            
            <a-button
              type="primary"
              :loading="submitting"
              :disabled="!commentContent.trim()"
              @click="handleSubmit"
            >
              {{ editingComment ? '保存' : '发表评论' }}
            </a-button>
          </a-space>
        </div>
      </a-card>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import MentionInput from './MentionInput.vue';
import AttachmentUpload from '@/components/upload/AttachmentUpload.vue';
import type { FileItem } from '@arco-design/web-vue';
import { formatDateTime } from '@/utils/date';

interface Attachment {
  name: string;
  url: string;
  size: number;
}

interface Comment {
  id: number;
  author: string;
  content: string;
  created_at: number;
  attachments?: Attachment[];
  replies?: Reply[];
}

interface Reply {
  id: number;
  author: string;
  reply_to?: string;
  content: string;
  created_at: number;
}

interface Props {
  comments: Comment[];
  currentUser?: string;
}

const props = withDefaults(defineProps<Props>(), {
  currentUser: '当前用户',
});

const emit = defineEmits<{
  add: [comment: { content: string; attachments: Attachment[] }];
  reply: [commentId: number, reply: { content: string; reply_to?: string }];
  edit: [commentId: number, content: string];
  delete: [commentId: number];
}>();

const commentContent = ref('');
const attachments = ref<FileItem[]>([]);
const submitting = ref(false);
const replyTo = ref<Comment | null>(null);
const editingComment = ref<Comment | null>(null);
const mentionedUsers = ref<string[]>([]);

// 格式化时间
const formatTime = (timestamp: number) => {
  return formatDateTime(timestamp);
};

// 渲染内容（处理 @提及）
const renderContent = (content: string) => {
  // 将 @用户名 高亮显示
  return content.replace(
    /@(\S+)/g,
    '<span class="mention">@$1</span>'
  );
};

// 是否可以编辑
const canEdit = (comment: Comment) => {
  return comment.author === props.currentUser;
};

// 是否可以删除
const canDelete = (comment: Comment) => {
  return comment.author === props.currentUser;
};

// 处理回复
const handleReply = (comment: Comment) => {
  replyTo.value = comment;
  editingComment.value = null;
  commentContent.value = '';
  attachments.value = [];
};

// 处理编辑
const handleEdit = (comment: Comment) => {
  editingComment.value = comment;
  replyTo.value = null;
  commentContent.value = comment.content;
  attachments.value = [];
};

// 处理删除
const handleDelete = (comment: Comment) => {
  emit('delete', comment.id);
};

// 处理取消
const handleCancel = () => {
  replyTo.value = null;
  editingComment.value = null;
  commentContent.value = '';
  attachments.value = [];
  mentionedUsers.value = [];
};

// 处理提及
const handleMention = (user: { id: number; name: string }) => {
  if (!mentionedUsers.value.includes(user.name)) {
    mentionedUsers.value.push(user.name);
  }
};

// 处理提交
const handleSubmit = async () => {
  if (!commentContent.value.trim()) {
    Message.warning('请输入评论内容');
    return;
  }
  
  submitting.value = true;
  
  try {
    if (editingComment.value) {
      // 编辑评论
      emit('edit', editingComment.value.id, commentContent.value);
      Message.success('评论已更新');
    } else if (replyTo.value) {
      // 回复评论
      emit('reply', replyTo.value.id, {
        content: commentContent.value,
        reply_to: replyTo.value.author,
      });
      Message.success('回复已发表');
    } else {
      // 新增评论
      emit('add', {
        content: commentContent.value,
        attachments: attachments.value.map((file) => ({
          name: file.name,
          url: file.url || '',
          size: file.file?.size || 0,
        })),
      });
      Message.success('评论已发表');
    }
    
    handleCancel();
  } catch (error: any) {
    Message.error(error?.message || '操作失败');
  } finally {
    submitting.value = false;
  }
};

// 下载附件
const handleDownloadAttachment = (attachment: Attachment) => {
  window.open(attachment.url, '_blank');
};
</script>

<style scoped lang="less">
.comment-section {
  .comment-list {
    margin-bottom: 24px;
    
    .comment-items {
      .comment-item {
        padding: 16px;
        border-bottom: 1px solid var(--color-border-2);
        
        &:last-child {
          border-bottom: none;
        }
        
        .comment-header {
          display: flex;
          align-items: center;
          margin-bottom: 12px;
          
          .comment-info {
            flex: 1;
            margin-left: 12px;
            
            .comment-author {
              font-size: 14px;
              font-weight: 500;
              color: var(--color-text-1);
            }
            
            .comment-time {
              font-size: 12px;
              color: var(--color-text-3);
              margin-top: 2px;
            }
          }
          
          .comment-actions {
            display: flex;
            gap: 4px;
          }
        }
        
        .comment-content {
          font-size: 14px;
          line-height: 1.6;
          color: var(--color-text-2);
          margin-bottom: 12px;
          white-space: pre-wrap;
          word-break: break-word;
          
          :deep(.mention) {
            color: var(--color-primary-6);
            font-weight: 500;
          }
        }
        
        .comment-attachments {
          margin-bottom: 12px;
          
          :deep(.arco-tag) {
            cursor: pointer;
            
            &:hover {
              opacity: 0.8;
            }
          }
        }
        
        .comment-replies {
          margin-top: 12px;
          padding-left: 44px;
          
          .reply-item {
            padding: 12px;
            background: var(--color-fill-1);
            border-radius: 4px;
            margin-bottom: 8px;
            
            &:last-child {
              margin-bottom: 0;
            }
            
            .reply-header {
              display: flex;
              align-items: center;
              margin-bottom: 8px;
              
              .reply-info {
                margin-left: 8px;
                font-size: 12px;
                
                .reply-author {
                  font-weight: 500;
                  color: var(--color-text-1);
                }
                
                .reply-to {
                  color: var(--color-text-3);
                  margin: 0 4px;
                  
                  .reply-to-name {
                    color: var(--color-primary-6);
                    font-weight: 500;
                  }
                }
                
                .reply-time {
                  color: var(--color-text-3);
                }
              }
            }
            
            .reply-content {
              font-size: 13px;
              line-height: 1.6;
              color: var(--color-text-2);
              white-space: pre-wrap;
              word-break: break-word;
              
              :deep(.mention) {
                color: var(--color-primary-6);
                font-weight: 500;
              }
            }
          }
        }
      }
    }
  }
  
  .comment-input {
    .comment-toolbar {
      margin-top: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
  }
}
</style>
