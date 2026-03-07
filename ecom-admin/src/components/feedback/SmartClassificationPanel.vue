<template>
  <div class="smart-classification-panel">
    <!-- AI分类结果 -->
    <a-card v-if="classificationResult" title="AI分类结果" :bordered="false" class="classification-card">
      <a-descriptions :column="2" bordered>
        <a-descriptions-item label="反馈类型">
          <a-tag :color="getTypeColor(classificationResult.type)">
            {{ getTypeText(classificationResult.type) }}
          </a-tag>
        </a-descriptions-item>

        <a-descriptions-item label="严重程度">
          <a-tag :color="getSeverityColor(classificationResult.severity)">
            {{ getSeverityText(classificationResult.severity) }}
          </a-tag>
        </a-descriptions-item>

        <a-descriptions-item label="置信度">
          <a-progress
            :percent="classificationResult.confidence"
            :stroke-width="8"
            size="small"
          />
        </a-descriptions-item>

        <a-descriptions-item label="优先级">
          <a-rate
            :model-value="classificationResult.priority"
            readonly
            :count="5"
          />
        </a-descriptions-item>

        <a-descriptions-item label="分类">
          <a-tag color="blue">{{ classificationResult.category }}</a-tag>
        </a-descriptions-item>

        <a-descriptions-item label="预计处理时间">
          {{ classificationResult.estimatedTime }} 小时
        </a-descriptions-item>

        <a-descriptions-item label="建议处理人" :span="2">
          <a-tag v-if="classificationResult.suggestedAssignee" color="purple">
            {{ classificationResult.suggestedAssignee }}
          </a-tag>
          <span v-else class="text-placeholder">未推荐</span>
        </a-descriptions-item>

        <a-descriptions-item label="推荐标签" :span="2">
          <a-space wrap>
            <a-tag
              v-for="tag in classificationResult.tags"
              :key="tag"
              color="orange"
            >
              {{ tag }}
            </a-tag>
          </a-space>
        </a-descriptions-item>
      </a-descriptions>

      <div class="actions">
        <a-space>
          <a-button type="primary" @click="handleApplyClassification">
            应用分类结果
          </a-button>
          <a-button @click="handleReClassify">
            重新分类
          </a-button>
        </a-space>
      </div>
    </a-card>

    <!-- 智能标签推荐 -->
    <a-card v-if="tagSuggestions.length > 0" title="智能标签推荐" :bordered="false" class="tags-card">
      <a-list :data="tagSuggestions" size="small">
        <template #item="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #title>
                <a-space>
                  <a-tag color="blue">{{ item.tag }}</a-tag>
                  <a-progress
                    :percent="item.confidence"
                    :stroke-width="6"
                    :show-text="false"
                    size="small"
                    style="width: 100px"
                  />
                  <span class="confidence-text">{{ item.confidence }}%</span>
                </a-space>
              </template>
              <template #description>
                {{ item.reason }}
              </template>
            </a-list-item-meta>
            <template #actions>
              <a-button type="text" size="small" @click="handleAddTag(item.tag)">
                添加
              </a-button>
            </template>
          </a-list-item>
        </template>
      </a-list>
    </a-card>

    <!-- 相似反馈推荐 -->
    <a-card v-if="similarFeedbacks.length > 0" title="相似反馈" :bordered="false" class="similar-card">
      <template #extra>
        <a-tag color="green">找到 {{ similarFeedbacks.length }} 条相似反馈</a-tag>
      </template>

      <a-list :data="similarFeedbacks" size="small">
        <template #item="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #title>
                <a-space>
                  <a-link @click="handleViewSimilar(item.id)">
                    {{ item.title }}
                  </a-link>
                  <a-tag :color="getStatusColor(item.status)">
                    {{ getStatusText(item.status) }}
                  </a-tag>
                </a-space>
              </template>
              <template #description>
                <div class="similar-info">
                  <div class="similarity">
                    <span class="label">相似度:</span>
                    <a-progress
                      :percent="item.similarity"
                      :stroke-width="6"
                      size="small"
                      style="width: 100px"
                    />
                    <span class="value">{{ item.similarity }}%</span>
                  </div>
                  <div v-if="item.resolution" class="resolution">
                    <span class="label">解决方案:</span>
                    <span class="value">{{ item.resolution }}</span>
                  </div>
                </div>
              </template>
            </a-list-item-meta>
            <template #actions>
              <a-button type="text" size="small" @click="handleReferSolution(item)">
                参考方案
              </a-button>
            </template>
          </a-list-item>
        </template>
      </a-list>
    </a-card>

    <!-- 分类准确率统计 -->
    <a-card title="分类准确率" :bordered="false" class="accuracy-card">
      <a-statistic
        title="总分类数"
        :value="accuracy.total"
        :value-style="{ color: '#165dff' }"
      />
      <a-statistic
        title="正确分类数"
        :value="accuracy.correct"
        :value-style="{ color: '#00b42a' }"
      />
      <a-statistic
        title="准确率"
        :value="accuracy.accuracy"
        suffix="%"
        :precision="1"
        :value-style="{ color: '#ff7d00' }"
      />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import { useFeedbackClassification } from '@/composables/useFeedbackClassification';
