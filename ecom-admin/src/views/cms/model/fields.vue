<template>
  <div class="cms-field-manager">
    <a-card title="字段管理">
      <template #extra>
        <a-space>
          <a-button @click="goBack"> <icon-left /> 返回模型列表 </a-button>
          <a-button type="primary" @click="showAddFieldModal">
            <icon-plus /> 新增字段
          </a-button>
        </a-space>
      </template>

      <a-alert type="warning" style="margin-bottom: 16px">
        字段变更会影响已有数据，请谨慎操作。删除字段会同时删除该字段的所有数据。
      </a-alert>

      <a-table
        :data="fields"
        :loading="loading"
        :pagination="false"
        row-key="id"
        :draggable="{ type: 'handle', width: 40 }"
        @change="handleSort"
      >
        <template #columns>
          <a-table-column title="排序" :width="80">
            <template #cell>
              <icon-drag-dot-vertical />
            </template>
          </a-table-column>
          <a-table-column title="字段名称" data-index="label" />
          <a-table-column title="字段标识">
            <template #cell="{ record }">
              <a-tag color="blue">{{ record.key }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="字段类型">
            <template #cell="{ record }">
              {{ getFieldTypeLabel(record.type) }}
            </template>
          </a-table-column>
          <a-table-column title="必填" :width="80">
            <template #cell="{ record }">
              <a-tag :color="record.required ? 'red' : 'gray'">
                {{ record.required ? '是' : '否' }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="唯一" :width="80">
            <template #cell="{ record }">
              <a-tag :color="record.unique ? 'orange' : 'gray'">
                {{ record.unique ? '是' : '否' }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="可搜索" :width="80">
            <template #cell="{ record }">
              <a-tag :color="record.searchable ? 'green' : 'gray'">
                {{ record.searchable ? '是' : '否' }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="操作" :width="200">
            <template #cell="{ record, rowIndex }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="editField(record, rowIndex)"
                >
                  <icon-edit /> 编辑
                </a-button>
                <a-popconfirm
                  :content="`删除字段将删除所有内容中的【${record.label}】数据，确定删除吗？`"
                  @ok="deleteField(rowIndex)"
                >
                  <a-button type="text" size="small" status="danger">
                    <icon-delete /> 删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <!-- 新增/编辑字段弹窗 -->
    <a-modal
      v-model:visible="fieldModalVisible"
      :title="editingIndex === -1 ? '新增字段' : '编辑字段'"
      width="800px"
      @ok="handleFieldSubmit"
      @cancel="handleFieldCancel"
    >
      <a-form :model="fieldForm" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="字段名称" required>
              <a-input
                v-model="fieldForm.label"
                placeholder="如：标题、价格、封面图"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="字段标识" required>
              <a-input
                v-model="fieldForm.key"
                placeholder="英文标识，如：title、price"
                :disabled="editingIndex !== -1"
              />
              <template #extra>
                {{
                  editingIndex !== -1
                    ? '字段标识不可修改'
                    : '数据库字段名，创建后不可修改'
                }}
              </template>
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="字段类型" required>
          <a-select
            v-model="fieldForm.type"
            placeholder="选择字段类型"
            :disabled="editingIndex !== -1"
          >
            <a-optgroup label="文本类">
              <a-option value="text">单行文本</a-option>
              <a-option value="textarea">多行文本</a-option>
              <a-option value="richtext">富文本编辑器</a-option>
              <a-option value="markdown">Markdown</a-option>
            </a-optgroup>
            <a-optgroup label="数字类">
              <a-option value="number">数字</a-option>
              <a-option value="money">金额</a-option>
              <a-option value="percent">百分比</a-option>
            </a-optgroup>
            <a-optgroup label="日期类">
              <a-option value="date">日期</a-option>
              <a-option value="datetime">日期时间</a-option>
              <a-option value="time_range">时间范围</a-option>
            </a-optgroup>
            <a-optgroup label="选择类">
              <a-option value="select">下拉选择</a-option>
              <a-option value="radio">单选框</a-option>
              <a-option value="checkbox">多选框</a-option>
              <a-option value="switch">开关</a-option>
            </a-optgroup>
            <a-optgroup label="媒体类">
              <a-option value="image">图片上传</a-option>
              <a-option value="file">文件上传</a-option>
              <a-option value="video">视频上传</a-option>
            </a-optgroup>
            <a-optgroup label="其他">
              <a-option value="relation">关联内容</a-option>
              <a-option value="json">JSON对象</a-option>
              <a-option value="color">颜色选择器</a-option>
              <a-option value="rating">评分</a-option>
            </a-optgroup>
          </a-select>
          <template #extra v-if="editingIndex !== -1">
            字段类型不可修改
          </template>
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item>
              <a-checkbox v-model="fieldForm.required">必填</a-checkbox>
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item>
              <a-checkbox v-model="fieldForm.unique">唯一值</a-checkbox>
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item>
              <a-checkbox v-model="fieldForm.searchable">可搜索</a-checkbox>
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="默认值">
              <a-input
                v-model="fieldForm.default_value"
                placeholder="新建内容时的默认值"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="占位提示">
              <a-input
                v-model="fieldForm.placeholder"
                placeholder="输入框的提示文字"
              />
            </a-form-item>
          </a-col>
        </a-row>

        <!-- 文本类验证 -->
        <a-row
          :gutter="16"
          v-if="['text', 'textarea'].includes(fieldForm.type)"
        >
          <a-col :span="12">
            <a-form-item label="最小长度">
              <a-input-number
                v-model="fieldForm.validation_rules.min_length"
                :min="0"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="最大长度">
              <a-input-number
                v-model="fieldForm.validation_rules.max_length"
                :min="0"
              />
            </a-form-item>
          </a-col>
        </a-row>

        <!-- 数字类验证 -->
        <a-row
          :gutter="16"
          v-if="['number', 'money', 'percent'].includes(fieldForm.type)"
        >
          <a-col :span="12">
            <a-form-item label="最小值">
              <a-input-number v-model="fieldForm.validation_rules.min" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="最大值">
              <a-input-number v-model="fieldForm.validation_rules.max" />
            </a-form-item>
          </a-col>
        </a-row>

        <!-- 选择类选项 -->
        <a-form-item
          label="选项配置"
          v-if="['select', 'radio', 'checkbox'].includes(fieldForm.type)"
        >
          <a-textarea
            v-model="fieldForm.optionsText"
            placeholder="每行一个选项，格式：值:标签&#10;例如：&#10;1:选项一&#10;2:选项二"
            :rows="4"
          />
        </a-form-item>

        <a-form-item label="帮助说明">
          <a-textarea
            v-model="fieldForm.help_text"
            placeholder="字段的详细说明"
            :max-length="200"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted } from 'vue';
  import { useRoute, useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { getModelDetail, updateModel } from '@/api/cms';
  import type { ModelField } from '@/types/cms';

  const route = useRoute();
  const router = useRouter();
  const modelId = Number(route.params.modelId);

  const loading = ref(false);
  const fields = ref<ModelField[]>([]);
  const fieldModalVisible = ref(false);
  const editingIndex = ref(-1);

  const fieldForm = reactive<any>({
    label: '',
    key: '',
    type: 'text',
    required: false,
    unique: false,
    searchable: false,
    default_value: '',
    placeholder: '',
    help_text: '',
    validation_rules: {},
    optionsText: '',
  });

  const fieldTypeLabels: Record<string, string> = {
    text: '单行文本',
    textarea: '多行文本',
    richtext: '富文本',
    markdown: 'Markdown',
    number: '数字',
    money: '金额',
    percent: '百分比',
    date: '日期',
    datetime: '日期时间',
    time_range: '时间范围',
    select: '下拉选择',
    radio: '单选框',
    checkbox: '多选框',
    switch: '开关',
    image: '图片',
    file: '文件',
    video: '视频',
    relation: '关联内容',
    json: 'JSON',
    color: '颜色',
    rating: '评分',
  };

  const getFieldTypeLabel = (type: string) => {
    return fieldTypeLabels[type] || type;
  };

  const loadFields = async () => {
    loading.value = true;
    try {
      const res = await getModelDetail(modelId);
      fields.value = res.data.data.fields || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  const showAddFieldModal = () => {
    editingIndex.value = -1;
    resetFieldForm();
    fieldModalVisible.value = true;
  };

  const editField = (field: ModelField, index: number) => {
    editingIndex.value = index;
    Object.assign(fieldForm, {
      ...field,
      validation_rules: field.validation_rules || {},
      optionsText:
        field.options?.map((o) => `${o.value}:${o.label}`).join('\n') || '',
    });
    fieldModalVisible.value = true;
  };

  const deleteField = async (index: number) => {
    fields.value.splice(index, 1);
    await saveFields();
    Message.success('字段已删除');
  };

  const handleSort = (data: any) => {
    fields.value = data;
    saveFields();
  };

  const handleFieldSubmit = async () => {
    if (!fieldForm.label || !fieldForm.key || !fieldForm.type) {
      Message.warning('请填写必填项');
      return;
    }

    const newField: ModelField = {
      id:
        editingIndex.value === -1
          ? Date.now()
          : fields.value[editingIndex.value].id,
      label: fieldForm.label,
      key: fieldForm.key,
      type: fieldForm.type,
      required: fieldForm.required,
      unique: fieldForm.unique,
      searchable: fieldForm.searchable,
      default_value: fieldForm.default_value,
      placeholder: fieldForm.placeholder,
      help_text: fieldForm.help_text,
      validation_rules: fieldForm.validation_rules,
      sort:
        editingIndex.value === -1
          ? fields.value.length + 1
          : fields.value[editingIndex.value].sort,
    };

    // 解析选项
    if (
      ['select', 'radio', 'checkbox'].includes(fieldForm.type) &&
      fieldForm.optionsText
    ) {
      newField.options = fieldForm.optionsText
        .split('\n')
        .map((line: string) => {
          const [value, label] = line.split(':');
          return { value: value.trim(), label: label?.trim() || value.trim() };
        });
    }

    if (editingIndex.value === -1) {
      fields.value.push(newField);
    } else {
      fields.value[editingIndex.value] = newField;
    }

    await saveFields();
    fieldModalVisible.value = false;
    Message.success(editingIndex.value === -1 ? '字段已添加' : '字段已更新');
  };

  const handleFieldCancel = () => {
    fieldModalVisible.value = false;
    resetFieldForm();
  };

  const resetFieldForm = () => {
    Object.assign(fieldForm, {
      label: '',
      key: '',
      type: 'text',
      required: false,
      unique: false,
      searchable: false,
      default_value: '',
      placeholder: '',
      help_text: '',
      validation_rules: {},
      optionsText: '',
    });
  };

  const saveFields = async () => {
    try {
      await updateModel(modelId, { fields: fields.value });
    } catch (error) {
      Message.error('保存失败');
    }
  };

  const goBack = () => {
    router.push('/cms/model');
  };

  onMounted(() => {
    loadFields();
  });
</script>

<style scoped>
  .cms-field-manager {
    padding: 20px;
  }
</style>
