<template>
  <div class="config-list">
    <a-list :data="configs" :pagination="false">
      <template #item="{ item }">
        <a-list-item class="config-item">
          <a-list-item-meta>
            <template #avatar>
              <div class="config-icon" :class="`type-${item.config_type}`">
                <icon-settings v-if="item.config_type === 'text'" />
                <icon-number v-else-if="item.config_type === 'number'" />
                <icon-file v-else-if="item.config_type === 'textarea'" />
                <icon-toggle v-else-if="item.config_type === 'switch'" />
                <icon-select v-else-if="item.config_type === 'select'" />
                <icon-check-circle v-else-if="item.config_type === 'radio'" />
                <icon-check-square
                  v-else-if="item.config_type === 'checkbox'"
                />
                <icon-image v-else-if="item.config_type === 'image'" />
                <icon-folder v-else-if="item.config_type === 'file'" />
                <icon-code v-else-if="item.config_type === 'json'" />
                <icon-list v-else-if="item.config_type === 'array'" />
                <icon-bg-colors v-else-if="item.config_type === 'color'" />
                <icon-calendar v-else-if="item.config_type === 'date'" />
                <icon-clock-circle
                  v-else-if="item.config_type === 'datetime'"
                />
                <icon-settings v-else />
              </div>
            </template>
            <template #title>
              <a-space>
                <span class="config-name">{{ item.config_name }}</span>
                <a-tag size="small" :color="getTypeColor(item.config_type)">
                  {{ getTypeText(item.config_type) }}
                </a-tag>
              </a-space>
            </template>
            <template #description>
              <div class="config-meta">
                <div class="config-key">
                  <icon-code-block />
                  {{ item.config_key }}
                </div>
                <div class="config-value">
                  <template v-if="item.config_type === 'image'">
                    <img
                      :src="item.config_value"
                      alt="preview"
                      class="value-image"
                    />
                  </template>
                  <template v-else-if="item.config_type === 'switch'">
                    <a-tag :color="item.config_value ? 'green' : 'gray'">
                      {{ item.config_value ? '开启' : '关闭' }}
                    </a-tag>
                  </template>
                  <template v-else-if="item.config_type === 'array'">
                    <a-space wrap>
                      <a-tag
                        v-for="(val, idx) in item.config_value"
                        :key="idx"
                        size="small"
                      >
                        {{ val }}
                      </a-tag>
                    </a-space>
                  </template>
                  <template v-else-if="item.config_type === 'json'">
                    <a-typography-text code>{{
                      formatJson(item.config_value)
                    }}</a-typography-text>
                  </template>
                  <template v-else-if="item.config_type === 'color'">
                    <a-space>
                      <div
                        class="color-preview"
                        :style="{ background: item.config_value }"
                      ></div>
                      <span>{{ item.config_value }}</span>
                    </a-space>
                  </template>
                  <template v-else>
                    <span class="value-text">{{ item.config_value }}</span>
                  </template>
                </div>
              </div>
            </template>
          </a-list-item-meta>
          <template #actions>
            <a-space>
              <a-switch
                :model-value="item.status === 1"
                size="small"
                @change="$emit('statusChange', item)"
              />
              <a-button size="mini" type="text" @click="$emit('edit', item)">
                <template #icon><icon-edit /></template>
              </a-button>
              <a-popconfirm
                content="确定要删除吗？"
                @ok="$emit('delete', item)"
              >
                <a-button size="mini" type="text" status="danger">
                  <template #icon><icon-delete /></template>
                </a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </a-list-item>
      </template>
    </a-list>

    <a-empty v-if="configs.length === 0" description="暂无配置" />
  </div>
</template>

<script setup lang="ts">
  interface Props {
    configs: any[];
  }

  defineProps<Props>();
  defineEmits(['edit', 'delete', 'statusChange']);

  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      text: 'blue',
      number: 'green',
      textarea: 'purple',
      switch: 'orange',
      select: 'cyan',
      radio: 'magenta',
      checkbox: 'lime',
      image: 'pink',
      file: 'gold',
      json: 'red',
      array: 'arcoblue',
      color: 'pinkpurple',
      date: 'orangered',
      datetime: 'blue',
    };
    return colors[type] || 'gray';
  };

  const getTypeText = (type: string) => {
    const texts: Record<string, string> = {
      text: '文本',
      number: '数字',
      textarea: '多行文本',
      switch: '开关',
      select: '下拉',
      radio: '单选',
      checkbox: '多选',
      image: '图片',
      file: '文件',
      json: 'JSON',
      array: '数组',
      color: '颜色',
      date: '日期',
      datetime: '日期时间',
    };
    return texts[type] || type;
  };

  const formatJson = (value: any) => {
    try {
      return typeof value === 'string' ? value : JSON.stringify(value);
    } catch {
      return value;
    }
  };
</script>

<style scoped lang="less">
  .config-list {
    :deep(.arco-list-item) {
      padding: 16px;
      border-bottom: 1px solid var(--color-border-1);
      transition: background 0.2s;

      &:hover {
        background: var(--color-fill-1);
      }
    }
  }

  .config-item {
    .config-icon {
      width: 40px;
      height: 40px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 20px;
      background: var(--color-fill-2);
      color: var(--color-text-2);

      &.type-text,
      &.type-textarea {
        background: #e6f7ff;
        color: #1890ff;
      }

      &.type-number {
        background: #f6ffed;
        color: #52c41a;
      }

      &.type-switch {
        background: #fff7e6;
        color: #fa8c16;
      }

      &.type-image {
        background: #fff0f6;
        color: #eb2f96;
      }

      &.type-json,
      &.type-array {
        background: #fff1f0;
        color: #f5222d;
      }
    }

    .config-name {
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    .config-meta {
      display: flex;
      flex-direction: column;
      gap: 8px;
      margin-top: 4px;
    }

    .config-key {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      color: var(--color-text-3);
      font-family: 'Monaco', 'Courier New', monospace;
    }

    .config-value {
      font-size: 12px;
      color: var(--color-text-2);

      .value-text {
        max-width: 400px;
        display: inline-block;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .value-image {
        width: 60px;
        height: 60px;
        object-fit: cover;
        border-radius: 4px;
        border: 1px solid var(--color-border);
      }

      .color-preview {
        width: 20px;
        height: 20px;
        border-radius: 4px;
        border: 1px solid var(--color-border);
      }
    }
  }
</style>
