<template>
  <div class="container">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon blue">
              <icon-notification />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ notifications.length }}</div>
              <div class="stat-label">通知总数</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon red">
              <icon-exclamation-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ unreadCount }}</div>
              <div class="stat-label">未读通知</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon green">
              <icon-check-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ notifications.length - unreadCount }}</div>
              <div class="stat-label">已读通知</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon orange">
              <icon-clock-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ todayCount }}</div>
              <div class="stat-label">今日通知</div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 通知列表 -->
    <a-card class="notification-card" :bordered="false">
      <template #title>
        <div class="card-header">
          <div class="header-title">
            <icon-notification class="header-icon" />
            <span>通知中心</span>
            <a-tag color="arcoblue" size="small">{{ notifications.length }}条</a-tag>
          </div>
        </div>
      </template>

      <template #extra>
        <a-space>
          <a-input-search
            v-model="searchKey"
            placeholder="搜索通知内容..."
            size="small"
            style="width: 220px"
            allow-clear
          />
          <a-button
            size="small"
            :disabled="unreadCount === 0"
            @click="markAllRead"
          >
            <icon-check /> 全部已读
          </a-button>
          <a-button
            size="small"
            status="danger"
            :disabled="notifications.length === 0"
            @click="clearAll"
          >
            <icon-delete /> 清空通知
          </a-button>
        </a-space>
      </template>

      <!-- 类型筛选 -->
      <div class="filter-bar">
        <a-radio-group v-model="filterType" type="button" size="small">
          <a-radio value="all">
            <icon-apps /> 全部
          </a-radio>
          <a-radio value="unread">
            <icon-exclamation-circle /> 未读
            <a-badge v-if="unreadCount > 0" :count="unreadCount" :offset="[8, -5]" />
          </a-radio>
          <a-radio value="info">
            <icon-info-circle /> 信息
          </a-radio>
          <a-radio value="success">
            <icon-check-circle /> 成功
          </a-radio>
          <a-radio value="warning">
            <icon-exclamation-circle /> 警告
          </a-radio>
          <a-radio value="error">
            <icon-close-circle /> 错误
          </a-radio>
        </a-radio-group>
      </div>

      <!-- 通知列表 -->
      <a-list
        :data="displayList"
        :pagination="pagination"
        class="notification-list"
      >
        <template #item="{ item }">
          <a-list-item
            :class="['notification-item', { unread: !item.read }]"
            @click="handleItemClick(item)"
          >
            <div class="notification-main">
              <div class="notification-avatar">
                <a-avatar :style="getAvatarStyle(item.type)" :size="40">
                  <icon-info-circle v-if="item.type === 'info'" />
                  <icon-check-circle v-if="item.type === 'success'" />
                  <icon-exclamation-circle v-if="item.type === 'warning'" />
                  <icon-close-circle v-if="item.type === 'error'" />
                </a-avatar>
                <div v-if="!item.read" class="unread-dot"></div>
              </div>

              <div class="notification-body">
                <div class="notification-title-row">
                  <span class="notification-title" :class="{ bold: !item.read }">
                    {{ item.title }}
                  </span>
                  <a-tag
                    v-if="!item.read"
                    color="red"
                    size="small"
                    class="unread-tag"
                  >未读</a-tag>
                  <a-tag
                    :color="getTypeColor(item.type)"
                    size="small"
                    class="type-tag"
                  >
                    {{ getTypeLabel(item.type) }}
                  </a-tag>
                </div>
                <div class="notification-content">{{ item.content }}</div>
                <div class="notification-meta">
                  <span class="notification-time">
                    <icon-clock-circle /> {{ formatTime(item.created_at) }}
                  </span>
                  <span v-if="item.link" class="notification-link">
                    <icon-link /> 可跳转
                  </span>
                </div>
              </div>
            </div>

            <template #actions>
              <a-space>
                <a-button
                  v-if="!item.read"
                  size="small"
                  type="text"
                  @click.stop="markRead(item)"
                >
                  <icon-check /> 已读
                </a-button>
                <a-button
                  size="small"
                  type="text"
                  status="danger"
                  @click.stop="deleteItem(item)"
                >
                  <icon-delete /> 删除
                </a-button>
              </a-space>
            </template>
          </a-list-item>
        </template>

        <template #empty>
          <a-empty description="暂无通知" />
        </template>
      </a-list>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message, Modal } from '@arco-design/web-vue';

  interface Notification {
    id: number;
    type: 'info' | 'success' | 'warning' | 'error';
    title: string;
    content: string;
    read: boolean;
    link?: string;
    created_at: string;
  }

  const router = useRouter();
  const filterType = ref('all');
  const searchKey = ref('');

  const notifications = ref<Notification[]>([
    {
      id: 1,
      type: 'info',
      title: '系统更新通知',
      content: '系统将于今晚 22:00 进行维护升级，预计持续 2 小时',
      read: false,
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      type: 'success',
      title: '订单处理提醒',
      content: '您有 5 个新订单待处理，请及时查看',
      read: false,
      link: '/business/order',
      created_at: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 3,
      type: 'warning',
      title: '库存预警',
      content: '商品 "iPhone 15 Pro" 库存不足 10 件，请及时补货',
      read: true,
      link: '/business/warehouse',
      created_at: new Date(Date.now() - 7200000).toISOString(),
    },
    {
      id: 4,
      type: 'error',
      title: '支付异常',
      content: '订单 #12345 支付失败，请联系客户处理',
      read: true,
      link: '/business/order',
      created_at: new Date(Date.now() - 86400000).toISOString(),
    },
    {
      id: 5,
      type: 'success',
      title: '会员注册成功',
      content: '新用户 "张三" 注册成功，请及时跟进',
      read: false,
      created_at: new Date(Date.now() - 1800000).toISOString(),
    },
    {
      id: 6,
      type: 'info',
      title: '活动提醒',
      content: '双11促销活动将于明天开始，请做好准备',
      read: false,
      created_at: new Date(Date.now() - 7200000).toISOString(),
    },
  ]);

  const pagination = {
    pageSize: 10,
    showTotal: true,
    showJumper: true,
  };

  const unreadCount = computed(
    () => notifications.value.filter((n) => !n.read).length
  );

  const todayCount = computed(() => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return notifications.value.filter(
      (n) => new Date(n.created_at).getTime() >= today.getTime()
    ).length;
  });

  const displayList = computed(() => {
    let list = notifications.value;

    // 类型筛选
    if (filterType.value === 'unread') {
      list = list.filter((n) => !n.read);
    } else if (filterType.value !== 'all') {
      list = list.filter((n) => n.type === filterType.value);
    }

    // 搜索筛选
    if (searchKey.value) {
      const key = searchKey.value.toLowerCase();
      list = list.filter(
        (n) =>
          n.title.toLowerCase().includes(key) ||
          n.content.toLowerCase().includes(key)
      );
    }

    return list;
  });

  const formatTime = (time: string) => {
    const now = Date.now();
    const diff = now - new Date(time).getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return '刚刚';
    if (minutes < 60) return `${minutes} 分钟前`;
    if (hours < 24) return `${hours} 小时前`;
    if (days < 7) return `${days} 天前`;
    return new Date(time).toLocaleDateString();
  };

  const getAvatarStyle = (type: string) => {
    const styles: Record<string, any> = {
      info: {
        background: 'linear-gradient(135deg, #e6f4ff 0%, #bae0ff 100%)',
        color: '#1677ff',
      },
      success: {
        background: 'linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%)',
        color: '#52c41a',
      },
      warning: {
        background: 'linear-gradient(135deg, #fffbe6 0%, #ffe58f 100%)',
        color: '#faad14',
      },
      error: {
        background: 'linear-gradient(135deg, #fff2f0 0%, #ffccc7 100%)',
        color: '#ff4d4f',
      },
    };
    return styles[type] || styles.info;
  };

  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      info: 'arcoblue',
      success: 'green',
      warning: 'orange',
      error: 'red',
    };
    return colors[type] || 'arcoblue';
  };

  const getTypeLabel = (type: string) => {
    const labels: Record<string, string> = {
      info: '信息',
      success: '成功',
      warning: '警告',
      error: '错误',
    };
    return labels[type] || '信息';
  };

  const handleItemClick = (item: Notification) => {
    item.read = true;
    if (item.link) {
      router.push(item.link);
    }
  };

  const markRead = (item: Notification) => {
    item.read = true;
    Message.success('已标记为已读');
  };

  const markAllRead = () => {
    Modal.confirm({
      title: '确认操作',
      content: `确定要将 ${unreadCount.value} 条未读通知全部标记为已读吗？`,
      onOk: () => {
        notifications.value.forEach((n) => {
          n.read = true;
        });
        Message.success('已全部标记为已读');
      },
    });
  };

  const deleteItem = (item: Notification) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这条通知吗？',
      onOk: () => {
        const index = notifications.value.findIndex((n) => n.id === item.id);
        if (index > -1) {
          notifications.value.splice(index, 1);
          Message.success('删除成功');
        }
      },
    });
  };

  const clearAll = () => {
    Modal.confirm({
      title: '确认清空',
      content: '确定要清空所有通知吗？此操作不可恢复。',
      onOk: () => {
        notifications.value = [];
        Message.success('已清空所有通知');
      },
    });
  };
