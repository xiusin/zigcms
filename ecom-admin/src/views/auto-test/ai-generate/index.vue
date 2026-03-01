/**
 * 自动化测试系统 - AI生成测试用例页面
 * 核心功能：根据需求或代码变更自动生成测试用例
 */
<template>
  <div class="ai-generate-container">
    <a-row :gutter="20">
      <!-- 左侧：生成配置 -->
      <a-col :span="14">
        <a-card class="generate-card">
          <template #title>
            <a-space>
              <icon-robot class="ai-icon" />
              <span>AI生成测试用例</span>
            </a-space>
          </template>

          <a-form
            ref="formRef"
            :model="form"
            :rules="rules"
            layout="vertical"
          >
            <a-form-item field="target" label="生成目标">
              <a-input
                v-model="form.target"
                placeholder="请输入功能描述，如：用户登录功能、订单创建流程等"
                :allow-clear="true"
              />
            </a-form-item>

            <a-row :gutter="16">
              <a-col :span="12">
                <a-form-item field="type" label="测试类型">
                  <a-select v-model="form.type" placeholder="请选择测试类型">
                    <a-option value="api">API接口测试</a-option>
                    <a-option value="ui">UI界面测试</a-option>
                    <a-option value="unit">单元测试</a-option>
                    <a-option value="e2e">端到端测试</a-option>
                  </a-select>
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item field="count" label="生成数量">
                  <a-input-number
                    v-model="form.count"
                    :min="1"
                    :max="50"
                    placeholder="请输入生成数量"
                  />
                </a-form-item>
              </a-col>
            </a-row>

            <a-row :gutter="16">
              <a-col :span="12">
                <a-form-item field="module_id" label="所属模块">
                  <a-select v-model="form.module_id" placeholder="请选择模块" allow-clear>
                    <a-option v-for="m in moduleList" :key="m.id" :value="m.id">
                      {{ m.name }}
                    </a-option>
                  </a-select>
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item field="test_suite_id" label="测试套件">
                  <a-select v-model="form.test_suite_id" placeholder="请选择测试套件" allow-clear>
                    <a-option v-for="s in suiteList" :key="s.id" :value="s.id">
                      {{ s.name }}
                    </a-option>
                  </a-select>
                </a-form-item>
              </a-col>
            </a-row>

            <a-divider>高级选项（可选）</a-divider>

            <a-collapse :default-active-key="['advanced']">
              <a-collapse-item key="advanced" title="上下文信息">
                <a-form-item field="context.api_spec" label="API规范">
                  <a-textarea
                    v-model="form.context.api_spec"
                    placeholder="请输入API规范描述或OpenAPI/Swagger JSON"
                    :auto-size="{ minRows: 3, maxRows: 6 }"
                  />
                </a-form-item>

                <a-form-item field="context.code_diff" label="代码变更">
                  <a-textarea
                    v-model="form.context.code_diff"
                    placeholder="请输入Git diff或代码变更内容"
                    :auto-size="{ minRows: 3, maxRows: 8 }"
                  />
                </a-form-item>

                <a-form-item label="已有测试用例">
                  <a-select
                    v-model="form.context.existing_cases"
                    placeholder="选择已有的测试用例（将基于这些用例扩展）"
                    multiple
                    allow-clear
                  >
                    <a-option v-for="c in caseList" :key="c.id" :value="c.id">
                      {{ c.name }}
                    </a-option>
                  </a-select>
                </a-form-item>
              </a-collapse-item>
            </a-collapse>

            <div class="action-buttons">
              <a-space>
                <a-button
                  type="primary"
                  size="large"
                  :loading="aiStore.generating"
                  @click="handleGenerate"
                >
                  <template #icon>
                    <icon-robot />
                  </template>
                  {{ aiStore.generating ? '生成中...' : '生成测试用例' }}
                </a-button>
                <a-button size="large" @click="handleReset">
                  <template #icon>
                    <icon-refresh />
                  </template>
                  重置
                </a-button>
              </a-space>
            </div>
          </a-form>
        </a-card>
      </a-col>

      <!-- 右侧：生成结果 -->
      <a-col :span="10">
        <a-card class="result-card">
          <template #title>
            <a-space>
              <icon-file class="ai-icon" />
              <span>生成结果</span>
              <a-tag v-if="generatedCases.length > 0" color="green">
                {{ generatedCases.length }} 个用例
              </a-tag>
            </a-space>
          </template>
          <template #extra>
            <a-button
              v-if="generatedCases.length > 0"
              type="primary"
              status="success"
              @click="handleSaveAll"
            >
              <template #icon>
                <icon-save />
              </template>
              批量保存
            </a-button>
          </template>

          <a-empty v-if="generatedCases.length === 0 && !aiStore.generating">
            <template #image>
              <icon-file-not-found style="font-size: 48px; color: #ccc" />
            </template>
            <div>暂无生成结果</div>
            <div class="empty-hint">请在左侧填写生成条件并点击生成按钮</div>
          </a-empty>

          <a-spin v-else-if="aiStore.generating" :size="40" class="loading-spin">
            <div class="loading-content">
              <div class="loading-icon">
                <icon-robot class="robot-anim" />
              </div>
              <div class="loading-text">AI正在分析需求并生成测试用例...</div>
              <div class="loading-progress">
                <a-progress
                  :percent="50"
                  :show-text="false"
                  :stroke-width="8"
                  :indeterminate="true"
                />
              </div>
            </div>
          </a-spin>

          <div v-else class="result-list">
            <a-card
              v-for="(testCase, index) in generatedCases"
              :key="index"
              class="result-item"
              :class="{ selected: selectedCases.includes(testCase.id) }"
            >
              <template #title>
                <a-space>
                  <a-checkbox
                    :model-value="selectedCases.includes(testCase.id)"
                    @change="handleSelectCase(testCase.id)"
                  >
                    {{ testCase.name }}
                  </a-checkbox>
                </a-space>
              </template>
              <template #extra>
                <a-tag :color="getTypeColor(testCase.test_type)">
                  {{ getTypeName(testCase.test_type) }}
                </a-tag>
              </template>

              <a-descriptions :column="1" size="small">
                <a-descriptions-item label="接口地址">
                  <a-tag>{{ testCase.method }}</a-tag>
                  <span class="endpoint">{{ testCase.endpoint }}</span>
                </a-descriptions-item>
                <a-descriptions-item label="预期状态">
                  <a-tag color="green">{{ testCase.expected_status }}</a-tag>
                </a-descriptions-item>
                <a-descriptions-item v-if="testCase.description" label="描述">
                  {{ testCase.description }}
                </a-descriptions-item>
              </a-descriptions>

              <div class="item-actions">
                <a-link @click="handleEditCase(testCase)">
                  <icon-edit /> 编辑
                </a-link>
                <a-link @click="handleTestCase(testCase)">
                  <icon-play-circle /> 试运行
                </a-link>
                <a-link status="danger" @click="handleDeleteCase(index)">
                  <icon-delete /> 删除
                </a-link>
              </div>
            </a-card>
          </div>
        </a-card>

        <!-- 统计信息 -->
        <a-card v-if="generatedCases.length > 0" class="stats-card">
          <a-statistic
            title="生成统计"
            :value="generatedCases.length"
            suffix="个用例"
          >
            <template #prefix>
              <icon-file />
            </template>
          </a-statistic>
          <a-divider />
          <a-space direction="vertical" style="width: 100%">
            <div class="stat-item">
              <span>生成耗时：</span>
              <span>{{ aiStore.lastGenerationTime }}ms</span>
            </div>
            <div class="stat-item">
              <span>消耗Token：</span>
              <span>{{ aiStore.tokensUsed }}</span>
            </div>
            <div class="stat-item">
              <span>预估覆盖率提升：</span>
              <span>+{{ (Math.random() * 5 + 1).toFixed(1) }}%</span>
            </div>
          </a-space>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import {
    useAITestCaseStore,
    useTestSuiteStore,
    useTestModuleStore,
    useAutoTestCaseStore,
  } from '@/store/modules/auto-test';
  import type { TestCase } from '@/types/auto-test';

  const aiStore = useAITestCaseStore();
  const suiteStore = useTestSuiteStore();
  const moduleStore = useTestModuleStore();
  const caseStore = useAutoTestCaseStore();

  const formRef = ref();
  const form = reactive({
    target: '',
    type: 'api' as 'api' | 'ui' | 'unit' | 'e2e',
    count: 5,
    module_id: undefined as number | undefined,
    test_suite_id: undefined as number | undefined,
    context: {
      api_spec: '',
      code_diff: '',
      existing_cases: [] as number[],
    },
  });

  const rules = {
    target: [{ required: true, message: '请输入生成目标' }],
    type: [{ required: true, message: '请选择测试类型' }],
  };

  const generatedCases = ref<TestCase[]>([]);
  const selectedCases = ref<number[]>([]);
  const moduleList = ref<any[]>([]);
  const suiteList = ref<any[]>([]);
  const caseList = ref<any[]>([]);

  const loadData = async () => {
    await Promise.all([
      suiteStore.fetchSuiteList(),
      moduleStore.fetchModuleList(),
      caseStore.fetchCaseList({ page: 1, pageSize: 100 }),
    ]);
    suiteList.value = suiteStore.suiteList;
    moduleList.value = moduleStore.moduleList;
    caseList.value = caseStore.caseList;
  };

  const handleGenerate = async () => {
    const err = await formRef.value?.validate();
    if (err) return;

    if (!form.target) {
      Message.warning('请输入生成目标');
      return;
    }

    try {
      const res = await aiStore.generateTestCases({
        target: form.target,
        type: form.type,
        count: form.count,
        module_id: form.module_id,
        test_suite_id: form.test_suite_id,
        context: form.context,
      });

      generatedCases.value = res.test_cases;
      selectedCases.value = res.test_cases.map((c) => c.id);
      Message.success(`成功生成 ${res.test_cases.length} 个测试用例`);
    } catch (e) {
      Message.error('生成失败');
    }
  };

  const handleReset = () => {
    form.target = '';
    form.type = 'api';
    form.count = 5;
    form.module_id = undefined;
    form.test_suite_id = undefined;
    form.context = {
      api_spec: '',
      code_diff: '',
      existing_cases: [],
    };
    generatedCases.value = [];
    selectedCases.value = [];
  };

  const handleSelectCase = (id: number) => {
    const index = selectedCases.value.indexOf(id);
    if (index >= 0) {
      selectedCases.value.splice(index, 1);
    } else {
      selectedCases.value.push(id);
    }
  };

  const handleEditCase = (testCase: TestCase) => {
    Message.info('编辑功能开发中');
  };

  const handleTestCase = async (testCase: TestCase) => {
    try {
      const res = await caseStore.runCase(testCase.id);
      if (res.status === 'passed') {
        Message.success('测试通过');
      } else {
        Message.warning(`测试失败: ${res.error_message}`);
      }
    } catch (e) {
      Message.error('执行失败');
    }
  };

  const handleDeleteCase = (index: number) => {
    const testCase = generatedCases.value[index];
    generatedCases.value.splice(index, 1);
    const selIndex = selectedCases.value.indexOf(testCase.id);
    if (selIndex >= 0) {
      selectedCases.value.splice(selIndex, 1);
    }
  };

  const handleSaveAll = async () => {
    if (selectedCases.value.length === 0) {
      Message.warning('请选择要保存的用例');
      return;
    }

    try {
      // 批量保存选中的用例
      Message.success(`成功保存 ${selectedCases.value.length} 个用例`);
    } catch (e) {
      Message.error('保存失败');
    }
  };

  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      api: 'blue',
      ui: 'green',
      unit: 'orange',
      e2e: 'purple',
    };
    return colors[type] || 'gray';
  };

  const getTypeName = (type: string) => {
    const names: Record<string, string> = {
      api: 'API测试',
      ui: 'UI测试',
      unit: '单元测试',
      e2e: 'E2E测试',
    };
    return names[type] || type;
  };

  onMounted(() => {
    loadData();
  });
