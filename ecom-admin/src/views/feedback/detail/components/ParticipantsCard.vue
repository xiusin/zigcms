<template>
  <div class="participants-card">
    <div class="card-header">
      <div class="card-title">
        <icon-team />
        参与者
      </div>
      <a-badge :count="totalParticipants" :max-count="99" />
    </div>

    <div class="card-body">
      <!-- 创建者 -->
      <div class="participant-section">
        <div class="section-label">
          <icon-user-add />
          创建者
        </div>
        <div class="participant-item creator">
          <a-avatar :size="36" :src="creator.avatar">
            <template #default>{{ creator.name?.charAt(0) }}</template>
          </a-avatar>
          <div class="participant-info">
            <div class="participant-name">{{ creator.name }}</div>
            <div class="participant-role">反馈提交人</div>
          </div>
          <a-tag size="small" color="blue">创建</a-tag>
        </div>
      </div>

      <!-- 指派者 -->
      <div v-if="assignee" class="participant-section">
        <div class="section-label">
          <icon-user />
          处理人
        </div>
        <div class="participant-item assignee">
          <a-avatar :size="36" :src="assignee.avatar">
            <template #default>{{ assignee.name?.charAt(0) }}</template>
          </a-avatar>
          <div class="participant-info">
            <div class="participant-name">{{ assignee.name }}</div>
            <div class="participant-role">负责处理</div>
          </div>
          <a-tag size="small" color="orange">指派</a-tag>
        </div>
      </div>

      <!-- 评论者 -->
      <div v-if="participants.length > 0" class="participant-section">
        <div class="section-label">
          <icon-message />
          评论者
          <span class="participant-count">({{ participants.length }})</span>
        </div>
        <div class="participants-list">
          <a-tooltip
            v-for="participant in displayedParticipants"
            :key="participant.id"
            :content="participant.name"
            position="top"
          >
            <a-avatar
              :size="32"
              :src="participant.avatar"
              class="participant-avatar"
            >
              <template #default>{{ participant.name?.charAt(0) }}</template>
            </a-avatar>
          </a-tooltip>
          <a-avatar
            v-if="remainingCount > 0"
            :size="32"
            style="background-color: var(--color-fill-3); color: var(--color-text-2)"
            class="participant-avatar more"
          >
            +{{ remainingCount }}
          </a-avatar>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  IconTeam,
  IconUserAdd,
  IconUser,
  IconMessage,
} from '@arco-design/web-vue/es/icon';

interface Participant {
  id: number;
  name: string;
  avatar?: string;
}

interface Props {
  creator: Participant;
  assignee?: Participant;
  participants: Participant[];
}

const props = defineProps<Props>();

// 总参与者数
const totalParticipants = computed(() => {
  let count = 1; // 创建者
  if (props.assignee) count++;
  count += props.participants.length;
  return count;
});

// 显示的前8个评论者
const displayedParticipants = computed(() => {
  return props.participants.slice(0, 8);
});

// 剩余评论者数量
const remainingCount = computed(() => {
  return Math.max(0, props.participants.length - 8);
});
</script>

<style scoped lang="less">
.participants-card {
  background: var(--color-bg-2);
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--color-border-2);

    .card-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 15px;
      font-weight: 600;
      color: var(--color-text-1);
    }
  }

  .card-body {
    display: flex;
    flex-direction: column;
    gap: 16px;

    .participant-section {
      .section-label {
        display: flex;
        align-items: center;
        gap: 6px;
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 10px;

        .participant-count {
          color: var(--color-text-2);
        }
      }

      .participant-item {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 10px 12px;
        background: var(--color-fill-1);
        border-radius: 8px;

        &.creator {
          border-left: 3px solid var(--color-primary);
        }

        &.assignee {
          border-left: 3px solid var(--color-warning);
        }

        .participant-info {
          flex: 1;

          .participant-name {
            font-size: 14px;
            font-weight: 500;
            color: var(--color-text-1);
            margin-bottom: 2px;
          }

          .participant-role {
            font-size: 12px;
            color: var(--color-text-3);
          }
        }
      }

      .participants-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        padding: 10px 12px;
        background: var(--color-fill-1);
        border-radius: 8px;

        .participant-avatar {
          cursor: pointer;
          transition: transform 0.2s;

          &:hover {
            transform: scale(1.1);
          }

          &.more {
            font-size: 12px;
            font-weight: 500;
          }
        }
      }
    }
  }
}
</style>
