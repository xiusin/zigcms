<template>
  <a-timeline>
    <a-timeline-item
      v-for="(followUp, index) in followUps"
      :key="index"
      :label="formatDateTime(followUp.created_at)"
    >
      <template #dot>
        <div class="timeline-dot">
          <icon-user />
        </div>
      </template>

      <div class="timeline-content">
        <div class="timeline-header">
          <span class="follower-name">{{ followUp.follower }}</span>
          <span class="follow-time">{{ formatTime(followUp.created_at) }}</span>
        </div>

        <div class="timeline-body">
          <div v-html="renderContent(followUp.content)" class="content-html" />
        </div>
      </div>
    </a-timeline-item>
  </a-timeline>
</template>

<script setup lang="ts">
import { marked } from 'marked';
import DOMPurify from 'dompurify';
import { formatDateTime, formatTime } from '@/utils/date';

interface FollowUp {
  follower: string;
  content: string;
  created_at: string | number;
}

interface Props {
  followUps: FollowUp[];
}

defineProps<Props>();

// 渲染 Markdown 内容
const renderContent = (content: string) => {
  // 配置 marked
  marked.setOptions({
    breaks: true,
    gfm: true,
  });

  // 转换 Markdown 为 HTML
  const html = marked(content);

  // 使用 DOMPurify 清理 HTML，防止 XSS 攻击
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: [
      'p',
      'br',
      'strong',
      'em',
      'u',
      'a',
      'ul',
      'ol',
      'li',
      'blockquote',
      'code',
      'pre',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'img',
    ],
    ALLOWED_ATTR: ['href', 'src', 'alt', 'title', 'class'],
  });
};
</script>

<style scoped lang="less">
.timeline-dot {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  background-color: var(--color-primary-light-1);
  border-radius: 50%;
  color: var(--color-primary);
}

.timeline-content {
  .timeline-header {
    display: flex;
    align-items: center;
    margin-bottom: 8px;

    .follower-name {
      font-size: 14px;
      font-weight: 600;
      color: var(--color-text-1);
      margin-right: 12px;
    }

    .follow-time {
      font-size: 12px;
      color: var(--color-text-3);
    }
  }

  .timeline-body {
    .content-html {
      font-size: 14px;
      line-height: 1.6;
      color: var(--color-text-2);

      :deep(p) {
        margin: 0 0 8px 0;

        &:last-child {
          margin-bottom: 0;
        }
      }

      :deep(a) {
        color: var(--color-primary);
        text-decoration: none;

        &:hover {
          text-decoration: underline;
        }
      }

      :deep(img) {
        max-width: 100%;
        border-radius: 4px;
        margin: 8px 0;
      }

      :deep(code) {
        padding: 2px 6px;
        background-color: var(--color-fill-2);
        border-radius: 2px;
        font-family: 'Courier New', monospace;
        font-size: 13px;
      }

      :deep(pre) {
        padding: 12px;
        background-color: var(--color-fill-2);
        border-radius: 4px;
        overflow-x: auto;
        margin: 8px 0;

        code {
          padding: 0;
          background-color: transparent;
        }
      }

      :deep(blockquote) {
        margin: 8px 0;
        padding-left: 12px;
        border-left: 3px solid var(--color-border-2);
        color: var(--color-text-3);
      }

      :deep(ul),
      :deep(ol) {
        margin: 8px 0;
        padding-left: 24px;
      }

      :deep(li) {
        margin-bottom: 4px;
      }

      :deep(h1),
      :deep(h2),
      :deep(h3),
      :deep(h4),
      :deep(h5),
      :deep(h6) {
        margin: 12px 0 8px 0;
        font-weight: 600;
        color: var(--color-text-1);
      }

      :deep(h1) {
        font-size: 20px;
      }

      :deep(h2) {
        font-size: 18px;
      }

      :deep(h3) {
        font-size: 16px;
      }

      :deep(h4),
      :deep(h5),
      :deep(h6) {
        font-size: 14px;
      }
    }
  }
}
</style>