import type { FeedbackType, FeedbackSeverity } from '@/types/quality-center';

interface Props {
  title: string;
  content: string;
  autoClassify?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  autoClassify: true,
});

const emit = defineEmits<{
  apply: [result: any];
  addTag: [tag: string];
  viewSimilar: [id: number];
  referSolution: [feedback: any];
}>();

const {
  loading,
  classificationResult,
  similarFeedbacks,
  tagSuggestions,
  classifyFeedback,
  findSimilarFeedbacks,
  suggestTags,
  getClassificationAccuracy,
} = useFeedbackClassification();

const accuracy = computed(() => getClassificationAccuracy());

// 执行分类
const performClassification = async () => {
  if (!props.title && !props.content) return;

  try {
    await Promise.all([
      classifyFeedback(props.title, props.content),
      findSimilarFeedbacks(props.title, props.content),
      suggestTags(props.title, props.content),
    ]);
  } catch (error: any) {
    Message.error(`分类失败: ${error.message}`);
  }
};

// 应用分类结果
const handleApplyClassification = () => {
  if (!classificationResult.value) return;
  emit('apply', classificationResult.value);
  Message.success('已应用分类结果');
};

// 重新分类
const handleReClassify = () => {
  performClassification();
};

// 添加标签
const handleAddTag = (tag: string) => {
  emit('addTag', tag);
  Message.success(`已添加标签: ${tag}`);
};

// 查看相似反馈
const handleViewSimilar = (id: number) => {
  emit('viewSimilar', id);
};

// 参考解决方案
const handleReferSolution = (feedback: any) => {
  emit('referSolution', feedback);
  Message.success('已参考解决方案');
};

// 类型相关
const getTypeText = (type: FeedbackType) => {
  const map: Record<FeedbackType, string> = {
    bug: 'Bug',
    feature: '功能建议',
    improvement: '改进建议',
    question: '问题咨询',
  };
  return map[type];
};

const getTypeColor = (type: FeedbackType) => {
  const map: Record<FeedbackType, string> = {
    bug: 'red',
    feature: 'blue',
    improvement: 'orange',
    question: 'purple',
  };
  return map[type];
};

// 严重程度相关
const getSeverityText = (severity: FeedbackSeverity) => {
  const map: Record<FeedbackSeverity, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return map[severity];
};

const getSeverityColor = (severity: FeedbackSeverity) => {
  const map: Record<FeedbackSeverity, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return map[severity];
};

// 状态相关
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    pending: '待处理',
    in_progress: '处理中',
    resolved: '已解决',
    closed: '已关闭',
    rejected: '已拒绝',
  };
  return map[status] || status;
};

const getStatusColor = (status: string) => {
  const map: Record<string, string> = {
    pending: 'gray',
    in_progress: 'blue',
    resolved: 'green',
    closed: 'arcoblue',
    rejected: 'red',
  };
  return map[status] || 'gray';
};

// 监听标题和内容变化
watch(
  () => [props.title, props.content],
  () => {
    if (props.autoClassify) {
      performClassification();
    }
  },
  { immediate: true }
);
</script>

<style scoped lang="less">
.smart-classification-panel {
  .classification-card,
  .tags-card,
  .similar-card,
  .accuracy-card {
    margin-bottom: 16px;
  }

  .actions {
    margin-top: 16px;
    text-align: right;
  }

  .confidence-text {
    font-size: 12px;
    color: var(--color-text-3);
  }

  .similar-info {
    .similarity,
    .resolution {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 4px;

      .label {
        color: var(--color-text-3);
        font-size: 12px;
      }

      .value {
        color: var(--color-text-2);
        font-size: 12px;
      }
    }
  }

  .text-placeholder {
    color: var(--color-text-3);
  }

  .accuracy-card {
    :deep(.arco-statistic) {
      margin-bottom: 16px;

      &:last-child {
        margin-bottom: 0;
      }
    }
  }
}
</style>