</script>

<style scoped lang="less">
  .container {
    padding: 20px;
  }

  .stat-row {
    margin-bottom: 20px;
  }

  .stat-card {
    border-radius: 8px;
    background: var(--color-bg-2);

    :deep(.arco-card-body) {
      padding: 16px;
    }
  }

  .stat-content {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;

    &.blue {
      background: linear-gradient(135deg, #e6f4ff 0%, #bae0ff 100%);
      color: #1677ff;
    }

    &.red {
      background: linear-gradient(135deg, #fff2f0 0%, #ffccc7 100%);
      color: #ff4d4f;
    }

    &.green {
      background: linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%);
      color: #52c41a;
    }

    &.orange {
      background: linear-gradient(135deg, #fff7e6 0%, #ffd591 100%);
      color: #fa8c16;
    }
  }

  .stat-info {
    flex: 1;
  }

  .stat-value {
    font-size: 24px;
    font-weight: 600;
    color: var(--color-text-1);
    line-height: 1.2;
  }

  .stat-label {
    font-size: 13px;
    color: var(--color-text-3);
    margin-top: 4px;
  }

  .notification-card {
    border-radius: 8px;

    :deep(.arco-card-header) {
      padding: 16px 20px;
      border-bottom: 1px solid var(--color-border-2);
    }

    :deep(.arco-card-body) {
      padding: 0;
    }
  }

  .card-header {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .header-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 16px;
    font-weight: 600;
    color: var(--color-text-1);

    .header-icon {
      font-size: 20px;
      color: rgb(var(--arcoblue-6));
    }
  }

  .filter-bar {
    padding: 16px 20px;
    border-bottom: 1px solid var(--color-border-2);
    background: var(--color-fill-1);
  }

  .notification-list {
    :deep(.arco-list-content) {
      padding: 0;
    }

    :deep(.arco-list-item) {
      padding: 16px 20px;
      cursor: pointer;
      transition: all 0.2s;
      border-bottom: 1px solid var(--color-border-2);

      &:hover {
        background: var(--color-fill-2);
      }

      &:last-child {
        border-bottom: none;
      }
    }

    :deep(.arco-list-item-action) {
      opacity: 0;
      transition: opacity 0.2s;
    }

    :deep(.arco-list-item:hover .arco-list-item-action) {
      opacity: 1;
    }
  }

  .notification-item {
    &.unread {
      background: rgba(var(--arcoblue-1), 0.3);
    }
  }

  .notification-main {
    display: flex;
    gap: 16px;
    flex: 1;
  }

  .notification-avatar {
    position: relative;
    flex-shrink: 0;

    .unread-dot {
      position: absolute;
      top: 0;
      right: 0;
      width: 10px;
      height: 10px;
      background: #ff4d4f;
      border-radius: 50%;
      border: 2px solid #fff;
    }
  }

  .notification-body {
    flex: 1;
    min-width: 0;
  }

  .notification-title-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }

  .notification-title {
    font-size: 15px;
    color: var(--color-text-1);

    &.bold {
      font-weight: 600;
    }
  }

  .unread-tag {
    flex-shrink: 0;
  }

  .type-tag {
    flex-shrink: 0;
  }

  .notification-content {
    font-size: 14px;
    color: var(--color-text-2);
    line-height: 1.6;
    margin-bottom: 8px;
  }

  .notification-meta {
    display: flex;
    align-items: center;
    gap: 16px;
    font-size: 12px;
    color: var(--color-text-3);

    .notification-time,
    .notification-link {
      display: flex;
      align-items: center;
      gap: 4px;
    }

    .notification-link {
      color: rgb(var(--arcoblue-6));
    }
  }

  :deep(.arco-empty) {
    padding: 60px 0;
  }
</style>