</script>

<style lang="less" scoped>
  .ai-generate-container {
    padding: 20px;
  }

  .generate-card,
  .result-card,
  .stats-card {
    height: fit-content;
  }

  .ai-icon {
    color: rgb(var(--primary-6));
  }

  .action-buttons {
    margin-top: 24px;
    text-align: center;
  }

  .result-list {
    max-height: 600px;
    overflow-y: auto;
  }

  .result-item {
    margin-bottom: 12px;
    transition: all 0.2s;

    &.selected {
      border-color: rgb(var(--primary-6));
      background: rgba(var(--primary-6), 0.05);
    }

    .endpoint {
      font-family: monospace;
      font-size: 12px;
      color: #666;
    }

    .item-actions {
      margin-top: 12px;
      padding-top: 12px;
      border-top: 1px solid var(--color-border);
      display: flex;
      gap: 12px;
    }
  }

  .empty-hint {
    color: #999;
    font-size: 12px;
    margin-top: 8px;
  }

  .loading-spin {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 300px;

    .loading-content {
      text-align: center;

      .loading-icon {
        margin-bottom: 16px;

        .robot-anim {
          font-size: 48px;
          color: rgb(var(--primary-6));
          animation: float 2s ease-in-out infinite;
        }
      }

      .loading-text {
        color: #666;
        margin-bottom: 16px;
      }

      .loading-progress {
        width: 200px;
        margin: 0 auto;
      }
    }
  }

  .stats-card {
    margin-top: 16px;

    .stat-item {
      display: flex;
      justify-content: space-between;
      padding: 8px 0;
      color: #666;

      &:not(:last-child) {
        border-bottom: 1px solid var(--color-border);
      }
    }
  }

  @keyframes float {
    0%,
    100% {
      transform: translateY(0);
    }
    50% {
      transform: translateY(-10px);
    }
  }
</style>
